-- ============================================================================
-- Kognisant Cognitive State Schema
-- Location: ~/.kognisant/projects/{id}/cognitive_state.db
-- Purpose: Persists the running cognitive state for crash recovery, session
--          continuity, and state inspection. Captures per-tick snapshots of
--          all major subsystems: predictive stack, affective economy,
--          homunculus, goal market, agent society, and meta-cognitive controller.
-- ============================================================================

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA synchronous = NORMAL;

-- ============================================================================
-- SYSTEM STATE SNAPSHOTS
-- Per-tick state captures for crash recovery. Ring buffer behavior: only the
-- last N snapshots are retained (configurable by device tier).
-- On crash, the kernel resumes from the most recent valid snapshot.
-- ============================================================================

CREATE TABLE IF NOT EXISTS state_snapshots (
    id              INTEGER PRIMARY KEY,
    tick_number     INTEGER NOT NULL,        -- Global monotonic tick counter
    session_id      TEXT NOT NULL,           -- Current session
    timestamp_ms    INTEGER NOT NULL,        -- Wall clock (epoch ms)
    -- Snapshot content (binary for speed, JSON for debuggability)
    state_binary    BLOB,                   -- MessagePack-serialized full state (fast restore)
    state_json      TEXT,                    -- JSON representation (for debugging/inspection)
    -- Integrity
    checksum        TEXT NOT NULL,           -- BLAKE3 hash of state_binary
    schema_version  INTEGER NOT NULL,        -- For migration compatibility
    -- Phase info
    tick_phase      TEXT NOT NULL,           -- 'perception', 'comparison', 'update', 'deliberation', 'action'
    tick_duration_us INTEGER,               -- Microseconds this tick took
    -- Flags
    is_checkpoint   INTEGER NOT NULL DEFAULT 0, -- 1 = deliberate checkpoint (not just ring buffer)
    is_valid        INTEGER NOT NULL DEFAULT 1, -- 0 = corrupted/incomplete
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: find latest valid snapshot for recovery
CREATE INDEX idx_snapshots_recovery ON state_snapshots(tick_number DESC) WHERE is_valid = 1;
-- Access pattern: find checkpoints (deliberate save points)
CREATE INDEX idx_snapshots_checkpoints ON state_snapshots(tick_number DESC) WHERE is_checkpoint = 1;
-- Access pattern: session-scoped queries
CREATE INDEX idx_snapshots_session ON state_snapshots(session_id, tick_number DESC);

-- ============================================================================
-- PREDICTIVE STACK STATE
-- The 5-layer predictive processing stack. Each layer maintains predictions,
-- precision weights, and error signals. Persisted for continuity across
-- restarts and for telemetry analysis.
-- ============================================================================

CREATE TABLE IF NOT EXISTS predictive_stack_state (
    id              INTEGER PRIMARY KEY,
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    -- Layer identification
    layer_index     INTEGER NOT NULL,        -- 0=raw, 1=syntactic, 2=semantic, 3=pragmatic, 4=strategic
    layer_name      TEXT NOT NULL,           -- Human-readable layer name
    -- Predictions
    current_prediction TEXT NOT NULL,        -- JSON: what this layer currently predicts
    prediction_confidence REAL NOT NULL,     -- 0-1: how confident in the prediction
    -- Error signals
    prediction_error REAL NOT NULL DEFAULT 0.0, -- Magnitude of last prediction error
    error_direction TEXT,                    -- JSON: vector direction of error
    error_propagated INTEGER NOT NULL DEFAULT 0, -- 1 = error was passed to layer above
    -- Precision weighting
    precision_weight REAL NOT NULL DEFAULT 0.5, -- How much this layer's errors matter (0-1)
    precision_source TEXT,                   -- What determined precision ('affect', 'context', 'learned')
    -- Layer state
    is_active       INTEGER NOT NULL DEFAULT 1, -- MCC can deactivate layers on low-tier devices
    activation_energy REAL NOT NULL DEFAULT 0.5, -- How "awake" this layer is
    -- Generative model parameters (compressed)
    model_params    BLOB,                   -- Serialized layer-specific model state
    model_version   INTEGER NOT NULL DEFAULT 1,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: get all layers for a specific tick
CREATE INDEX idx_pp_tick ON predictive_stack_state(tick_number, layer_index);
-- Access pattern: track a single layer over time
CREATE INDEX idx_pp_layer_time ON predictive_stack_state(layer_index, tick_number DESC);
-- Access pattern: find high-error states (for telemetry)
CREATE INDEX idx_pp_error ON predictive_stack_state(prediction_error DESC);

-- ============================================================================
-- AFFECTIVE ECONOMY STATE
-- The 6-dimensional affective state plus valence, arousal, and cognitive budget.
-- Persisted at lower frequency than tick (every 10 ticks or on significant change).
-- Drives resource allocation across the entire cognitive system.
-- ============================================================================

CREATE TABLE IF NOT EXISTS affective_state (
    id              INTEGER PRIMARY KEY,
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    -- 6 Affective Dimensions
    uncertainty     REAL NOT NULL DEFAULT 0.5,  -- Drives information seeking
    curiosity       REAL NOT NULL DEFAULT 0.3,  -- Drives exploration
    frustration     REAL NOT NULL DEFAULT 0.0,  -- Triggers strategy change
    fatigue         REAL NOT NULL DEFAULT 0.0,  -- Reduces tick rate, triggers consolidation
    novelty_drive   REAL NOT NULL DEFAULT 0.5,  -- Weights novel memories higher
    reward_expectation REAL NOT NULL DEFAULT 0.5, -- Discount factor for future rewards
    -- Derived values
    valence         REAL NOT NULL DEFAULT 0.0,  -- -1 (aversive) to +1 (appetitive)
    arousal         REAL NOT NULL DEFAULT 0.5,  -- 0 (calm) to 1 (activated)
    -- Cognitive Budget (derived from affect)
    budget_tokens_per_tick INTEGER NOT NULL DEFAULT 1000,
    budget_llm_queries_per_min INTEGER NOT NULL DEFAULT 10,
    budget_planning_depth INTEGER NOT NULL DEFAULT 5,
    budget_memory_depth INTEGER NOT NULL DEFAULT 3,
    budget_self_mod_risk REAL NOT NULL DEFAULT 0.0,
    -- Precision weights per modality
    precision_weights TEXT,                  -- JSON: { "user_message": 0.9, "file_change": 0.6, ... }
    -- What caused this state change
    trigger_event   TEXT,                    -- JSON: event that caused significant affect change
    delta_magnitude REAL,                    -- How much affect changed from previous sample
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: time-series of affect (for visualization)
CREATE INDEX idx_affect_time ON affective_state(timestamp_ms DESC);
-- Access pattern: find high-frustration periods
CREATE INDEX idx_affect_frustration ON affective_state(frustration DESC);
-- Access pattern: session-scoped affect history
CREATE INDEX idx_affect_session ON affective_state(session_id, tick_number);

-- ============================================================================
-- HOMUNCULUS / SELF-MODEL STATE
-- The system's model of itself. Tracks confidence maps, known unknowns,
-- self-prediction accuracy, and introspection depth. Updated every tick
-- by comparing predicted self-state to actual self-state.
-- ============================================================================

CREATE TABLE IF NOT EXISTS homunculus_state (
    id              INTEGER PRIMARY KEY,
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    -- Self-prediction accuracy (rolling windows)
    self_prediction_accuracy_1m REAL,       -- Last 60 seconds
    self_prediction_accuracy_5m REAL,       -- Last 5 minutes
    self_prediction_accuracy_1h REAL,       -- Last hour
    -- Confidence map (per-domain)
    confidence_map  TEXT NOT NULL,           -- JSON: { "planning": 0.8, "coding": 0.9, "debugging": 0.6, ... }
    -- Known unknowns (things the system knows it doesn't know)
    known_unknowns  TEXT,                   -- JSON array: [{ "description": "...", "detected_at": tick, "priority": 0.7 }]
    known_unknowns_count INTEGER NOT NULL DEFAULT 0,
    -- Belief stability (how much beliefs are changing)
    belief_stability TEXT,                   -- JSON: { "world_model": 0.9, "user_model": 0.7, ... }
    overall_stability REAL NOT NULL DEFAULT 0.5,
    -- Introspection state
    introspection_depth REAL NOT NULL DEFAULT 0.3, -- 0-1: how much resource allocated to self-monitoring
    -- Self-modification readiness
    can_self_modify INTEGER NOT NULL DEFAULT 0,
    self_mod_success_rate REAL NOT NULL DEFAULT 0.0,
    last_self_modification_tick INTEGER,
    -- Self-surprise (prediction error about own behavior)
    self_surprise   REAL NOT NULL DEFAULT 0.0,
    self_surprise_source TEXT,              -- What aspect of self was surprising
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: latest self-model state
CREATE INDEX idx_homunculus_tick ON homunculus_state(tick_number DESC);
-- Access pattern: track self-prediction accuracy over time
CREATE INDEX idx_homunculus_accuracy ON homunculus_state(session_id, tick_number);
-- Access pattern: find moments of high self-surprise
CREATE INDEX idx_homunculus_surprise ON homunculus_state(self_surprise DESC);

-- ============================================================================
-- GOAL MARKET STATE
-- Active goals, their bids, coalitions, and value function weights.
-- The goal market is where agent bids compete for cognitive resources.
-- ============================================================================

CREATE TABLE IF NOT EXISTS goals (
    id              INTEGER PRIMARY KEY,
    goal_id         TEXT NOT NULL UNIQUE,    -- Stable identifier (UUID)
    -- Goal definition
    origin          TEXT NOT NULL,           -- 'user_request', 'prediction_error', 'curiosity_gap',
                                             -- 'value_gradient', 'contradiction', 'opportunity',
                                             -- 'self_improvement', 'social_maintenance'
    description     TEXT NOT NULL,
    priority        REAL NOT NULL DEFAULT 0.5, -- Current priority (dynamic, affected by affect)
    -- Value estimation
    expected_free_energy_reduction REAL,     -- How much surprise this goal would eliminate
    expected_value  REAL NOT NULL DEFAULT 0.5,
    expected_cost   REAL NOT NULL DEFAULT 0.5,
    epistemic_value REAL DEFAULT 0.0,        -- Information gain
    pragmatic_value REAL DEFAULT 0.0,        -- Task completion value
    -- Temporal
    deadline_tick   INTEGER,                 -- Tick by which goal should complete (NULL = no deadline)
    temporal_discount REAL NOT NULL DEFAULT 0.9, -- How much value decays per tick
    -- State
    status          TEXT NOT NULL DEFAULT 'active', -- 'active', 'executing', 'completed', 'failed',
                                                    -- 'abandoned', 'superseded', 'blocked'
    progress        REAL NOT NULL DEFAULT 0.0, -- 0-1 completion estimate
    -- Execution
    assigned_agent  TEXT,                    -- Agent currently executing this goal
    coalition_members TEXT,                  -- JSON array of agent names in coalition
    resource_allocated REAL DEFAULT 0.0,     -- Fraction of cognitive budget allocated
    -- Outcome
    outcome         TEXT,                    -- JSON: what happened when goal completed/failed
    outcome_satisfaction REAL,              -- -1 to +1: how well the outcome matched expectations
    -- Lifecycle
    activated_at    INTEGER,                 -- Epoch ms when goal became active
    started_at      INTEGER,                 -- Epoch ms when execution began
    completed_at    INTEGER,                 -- Epoch ms when goal resolved
    parent_goal_id  TEXT,                    -- FK to parent goal (for decomposition)
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (parent_goal_id) REFERENCES goals(goal_id) ON DELETE SET NULL
);

-- Access pattern: active goals sorted by priority
CREATE INDEX idx_goals_active ON goals(priority DESC) WHERE status IN ('active', 'executing');
-- Access pattern: goals by origin type
CREATE INDEX idx_goals_origin ON goals(origin, status);
-- Access pattern: goal hierarchy (parent-child)
CREATE INDEX idx_goals_parent ON goals(parent_goal_id) WHERE parent_goal_id IS NOT NULL;
-- Access pattern: completed goals for learning
CREATE INDEX idx_goals_completed ON goals(completed_at DESC) WHERE status = 'completed';

-- Value function weights (learned through experience)
CREATE TABLE IF NOT EXISTS value_function (
    id              INTEGER PRIMARY KEY,
    -- Intrinsic values (hardcoded base, weighted by experience)
    curiosity_satisfaction REAL NOT NULL DEFAULT 0.5,
    competence_increase REAL NOT NULL DEFAULT 0.5,
    social_rapport  REAL NOT NULL DEFAULT 0.5,
    autonomy        REAL NOT NULL DEFAULT 0.5,
    coherence       REAL NOT NULL DEFAULT 0.5,
    -- Learned domain values
    domain_values   TEXT NOT NULL DEFAULT '{}', -- JSON: { "rust": 0.8, "testing": 0.6, ... }
    tool_values     TEXT NOT NULL DEFAULT '{}', -- JSON: { "file_write": 0.7, "llm_query": 0.5, ... }
    strategy_values TEXT NOT NULL DEFAULT '{}', -- JSON: { "plan_first": 0.8, "iterate": 0.6, ... }
    -- Learning metadata
    total_updates   INTEGER NOT NULL DEFAULT 0,
    last_update_tick INTEGER,
    avg_prediction_error REAL DEFAULT 0.0,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- ============================================================================
-- AGENT SOCIETY STATE
-- Configuration and state of all cognitive agents in the society of mind.
-- Tracks agent configs, bid history, coalition records, and performance.
-- ============================================================================

CREATE TABLE IF NOT EXISTS agents (
    id              INTEGER PRIMARY KEY,
    agent_id        TEXT NOT NULL UNIQUE,    -- 'planner', 'coder', 'debugger', 'research', etc.
    display_name    TEXT NOT NULL,
    agent_type      TEXT NOT NULL,           -- 'specialist', 'meta', 'safety', 'social'
    -- Configuration
    config          TEXT NOT NULL,           -- JSON: agent-specific configuration
    prompt_template TEXT,                    -- System prompt for this agent (if LLM-backed)
    -- State
    is_active       INTEGER NOT NULL DEFAULT 1, -- MCC can deactivate on low-tier devices
    activation_priority INTEGER NOT NULL DEFAULT 50, -- Lower = activated first on constrained devices
    -- Performance metrics
    total_bids      INTEGER NOT NULL DEFAULT 0,
    winning_bids    INTEGER NOT NULL DEFAULT 0,
    total_executions INTEGER NOT NULL DEFAULT 0,
    successful_executions INTEGER NOT NULL DEFAULT 0,
    avg_execution_ms INTEGER,
    -- Trust/reputation
    trust_score     REAL NOT NULL DEFAULT 0.5, -- 0-1, earned through successful outcomes
    reliability     REAL NOT NULL DEFAULT 0.5, -- How often predictions match outcomes
    -- Resource usage
    total_tokens_used INTEGER NOT NULL DEFAULT 0,
    total_tool_calls INTEGER NOT NULL DEFAULT 0,
    -- Lifecycle
    last_bid_tick   INTEGER,
    last_execution_tick INTEGER,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE INDEX idx_agents_active ON agents(is_active, activation_priority);
CREATE INDEX idx_agents_trust ON agents(trust_score DESC) WHERE is_active = 1;

-- Coalition records (when agents team up)
CREATE TABLE IF NOT EXISTS coalitions (
    id              INTEGER PRIMARY KEY,
    coalition_id    TEXT NOT NULL UNIQUE,    -- UUID
    -- Formation
    goal_id         TEXT NOT NULL,           -- Goal this coalition serves
    lead_agent_id   TEXT NOT NULL,           -- Agent that initiated the coalition
    member_agents   TEXT NOT NULL,           -- JSON array of agent_ids
    -- State
    status          TEXT NOT NULL DEFAULT 'active', -- 'forming', 'active', 'completed', 'dissolved'
    -- Performance
    formation_tick  INTEGER NOT NULL,
    dissolution_tick INTEGER,
    outcome         TEXT,                    -- 'success', 'failure', 'partial'
    synergy_score   REAL,                    -- Did coalition outperform individual agents? (0-2, >1 = synergy)
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (goal_id) REFERENCES goals(goal_id) ON DELETE SET NULL,
    FOREIGN KEY (lead_agent_id) REFERENCES agents(agent_id) ON DELETE SET NULL
);

CREATE INDEX idx_coalitions_active ON coalitions(status) WHERE status = 'active';
CREATE INDEX idx_coalitions_goal ON coalitions(goal_id);

-- ============================================================================
-- META-COGNITIVE CONTROLLER STATE
-- Attention allocation, sleep scheduling, LLM gateway state, and
-- layer activation decisions. The "brain's brain" state.
-- ============================================================================

CREATE TABLE IF NOT EXISTS mcc_state (
    id              INTEGER PRIMARY KEY,
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    -- Attention allocation
    attention_focus TEXT NOT NULL,           -- JSON: { "channel": weight } mapping
    attention_mode  TEXT NOT NULL DEFAULT 'balanced', -- 'focused', 'diffuse', 'balanced', 'vigilant'
    -- Layer activation decisions
    active_layers   TEXT NOT NULL,           -- JSON array of active PP layer indices [0,1,2,3,4]
    layer_rationale TEXT,                    -- Why these layers are active
    -- LLM gateway state
    llm_budget_remaining INTEGER,           -- Queries remaining this minute
    llm_last_query_tick INTEGER,
    llm_queue_depth INTEGER NOT NULL DEFAULT 0,
    -- Sleep/consolidation scheduling
    consolidation_due INTEGER NOT NULL DEFAULT 0, -- 1 = consolidation should happen soon
    last_consolidation_tick INTEGER,
    idle_ticks      INTEGER NOT NULL DEFAULT 0, -- Consecutive ticks with no external input
    -- Tick rate management
    current_tick_rate_hz INTEGER NOT NULL DEFAULT 10,
    tick_rate_reason TEXT,                   -- Why tick rate is what it is
    -- Resource pressure
    memory_pressure REAL NOT NULL DEFAULT 0.0, -- 0-1
    cpu_pressure    REAL NOT NULL DEFAULT 0.0, -- 0-1
    thermal_pressure REAL NOT NULL DEFAULT 0.0, -- 0-1
    -- Self-modification gate
    self_mod_permitted INTEGER NOT NULL DEFAULT 0,
    self_mod_reason TEXT,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: latest MCC state
CREATE INDEX idx_mcc_tick ON mcc_state(tick_number DESC);
-- Access pattern: find pressure events
CREATE INDEX idx_mcc_pressure ON mcc_state(memory_pressure DESC);
-- Access pattern: session timeline
CREATE INDEX idx_mcc_session ON mcc_state(session_id, tick_number);
