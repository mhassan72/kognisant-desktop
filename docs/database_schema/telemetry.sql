-- ============================================================================
-- Kognisant Telemetry Database Schema
-- Location: ~/.kognisant/projects/{id}/telemetry.db
-- Purpose: CRITICAL traceability system. Full execution traces enabling
--          cognitive replay, causal attribution, performance regression
--          detection, self-modification audit, and cross-session continuity.
--
-- DESIGN: All tables are APPEND-ONLY in normal operation. No UPDATE/DELETE
--         except during scheduled maintenance/pruning passes.
--
-- PARTITIONING STRATEGY: Logical single tables with time-based indexes.
--         Archival process moves data older than retention window to
--         compressed parquet files. Retention is device-tier dependent.
--
-- TRACEABILITY: Every event carries tick_number, session_id, timestamp_ms,
--              correlation_id, and causation_chain for full causal graph
--              reconstruction.
-- ============================================================================

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA synchronous = NORMAL;
PRAGMA auto_vacuum = INCREMENTAL;
PRAGMA page_size = 8192;

-- ============================================================================
-- SESSION BOUNDARIES
-- Defines session start/stop events. All other telemetry references a session.
-- Sessions track device info, duration, and cross-session linking.
-- ============================================================================

CREATE TABLE IF NOT EXISTS sessions (
    id              INTEGER PRIMARY KEY,
    session_id      TEXT NOT NULL UNIQUE,    -- UUID for this session
    -- Device context
    device_id       TEXT NOT NULL,           -- Links to global.db device_profile
    device_tier     TEXT NOT NULL,           -- 'minimal', 'standard', 'performance', 'server'
    os_type         TEXT NOT NULL,
    app_version     TEXT NOT NULL,           -- Kognisant version
    schema_version  INTEGER NOT NULL,        -- Telemetry schema version
    -- Session lifecycle
    started_at      INTEGER NOT NULL,        -- Epoch ms
    ended_at        INTEGER,                 -- Epoch ms (NULL = still active)
    duration_ms     INTEGER,                 -- Computed on close
    end_reason      TEXT,                    -- 'user_quit', 'crash', 'update', 'idle_timeout', 'system_shutdown'
    -- Tick range
    first_tick      INTEGER,                 -- First tick_number in this session
    last_tick       INTEGER,                 -- Last tick_number in this session
    total_ticks     INTEGER NOT NULL DEFAULT 0,
    -- Cross-session linking
    previous_session_id TEXT,               -- Links to prior session (for continuity)
    resumed_from_tick INTEGER,              -- If resuming, which tick state was restored
    -- Summary metrics (computed on close)
    total_llm_queries INTEGER NOT NULL DEFAULT 0,
    total_llm_tokens INTEGER NOT NULL DEFAULT 0,
    total_tool_executions INTEGER NOT NULL DEFAULT 0,
    total_goals_completed INTEGER NOT NULL DEFAULT 0,
    total_self_modifications INTEGER NOT NULL DEFAULT 0,
    avg_surprise    REAL,
    avg_tick_duration_us INTEGER,
    -- Retention
    archived        INTEGER NOT NULL DEFAULT 0,
    archive_path    TEXT,                    -- Path to compressed archive if archived
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE INDEX idx_sessions_time ON sessions(started_at DESC);
CREATE INDEX idx_sessions_active ON sessions(ended_at) WHERE ended_at IS NULL;
CREATE INDEX idx_sessions_chain ON sessions(previous_session_id);

-- ============================================================================
-- COGNITIVE TICK TRACES
-- Every tick: phase timings, surprise values, actions taken. This is the
-- heartbeat of the system — enables full cognitive replay.
-- One row per tick (10Hz = 36,000 rows/hour when active).
-- ============================================================================

CREATE TABLE IF NOT EXISTS tick_traces (
    id              INTEGER PRIMARY KEY,
    -- Traceability fields (present on ALL telemetry tables)
    tick_number     INTEGER NOT NULL,        -- Global monotonic counter
    session_id      TEXT NOT NULL,           -- Links to sessions table
    timestamp_ms    INTEGER NOT NULL,        -- Wall clock (epoch ms)
    correlation_id  TEXT NOT NULL,           -- UUID linking related events
    causation_chain TEXT,                    -- JSON array of upstream event IDs
    -- Phase timings (microseconds per phase)
    perception_us   INTEGER NOT NULL,        -- Phase 1: gather sensory input
    comparison_us   INTEGER NOT NULL,        -- Phase 2: compare predictions to observations
    update_us       INTEGER NOT NULL,        -- Phase 3: update beliefs
    deliberation_us INTEGER NOT NULL,        -- Phase 4: goal market bidding
    action_us       INTEGER NOT NULL,        -- Phase 5: execute actions
    total_us        INTEGER NOT NULL,        -- Total tick duration
    -- Surprise summary
    total_surprise  REAL NOT NULL,           -- Sum of free energy across all channels
    max_surprise    REAL NOT NULL,           -- Highest single surprise value
    surprise_channel TEXT,                   -- Channel with highest surprise
    salient_events  INTEGER NOT NULL DEFAULT 0, -- Count of events exceeding salience threshold
    -- Actions taken
    actions_count   INTEGER NOT NULL DEFAULT 0,
    actions_summary TEXT,                    -- JSON array: [{"type": "llm_query", "target": "..."}, ...]
    -- State summary
    active_goals    INTEGER NOT NULL DEFAULT 0,
    active_agents   INTEGER NOT NULL DEFAULT 0,
    wm_occupancy    INTEGER NOT NULL DEFAULT 0, -- Working memory slots filled
    tick_rate_hz    INTEGER NOT NULL DEFAULT 10,
    -- Affect snapshot (compact)
    valence         REAL,
    arousal         REAL,
    -- Flags
    is_idle         INTEGER NOT NULL DEFAULT 0, -- 1 = no external input this tick
    had_llm_query   INTEGER NOT NULL DEFAULT 0,
    had_tool_exec   INTEGER NOT NULL DEFAULT 0,
    had_self_mod    INTEGER NOT NULL DEFAULT 0,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Primary access: time-range queries for replay
CREATE INDEX idx_ticks_time ON tick_traces(timestamp_ms DESC);
-- Primary access: tick number lookup
CREATE INDEX idx_ticks_number ON tick_traces(tick_number DESC);
-- Access pattern: find high-surprise ticks
CREATE INDEX idx_ticks_surprise ON tick_traces(total_surprise DESC);
-- Access pattern: session-scoped replay
CREATE INDEX idx_ticks_session ON tick_traces(session_id, tick_number);
-- Access pattern: correlation graph traversal
CREATE INDEX idx_ticks_correlation ON tick_traces(correlation_id);
-- Access pattern: find non-idle ticks (active cognition)
CREATE INDEX idx_ticks_active ON tick_traces(tick_number DESC) WHERE is_idle = 0;

-- ============================================================================
-- LLM QUERY LOG
-- Every LLM invocation: provider, model, tokens, latency, cost, and the
-- routing decision that selected this provider. Critical for cost tracking
-- and quality regression detection.
-- ============================================================================

CREATE TABLE IF NOT EXISTS llm_queries (
    id              INTEGER PRIMARY KEY,
    -- Traceability
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    correlation_id  TEXT NOT NULL,
    causation_chain TEXT,                    -- JSON: what triggered this query
    -- Provider & model
    provider_name   TEXT NOT NULL,           -- 'kognisant', 'ollama', 'openai', etc.
    model_id        TEXT NOT NULL,           -- 'gpt-4o', 'llama3:70b', etc.
    -- Routing decision
    routing_reason  TEXT NOT NULL,           -- Why this provider/model was chosen
    routing_score   REAL,                    -- Score from routing algorithm
    alternatives_considered TEXT,            -- JSON: other models considered and their scores
    -- Request
    request_type    TEXT NOT NULL,           -- 'completion', 'chat', 'embedding', 'function_call'
    system_prompt_hash TEXT,                 -- Hash of system prompt (for dedup)
    input_tokens    INTEGER NOT NULL,
    input_hash      TEXT,                    -- Hash of input (for cache hit detection)
    -- Response
    output_tokens   INTEGER NOT NULL DEFAULT 0,
    total_tokens    INTEGER NOT NULL DEFAULT 0,
    finish_reason   TEXT,                    -- 'stop', 'length', 'function_call', 'error'
    output_hash     TEXT,                    -- Hash of output
    -- Performance
    latency_ms      INTEGER NOT NULL,        -- Total request duration
    time_to_first_token_ms INTEGER,         -- Streaming: time to first token
    tokens_per_second REAL,                 -- Generation speed
    -- Cost
    cost_usd        REAL NOT NULL DEFAULT 0.0, -- Computed cost for this query
    -- Quality signals
    was_cached      INTEGER NOT NULL DEFAULT 0, -- 1 = served from cache
    was_retried     INTEGER NOT NULL DEFAULT 0, -- 1 = had to retry
    retry_count     INTEGER NOT NULL DEFAULT 0,
    error_type      TEXT,                    -- NULL = success, else error category
    error_message   TEXT,
    -- Context
    requesting_agent TEXT,                   -- Which cognitive agent requested this
    goal_id         TEXT,                    -- Goal this query serves
    -- Quality assessment (filled post-hoc)
    satisfaction_score REAL,                 -- 0-1: how useful was the response
    hallucination_detected INTEGER NOT NULL DEFAULT 0,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Access pattern: cost tracking over time
CREATE INDEX idx_llm_time ON llm_queries(timestamp_ms DESC);
-- Access pattern: per-provider analysis
CREATE INDEX idx_llm_provider ON llm_queries(provider_name, model_id, timestamp_ms DESC);
-- Access pattern: find errors
CREATE INDEX idx_llm_errors ON llm_queries(error_type) WHERE error_type IS NOT NULL;
-- Access pattern: correlation graph
CREATE INDEX idx_llm_correlation ON llm_queries(correlation_id);
-- Access pattern: per-agent usage
CREATE INDEX idx_llm_agent ON llm_queries(requesting_agent, timestamp_ms DESC);
-- Access pattern: cache hit analysis
CREATE INDEX idx_llm_cache ON llm_queries(input_hash) WHERE was_cached = 1;

-- ============================================================================
-- TOOL EXECUTION LOG
-- Every tool invocation: name, input hash, output, duration, success/failure.
-- Tools include file operations, shell commands, web searches, etc.
-- ============================================================================

CREATE TABLE IF NOT EXISTS tool_executions (
    id              INTEGER PRIMARY KEY,
    -- Traceability
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    correlation_id  TEXT NOT NULL,
    causation_chain TEXT,
    -- Tool identification
    tool_name       TEXT NOT NULL,           -- 'file_read', 'file_write', 'shell_exec', 'web_search', etc.
    tool_category   TEXT NOT NULL,           -- 'filesystem', 'shell', 'network', 'internal'
    -- Input
    input_params    TEXT NOT NULL,           -- JSON: tool parameters (sensitive values hashed)
    input_hash      TEXT NOT NULL,           -- Hash of full input for dedup/cache
    -- Output
    output_summary  TEXT,                    -- Truncated output (first 1KB)
    output_hash     TEXT,                    -- Hash of full output
    output_size_bytes INTEGER,              -- Full output size
    -- Execution
    duration_ms     INTEGER NOT NULL,
    status          TEXT NOT NULL,           -- 'success', 'failure', 'timeout', 'cancelled', 'partial'
    error_type      TEXT,                    -- NULL = success
    error_message   TEXT,
    exit_code       INTEGER,                -- For shell commands
    -- Context
    requesting_agent TEXT,                   -- Which agent requested this tool
    goal_id         TEXT,                    -- Goal this serves
    -- Side effects
    files_modified  TEXT,                    -- JSON array of file paths modified
    bytes_written   INTEGER DEFAULT 0,
    bytes_read      INTEGER DEFAULT 0,
    -- Safety
    safety_check_passed INTEGER NOT NULL DEFAULT 1,
    safety_flags    TEXT,                    -- JSON: any safety concerns raised
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Access pattern: time-range queries
CREATE INDEX idx_tools_time ON tool_executions(timestamp_ms DESC);
-- Access pattern: per-tool analysis
CREATE INDEX idx_tools_name ON tool_executions(tool_name, timestamp_ms DESC);
-- Access pattern: find failures
CREATE INDEX idx_tools_failures ON tool_executions(status) WHERE status != 'success';
-- Access pattern: correlation graph
CREATE INDEX idx_tools_correlation ON tool_executions(correlation_id);
-- Access pattern: per-agent tool usage
CREATE INDEX idx_tools_agent ON tool_executions(requesting_agent, timestamp_ms DESC);

-- ============================================================================
-- GOAL LIFECYCLE LOG
-- Tracks goals from creation through bidding, execution, to outcome.
-- Enables causal attribution: why was this action taken? Because of this goal.
-- ============================================================================

CREATE TABLE IF NOT EXISTS goal_lifecycle (
    id              INTEGER PRIMARY KEY,
    -- Traceability
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    correlation_id  TEXT NOT NULL,
    causation_chain TEXT,
    -- Goal identification
    goal_id         TEXT NOT NULL,           -- Links to cognitive_state.goals
    -- Lifecycle event
    event_type      TEXT NOT NULL,           -- 'created', 'activated', 'bid_received', 'bid_won',
                                             -- 'execution_started', 'progress_update', 'completed',
                                             -- 'failed', 'abandoned', 'superseded', 'blocked', 'unblocked'
    -- Event details
    event_data      TEXT NOT NULL,           -- JSON: event-specific data
    -- For bid events
    bidding_agent   TEXT,                    -- Agent that placed the bid
    bid_value       REAL,                    -- Bid amount
    bid_confidence  REAL,                    -- Bidder's confidence
    -- For completion/failure events
    outcome_value   REAL,                    -- Actual value delivered (-1 to +1)
    duration_ticks  INTEGER,                -- Ticks from start to completion
    resources_used  REAL,                    -- Fraction of budget consumed
    -- For progress events
    progress_delta  REAL,                    -- How much progress changed
    -- Context
    affect_state_at_event TEXT,             -- JSON: affect dimensions when event occurred
    active_goals_count INTEGER,             -- How many goals were active at this point
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Access pattern: goal timeline (all events for one goal)
CREATE INDEX idx_goal_lc_goal ON goal_lifecycle(goal_id, tick_number);
-- Access pattern: time-range queries
CREATE INDEX idx_goal_lc_time ON goal_lifecycle(timestamp_ms DESC);
-- Access pattern: event type filtering
CREATE INDEX idx_goal_lc_event ON goal_lifecycle(event_type, timestamp_ms DESC);
-- Access pattern: correlation graph
CREATE INDEX idx_goal_lc_correlation ON goal_lifecycle(correlation_id);
-- Access pattern: per-agent bid history
CREATE INDEX idx_goal_lc_agent ON goal_lifecycle(bidding_agent, timestamp_ms DESC)
    WHERE bidding_agent IS NOT NULL;

-- ============================================================================
-- MEMORY ACTIVATION LOG
-- Which memories competed for working memory, which won, and why.
-- Critical for understanding why the system "remembered" certain things.
-- ============================================================================

CREATE TABLE IF NOT EXISTS memory_activations (
    id              INTEGER PRIMARY KEY,
    -- Traceability
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    correlation_id  TEXT NOT NULL,
    causation_chain TEXT,
    -- Competition context
    trigger_type    TEXT NOT NULL,           -- 'surprise', 'goal_context', 'spread_activation', 'rehearsal'
    trigger_source  TEXT,                    -- What triggered this activation competition
    -- Candidates
    candidates_count INTEGER NOT NULL,       -- Total memories that competed
    candidates_summary TEXT,                 -- JSON: top 10 candidates with scores
    -- Winners
    winners_count   INTEGER NOT NULL,        -- How many entered working memory
    winners         TEXT NOT NULL,           -- JSON: [{ "source": "episodic:42", "score": 0.9, "reason": "..." }]
    -- Losers (top inhibited)
    inhibited_count INTEGER NOT NULL DEFAULT 0,
    top_inhibited   TEXT,                    -- JSON: top 5 that almost won but didn't
    -- Scoring breakdown
    relevance_weight REAL,                   -- How much relevance mattered
    recency_weight  REAL,                    -- How much recency mattered
    salience_weight REAL,                    -- How much emotional salience mattered
    -- Working memory state after
    wm_occupancy_after INTEGER NOT NULL,
    wm_capacity     INTEGER NOT NULL,        -- Current dynamic capacity
    -- Performance
    competition_duration_us INTEGER,         -- How long the competition took
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Access pattern: time-range queries
CREATE INDEX idx_mem_act_time ON memory_activations(timestamp_ms DESC);
-- Access pattern: tick-based lookup
CREATE INDEX idx_mem_act_tick ON memory_activations(tick_number);
-- Access pattern: correlation graph
CREATE INDEX idx_mem_act_correlation ON memory_activations(correlation_id);
-- Access pattern: find by trigger type
CREATE INDEX idx_mem_act_trigger ON memory_activations(trigger_type, timestamp_ms DESC);

-- ============================================================================
-- SELF-MODIFICATION LOG
-- Every code change: patch proposed → safety check → compile → test → apply/rollback.
-- Full audit trail with before/after benchmarks. CRITICAL for safety.
-- ============================================================================

CREATE TABLE IF NOT EXISTS self_modifications (
    id              INTEGER PRIMARY KEY,
    -- Traceability
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    correlation_id  TEXT NOT NULL,
    causation_chain TEXT,
    -- Modification identification
    modification_id TEXT NOT NULL UNIQUE,    -- UUID
    -- Trigger
    trigger_goal_id TEXT,                    -- Goal that motivated this modification
    trigger_type    TEXT NOT NULL,           -- 'performance', 'novelty', 'efficiency', 'capability',
                                             -- 'meta_learning', 'curiosity'
    trigger_description TEXT NOT NULL,       -- Human-readable reason
    -- Patch details
    target_module   TEXT NOT NULL,           -- Module being modified
    files_changed   TEXT NOT NULL,           -- JSON array of file paths
    patch_summary   TEXT NOT NULL,           -- Human-readable summary of changes
    patch_diff      TEXT,                    -- Unified diff (may be large)
    patch_hash      TEXT NOT NULL,           -- Hash of the patch content
    lines_added     INTEGER NOT NULL DEFAULT 0,
    lines_removed   INTEGER NOT NULL DEFAULT 0,
    complexity_delta REAL,                   -- Change in code complexity
    -- Safety gate
    safety_check_passed INTEGER NOT NULL,    -- 1 = passed, 0 = rejected
    safety_violations TEXT,                  -- JSON: any violations detected
    safety_check_duration_ms INTEGER,
    -- Compilation
    compile_attempted INTEGER NOT NULL DEFAULT 0,
    compile_passed  INTEGER,                 -- NULL = not attempted, 1 = passed, 0 = failed
    compile_duration_ms INTEGER,
    compile_errors  TEXT,                    -- JSON: compiler errors if failed
    -- Testing
    tests_attempted INTEGER NOT NULL DEFAULT 0,
    tests_passed    INTEGER,                 -- NULL = not attempted, 1 = all passed, 0 = some failed
    tests_run_count INTEGER,
    tests_pass_count INTEGER,
    tests_fail_count INTEGER,
    test_duration_ms INTEGER,
    test_failures   TEXT,                    -- JSON: failed test details
    -- Benchmarks (before/after)
    benchmark_before TEXT,                   -- JSON: CognitiveBenchmark before modification
    benchmark_after TEXT,                    -- JSON: CognitiveBenchmark after modification
    benchmark_dominates INTEGER,            -- 1 = after dominates before
    -- Application
    applied         INTEGER NOT NULL DEFAULT 0, -- 1 = modification was applied to live system
    applied_at      INTEGER,                -- Epoch ms when applied
    commit_hash     TEXT,                    -- Git commit in source_mirror
    -- Rollback
    rolled_back     INTEGER NOT NULL DEFAULT 0,
    rollback_reason TEXT,
    rollback_at     INTEGER,
    -- Health monitoring (post-apply)
    health_check_passed INTEGER,            -- 1 = healthy after 60s monitoring
    health_check_duration_ms INTEGER,
    -- Outcome
    final_status    TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'applied', 'rolled_back',
                                                     -- 'rejected_safety', 'rejected_compile',
                                                     -- 'rejected_tests', 'rejected_benchmark',
                                                     -- 'rejected_health'
    -- Semantic diff
    behavioral_changes TEXT,                -- JSON: SemanticDiff behavioral changes
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Access pattern: audit trail (chronological)
CREATE INDEX idx_selfmod_time ON self_modifications(timestamp_ms DESC);
-- Access pattern: find by status
CREATE INDEX idx_selfmod_status ON self_modifications(final_status, timestamp_ms DESC);
-- Access pattern: find rollbacks
CREATE INDEX idx_selfmod_rollbacks ON self_modifications(rolled_back) WHERE rolled_back = 1;
-- Access pattern: correlation graph
CREATE INDEX idx_selfmod_correlation ON self_modifications(correlation_id);
-- Access pattern: per-module history
CREATE INDEX idx_selfmod_module ON self_modifications(target_module, timestamp_ms DESC);
-- Access pattern: find by trigger goal
CREATE INDEX idx_selfmod_goal ON self_modifications(trigger_goal_id) WHERE trigger_goal_id IS NOT NULL;

-- ============================================================================
-- PREDICTION ACCURACY LOG
-- Predicted vs observed values, per layer, per channel. Enables tracking
-- of prediction quality over time and detecting model degradation.
-- ============================================================================

CREATE TABLE IF NOT EXISTS prediction_accuracy (
    id              INTEGER PRIMARY KEY,
    -- Traceability
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    correlation_id  TEXT NOT NULL,
    causation_chain TEXT,
    -- Prediction identification
    layer_index     INTEGER NOT NULL,        -- PP layer (0-4)
    channel         TEXT NOT NULL,           -- Sensory channel
    -- Prediction vs observation
    predicted_hash  TEXT,                    -- Hash of predicted state
    observed_hash   TEXT,                    -- Hash of observed state
    -- Error metrics
    prediction_error REAL NOT NULL,          -- Magnitude of error (0-1 normalized)
    error_direction TEXT,                    -- JSON: vector direction of error
    precision       REAL NOT NULL,           -- Confidence in prediction (0-1)
    free_energy     REAL NOT NULL,           -- Variational free energy
    -- Resolution
    resolution      TEXT NOT NULL,           -- 'belief_update', 'action_taken', 'explained_away', 'ignored'
    -- Accuracy tracking (rolling)
    accuracy_1min   REAL,                    -- Rolling accuracy over last minute
    accuracy_5min   REAL,                    -- Rolling accuracy over last 5 minutes
    accuracy_1hr    REAL,                    -- Rolling accuracy over last hour
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Access pattern: per-layer accuracy over time
CREATE INDEX idx_pred_layer_time ON prediction_accuracy(layer_index, timestamp_ms DESC);
-- Access pattern: per-channel accuracy
CREATE INDEX idx_pred_channel ON prediction_accuracy(channel, timestamp_ms DESC);
-- Access pattern: find high-error predictions
CREATE INDEX idx_pred_error ON prediction_accuracy(prediction_error DESC);
-- Access pattern: tick-based lookup
CREATE INDEX idx_pred_tick ON prediction_accuracy(tick_number);
-- Access pattern: correlation graph
CREATE INDEX idx_pred_correlation ON prediction_accuracy(correlation_id);

-- ============================================================================
-- AFFECT STATE LOG
-- Affective dimension values over time and budget decisions.
-- Lower frequency than tick traces (sampled every 10 ticks or on change).
-- Enables understanding of resource allocation decisions.
-- ============================================================================

CREATE TABLE IF NOT EXISTS affect_log (
    id              INTEGER PRIMARY KEY,
    -- Traceability
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    correlation_id  TEXT NOT NULL,
    causation_chain TEXT,
    -- Affective dimensions
    uncertainty     REAL NOT NULL,
    curiosity       REAL NOT NULL,
    frustration     REAL NOT NULL,
    fatigue         REAL NOT NULL,
    novelty_drive   REAL NOT NULL,
    reward_expectation REAL NOT NULL,
    -- Derived
    valence         REAL NOT NULL,
    arousal         REAL NOT NULL,
    -- Budget decisions made from this affect state
    budget_decision TEXT,                    -- JSON: what budget was set and why
    -- What caused this affect change
    trigger_event_type TEXT,                 -- 'surprise', 'success', 'failure', 'idle', 'user_input'
    trigger_magnitude REAL,                  -- How much the trigger changed affect
    -- Delta from previous sample
    delta_valence   REAL,
    delta_arousal   REAL,
    delta_max_dimension TEXT,               -- Which dimension changed most
    delta_max_value REAL,                    -- How much it changed
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Access pattern: time-series visualization
CREATE INDEX idx_affect_log_time ON affect_log(timestamp_ms DESC);
-- Access pattern: session-scoped
CREATE INDEX idx_affect_log_session ON affect_log(session_id, tick_number);
-- Access pattern: find frustration spikes
CREATE INDEX idx_affect_log_frustration ON affect_log(frustration DESC);
-- Access pattern: correlation graph
CREATE INDEX idx_affect_log_correlation ON affect_log(correlation_id);

-- ============================================================================
-- AGENT BID LOG
-- Who bid what, who won, coalition formation. Enables understanding of
-- emergent task allocation and agent competition dynamics.
-- ============================================================================

CREATE TABLE IF NOT EXISTS agent_bids (
    id              INTEGER PRIMARY KEY,
    -- Traceability
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    correlation_id  TEXT NOT NULL,
    causation_chain TEXT,
    -- Bid details
    agent_id        TEXT NOT NULL,           -- Which agent placed this bid
    goal_id         TEXT NOT NULL,           -- What goal the bid is for
    -- Bid values
    urgency         REAL NOT NULL,           -- 0-1: time sensitivity
    expected_value  REAL NOT NULL,           -- Predicted outcome quality
    expected_cost   REAL NOT NULL,           -- Resources needed
    epistemic_value REAL NOT NULL,           -- Information gain
    pragmatic_value REAL NOT NULL,           -- Task completion value
    confidence      REAL NOT NULL,           -- Bidder's confidence
    -- Computed score
    final_score     REAL NOT NULL,           -- Score after affect-weighted computation
    scoring_mode    TEXT NOT NULL,           -- 'exploration', 'frustration', 'normal'
    -- Outcome
    won             INTEGER NOT NULL DEFAULT 0, -- 1 = this bid won
    -- Coalition
    joined_coalition INTEGER NOT NULL DEFAULT 0, -- 1 = merged into existing coalition
    coalition_id    TEXT,                    -- If joined/formed a coalition
    -- Context
    affect_mode     TEXT,                    -- Affect state that influenced scoring
    competing_bids  INTEGER NOT NULL DEFAULT 0, -- How many other bids competed
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Access pattern: per-agent bid history
CREATE INDEX idx_bids_agent ON agent_bids(agent_id, timestamp_ms DESC);
-- Access pattern: per-goal bid competition
CREATE INDEX idx_bids_goal ON agent_bids(goal_id, tick_number);
-- Access pattern: winning bids only
CREATE INDEX idx_bids_winners ON agent_bids(tick_number DESC) WHERE won = 1;
-- Access pattern: time-range queries
CREATE INDEX idx_bids_time ON agent_bids(timestamp_ms DESC);
-- Access pattern: correlation graph
CREATE INDEX idx_bids_correlation ON agent_bids(correlation_id);
-- Access pattern: coalition analysis
CREATE INDEX idx_bids_coalition ON agent_bids(coalition_id) WHERE coalition_id IS NOT NULL;

-- ============================================================================
-- ERROR / PATHOLOGY LOG
-- Cognitive immune system detections and interventions. Tracks anomalies,
-- loops, degradation, and the corrective actions taken.
-- ============================================================================

CREATE TABLE IF NOT EXISTS error_pathology (
    id              INTEGER PRIMARY KEY,
    -- Traceability
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    correlation_id  TEXT NOT NULL,
    causation_chain TEXT,
    -- Detection
    pathology_type  TEXT NOT NULL,           -- 'infinite_loop', 'hallucination', 'resource_leak',
                                             -- 'goal_thrashing', 'memory_corruption', 'affect_stuck',
                                             -- 'prediction_collapse', 'agent_deadlock', 'self_mod_failure',
                                             -- 'constitutional_violation', 'performance_regression'
    severity        TEXT NOT NULL,           -- 'info', 'warning', 'error', 'critical', 'emergency'
    -- Details
    description     TEXT NOT NULL,           -- Human-readable description
    evidence        TEXT NOT NULL,           -- JSON: data supporting the detection
    affected_subsystem TEXT NOT NULL,        -- Which subsystem is affected
    -- Detection method
    detector        TEXT NOT NULL,           -- 'immune_system', 'supervisor', 'homunculus', 'safety_gate'
    detection_confidence REAL NOT NULL,      -- 0-1: how sure the detector is
    -- Intervention
    intervention_type TEXT,                  -- 'throttle', 'restart_subsystem', 'rollback', 'quarantine',
                                             -- 'alert_user', 'force_consolidation', 'reduce_tick_rate',
                                             -- 'disable_agent', 'factory_reset'
    intervention_applied INTEGER NOT NULL DEFAULT 0,
    intervention_at INTEGER,                -- Epoch ms when intervention was applied
    -- Resolution
    resolved        INTEGER NOT NULL DEFAULT 0,
    resolved_at     INTEGER,
    resolution_method TEXT,                  -- How it was ultimately resolved
    -- Impact
    ticks_affected  INTEGER,                -- How many ticks were impacted
    goals_affected  TEXT,                    -- JSON array of affected goal IDs
    data_loss       INTEGER NOT NULL DEFAULT 0, -- 1 = some data was lost
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Access pattern: recent errors
CREATE INDEX idx_errors_time ON error_pathology(timestamp_ms DESC);
-- Access pattern: by severity
CREATE INDEX idx_errors_severity ON error_pathology(severity, timestamp_ms DESC);
-- Access pattern: by type
CREATE INDEX idx_errors_type ON error_pathology(pathology_type, timestamp_ms DESC);
-- Access pattern: unresolved issues
CREATE INDEX idx_errors_unresolved ON error_pathology(resolved) WHERE resolved = 0;
-- Access pattern: correlation graph
CREATE INDEX idx_errors_correlation ON error_pathology(correlation_id);

-- ============================================================================
-- SYNC EVENTS LOG
-- Push/pull/merge operations, bytes transferred, conflicts encountered.
-- Tracks cloud sync activity for debugging and audit.
-- ============================================================================

CREATE TABLE IF NOT EXISTS sync_events (
    id              INTEGER PRIMARY KEY,
    -- Traceability
    tick_number     INTEGER,                 -- May be NULL if sync happens outside tick loop
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    correlation_id  TEXT NOT NULL,
    causation_chain TEXT,
    -- Sync operation
    direction       TEXT NOT NULL,           -- 'push', 'pull', 'merge', 'conflict_resolution'
    scope           TEXT NOT NULL,           -- 'full', 'incremental', 'selective'
    -- Transfer details
    files_affected  INTEGER NOT NULL DEFAULT 0,
    bytes_uploaded  INTEGER NOT NULL DEFAULT 0,
    bytes_downloaded INTEGER NOT NULL DEFAULT 0,
    -- Timing
    duration_ms     INTEGER NOT NULL,
    -- Outcome
    status          TEXT NOT NULL,           -- 'success', 'partial', 'failed', 'conflict'
    error_message   TEXT,
    -- Conflicts
    conflicts_detected INTEGER NOT NULL DEFAULT 0,
    conflicts_resolved INTEGER NOT NULL DEFAULT 0,
    conflict_details TEXT,                   -- JSON: conflict descriptions and resolutions
    -- Encryption
    encrypted       INTEGER NOT NULL DEFAULT 1,
    encryption_overhead_ms INTEGER,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Access pattern: recent sync activity
CREATE INDEX idx_sync_events_time ON sync_events(timestamp_ms DESC);
-- Access pattern: find failures
CREATE INDEX idx_sync_events_status ON sync_events(status) WHERE status != 'success';
-- Access pattern: correlation graph
CREATE INDEX idx_sync_events_correlation ON sync_events(correlation_id);

-- ============================================================================
-- USER INTERACTION LOG
-- Links user messages/actions to cognitive responses. Enables correlation
-- between what the user did and how the system responded cognitively.
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_interactions (
    id              INTEGER PRIMARY KEY,
    -- Traceability
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    timestamp_ms    INTEGER NOT NULL,
    correlation_id  TEXT NOT NULL,
    causation_chain TEXT,
    -- Interaction
    interaction_type TEXT NOT NULL,          -- 'message', 'command', 'file_edit', 'ui_action', 'feedback'
    content_hash    TEXT,                    -- Hash of user content (privacy: don't store raw in telemetry)
    content_length  INTEGER,                -- Length of user input
    -- Cognitive response
    surprise_generated REAL,                -- How surprising was this input
    goals_generated INTEGER NOT NULL DEFAULT 0, -- Goals created in response
    response_tick   INTEGER,                -- Tick when system responded
    response_latency_ms INTEGER,            -- Time from input to response
    -- Quality
    user_satisfaction REAL,                  -- Explicit or inferred satisfaction (-1 to +1)
    feedback_type   TEXT,                    -- 'positive', 'negative', 'correction', 'none'
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- Access pattern: time-range queries
CREATE INDEX idx_user_int_time ON user_interactions(timestamp_ms DESC);
-- Access pattern: session-scoped
CREATE INDEX idx_user_int_session ON user_interactions(session_id, tick_number);
-- Access pattern: correlation graph
CREATE INDEX idx_user_int_correlation ON user_interactions(correlation_id);
-- Access pattern: find negative feedback
CREATE INDEX idx_user_int_feedback ON user_interactions(feedback_type)
    WHERE feedback_type IS NOT NULL AND feedback_type != 'none';

-- ============================================================================
-- TELEMETRY MAINTENANCE METADATA
-- Tracks pruning, archival, and retention operations on the telemetry DB itself.
-- ============================================================================

CREATE TABLE IF NOT EXISTS telemetry_maintenance (
    id              INTEGER PRIMARY KEY,
    -- Operation
    operation_type  TEXT NOT NULL,           -- 'prune', 'archive', 'vacuum', 'integrity_check'
    started_at      INTEGER NOT NULL,
    completed_at    INTEGER,
    duration_ms     INTEGER,
    -- Scope
    tables_affected TEXT NOT NULL,           -- JSON array of table names
    rows_before     INTEGER,
    rows_after      INTEGER,
    rows_removed    INTEGER,
    bytes_freed     INTEGER,
    -- Archive details
    archive_path    TEXT,                    -- Path to archive file if archiving
    archive_format  TEXT,                    -- 'parquet', 'sqlite_backup', 'compressed_json'
    time_range_start INTEGER,               -- Oldest timestamp in archived data
    time_range_end  INTEGER,                -- Newest timestamp in archived data
    -- Status
    status          TEXT NOT NULL DEFAULT 'running', -- 'running', 'completed', 'failed'
    error_message   TEXT,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE INDEX idx_maintenance_time ON telemetry_maintenance(started_at DESC);
CREATE INDEX idx_maintenance_type ON telemetry_maintenance(operation_type, started_at DESC);
