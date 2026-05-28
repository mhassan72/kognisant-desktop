-- ============================================================================
-- Kognisant Memory Palace Schema
-- Location: ~/.kognisant/projects/{id}/memory_palace.db
-- Purpose: Multi-tier neuro-symbolic memory system. Implements the 5-tier
--          memory architecture: Working Memory (transient), Episodic Buffer,
--          Semantic Network, Procedural Memory, Consolidated LTM, and
--          Dream Engine state.
-- ============================================================================

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA synchronous = NORMAL;

-- ============================================================================
-- TIER 1: WORKING MEMORY SLOTS
-- NOTE: Working memory is primarily an in-memory Rust struct (per-tick refresh).
-- This table persists WM state for crash recovery and session continuity only.
-- Capacity is dynamic, bounded by LLM context window and available RAM.
-- ============================================================================

CREATE TABLE IF NOT EXISTS working_memory_slots (
    id              INTEGER PRIMARY KEY,
    slot_index      INTEGER NOT NULL,        -- Position in WM (0-based)
    chunk_type      TEXT NOT NULL,           -- 'episodic', 'semantic', 'procedural', 'ltm', 'prediction', 'goal'
    source_id       TEXT,                    -- Reference to source memory (table:id format)
    -- Content
    content         TEXT NOT NULL,           -- JSON: serialized memory chunk
    content_hash    TEXT NOT NULL,           -- For dedup detection
    -- Activation dynamics
    activation      REAL NOT NULL DEFAULT 1.0, -- Current activation level (decays without rehearsal)
    relevance_score REAL NOT NULL DEFAULT 0.0, -- Why this chunk won competition
    rehearsal_count INTEGER NOT NULL DEFAULT 0, -- Times re-activated this session
    -- Context binding
    bound_to_goal   TEXT,                    -- Goal ID this chunk serves
    bound_to_tick   INTEGER,                 -- Tick when loaded
    -- Lifecycle
    loaded_at       INTEGER NOT NULL,        -- Epoch ms when entered WM
    last_accessed   INTEGER NOT NULL,        -- Epoch ms of last read
    evicted_at      INTEGER,                 -- NULL = still in WM
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE INDEX idx_wm_active ON working_memory_slots(evicted_at) WHERE evicted_at IS NULL;
CREATE INDEX idx_wm_activation ON working_memory_slots(activation DESC) WHERE evicted_at IS NULL;

-- ============================================================================
-- TIER 2: EPISODIC BUFFER
-- Ring buffer of time-indexed sensory sequences. Stores the last N ticks of
-- experience with embeddings for similarity search. Implements short-term
-- binding and immediate replay capability.
-- ============================================================================

CREATE TABLE IF NOT EXISTS episodic_buffer (
    id              INTEGER PRIMARY KEY,
    tick_number     INTEGER NOT NULL,        -- Global tick when this episode occurred
    session_id      TEXT NOT NULL,           -- Session boundary reference
    timestamp_ms    INTEGER NOT NULL,        -- Wall clock (epoch ms)
    -- Episode content
    channel         TEXT NOT NULL,           -- Sensory channel: 'user_message', 'file_change', 'tool_output', etc.
    content         TEXT NOT NULL,           -- JSON: full sensory event data
    content_summary TEXT,                    -- Compressed text summary (for LLM context)
    -- Embedding for similarity search
    embedding       BLOB,                   -- f32 array (semantic embedding of content)
    embedding_dim   INTEGER,                -- Dimension of embedding vector
    embedding_model TEXT,                    -- Model used to generate embedding
    -- Surprise/salience at time of recording
    surprise_value  REAL NOT NULL DEFAULT 0.0, -- Free energy at this tick
    precision       REAL NOT NULL DEFAULT 0.5, -- Confidence in prediction that was violated
    -- Activation & retrieval
    activation      REAL NOT NULL DEFAULT 1.0, -- Decays over time, boosted by retrieval
    retrieval_count INTEGER NOT NULL DEFAULT 0, -- Times this episode was recalled
    last_retrieved  INTEGER,                 -- Epoch ms of last retrieval
    -- Emotional tagging (for salience-weighted retrieval)
    valence         REAL DEFAULT 0.0,        -- -1 to +1 (negative to positive)
    arousal         REAL DEFAULT 0.0,        -- 0 to 1 (calm to activated)
    -- Consolidation state
    consolidated    INTEGER NOT NULL DEFAULT 0, -- 1 = absorbed into LTM
    consolidation_id INTEGER,               -- FK to consolidation_log if consolidated
    -- Pruning metadata
    importance_score REAL NOT NULL DEFAULT 0.5, -- Computed: surprise × recency × retrieval
    archive_eligible INTEGER NOT NULL DEFAULT 0,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Primary access pattern: time-range queries for replay
CREATE INDEX idx_episodic_time ON episodic_buffer(timestamp_ms DESC);
CREATE INDEX idx_episodic_tick ON episodic_buffer(tick_number DESC);
-- Access pattern: find episodes by channel type within time range
CREATE INDEX idx_episodic_channel ON episodic_buffer(channel, timestamp_ms DESC);
-- Access pattern: find high-surprise episodes for consolidation
CREATE INDEX idx_episodic_surprise ON episodic_buffer(surprise_value DESC) WHERE consolidated = 0;
-- Access pattern: session-scoped queries
CREATE INDEX idx_episodic_session ON episodic_buffer(session_id, tick_number);
-- Pruning: find archive-eligible episodes
CREATE INDEX idx_episodic_prune ON episodic_buffer(importance_score ASC) WHERE archive_eligible = 1;

-- ============================================================================
-- TIER 3: SEMANTIC NETWORK — NODES (Concepts)
-- Graph-structured knowledge store. Nodes represent concepts, categories,
-- entities, and schemas. Supports both graph traversal and vector similarity
-- queries (hybrid retrieval).
-- ============================================================================

CREATE TABLE IF NOT EXISTS semantic_nodes (
    id              INTEGER PRIMARY KEY,
    node_id         TEXT NOT NULL UNIQUE,    -- Stable identifier (slug or UUID)
    label           TEXT NOT NULL,           -- Human-readable concept name
    category        TEXT NOT NULL,           -- 'entity', 'concept', 'category', 'schema', 'action', 'property'
    -- Embedding for vector similarity
    embedding       BLOB,                   -- f32 array
    embedding_dim   INTEGER,
    embedding_model TEXT,
    -- Activation dynamics (competitive memory)
    activation      REAL NOT NULL DEFAULT 0.0, -- Current activation (0-1, decays per tick)
    base_activation REAL NOT NULL DEFAULT 0.1, -- Resting activation (increases with use)
    stability       REAL NOT NULL DEFAULT 0.1, -- How well-established (0-1, grows with evidence)
    -- Content
    definition      TEXT,                    -- JSON: structured definition/properties
    examples        TEXT,                    -- JSON array: concrete instances
    source          TEXT,                    -- Where this concept came from ('user', 'inferred', 'llm', 'consolidated')
    -- Usage statistics
    usage_count     INTEGER NOT NULL DEFAULT 0,
    last_activated  INTEGER,                 -- Epoch ms
    activation_history TEXT,                 -- JSON: last 10 activation timestamps (for decay computation)
    -- Graph metrics (cached, recomputed periodically)
    in_degree       INTEGER NOT NULL DEFAULT 0,  -- Number of incoming edges
    out_degree      INTEGER NOT NULL DEFAULT 0,  -- Number of outgoing edges
    centrality      REAL DEFAULT 0.0,        -- PageRank-style importance
    -- Lifecycle
    is_active       INTEGER NOT NULL DEFAULT 1,
    archived_at     INTEGER,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: find nodes by label (exact or prefix)
CREATE INDEX idx_semantic_label ON semantic_nodes(label);
-- Access pattern: category-filtered queries
CREATE INDEX idx_semantic_category ON semantic_nodes(category, is_active);
-- Access pattern: activation-based competition (find most active nodes)
CREATE INDEX idx_semantic_activation ON semantic_nodes(activation DESC) WHERE is_active = 1;
-- Access pattern: stability-based pruning (find unstable nodes)
CREATE INDEX idx_semantic_stability ON semantic_nodes(stability ASC) WHERE is_active = 1;
-- Access pattern: centrality for importance ranking
CREATE INDEX idx_semantic_centrality ON semantic_nodes(centrality DESC) WHERE is_active = 1;

-- ============================================================================
-- TIER 3: SEMANTIC NETWORK — EDGES (Relations)
-- Typed, weighted edges between concept nodes. Supports spread activation
-- (propagate activation along edges with decay) and graph traversal queries.
-- ============================================================================

CREATE TABLE IF NOT EXISTS semantic_edges (
    id              INTEGER PRIMARY KEY,
    source_node_id  TEXT NOT NULL,           -- FK to semantic_nodes.node_id
    target_node_id  TEXT NOT NULL,           -- FK to semantic_nodes.node_id
    relation_type   TEXT NOT NULL,           -- 'is_a', 'part_of', 'causes', 'enables', 'similar_to',
                                             -- 'contradicts', 'precedes', 'used_for', 'implies',
                                             -- 'has_property', 'instance_of', 'co_occurs'
    -- Edge weight and confidence
    strength        REAL NOT NULL DEFAULT 0.5, -- 0-1, how strong the relation
    confidence      REAL NOT NULL DEFAULT 0.5, -- 0-1, how certain we are it exists
    evidence_count  INTEGER NOT NULL DEFAULT 1, -- Number of observations supporting this edge
    -- Directionality
    is_bidirectional INTEGER NOT NULL DEFAULT 0, -- 1 = relation holds both ways
    -- Spread activation parameters
    propagation_weight REAL NOT NULL DEFAULT 0.5, -- How much activation passes through (0-1)
    decay_factor    REAL NOT NULL DEFAULT 0.7,    -- Activation decay per hop
    -- Provenance
    source          TEXT,                    -- 'observed', 'inferred', 'llm', 'user', 'consolidated'
    first_observed  INTEGER,                 -- Epoch ms
    last_observed   INTEGER,                 -- Epoch ms
    -- Lifecycle
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (source_node_id) REFERENCES semantic_nodes(node_id) ON DELETE CASCADE,
    FOREIGN KEY (target_node_id) REFERENCES semantic_nodes(node_id) ON DELETE CASCADE
);

-- Access pattern: graph traversal from a node (outgoing edges)
CREATE INDEX idx_edges_source ON semantic_edges(source_node_id, relation_type) WHERE is_active = 1;
-- Access pattern: reverse traversal (incoming edges)
CREATE INDEX idx_edges_target ON semantic_edges(target_node_id, relation_type) WHERE is_active = 1;
-- Access pattern: find strongest edges for spread activation
CREATE INDEX idx_edges_strength ON semantic_edges(strength DESC) WHERE is_active = 1;
-- Access pattern: find edges by type (e.g., all causal relations)
CREATE INDEX idx_edges_type ON semantic_edges(relation_type, strength DESC) WHERE is_active = 1;
-- Uniqueness: only one edge of each type between two nodes
CREATE UNIQUE INDEX idx_edges_unique ON semantic_edges(source_node_id, target_node_id, relation_type)
    WHERE is_active = 1;

-- ============================================================================
-- TIER 4: PROCEDURAL MEMORY
-- Condition → Action → Outcome chains with reinforcement learning weights.
-- These are the system's learned "skills" — how to do things, not what things are.
-- Updated through trial-and-error and imitation (LLM demonstrations).
-- ============================================================================

CREATE TABLE IF NOT EXISTS procedural_memory (
    id              INTEGER PRIMARY KEY,
    procedure_id    TEXT NOT NULL UNIQUE,    -- Stable identifier
    name            TEXT NOT NULL,           -- Human-readable procedure name
    category        TEXT NOT NULL,           -- 'tool_use', 'planning', 'debugging', 'communication', 'meta'
    -- Condition (when to activate)
    condition       TEXT NOT NULL,           -- JSON: context pattern that triggers this procedure
    condition_embedding BLOB,               -- f32 array for fast matching
    condition_embedding_dim INTEGER,
    -- Action (what to do)
    action_template TEXT NOT NULL,           -- JSON: parameterized action sequence
    action_steps    INTEGER NOT NULL DEFAULT 1, -- Number of steps in the procedure
    -- Expected outcome
    expected_outcome TEXT NOT NULL,          -- JSON: predicted result
    outcome_embedding BLOB,                 -- f32 array for outcome similarity
    outcome_embedding_dim INTEGER,
    -- Reinforcement learning weights
    confidence      REAL NOT NULL DEFAULT 0.5, -- Q-value: expected reward (0-1)
    learning_rate   REAL NOT NULL DEFAULT 0.1, -- How fast this procedure updates
    discount_factor REAL NOT NULL DEFAULT 0.9, -- Temporal discounting for multi-step
    -- Execution statistics
    execution_count INTEGER NOT NULL DEFAULT 0,
    success_count   INTEGER NOT NULL DEFAULT 0,
    failure_count   INTEGER NOT NULL DEFAULT 0,
    avg_duration_ms INTEGER,                -- Average execution time
    last_executed   INTEGER,                -- Epoch ms
    last_outcome    TEXT,                    -- 'success', 'failure', 'partial', 'timeout'
    -- Exploration vs exploitation
    exploration_bonus REAL NOT NULL DEFAULT 0.1, -- UCB exploration term (decays with use)
    novelty_score   REAL NOT NULL DEFAULT 1.0,  -- How novel this procedure still is
    -- Generalization
    generality      REAL NOT NULL DEFAULT 0.5,  -- 0=very specific, 1=very general
    domain          TEXT,                    -- Domain restriction (NULL = universal)
    -- Lifecycle
    is_active       INTEGER NOT NULL DEFAULT 1,
    superseded_by   INTEGER,                -- FK to newer version of this procedure
    archived_at     INTEGER,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (superseded_by) REFERENCES procedural_memory(id) ON DELETE SET NULL
);

-- Access pattern: find procedures matching current context
CREATE INDEX idx_proc_category ON procedural_memory(category, is_active);
-- Access pattern: highest confidence procedures (exploitation)
CREATE INDEX idx_proc_confidence ON procedural_memory(confidence DESC) WHERE is_active = 1;
-- Access pattern: highest exploration bonus (exploration)
CREATE INDEX idx_proc_exploration ON procedural_memory(exploration_bonus DESC) WHERE is_active = 1;
-- Access pattern: recently executed (for temporal context)
CREATE INDEX idx_proc_recent ON procedural_memory(last_executed DESC) WHERE is_active = 1;

-- Procedure execution history (for RL updates)
CREATE TABLE IF NOT EXISTS procedural_outcomes (
    id              INTEGER PRIMARY KEY,
    procedure_id    TEXT NOT NULL,           -- FK to procedural_memory.procedure_id
    tick_number     INTEGER NOT NULL,
    session_id      TEXT NOT NULL,
    -- Execution context
    context_snapshot TEXT NOT NULL,          -- JSON: state when procedure was triggered
    parameters      TEXT,                    -- JSON: actual parameters used
    -- Outcome
    outcome         TEXT NOT NULL,           -- 'success', 'failure', 'partial', 'timeout', 'aborted'
    reward          REAL NOT NULL,           -- -1 to +1 (punishment to reward)
    duration_ms     INTEGER,
    -- What happened
    result_summary  TEXT,                    -- Brief description of what occurred
    error_type      TEXT,                    -- If failed: error category
    -- RL update applied
    confidence_delta REAL,                   -- How much confidence changed
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (procedure_id) REFERENCES procedural_memory(procedure_id) ON DELETE CASCADE
);

CREATE INDEX idx_proc_outcomes_proc ON procedural_outcomes(procedure_id, created_at DESC);
CREATE INDEX idx_proc_outcomes_tick ON procedural_outcomes(tick_number);

-- ============================================================================
-- TIER 5: CONSOLIDATED LONG-TERM MEMORY
-- Generalized episodes and abstracted concepts formed during sleep/consolidation.
-- Sparse distributed representations with symbolic summaries.
-- These are the "gist" of experience — details forgotten, patterns retained.
-- ============================================================================

CREATE TABLE IF NOT EXISTS consolidated_ltm (
    id              INTEGER PRIMARY KEY,
    ltm_id          TEXT NOT NULL UNIQUE,    -- Stable identifier
    memory_type     TEXT NOT NULL,           -- 'generalized_episode', 'abstracted_concept', 'schema', 'rule'
    -- Content
    symbolic_summary TEXT NOT NULL,          -- Human-readable summary of the memory
    structured_content TEXT NOT NULL,        -- JSON: full structured representation
    -- Compressed embedding (sparse distributed representation)
    embedding       BLOB NOT NULL,          -- f32 array (compressed from multiple episodes)
    embedding_dim   INTEGER NOT NULL,
    compression_ratio REAL,                 -- How much compression from source episodes
    -- Source tracking
    source_episodes TEXT NOT NULL,           -- JSON array of episodic_buffer IDs that formed this
    source_count    INTEGER NOT NULL,        -- Number of episodes consolidated
    consolidation_id INTEGER NOT NULL,       -- FK to dream_consolidation_log
    -- Retrieval dynamics
    activation      REAL NOT NULL DEFAULT 0.5,
    retrieval_count INTEGER NOT NULL DEFAULT 0,
    last_retrieved  INTEGER,
    -- Quality metrics
    coherence_score REAL NOT NULL DEFAULT 0.5, -- Internal consistency (0-1)
    utility_score   REAL NOT NULL DEFAULT 0.5, -- How useful in practice (0-1)
    stability       REAL NOT NULL DEFAULT 0.5, -- Resistance to modification
    -- Lifecycle
    is_active       INTEGER NOT NULL DEFAULT 1,
    last_reinforced INTEGER,                 -- Epoch ms when last confirmed by new evidence
    decay_rate      REAL NOT NULL DEFAULT 0.001, -- How fast this memory fades without reinforcement
    archived_at     INTEGER,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (consolidation_id) REFERENCES dream_consolidation_log(id) ON DELETE SET NULL
);

-- Access pattern: retrieval by activation (competitive)
CREATE INDEX idx_ltm_activation ON consolidated_ltm(activation DESC) WHERE is_active = 1;
-- Access pattern: type-filtered queries
CREATE INDEX idx_ltm_type ON consolidated_ltm(memory_type, is_active);
-- Access pattern: find memories needing reinforcement (decay prevention)
CREATE INDEX idx_ltm_decay ON consolidated_ltm(last_reinforced ASC) WHERE is_active = 1;

-- ============================================================================
-- TIER 6: DREAM ENGINE STATE
-- Consolidation logs, pattern extractions, and counterfactual generation records.
-- The dream engine runs during idle periods, replaying and abstracting memories.
-- ============================================================================

CREATE TABLE IF NOT EXISTS dream_consolidation_log (
    id              INTEGER PRIMARY KEY,
    session_id      TEXT,                    -- Session during which consolidation occurred
    -- Timing
    started_at      INTEGER NOT NULL,        -- Epoch ms
    completed_at    INTEGER,                 -- Epoch ms (NULL = in progress)
    duration_ms     INTEGER,
    -- Trigger
    trigger_type    TEXT NOT NULL,           -- 'idle', 'scheduled', 'fatigue', 'manual', 'buffer_full'
    -- Input
    episodes_processed INTEGER NOT NULL DEFAULT 0,
    tick_range_start INTEGER,                -- First tick in consolidation window
    tick_range_end  INTEGER,                 -- Last tick in consolidation window
    -- Output
    patterns_extracted INTEGER NOT NULL DEFAULT 0,
    concepts_created INTEGER NOT NULL DEFAULT 0,
    concepts_updated INTEGER NOT NULL DEFAULT 0,
    edges_created   INTEGER NOT NULL DEFAULT 0,
    ltm_entries_created INTEGER NOT NULL DEFAULT 0,
    procedures_updated INTEGER NOT NULL DEFAULT 0,
    -- Quality
    coherence_before REAL,                   -- Semantic network coherence before
    coherence_after REAL,                    -- Semantic network coherence after
    -- Counterfactuals
    counterfactuals_generated INTEGER NOT NULL DEFAULT 0,
    insights_produced INTEGER NOT NULL DEFAULT 0,
    -- Status
    status          TEXT NOT NULL DEFAULT 'running', -- 'running', 'completed', 'interrupted', 'failed'
    error_message   TEXT,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE INDEX idx_dream_time ON dream_consolidation_log(started_at DESC);
CREATE INDEX idx_dream_status ON dream_consolidation_log(status);

-- Patterns extracted during consolidation
CREATE TABLE IF NOT EXISTS dream_patterns (
    id              INTEGER PRIMARY KEY,
    consolidation_id INTEGER NOT NULL,
    -- Pattern definition
    pattern_type    TEXT NOT NULL,           -- 'temporal_sequence', 'co_occurrence', 'causal', 'analogy', 'anomaly'
    description     TEXT NOT NULL,           -- Human-readable pattern description
    pattern_data    TEXT NOT NULL,           -- JSON: structured pattern representation
    -- Evidence
    supporting_episodes TEXT NOT NULL,       -- JSON array of episode IDs
    evidence_strength REAL NOT NULL,         -- 0-1
    -- Application
    applied_to      TEXT,                    -- JSON: what was updated (nodes, edges, procedures)
    confidence      REAL NOT NULL DEFAULT 0.5,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (consolidation_id) REFERENCES dream_consolidation_log(id) ON DELETE CASCADE
);

CREATE INDEX idx_patterns_consolidation ON dream_patterns(consolidation_id);
CREATE INDEX idx_patterns_type ON dream_patterns(pattern_type, confidence DESC);

-- Counterfactual simulations run during dreaming
CREATE TABLE IF NOT EXISTS dream_counterfactuals (
    id              INTEGER PRIMARY KEY,
    consolidation_id INTEGER NOT NULL,
    -- What-if scenario
    original_episode_id INTEGER NOT NULL,    -- Episode being counterfactualized
    intervention    TEXT NOT NULL,           -- JSON: what was changed
    -- Results
    predicted_outcome TEXT NOT NULL,         -- JSON: what would have happened
    actual_outcome  TEXT NOT NULL,           -- JSON: what actually happened
    regret_score    REAL,                    -- How much better the alternative was (0-1)
    relief_score    REAL,                    -- How much worse the alternative was (0-1)
    -- Learning
    lesson_extracted TEXT,                   -- What was learned from this counterfactual
    applied_to_procedure TEXT,              -- Procedure ID if this updated a skill
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (consolidation_id) REFERENCES dream_consolidation_log(id) ON DELETE CASCADE
);

CREATE INDEX idx_counterfactuals_consolidation ON dream_counterfactuals(consolidation_id);
CREATE INDEX idx_counterfactuals_regret ON dream_counterfactuals(regret_score DESC);
