-- =============================================================================
-- Kognisant Desktop — Goals Database Schema
-- Location: ~/.kc/state/goals.db
-- Purpose:  Goal market state — active/completed/abandoned goals with origin,
--           priority, assignment, hierarchy, bid history, and coalition records.
--           Frequent reads/writes during the deliberation phase (every tick).
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

INSERT INTO schema_version (version, description) VALUES (1, 'Initial goals schema');

-- =============================================================================
-- Table: goals
-- Purpose: Active, completed, and abandoned goals. Goals emerge from prediction
--          errors and compete in the goal market. Each goal has an origin,
--          priority, assignment, and lifecycle state.
-- =============================================================================

CREATE TABLE goals (
    id              INTEGER PRIMARY KEY,
    goal_id         TEXT NOT NULL UNIQUE,                                         -- UUID for cross-db references
    description     TEXT NOT NULL,                                                -- Human-readable goal description
    origin          TEXT NOT NULL CHECK (origin IN (
                        'UserRequest',      -- User explicitly asked for something
                        'PredictionError',  -- Layer 0-1 surprise
                        'CuriosityGap',     -- Layer 2 surprise, repeated pattern
                        'ValueGradient',    -- Layer 3-4, positive expected outcome
                        'Contradiction',    -- Conflicting beliefs detected
                        'Opportunity',      -- Pattern match to known improvement
                        'SelfImprovement',  -- L3 self-evaluation detects degradation
                        'SocialMaintenance', -- User engagement dropping
                        'Bootstrap',        -- Cold-start bootstrap goal
                        'Decomposition'     -- Sub-goal from parent decomposition
                    )),
    status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
                        'active',       -- Currently being pursued
                        'blocked',      -- Waiting on dependencies
                        'dormant',      -- Low priority, not actively pursued
                        'completed',    -- Successfully resolved
                        'abandoned',    -- Given up (see abandon_reason)
                        'subsumed'      -- Merged into another goal
                    )),
    priority        REAL NOT NULL DEFAULT 0.5 CHECK (priority >= 0.0 AND priority <= 1.0), -- Current priority (dynamic)
    initial_priority REAL NOT NULL DEFAULT 0.5,                                  -- Priority at creation
    urgency         REAL NOT NULL DEFAULT 0.5 CHECK (urgency >= 0.0 AND urgency <= 1.0), -- Urgency multiplier (escalates with age)
    expected_value  REAL NOT NULL DEFAULT 0.5 CHECK (expected_value >= 0.0 AND expected_value <= 1.0), -- Expected outcome value
    discounted_value REAL NOT NULL DEFAULT 0.5,                                  -- After temporal discounting
    confidence      REAL NOT NULL DEFAULT 0.5 CHECK (confidence >= 0.0 AND confidence <= 1.0), -- Belief that goal can be achieved
    estimated_ticks INTEGER NOT NULL DEFAULT 100,                                -- Estimated ticks to completion
    actual_ticks    INTEGER NOT NULL DEFAULT 0,                                  -- Ticks spent so far
    assigned_agent  TEXT,                                                         -- UUID of agent currently pursuing this goal
    assigned_coalition TEXT,                                                     -- UUID of coalition (if multi-agent)
    pp_layer        INTEGER CHECK (pp_layer >= 0 AND pp_layer <= 4),             -- PP layer that generated this goal
    surprise_value  REAL NOT NULL DEFAULT 0.0 CHECK (surprise_value >= 0.0),     -- Free energy that triggered this goal
    embedding       BLOB,                                                        -- Goal description embedding (for duplicate detection)
    embedding_dim   INTEGER,
    embedding_model TEXT,
    bypass_bidding  INTEGER NOT NULL DEFAULT 0 CHECK (bypass_bidding IN (0, 1)), -- Bootstrap goals bypass market
    abandon_reason  TEXT,                                                         -- Why goal was abandoned
    completion_outcome TEXT CHECK (completion_outcome IN (
                        'resolved', 'partial', 'failed', NULL
                    )),                                                           -- How goal was completed
    subsumed_by     TEXT,                                                         -- UUID of goal that absorbed this one
    session_id      TEXT,                                                         -- Session where goal was created
    metadata        TEXT NOT NULL DEFAULT '{}',                                   -- Additional JSON context
    created_at_tick INTEGER NOT NULL DEFAULT 0,                                  -- Tick when created
    completed_at_tick INTEGER,                                                   -- Tick when completed/abandoned
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find active goals for market resolution (every tick)
CREATE INDEX idx_goals_active_priority ON goals(priority DESC)
    WHERE status = 'active';

-- Query pattern: find goals by status
CREATE INDEX idx_goals_status ON goals(status);

-- Query pattern: find goals by origin type
CREATE INDEX idx_goals_origin ON goals(origin) WHERE status = 'active';

-- Query pattern: find goals assigned to a specific agent
CREATE INDEX idx_goals_agent ON goals(assigned_agent)
    WHERE assigned_agent IS NOT NULL AND status = 'active';

-- Query pattern: find blocked goals (check if dependencies resolved)
CREATE INDEX idx_goals_blocked ON goals(status) WHERE status = 'blocked';

-- Query pattern: find dormant goals (for urgency escalation)
CREATE INDEX idx_goals_dormant ON goals(created_at_tick)
    WHERE status = 'dormant';

-- Query pattern: find goals by session (for session replay)
CREATE INDEX idx_goals_session ON goals(session_id)
    WHERE session_id IS NOT NULL;

-- Query pattern: find old active goals (for abandonment check)
CREATE INDEX idx_goals_age ON goals(created_at_tick)
    WHERE status = 'active';

-- =============================================================================
-- Table: goal_hierarchy
-- Purpose: Parent-child relationships between goals. Goals decompose into
--          sub-goals forming a DAG. Parent goals complete when all required
--          children complete.
-- =============================================================================

CREATE TABLE goal_hierarchy (
    id              INTEGER PRIMARY KEY,
    parent_id       INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,      -- Parent goal
    child_id        INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,      -- Child (sub-goal)
    dependency_type TEXT NOT NULL DEFAULT 'requires' CHECK (dependency_type IN (
                        'requires',     -- Child must complete before parent can
                        'benefits',     -- Better if done first, not required
                        'conflicts',    -- Cannot run simultaneously with parent
                        'produces'      -- Child produces a resource parent needs
                    )),
    ordering        INTEGER NOT NULL DEFAULT 0,                                  -- Execution order among siblings
    is_required     INTEGER NOT NULL DEFAULT 1 CHECK (is_required IN (0, 1)),    -- Whether parent needs this child
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find children of a goal (decomposition view)
CREATE INDEX idx_goal_hierarchy_parent ON goal_hierarchy(parent_id, ordering);

-- Query pattern: find parent of a goal (upward traversal)
CREATE INDEX idx_goal_hierarchy_child ON goal_hierarchy(child_id);

-- Prevent duplicate parent-child relationships
CREATE UNIQUE INDEX uq_goal_hierarchy_parent_child ON goal_hierarchy(parent_id, child_id);

-- =============================================================================
-- Table: bid_history
-- Purpose: Agent bids per goal. Records all bids submitted to the goal market
--          for learning (which agents bid on what, who won, what happened).
--          Used for agent confidence updates and market dynamics analysis.
-- =============================================================================

CREATE TABLE bid_history (
    id              INTEGER PRIMARY KEY,
    bid_id          TEXT NOT NULL UNIQUE,                                         -- UUID
    goal_id         INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,      -- Goal being bid on
    agent_id        TEXT NOT NULL,                                                -- UUID of bidding agent
    tick            INTEGER NOT NULL,                                             -- Tick when bid was submitted
    expected_value  REAL NOT NULL CHECK (expected_value >= 0.0 AND expected_value <= 1.0), -- Agent's value estimate
    confidence      REAL NOT NULL CHECK (confidence >= 0.0 AND confidence <= 1.0), -- Agent's confidence
    expected_cost   REAL NOT NULL CHECK (expected_cost >= 0.0 AND expected_cost <= 1.0), -- Estimated resource cost
    urgency         REAL NOT NULL DEFAULT 0.5 CHECK (urgency >= 0.0 AND urgency <= 1.0), -- Bid urgency
    base_score      REAL NOT NULL DEFAULT 0.0,                                   -- Raw score before affect modulation
    final_score     REAL NOT NULL DEFAULT 0.0,                                   -- Score after affect modulation
    affect_multiplier REAL NOT NULL DEFAULT 1.0,                                 -- Affect modulation factor applied
    epistemic_value REAL NOT NULL DEFAULT 0.0 CHECK (epistemic_value >= 0.0),    -- Information gain value
    pragmatic_value REAL NOT NULL DEFAULT 0.0 CHECK (pragmatic_value >= 0.0),    -- Practical outcome value
    novelty_score   REAL NOT NULL DEFAULT 0.0 CHECK (novelty_score >= 0.0),      -- Novelty contribution
    won             INTEGER NOT NULL DEFAULT 0 CHECK (won IN (0, 1)),            -- Whether this bid won
    coalition_id    TEXT,                                                         -- UUID of coalition (if part of one)
    outcome         TEXT CHECK (outcome IN (
                        'success', 'partial', 'failure', 'cancelled', NULL
                    )),                                                           -- Outcome after execution (NULL if didn't win)
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find bids for a specific goal (market resolution)
CREATE INDEX idx_bid_history_goal_score ON bid_history(goal_id, final_score DESC);

-- Query pattern: find bids by agent (agent performance analysis)
CREATE INDEX idx_bid_history_agent ON bid_history(agent_id, tick DESC);

-- Query pattern: find winning bids (for learning)
CREATE INDEX idx_bid_history_won ON bid_history(won, outcome)
    WHERE won = 1;

-- Query pattern: find bids by tick (temporal analysis)
CREATE INDEX idx_bid_history_tick ON bid_history(tick DESC);

-- Query pattern: find coalition bids
CREATE INDEX idx_bid_history_coalition ON bid_history(coalition_id)
    WHERE coalition_id IS NOT NULL;

-- =============================================================================
-- Table: coalition_history
-- Purpose: Coalition formation records. When agents form coalitions for complex
--          goals, the formation and outcome are recorded for learning which
--          agent combinations work well together.
-- =============================================================================

CREATE TABLE coalition_history (
    id              INTEGER PRIMARY KEY,
    coalition_id    TEXT NOT NULL UNIQUE,                                         -- UUID
    goal_id         INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,      -- Goal the coalition pursued
    member_agents   TEXT NOT NULL DEFAULT '[]',                                   -- JSON array of agent UUIDs
    member_count    INTEGER NOT NULL DEFAULT 0 CHECK (member_count >= 2),         -- Number of agents in coalition
    formation_tick  INTEGER NOT NULL,                                             -- Tick when coalition formed
    dissolution_tick INTEGER,                                                    -- Tick when coalition dissolved
    synergy_bonus   REAL NOT NULL DEFAULT 1.0 CHECK (synergy_bonus >= 1.0),      -- Synergy multiplier applied
    coordination_cost REAL NOT NULL DEFAULT 0.0 CHECK (coordination_cost >= 0.0), -- Overhead cost
    combined_score  REAL NOT NULL DEFAULT 0.0,                                   -- Total coalition score
    complementarity_count INTEGER NOT NULL DEFAULT 0,                            -- Number of complementary bid pairs
    outcome         TEXT NOT NULL DEFAULT 'in_progress' CHECK (outcome IN (
                        'in_progress',  -- Currently executing
                        'success',      -- Coalition achieved goal
                        'partial',      -- Partially successful
                        'failure',      -- Coalition failed
                        'dissolved',    -- Dissolved before completion (timeout, conflict)
                        'cancelled'     -- Goal was cancelled/abandoned
                    )),
    outcome_value   REAL,                                                        -- Scalar outcome quality
    duration_ticks  INTEGER NOT NULL DEFAULT 0,                                  -- How long coalition was active
    pattern_type    TEXT CHECK (pattern_type IN (
                        'implement_feature',    -- Planner + Coder + Test
                        'debug_and_fix',        -- Debugger + Coder
                        'research_and_implement', -- Research + Coder
                        'explain_and_document', -- Explain + Coder
                        'quality_pass',         -- Refactor + Test
                        'custom',               -- Novel combination
                        NULL
                    )),                                                           -- Known coalition pattern type
    metadata        TEXT NOT NULL DEFAULT '{}',                                   -- Additional JSON context
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find coalitions for a goal
CREATE INDEX idx_coalition_history_goal ON coalition_history(goal_id);

-- Query pattern: find successful coalitions (for learning)
CREATE INDEX idx_coalition_history_outcome ON coalition_history(outcome)
    WHERE outcome = 'success';

-- Query pattern: find coalitions by pattern type (for formation heuristics)
CREATE INDEX idx_coalition_history_pattern ON coalition_history(pattern_type)
    WHERE pattern_type IS NOT NULL;

-- Query pattern: find recent coalitions
CREATE INDEX idx_coalition_history_formation ON coalition_history(formation_tick DESC);

-- Query pattern: find active coalitions
CREATE INDEX idx_coalition_history_active ON coalition_history(outcome)
    WHERE outcome = 'in_progress';
