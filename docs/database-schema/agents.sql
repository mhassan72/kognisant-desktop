-- =============================================================================
-- Kognisant Desktop — Agents Database Schema
-- Location: ~/.kc/state/agents.db
-- Purpose:  Agent society persistent state — configs, confidence, strategy
--           weights, performance metrics, and coalition records.
--           Read-heavy with periodic metric updates after each action.
-- =============================================================================

-- SQLite Pragmas (applied at connection open, not stored in schema)
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;
PRAGMA cache_size = -64000;
PRAGMA mmap_size = 268435456;
PRAGMA temp_store = MEMORY;

-- =============================================================================
-- Schema Version Tracking
-- =============================================================================

CREATE TABLE IF NOT EXISTS schema_version (
    version     INTEGER NOT NULL,
    applied_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    description TEXT NOT NULL
);

INSERT INTO schema_version (version, description) VALUES (1, 'Initial agents schema');

-- =============================================================================
-- Table: agents
-- Purpose: Agent configurations, confidence levels, and strategy weights.
--          Each of the 13 cognitive agents has a persistent record tracking
--          its learned state across sessions.
-- =============================================================================

CREATE TABLE agents (
    id              INTEGER PRIMARY KEY,
    agent_id        TEXT NOT NULL UNIQUE,                                         -- UUID (stable across sessions)
    name            TEXT NOT NULL UNIQUE,                                         -- Agent name (e.g., 'PlannerAgent', 'CoderAgent')
    role            TEXT NOT NULL,                                                -- Human-readable role description
    agent_number    INTEGER NOT NULL UNIQUE CHECK (agent_number >= 1 AND agent_number <= 13), -- Fixed agent number (1-13)
    category        TEXT NOT NULL CHECK (category IN (
                        'core',         -- Essential on all tiers (Planner, Coder, Social, Safety)
                        'standard',     -- Available on Standard+ tiers
                        'optional'      -- Can be shed under resource pressure
                    )),
    -- Confidence and learning state
    confidence      REAL NOT NULL DEFAULT 0.5 CHECK (confidence >= 0.1 AND confidence <= 1.0), -- Current confidence (floor: 0.1)
    confidence_gain_rate REAL NOT NULL DEFAULT 0.1,                              -- α: how fast confidence grows on success
    confidence_loss_rate REAL NOT NULL DEFAULT 0.15,                             -- β: how fast confidence drops on failure (negativity bias)
    -- Strategy weights (learned approach preferences)
    strategy_weights TEXT NOT NULL DEFAULT '{}',                                  -- JSON: {"approach_name": weight, ...}
    -- Operational state
    status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
                        'active',       -- Running, generating bids
                        'dormant',      -- Not bidding, but perceiving (reactivates on signal)
                        'shed',         -- Temporarily disabled (resource pressure)
                        'suspended'     -- Temporarily disabled (pathology intervention)
                    )),
    shed_priority   INTEGER NOT NULL CHECK (shed_priority >= 1 AND shed_priority <= 14), -- Lower = shed first (1=CuriosityAgent, 14=SafetyAgent)
    -- Resource tracking
    consecutive_wins INTEGER NOT NULL DEFAULT 0,                                 -- Consecutive bid wins (for diminishing returns)
    effective_cost_multiplier REAL NOT NULL DEFAULT 1.0 CHECK (effective_cost_multiplier >= 1.0), -- Increases with consecutive wins
    last_bid_tick   INTEGER NOT NULL DEFAULT 0,                                  -- Tick of last bid
    last_win_tick   INTEGER NOT NULL DEFAULT 0,                                  -- Tick of last winning bid
    last_execution_tick INTEGER NOT NULL DEFAULT 0,                              -- Tick of last action execution
    -- Domain specialization
    domain_confidence TEXT NOT NULL DEFAULT '{}',                                 -- JSON: {"domain": confidence, ...}
    preferred_tools TEXT NOT NULL DEFAULT '[]',                                   -- JSON array of preferred tool names
    -- Folding (Minimal tier)
    folds_into      TEXT,                                                         -- Agent name this folds into on Minimal tier
    is_folded       INTEGER NOT NULL DEFAULT 0 CHECK (is_folded IN (0, 1)),      -- Whether currently folded
    -- Suspension tracking
    suspended_until_tick INTEGER NOT NULL DEFAULT 0,                             -- If suspended, when to reactivate
    suspension_reason TEXT,                                                       -- Why suspended
    metadata        TEXT NOT NULL DEFAULT '{}',                                   -- Additional JSON state
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find active agents for bid generation
CREATE INDEX idx_agents_status ON agents(status) WHERE status = 'active';

-- Query pattern: find agents by shed priority (for resource pressure response)
CREATE INDEX idx_agents_shed_priority ON agents(shed_priority)
    WHERE status = 'active';

-- Query pattern: find agents by category
CREATE INDEX idx_agents_category ON agents(category);

-- Query pattern: find suspended agents (check if suspension expired)
CREATE INDEX idx_agents_suspended ON agents(suspended_until_tick)
    WHERE status = 'suspended';

-- Seed the 13 agents with initial state
INSERT INTO agents (agent_id, name, role, agent_number, category, shed_priority, preferred_tools) VALUES
    ('00000000-0000-0000-0000-000000000001', 'PlannerAgent', 'Long-horizon task decomposition and sequencing', 1, 'core', 12, '["file_read", "search_text", "search_semantic"]'),
    ('00000000-0000-0000-0000-000000000002', 'CoderAgent', 'Code generation, modification, and completion', 2, 'core', 11, '["file_write", "file_read", "shell_exec", "search_text"]'),
    ('00000000-0000-0000-0000-000000000003', 'DebuggerAgent', 'Error diagnosis, root cause analysis, fix generation', 3, 'standard', 9, '["shell_exec", "file_read", "search_text"]'),
    ('00000000-0000-0000-0000-000000000004', 'ResearchAgent', 'Information gathering, documentation lookup', 4, 'optional', 8, '["search_semantic", "search_text", "file_read", "llm_query"]'),
    ('00000000-0000-0000-0000-000000000005', 'RefactorAgent', 'Code quality improvement, architecture optimization', 5, 'optional', 2, '["file_write", "file_read", "search_text"]'),
    ('00000000-0000-0000-0000-000000000006', 'TestAgent', 'Test generation, execution, coverage analysis', 6, 'optional', 7, '["shell_exec", "file_write", "file_read"]'),
    ('00000000-0000-0000-0000-000000000007', 'ExplainAgent', 'Documentation generation, concept explanation', 7, 'optional', 3, '["file_read", "search_semantic", "llm_query"]'),
    ('00000000-0000-0000-0000-000000000008', 'MetaAgent', 'Monitors other agents, suggests improvements', 8, 'optional', 5, '["search_semantic"]'),
    ('00000000-0000-0000-0000-000000000009', 'CuriosityAgent', 'Exploratory goals, prevents epistemic closure', 9, 'optional', 1, '["file_read", "search_text", "search_semantic"]'),
    ('00000000-0000-0000-0000-00000000000a', 'SafetyAgent', 'Veto dangerous actions (cannot be disabled)', 10, 'core', 14, '[]'),
    ('00000000-0000-0000-0000-00000000000b', 'SocialAgent', 'User relationship, tone, rapport management', 11, 'core', 13, '["llm_query"]'),
    ('00000000-0000-0000-0000-00000000000c', 'MemoryAgent', 'Memory organization, consolidation management', 12, 'optional', 4, '["memory_write", "search_semantic"]'),
    ('00000000-0000-0000-0000-00000000000d', 'SkillMiningAgent', 'Pattern extraction, skill candidate generation', 13, 'standard', 6, '["journal_append", "skill_suggest", "search_semantic"]');

-- =============================================================================
-- Table: agent_metrics
-- Purpose: Performance tracking per agent. Records bids won, success rate,
--          average execution time, and other metrics used for confidence
--          updates and MetaAgent monitoring.
-- =============================================================================

CREATE TABLE agent_metrics (
    id              INTEGER PRIMARY KEY,
    metric_id       TEXT NOT NULL UNIQUE,                                         -- UUID
    agent_id        TEXT NOT NULL,                                                -- UUID ref to agents table
    period_type     TEXT NOT NULL CHECK (period_type IN (
                        'session',      -- Current session metrics
                        'daily',        -- Rolling 24-hour metrics
                        'weekly',       -- Rolling 7-day metrics
                        'lifetime'      -- All-time metrics
                    )),
    period_start    TEXT NOT NULL,                                                -- ISO 8601 period start
    period_end      TEXT,                                                         -- ISO 8601 period end (NULL if current)
    -- Bid metrics
    bids_submitted  INTEGER NOT NULL DEFAULT 0,                                  -- Total bids generated
    bids_won        INTEGER NOT NULL DEFAULT 0,                                  -- Bids that won market resolution
    bid_win_rate    REAL NOT NULL DEFAULT 0.0 CHECK (bid_win_rate >= 0.0 AND bid_win_rate <= 1.0), -- Won / submitted
    avg_bid_score   REAL NOT NULL DEFAULT 0.0,                                   -- Average final_score of bids
    -- Execution metrics
    executions      INTEGER NOT NULL DEFAULT 0,                                  -- Times executed an action
    successes       INTEGER NOT NULL DEFAULT 0,                                  -- Successful executions
    failures        INTEGER NOT NULL DEFAULT 0,                                  -- Failed executions
    success_rate    REAL NOT NULL DEFAULT 0.0 CHECK (success_rate >= 0.0 AND success_rate <= 1.0), -- Successes / executions
    avg_execution_ticks INTEGER NOT NULL DEFAULT 0,                              -- Average ticks per execution
    -- Resource metrics
    total_tokens_used INTEGER NOT NULL DEFAULT 0,                                -- LLM tokens consumed
    total_cost_usd  REAL NOT NULL DEFAULT 0.0 CHECK (total_cost_usd >= 0.0),     -- Total cost in USD
    avg_cost_per_execution REAL NOT NULL DEFAULT 0.0,                            -- Average cost per execution
    -- Coalition metrics
    coalitions_joined INTEGER NOT NULL DEFAULT 0,                                -- Times joined a coalition
    coalition_success_rate REAL NOT NULL DEFAULT 0.0,                            -- Success rate in coalitions
    -- Quality metrics
    user_approval_rate REAL NOT NULL DEFAULT 0.0,                                -- Rate of user-approved outputs
    user_edit_distance REAL NOT NULL DEFAULT 0.0,                                -- Average edit distance on outputs
    -- Pathology metrics
    times_suspended INTEGER NOT NULL DEFAULT 0,                                  -- Times suspended by immune system
    times_shed      INTEGER NOT NULL DEFAULT 0,                                  -- Times shed for resource pressure
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find metrics for a specific agent
CREATE INDEX idx_agent_metrics_agent ON agent_metrics(agent_id, period_type);

-- Query pattern: find current session metrics
CREATE INDEX idx_agent_metrics_period ON agent_metrics(period_type, period_start DESC);

-- Prevent duplicate metrics for same agent+period
CREATE UNIQUE INDEX uq_agent_metrics_agent_period ON agent_metrics(agent_id, period_type, period_start);

-- =============================================================================
-- Table: coalition_records
-- Purpose: Historical coalition outcomes from the agent perspective. Records
--          which agent combinations worked well together, enabling the system
--          to learn preferred coalition patterns over time.
-- =============================================================================

CREATE TABLE coalition_records (
    id              INTEGER PRIMARY KEY,
    record_id       TEXT NOT NULL UNIQUE,                                         -- UUID
    coalition_id    TEXT NOT NULL,                                                -- UUID ref to goals.db coalition_history
    agent_id        TEXT NOT NULL,                                                -- UUID of this agent's participation
    role_in_coalition TEXT NOT NULL DEFAULT 'member' CHECK (role_in_coalition IN (
                        'initiator',    -- Agent that triggered coalition formation
                        'member',       -- Regular coalition member
                        'leader'        -- Agent with highest bid in coalition
                    )),
    partner_agents  TEXT NOT NULL DEFAULT '[]',                                   -- JSON array of other agent UUIDs in coalition
    goal_type       TEXT NOT NULL DEFAULT '',                                     -- Type/category of goal pursued
    contribution_score REAL NOT NULL DEFAULT 0.5 CHECK (contribution_score >= 0.0 AND contribution_score <= 1.0), -- How much this agent contributed
    outcome         TEXT NOT NULL CHECK (outcome IN (
                        'success', 'partial', 'failure', 'dissolved', 'cancelled'
                    )),
    outcome_value   REAL NOT NULL DEFAULT 0.0,                                   -- Scalar outcome quality
    synergy_experienced REAL NOT NULL DEFAULT 1.0,                               -- Actual synergy vs expected
    would_repeat    INTEGER NOT NULL DEFAULT 1 CHECK (would_repeat IN (0, 1)),   -- Whether this combination should be repeated
    tick            INTEGER NOT NULL,                                             -- Tick of coalition formation
    duration_ticks  INTEGER NOT NULL DEFAULT 0,                                  -- How long coalition lasted
    lessons_learned TEXT NOT NULL DEFAULT '',                                     -- What was learned from this coalition
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find coalition records for an agent
CREATE INDEX idx_coalition_records_agent ON coalition_records(agent_id, tick DESC);

-- Query pattern: find successful coalitions (for formation heuristics)
CREATE INDEX idx_coalition_records_outcome ON coalition_records(outcome)
    WHERE outcome = 'success';

-- Query pattern: find records by coalition ID
CREATE INDEX idx_coalition_records_coalition ON coalition_records(coalition_id);

-- Query pattern: find records where agent would repeat (positive experiences)
CREATE INDEX idx_coalition_records_repeat ON coalition_records(agent_id, would_repeat)
    WHERE would_repeat = 1;

-- Query pattern: find recent coalition experiences
CREATE INDEX idx_coalition_records_tick ON coalition_records(tick DESC);
