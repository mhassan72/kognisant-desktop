-- =============================================================================
-- Kognisant Desktop — World Model Database Schema
-- Location: ~/.kc/state/world_model.db
-- Purpose:  Beliefs, causal chains, social model, and simulation results.
--           Mixed reads/writes, graph traversals, frequent belief updates.
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

INSERT INTO schema_version (version, description) VALUES (1, 'Initial world model schema');

-- =============================================================================
-- Table: beliefs
-- Purpose: Propositions about the world with confidence, evidence, and
--          volatility. Beliefs decay over time unless re-confirmed. They
--          represent what the system thinks is true about the external world.
-- =============================================================================

CREATE TABLE beliefs (
    id              INTEGER PRIMARY KEY,
    belief_id       TEXT NOT NULL UNIQUE,                                         -- UUID for cross-db references
    proposition     TEXT NOT NULL,                                                -- The belief statement (natural language)
    category        TEXT NOT NULL CHECK (category IN (
                        'tool_behavior',    -- How tools/commands behave (half-life: ~83min)
                        'code_structure',   -- Project code organization (half-life: ~5.5h)
                        'user_preference',  -- User preferences (half-life: ~14h)
                        'domain_knowledge', -- Domain facts (half-life: ~28h)
                        'environment',      -- System environment state
                        'project_state',    -- Current project state
                        'social',           -- About the user (skill, mood)
                        'causal'            -- Causal relationship belief
                    )),
    confidence      REAL NOT NULL DEFAULT 0.5 CHECK (confidence >= 0.0 AND confidence <= 1.0), -- Current confidence level
    initial_confidence REAL NOT NULL DEFAULT 0.5,                                -- Confidence at creation
    evidence_count  INTEGER NOT NULL DEFAULT 1,                                  -- Observations supporting this belief
    contradicting_count INTEGER NOT NULL DEFAULT 0,                              -- Observations contradicting this belief
    volatility      REAL NOT NULL DEFAULT 0.5 CHECK (volatility >= 0.0 AND volatility <= 1.0), -- How often this changes (high = unstable)
    half_life_ticks INTEGER NOT NULL DEFAULT 200000,                             -- Decay half-life (category-dependent)
    last_confirmed_tick INTEGER NOT NULL DEFAULT 0,                              -- Tick of last confirming observation
    last_contradicted_tick INTEGER NOT NULL DEFAULT 0,                           -- Tick of last contradicting observation
    source_type     TEXT NOT NULL DEFAULT 'observed' CHECK (source_type IN (
                        'observed',     -- Directly observed
                        'inferred',     -- Inferred from other beliefs
                        'stated',       -- User explicitly stated
                        'default',      -- Default assumption
                        'simulated'     -- Result of simulation
                    )),
    source_evidence TEXT NOT NULL DEFAULT '[]',                                   -- JSON array of evidence references
    semantic_node_id TEXT,                                                       -- UUID ref to semantic.db node (if linked)
    embedding       BLOB,                                                        -- Embedding for similarity search
    embedding_dim   INTEGER,
    embedding_model TEXT,
    is_active       INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),       -- Whether belief is currently held
    superseded_by   TEXT,                                                         -- UUID of belief that replaced this one
    metadata        TEXT NOT NULL DEFAULT '{}',                                   -- Additional JSON context
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find active beliefs by category
CREATE INDEX idx_beliefs_category ON beliefs(category) WHERE is_active = 1;

-- Query pattern: find beliefs by confidence (for contradiction resolution priority)
CREATE INDEX idx_beliefs_confidence ON beliefs(confidence DESC) WHERE is_active = 1;

-- Query pattern: find stale beliefs (low confidence, old confirmation)
CREATE INDEX idx_beliefs_last_confirmed ON beliefs(last_confirmed_tick)
    WHERE is_active = 1;

-- Query pattern: find beliefs linked to semantic nodes
CREATE INDEX idx_beliefs_semantic_node ON beliefs(semantic_node_id)
    WHERE semantic_node_id IS NOT NULL;

-- Query pattern: find volatile beliefs (for frequent re-checking)
CREATE INDEX idx_beliefs_volatility ON beliefs(volatility DESC)
    WHERE is_active = 1;

-- =============================================================================
-- Table: causal_chains
-- Purpose: Cause→effect→mechanism relationships with strength and confounders.
--          Used for forward simulation, do-calculus, and counterfactual reasoning.
-- =============================================================================

CREATE TABLE causal_chains (
    id              INTEGER PRIMARY KEY,
    chain_id        TEXT NOT NULL UNIQUE,                                         -- UUID
    cause_belief_id INTEGER REFERENCES beliefs(id) ON DELETE SET NULL,            -- Cause node (belief reference)
    effect_belief_id INTEGER REFERENCES beliefs(id) ON DELETE SET NULL,           -- Effect node (belief reference)
    cause_description TEXT NOT NULL,                                              -- Natural language cause description
    effect_description TEXT NOT NULL,                                             -- Natural language effect description
    mechanism       TEXT NOT NULL DEFAULT '',                                     -- Human-readable explanation of how cause produces effect
    strength        REAL NOT NULL DEFAULT 0.5 CHECK (strength >= 0.0 AND strength <= 1.0), -- How reliably cause produces effect
    delay_ticks     INTEGER NOT NULL DEFAULT 0 CHECK (delay_ticks >= 0),          -- Ticks between cause and effect
    evidence_count  INTEGER NOT NULL DEFAULT 1,                                  -- Times this relationship observed
    last_observed_tick INTEGER NOT NULL DEFAULT 0,                                -- Tick of last confirmation
    confounders     TEXT NOT NULL DEFAULT '[]',                                   -- JSON array of confounder belief_ids
    is_interventional INTEGER NOT NULL DEFAULT 0 CHECK (is_interventional IN (0, 1)), -- Was this learned from active intervention (stronger evidence)
    domain          TEXT NOT NULL DEFAULT 'general',                              -- Domain context
    confidence      REAL NOT NULL DEFAULT 0.5 CHECK (confidence >= 0.0 AND confidence <= 1.0), -- Overall confidence in this causal link
    decay_rate      REAL NOT NULL DEFAULT 0.00001,                               -- Per-tick decay of strength
    status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
                        'active',       -- Valid causal relationship
                        'tentative',    -- Low evidence, needs confirmation
                        'weakened',     -- Contradicted but not removed
                        'pruned'        -- Removed
                    )),
    metadata        TEXT NOT NULL DEFAULT '{}',                                   -- Additional JSON (context, conditions)
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find causal chains from a cause (forward propagation)
CREATE INDEX idx_causal_chains_cause ON causal_chains(cause_belief_id)
    WHERE status = 'active';

-- Query pattern: find causal chains to an effect (backward reasoning)
CREATE INDEX idx_causal_chains_effect ON causal_chains(effect_belief_id)
    WHERE status = 'active';

-- Query pattern: find strong causal links (for simulation)
CREATE INDEX idx_causal_chains_strength ON causal_chains(strength DESC)
    WHERE status = 'active';

-- Query pattern: find tentative chains (for confirmation priority)
CREATE INDEX idx_causal_chains_status ON causal_chains(status)
    WHERE status = 'tentative';

-- Query pattern: find chains by domain
CREATE INDEX idx_causal_chains_domain ON causal_chains(domain)
    WHERE status = 'active';

-- Prevent duplicate causal links between same cause and effect
CREATE UNIQUE INDEX uq_causal_chains_cause_effect ON causal_chains(cause_belief_id, effect_belief_id)
    WHERE status = 'active' AND cause_belief_id IS NOT NULL AND effect_belief_id IS NOT NULL;

-- =============================================================================
-- Table: social_model
-- Purpose: User skill estimates, preferences, mood tracking. Bayesian user
--          model that adapts over time. Tracks per-domain skill levels,
--          communication preferences, and inferred mood.
-- =============================================================================

CREATE TABLE social_model (
    id              INTEGER PRIMARY KEY,
    entry_id        TEXT NOT NULL UNIQUE,                                         -- UUID
    aspect          TEXT NOT NULL CHECK (aspect IN (
                        'skill_level',      -- Per-domain skill assessment (Beta distribution)
                        'preference',       -- Communication/behavior preference
                        'mood_observation', -- Inferred mood data point
                        'engagement',       -- Engagement level tracking
                        'response_pattern', -- Response time/style patterns
                        'active_hours',     -- Activity probability per hour
                        'formality',        -- Communication formality level
                        'proactivity'       -- Tolerance for proactive suggestions
                    )),
    domain          TEXT NOT NULL DEFAULT 'general',                              -- Domain for skill_level (e.g., 'rust', 'frontend')
    -- Beta distribution parameters (for skill_level aspect)
    alpha           REAL NOT NULL DEFAULT 1.0 CHECK (alpha > 0.0),               -- Beta distribution α (successes + prior)
    beta_param      REAL NOT NULL DEFAULT 1.0 CHECK (beta_param > 0.0),          -- Beta distribution β (struggles + prior)
    -- Scalar value (for preference, formality, proactivity aspects)
    value           REAL NOT NULL DEFAULT 0.5 CHECK (value >= 0.0 AND value <= 1.0), -- Current estimated value
    -- Observation tracking
    observation_count INTEGER NOT NULL DEFAULT 0,                                -- Total observations
    last_observation_tick INTEGER NOT NULL DEFAULT 0,                            -- Tick of last observation
    confidence      REAL NOT NULL DEFAULT 0.5 CHECK (confidence >= 0.0 AND confidence <= 1.0), -- How confident in this estimate
    -- Decay (user preferences change over time)
    decay_rate      REAL NOT NULL DEFAULT 0.999,                                 -- Per-tick decay toward prior (very slow)
    -- Additional data
    evidence        TEXT NOT NULL DEFAULT '[]',                                   -- JSON array of observation references
    metadata        TEXT NOT NULL DEFAULT '{}',                                   -- Additional JSON (e.g., active_hours array)
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find skill levels by domain
CREATE INDEX idx_social_model_aspect_domain ON social_model(aspect, domain);

-- Query pattern: find all preferences
CREATE INDEX idx_social_model_aspect ON social_model(aspect);

-- Query pattern: find recently updated entries
CREATE INDEX idx_social_model_last_observation ON social_model(last_observation_tick DESC);

-- Prevent duplicate entries for same aspect+domain
CREATE UNIQUE INDEX uq_social_model_aspect_domain ON social_model(aspect, domain);

-- =============================================================================
-- Table: simulation_results
-- Purpose: Cached counterfactual outcomes from the mental sandbox. Simulations
--          are expensive (require causal propagation); caching avoids redundant
--          computation for similar scenarios.
-- =============================================================================

CREATE TABLE simulation_results (
    id              INTEGER PRIMARY KEY,
    simulation_id   TEXT NOT NULL UNIQUE,                                         -- UUID
    simulation_type TEXT NOT NULL CHECK (simulation_type IN (
                        'forward',          -- Forward causal propagation
                        'counterfactual',   -- "What if I had done X instead?"
                        'comparison',       -- Compare multiple alternatives
                        'intervention'      -- do(X) computation
                    )),
    context_tick    INTEGER NOT NULL,                                             -- Tick when simulation was run
    input_state     TEXT NOT NULL DEFAULT '{}',                                   -- JSON: belief state at simulation start
    action_simulated TEXT NOT NULL DEFAULT '{}',                                  -- JSON: action that was simulated
    alternative_action TEXT,                                                     -- JSON: alternative (for counterfactual)
    outcome         TEXT NOT NULL DEFAULT '{}',                                   -- JSON: predicted outcome
    expected_value  REAL NOT NULL DEFAULT 0.0,                                   -- Scalar value of outcome
    confidence      REAL NOT NULL DEFAULT 0.5 CHECK (confidence >= 0.0 AND confidence <= 1.0), -- Confidence in simulation accuracy
    steps_simulated INTEGER NOT NULL DEFAULT 0,                                  -- Propagation steps executed
    nodes_explored  INTEGER NOT NULL DEFAULT 0,                                  -- Graph nodes visited
    duration_ms     INTEGER NOT NULL DEFAULT 0,                                  -- Wall-clock time for simulation
    regret          REAL NOT NULL DEFAULT 0.0 CHECK (regret >= 0.0),             -- Regret value (counterfactual was better)
    relief          REAL NOT NULL DEFAULT 0.0 CHECK (relief >= 0.0),             -- Relief value (actual was better)
    used_for_decision INTEGER NOT NULL DEFAULT 0 CHECK (used_for_decision IN (0, 1)), -- Whether this informed an actual decision
    goal_id         TEXT,                                                         -- Goal this simulation served
    agent_id        TEXT,                                                         -- Agent that requested simulation
    is_valid        INTEGER NOT NULL DEFAULT 1 CHECK (is_valid IN (0, 1)),        -- Whether beliefs have changed since (invalidates cache)
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find recent simulations (for cache hits)
CREATE INDEX idx_simulation_results_tick ON simulation_results(context_tick DESC)
    WHERE is_valid = 1;

-- Query pattern: find simulations by type
CREATE INDEX idx_simulation_results_type ON simulation_results(simulation_type)
    WHERE is_valid = 1;

-- Query pattern: find simulations for a goal
CREATE INDEX idx_simulation_results_goal ON simulation_results(goal_id)
    WHERE goal_id IS NOT NULL;

-- Query pattern: find high-regret simulations (for learning)
CREATE INDEX idx_simulation_results_regret ON simulation_results(regret DESC)
    WHERE regret > 0.0;

-- Query pattern: invalidate stale simulations
CREATE INDEX idx_simulation_results_valid ON simulation_results(is_valid)
    WHERE is_valid = 0;
