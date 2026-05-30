-- =============================================================================
-- Kognisant Desktop — Procedural Memory Database Schema
-- Location: ~/.kc/state/memory_palace/procedural.db
-- Purpose:  Tier 4 procedural memory — condition→action→outcome chains.
--           Read-heavy (condition matching), infrequent writes.
--           Stores skills, habits, tool use patterns, and RL weights.
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

INSERT INTO schema_version (version, description) VALUES (1, 'Initial procedural memory schema');

-- =============================================================================
-- Table: procedures
-- Purpose: Skill/habit definitions. Each procedure is a condition→action→outcome
--          chain learned from repeated observations. Conditions are matched
--          against current context; actions are templates for execution.
-- =============================================================================

CREATE TABLE procedures (
    id                  INTEGER PRIMARY KEY,
    procedure_id        TEXT NOT NULL UNIQUE,                                     -- UUID for cross-db references
    name                TEXT NOT NULL,                                            -- Human-readable procedure name
    description         TEXT NOT NULL DEFAULT '',                                 -- What this procedure does
    category            TEXT NOT NULL CHECK (category IN (
                            'skill',        -- Learned skill (from skill mining)
                            'habit',        -- Automatic behavior pattern
                            'tool_use',     -- Tool usage pattern
                            'strategy',     -- High-level approach
                            'heuristic',    -- Rule of thumb
                            'anti_pattern'  -- Known bad pattern (negative example)
                        )),
    condition           TEXT NOT NULL DEFAULT '{}',                               -- JSON: context conditions for activation
    condition_embedding BLOB,                                                    -- Embedding of condition for similarity match
    condition_embedding_dim INTEGER,                                             -- Dimension of condition embedding
    condition_embedding_model TEXT,                                              -- Model used for condition embedding
    action_template     TEXT NOT NULL DEFAULT '{}',                               -- JSON: parameterized action template
    expected_outcome    TEXT NOT NULL DEFAULT '{}',                               -- JSON: predicted outcome if action succeeds
    success_rate        REAL NOT NULL DEFAULT 0.5 CHECK (success_rate >= 0.0 AND success_rate <= 1.0), -- Historical success rate
    execution_count     INTEGER NOT NULL DEFAULT 0,                              -- Times this procedure was executed
    last_executed_tick  INTEGER NOT NULL DEFAULT 0,                              -- Tick of last execution
    last_success_tick   INTEGER NOT NULL DEFAULT 0,                              -- Tick of last successful execution
    confidence          REAL NOT NULL DEFAULT 0.5 CHECK (confidence >= 0.0 AND confidence <= 1.0), -- How reliable this procedure is
    generalizability    REAL NOT NULL DEFAULT 0.5 CHECK (generalizability >= 0.0 AND generalizability <= 1.0), -- Cross-context applicability
    domain              TEXT NOT NULL DEFAULT 'general',                          -- Domain (e.g., 'rust', 'frontend', 'devops')
    tech_stack          TEXT NOT NULL DEFAULT '[]',                               -- JSON array of relevant technologies
    source_skill_id     TEXT,                                                    -- UUID ref to approved skill (if from skill mining)
    source_episodes     TEXT NOT NULL DEFAULT '[]',                               -- JSON array of source episode UUIDs
    activation          REAL NOT NULL DEFAULT 0.5 CHECK (activation >= 0.0),      -- Current activation level
    decay_rate          REAL NOT NULL DEFAULT 0.000005,                           -- Per-tick decay (very slow for procedures)
    half_life_ticks     INTEGER NOT NULL DEFAULT 140000,                          -- ~4 hours
    status              TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
                            'active',       -- Available for matching
                            'dormant',      -- Low activation, not actively matched
                            'deprecated',   -- Superseded by newer procedure
                            'pruned'        -- Marked for deletion
                        )),
    superseded_by       TEXT,                                                    -- UUID of newer version (if deprecated)
    created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find procedures by category for condition matching
CREATE INDEX idx_procedures_category_status ON procedures(category, status)
    WHERE status = 'active';

-- Query pattern: find procedures by domain
CREATE INDEX idx_procedures_domain ON procedures(domain) WHERE status = 'active';

-- Query pattern: find high-confidence procedures (for fast matching)
CREATE INDEX idx_procedures_confidence ON procedures(confidence DESC)
    WHERE status = 'active';

-- Query pattern: find procedures by success rate (for RL selection)
CREATE INDEX idx_procedures_success_rate ON procedures(success_rate DESC)
    WHERE status = 'active';

-- Query pattern: find procedures linked to a skill
CREATE INDEX idx_procedures_skill ON procedures(source_skill_id)
    WHERE source_skill_id IS NOT NULL;

-- Query pattern: find dormant procedures for potential reactivation
CREATE INDEX idx_procedures_activation ON procedures(activation)
    WHERE status IN ('active', 'dormant');

-- =============================================================================
-- Table: procedure_outcomes
-- Purpose: Execution history for RL updates. Each row records one execution
--          of a procedure with its context, result, and reward signal.
--          Used to update success_rate and RL weights.
-- =============================================================================

CREATE TABLE procedure_outcomes (
    id              INTEGER PRIMARY KEY,
    outcome_id      TEXT NOT NULL UNIQUE,                                         -- UUID
    procedure_id    INTEGER NOT NULL REFERENCES procedures(id) ON DELETE CASCADE, -- Which procedure was executed
    tick            INTEGER NOT NULL,                                             -- Tick of execution
    context         TEXT NOT NULL DEFAULT '{}',                                   -- JSON: context at execution time
    action_taken    TEXT NOT NULL DEFAULT '{}',                                   -- JSON: actual action (template instantiated)
    outcome         TEXT NOT NULL CHECK (outcome IN (
                        'success',      -- Action achieved expected outcome
                        'partial',      -- Partially successful
                        'failure',      -- Action failed
                        'timeout',      -- Action timed out
                        'cancelled',    -- Action was cancelled (approval denied)
                        'error'         -- Unexpected error during execution
                    )),
    reward_signal   REAL NOT NULL DEFAULT 0.0,                                   -- RL reward (-1.0 to 1.0)
    outcome_detail  TEXT NOT NULL DEFAULT '{}',                                   -- JSON: detailed outcome data
    surprise_delta  REAL NOT NULL DEFAULT 0.0,                                   -- Change in surprise after execution
    user_feedback   TEXT CHECK (user_feedback IN (
                        'positive', 'negative', 'neutral', NULL
                    )),                                                           -- Explicit user feedback if given
    execution_cost  REAL NOT NULL DEFAULT 0.0 CHECK (execution_cost >= 0.0),     -- Resource cost (tokens, time)
    duration_ticks  INTEGER NOT NULL DEFAULT 0,                                  -- How many ticks execution took
    agent_id        TEXT NOT NULL,                                                -- Which agent executed this
    goal_id         TEXT,                                                         -- Goal this execution served
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find outcomes for a specific procedure (for RL updates)
CREATE INDEX idx_procedure_outcomes_procedure ON procedure_outcomes(procedure_id, tick DESC);

-- Query pattern: find recent outcomes (for learning)
CREATE INDEX idx_procedure_outcomes_tick ON procedure_outcomes(tick DESC);

-- Query pattern: find outcomes by result type (for success rate computation)
CREATE INDEX idx_procedure_outcomes_outcome ON procedure_outcomes(outcome);

-- Query pattern: find outcomes with user feedback (high-value learning signal)
CREATE INDEX idx_procedure_outcomes_feedback ON procedure_outcomes(user_feedback)
    WHERE user_feedback IS NOT NULL;

-- =============================================================================
-- Table: rl_weights
-- Purpose: Q-values or contextual bandit weights per procedure. Stores the
--          learned value of executing each procedure in different contexts.
--          Updated after each outcome via TD(λ) learning.
-- =============================================================================

CREATE TABLE rl_weights (
    id              INTEGER PRIMARY KEY,
    weight_id       TEXT NOT NULL UNIQUE,                                         -- UUID
    procedure_id    INTEGER NOT NULL REFERENCES procedures(id) ON DELETE CASCADE, -- Which procedure
    context_key     TEXT NOT NULL,                                                -- Context feature key (e.g., 'domain:rust', 'error_type:compile')
    q_value         REAL NOT NULL DEFAULT 0.0,                                   -- Q-value for this (procedure, context) pair
    eligibility     REAL NOT NULL DEFAULT 0.0,                                   -- Eligibility trace for TD(λ)
    update_count    INTEGER NOT NULL DEFAULT 0,                                  -- Times this weight was updated
    last_updated_tick INTEGER NOT NULL DEFAULT 0,                                -- Tick of last update
    learning_rate   REAL NOT NULL DEFAULT 0.05 CHECK (learning_rate > 0.0 AND learning_rate <= 1.0), -- α
    discount_factor REAL NOT NULL DEFAULT 0.95 CHECK (discount_factor >= 0.0 AND discount_factor <= 1.0), -- γ
    trace_decay     REAL NOT NULL DEFAULT 0.8 CHECK (trace_decay >= 0.0 AND trace_decay <= 1.0), -- λ
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find all weights for a procedure (for action selection)
CREATE INDEX idx_rl_weights_procedure ON rl_weights(procedure_id);

-- Query pattern: find weights by context key (for contextual bandit)
CREATE INDEX idx_rl_weights_context ON rl_weights(context_key);

-- Prevent duplicate weights for same procedure+context
CREATE UNIQUE INDEX uq_rl_weights_procedure_context ON rl_weights(procedure_id, context_key);

-- Query pattern: find recently updated weights (for monitoring learning)
CREATE INDEX idx_rl_weights_last_updated ON rl_weights(last_updated_tick DESC);
