-- ============================================================================
-- Kognisant World Model Schema
-- Location: ~/.kognisant/projects/{id}/world_model.db
-- Purpose: The system's internal simulation of the world. Contains the belief
--          graph (what the system thinks is true), causal chains (cause-effect
--          relationships), social model (user preferences and state), and
--          simulation results (counterfactual runs and their outcomes).
-- ============================================================================

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA synchronous = NORMAL;

-- ============================================================================
-- BELIEF GRAPH — NODES
-- Nodes represent beliefs about the world. Each belief has a confidence level,
-- evidence count, and can be updated or contradicted by new observations.
-- Unlike semantic_nodes (which are concepts), these are propositions with
-- truth values.
-- ============================================================================

CREATE TABLE IF NOT EXISTS belief_nodes (
    id              INTEGER PRIMARY KEY,
    belief_id       TEXT NOT NULL UNIQUE,    -- Stable identifier (UUID)
    -- Belief content
    proposition     TEXT NOT NULL,           -- The belief statement (human-readable)
    category        TEXT NOT NULL,           -- 'factual', 'causal', 'preference', 'capability',
                                             -- 'state', 'prediction', 'assumption'
    domain          TEXT,                    -- Domain this belief applies to ('project', 'user', 'system', 'world')
    -- Confidence and evidence
    confidence      REAL NOT NULL DEFAULT 0.5, -- 0-1: how confident in this belief
    evidence_for    INTEGER NOT NULL DEFAULT 0, -- Observations supporting this belief
    evidence_against INTEGER NOT NULL DEFAULT 0, -- Observations contradicting this belief
    last_confirmed  INTEGER,                 -- Epoch ms when last confirmed by observation
    last_contradicted INTEGER,               -- Epoch ms when last contradicted
    -- Structured content
    structured_data TEXT,                    -- JSON: machine-readable belief representation
    embedding       BLOB,                   -- f32 array for similarity search
    embedding_dim   INTEGER,
    -- Source and provenance
    source          TEXT NOT NULL,           -- 'observed', 'inferred', 'told_by_user', 'llm_generated', 'default'
    source_tick     INTEGER,                 -- Tick when belief was formed
    source_evidence TEXT,                    -- JSON: what evidence formed this belief
    -- Dynamics
    volatility      REAL NOT NULL DEFAULT 0.5, -- How quickly this belief changes (0=stable, 1=volatile)
    importance      REAL NOT NULL DEFAULT 0.5, -- How much this belief matters for decisions
    -- Lifecycle
    is_active       INTEGER NOT NULL DEFAULT 1,
    archived_at     INTEGER,
    superseded_by   TEXT,                    -- belief_id of replacement belief
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: find beliefs by domain
CREATE INDEX idx_beliefs_domain ON belief_nodes(domain, category) WHERE is_active = 1;
-- Access pattern: find low-confidence beliefs (candidates for investigation)
CREATE INDEX idx_beliefs_confidence ON belief_nodes(confidence ASC) WHERE is_active = 1;
-- Access pattern: find recently contradicted beliefs
CREATE INDEX idx_beliefs_contradicted ON belief_nodes(last_contradicted DESC)
    WHERE last_contradicted IS NOT NULL AND is_active = 1;
-- Access pattern: importance-weighted queries
CREATE INDEX idx_beliefs_importance ON belief_nodes(importance DESC) WHERE is_active = 1;
-- Access pattern: find stale beliefs (not confirmed recently)
CREATE INDEX idx_beliefs_stale ON belief_nodes(last_confirmed ASC) WHERE is_active = 1;

-- ============================================================================
-- BELIEF GRAPH — EDGES
-- Relationships between beliefs. Edges carry causal strength, enabling
-- belief propagation (if A is true and A→B, then B is likely true).
-- ============================================================================

CREATE TABLE IF NOT EXISTS belief_edges (
    id              INTEGER PRIMARY KEY,
    source_belief_id TEXT NOT NULL,          -- FK to belief_nodes.belief_id
    target_belief_id TEXT NOT NULL,          -- FK to belief_nodes.belief_id
    -- Relationship
    relation_type   TEXT NOT NULL,           -- 'supports', 'contradicts', 'causes', 'requires',
                                             -- 'implies', 'correlates', 'depends_on', 'enables'
    -- Strength
    causal_strength REAL NOT NULL DEFAULT 0.5, -- 0-1: how strongly source affects target
    confidence      REAL NOT NULL DEFAULT 0.5, -- 0-1: how sure we are this edge exists
    evidence_count  INTEGER NOT NULL DEFAULT 1,
    -- Propagation
    propagation_delay INTEGER DEFAULT 0,     -- Ticks before effect propagates
    is_bidirectional INTEGER NOT NULL DEFAULT 0,
    -- Provenance
    source          TEXT NOT NULL DEFAULT 'inferred', -- 'observed', 'inferred', 'llm', 'user'
    first_observed  INTEGER,
    last_observed   INTEGER,
    -- Lifecycle
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (source_belief_id) REFERENCES belief_nodes(belief_id) ON DELETE CASCADE,
    FOREIGN KEY (target_belief_id) REFERENCES belief_nodes(belief_id) ON DELETE CASCADE
);

-- Access pattern: forward traversal (what does this belief imply?)
CREATE INDEX idx_belief_edges_source ON belief_edges(source_belief_id, relation_type) WHERE is_active = 1;
-- Access pattern: backward traversal (what supports this belief?)
CREATE INDEX idx_belief_edges_target ON belief_edges(target_belief_id, relation_type) WHERE is_active = 1;
-- Access pattern: find strong causal links
CREATE INDEX idx_belief_edges_strength ON belief_edges(causal_strength DESC) WHERE is_active = 1;
-- Uniqueness
CREATE UNIQUE INDEX idx_belief_edges_unique ON belief_edges(source_belief_id, target_belief_id, relation_type)
    WHERE is_active = 1;

-- ============================================================================
-- CAUSAL CHAINS
-- Explicit cause → effect → mechanism → confounders relationships.
-- More structured than belief edges — these represent understood causal
-- mechanisms, not just correlations.
-- ============================================================================

CREATE TABLE IF NOT EXISTS causal_chains (
    id              INTEGER PRIMARY KEY,
    chain_id        TEXT NOT NULL UNIQUE,    -- Stable identifier
    -- Cause and effect
    cause           TEXT NOT NULL,           -- Description of the cause
    cause_belief_id TEXT,                    -- FK to belief_nodes (if linked)
    effect          TEXT NOT NULL,           -- Description of the effect
    effect_belief_id TEXT,                   -- FK to belief_nodes (if linked)
    -- Mechanism
    mechanism       TEXT NOT NULL,           -- How cause produces effect
    mechanism_type  TEXT NOT NULL,           -- 'physical', 'logical', 'social', 'temporal', 'computational'
    -- Causal properties
    strength        REAL NOT NULL DEFAULT 0.5, -- 0-1: how reliably cause produces effect
    direction       TEXT NOT NULL DEFAULT 'forward', -- 'forward', 'backward', 'bidirectional'
    latency_estimate TEXT,                   -- JSON: { "min_ms": 0, "max_ms": 1000, "typical_ms": 100 }
    -- Confounders (things that could explain the correlation without causation)
    confounders     TEXT,                    -- JSON array: [{ "name": "...", "strength": 0.3 }]
    has_confounders INTEGER NOT NULL DEFAULT 0,
    -- Evidence
    observation_count INTEGER NOT NULL DEFAULT 1,
    intervention_count INTEGER NOT NULL DEFAULT 0, -- Times we tested by intervening (do-calculus)
    intervention_confirms INTEGER NOT NULL DEFAULT 0, -- Times intervention confirmed causality
    -- Causal assessment
    correlation     REAL,                    -- Statistical correlation (may be confounded)
    causation_probability REAL,             -- P(effect | do(cause)) — true causal probability
    is_confounded   INTEGER NOT NULL DEFAULT 0, -- 1 = known confounders exist
    -- Context
    domain          TEXT,                    -- Where this causal chain applies
    conditions      TEXT,                    -- JSON: conditions under which this chain holds
    -- Lifecycle
    is_active       INTEGER NOT NULL DEFAULT 1,
    last_confirmed  INTEGER,
    last_violated   INTEGER,                 -- When the chain failed to hold
    violation_count INTEGER NOT NULL DEFAULT 0,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (cause_belief_id) REFERENCES belief_nodes(belief_id) ON DELETE SET NULL,
    FOREIGN KEY (effect_belief_id) REFERENCES belief_nodes(belief_id) ON DELETE SET NULL
);

-- Access pattern: find chains by cause
CREATE INDEX idx_causal_cause ON causal_chains(cause_belief_id) WHERE is_active = 1;
-- Access pattern: find chains by effect (backward reasoning)
CREATE INDEX idx_causal_effect ON causal_chains(effect_belief_id) WHERE is_active = 1;
-- Access pattern: find strong causal links
CREATE INDEX idx_causal_strength ON causal_chains(strength DESC) WHERE is_active = 1;
-- Access pattern: find chains needing intervention testing
CREATE INDEX idx_causal_untested ON causal_chains(intervention_count ASC)
    WHERE is_active = 1 AND has_confounders = 1;
-- Access pattern: domain-scoped queries
CREATE INDEX idx_causal_domain ON causal_chains(domain) WHERE is_active = 1;

-- ============================================================================
-- SOCIAL MODEL
-- Model of the user: preferences, skill level estimates, mood tracking,
-- communication style, and interaction patterns. Enables the system to
-- adapt its behavior to the user's needs and state.
-- ============================================================================

CREATE TABLE IF NOT EXISTS social_model_profile (
    id              INTEGER PRIMARY KEY,
    -- User identification (single user per project in v1)
    user_id         TEXT NOT NULL DEFAULT 'primary',
    -- Skill level estimates (Bayesian, updated from interactions)
    skill_levels    TEXT NOT NULL DEFAULT '{}', -- JSON: { "rust": 0.8, "testing": 0.6, "architecture": 0.9, ... }
    skill_confidence TEXT NOT NULL DEFAULT '{}', -- JSON: confidence in each skill estimate
    -- Communication preferences
    verbosity_preference REAL NOT NULL DEFAULT 0.5, -- 0=terse, 1=verbose
    explanation_depth REAL NOT NULL DEFAULT 0.5,    -- 0=just do it, 1=explain everything
    autonomy_preference REAL NOT NULL DEFAULT 0.5,  -- 0=ask before acting, 1=act independently
    formality       REAL NOT NULL DEFAULT 0.3,      -- 0=casual, 1=formal
    -- Interaction patterns
    avg_response_time_ms INTEGER,            -- How fast user typically responds
    active_hours    TEXT,                    -- JSON: typical active hours [9, 10, 11, ..., 17]
    session_avg_duration_ms INTEGER,
    messages_per_session REAL,
    -- Current state estimates
    estimated_mood  REAL DEFAULT 0.0,        -- -1 (frustrated) to +1 (satisfied)
    mood_confidence REAL DEFAULT 0.3,
    estimated_focus TEXT DEFAULT 'unknown',  -- 'deep_work', 'exploring', 'debugging', 'learning', 'unknown'
    estimated_urgency REAL DEFAULT 0.5,      -- 0=relaxed, 1=deadline pressure
    -- Rapport tracking
    rapport_score   REAL NOT NULL DEFAULT 0.5, -- 0-1: quality of relationship
    trust_level     REAL NOT NULL DEFAULT 0.5, -- 0-1: how much user trusts the system
    last_positive_interaction INTEGER,
    last_negative_interaction INTEGER,
    consecutive_successes INTEGER NOT NULL DEFAULT 0,
    consecutive_failures INTEGER NOT NULL DEFAULT 0,
    -- Domain interests
    interests       TEXT DEFAULT '[]',       -- JSON array of topics user engages with most
    -- Lifecycle
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Social model observations (evidence for updating the model)
CREATE TABLE IF NOT EXISTS social_observations (
    id              INTEGER PRIMARY KEY,
    user_id         TEXT NOT NULL DEFAULT 'primary',
    tick_number     INTEGER NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    -- Observation
    observation_type TEXT NOT NULL,          -- 'message_style', 'response_time', 'correction',
                                             -- 'praise', 'frustration_signal', 'skill_demonstration',
                                             -- 'preference_expressed', 'topic_interest'
    observation_data TEXT NOT NULL,          -- JSON: observation details
    -- Inference
    inferred_attribute TEXT,                 -- Which profile attribute this updates
    inferred_value  REAL,                    -- New value for the attribute
    confidence      REAL NOT NULL DEFAULT 0.5,
    -- Impact
    profile_updated INTEGER NOT NULL DEFAULT 0, -- 1 = this observation updated the profile
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE INDEX idx_social_obs_time ON social_observations(timestamp_ms DESC);
CREATE INDEX idx_social_obs_type ON social_observations(observation_type, timestamp_ms DESC);
CREATE INDEX idx_social_obs_attr ON social_observations(inferred_attribute)
    WHERE inferred_attribute IS NOT NULL;

-- ============================================================================
-- SIMULATION RESULTS
-- Counterfactual runs: "what if I did X instead of Y?" Results include
-- predicted outcomes, regret/relief scores, and lessons learned.
-- Used by the World Simulator's Mental Sandbox.
-- ============================================================================

CREATE TABLE IF NOT EXISTS simulation_results (
    id              INTEGER PRIMARY KEY,
    simulation_id   TEXT NOT NULL UNIQUE,    -- UUID
    -- Context
    tick_number     INTEGER NOT NULL,        -- When simulation was run
    session_id      TEXT,
    timestamp_ms    INTEGER NOT NULL,
    -- Simulation type
    sim_type        TEXT NOT NULL,           -- 'counterfactual', 'forward_rollout', 'intervention_test',
                                             -- 'risk_assessment', 'planning_simulation'
    -- Input
    initial_state   TEXT NOT NULL,           -- JSON: world state at simulation start
    action_tested   TEXT NOT NULL,           -- JSON: action being simulated
    alternative_action TEXT,                 -- JSON: alternative (for counterfactuals)
    simulation_steps INTEGER NOT NULL,       -- How many steps forward
    -- Output
    final_state     TEXT NOT NULL,           -- JSON: predicted world state after simulation
    outcome_value   REAL NOT NULL,           -- -1 to +1: quality of predicted outcome
    outcome_probability REAL NOT NULL,       -- 0-1: confidence in this outcome
    expected_value  REAL NOT NULL,           -- outcome_value × outcome_probability
    -- Counterfactual comparison
    regret_score    REAL,                    -- How much better alternative would have been (0-1)
    relief_score    REAL,                    -- How much worse alternative would have been (0-1)
    -- Causal analysis
    causal_factors  TEXT,                    -- JSON: key factors that determined outcome
    sensitivity     TEXT,                    -- JSON: which inputs most affect outcome
    -- Learning
    lesson          TEXT,                    -- What was learned from this simulation
    applied_to_goal TEXT,                    -- Goal ID if this influenced a decision
    applied_to_procedure TEXT,              -- Procedure ID if this updated a skill
    -- Performance
    computation_ms  INTEGER NOT NULL,        -- How long simulation took
    -- Validation (was the simulation accurate?)
    validated       INTEGER NOT NULL DEFAULT 0, -- 1 = actual outcome observed and compared
    actual_outcome_value REAL,              -- What actually happened (if validated)
    prediction_error REAL,                   -- |predicted - actual| (if validated)
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: recent simulations
CREATE INDEX idx_sim_time ON simulation_results(timestamp_ms DESC);
-- Access pattern: by type
CREATE INDEX idx_sim_type ON simulation_results(sim_type, timestamp_ms DESC);
-- Access pattern: high-regret simulations (learning opportunities)
CREATE INDEX idx_sim_regret ON simulation_results(regret_score DESC)
    WHERE regret_score IS NOT NULL;
-- Access pattern: validated simulations (for calibration)
CREATE INDEX idx_sim_validated ON simulation_results(validated, prediction_error)
    WHERE validated = 1;
-- Access pattern: find simulations that influenced decisions
CREATE INDEX idx_sim_applied ON simulation_results(applied_to_goal)
    WHERE applied_to_goal IS NOT NULL;

-- ============================================================================
-- WORLD STATE SNAPSHOTS
-- Periodic snapshots of the full world model state for simulation forking.
-- The Mental Sandbox forks from these snapshots to run counterfactuals.
-- ============================================================================

CREATE TABLE IF NOT EXISTS world_snapshots (
    id              INTEGER PRIMARY KEY,
    snapshot_id     TEXT NOT NULL UNIQUE,    -- UUID
    tick_number     INTEGER NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    -- Content
    belief_count    INTEGER NOT NULL,        -- Number of active beliefs at this point
    edge_count      INTEGER NOT NULL,        -- Number of active belief edges
    causal_chain_count INTEGER NOT NULL,     -- Number of active causal chains
    -- Serialized state (for forking)
    state_binary    BLOB,                   -- MessagePack-serialized world state
    state_hash      TEXT NOT NULL,           -- BLAKE3 hash for integrity
    -- Metadata
    trigger         TEXT NOT NULL,           -- 'periodic', 'pre_simulation', 'checkpoint', 'significant_change'
    size_bytes      INTEGER NOT NULL,
    -- Lifecycle
    is_valid        INTEGER NOT NULL DEFAULT 1,
    expires_at      INTEGER,                 -- Epoch ms, NULL = keep indefinitely
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: find latest snapshot for forking
CREATE INDEX idx_world_snap_time ON world_snapshots(tick_number DESC) WHERE is_valid = 1;
-- Access pattern: find snapshots by trigger
CREATE INDEX idx_world_snap_trigger ON world_snapshots(trigger, tick_number DESC);
