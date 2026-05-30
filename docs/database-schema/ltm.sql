-- =============================================================================
-- Kognisant Desktop — Long-Term Memory Database Schema
-- Location: ~/.kc/state/memory_palace/ltm.db
-- Purpose:  Tier 5 consolidated long-term memory — compressed embeddings and
--           symbolic summaries. Bulk reads during consolidation, rare
--           individual access. Very slow decay (half-life ~19h).
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

INSERT INTO schema_version (version, description) VALUES (1, 'Initial long-term memory schema');

-- =============================================================================
-- Table: consolidated_memories
-- Purpose: Compressed embeddings + symbolic summaries of consolidated knowledge.
--          These are the final resting place of episodic memories after full
--          dream engine processing. Stored with reduced precision (f16 possible)
--          and symbolic summaries for efficient retrieval.
-- =============================================================================

CREATE TABLE consolidated_memories (
    id                  INTEGER PRIMARY KEY,
    memory_id           TEXT NOT NULL UNIQUE,                                     -- UUID for cross-db references
    summary             TEXT NOT NULL,                                            -- Human-readable symbolic summary
    abstract_content    TEXT NOT NULL DEFAULT '',                                 -- Abstracted content (categories replace specifics)
    category            TEXT NOT NULL CHECK (category IN (
                            'episode_cluster',  -- Compressed cluster of related episodes
                            'pattern',          -- Extracted recurring pattern
                            'generalization',   -- Abstracted concept
                            'skill_trace',      -- Procedural skill execution trace
                            'causal_model',     -- Consolidated causal understanding
                            'user_interaction', -- Compressed user interaction pattern
                            'project_context'   -- Long-term project knowledge
                        )),
    embedding           BLOB NOT NULL,                                           -- Compressed embedding (may be f16 for old entries)
    embedding_dim       INTEGER NOT NULL CHECK (embedding_dim IN (384, 768)),     -- Dimension count
    embedding_model     TEXT NOT NULL,                                            -- Model identifier
    embedding_precision TEXT NOT NULL DEFAULT 'f32' CHECK (embedding_precision IN ('f32', 'f16')), -- Precision level
    source_episode_ids  TEXT NOT NULL DEFAULT '[]',                               -- JSON array of source episode UUIDs
    source_node_ids     TEXT NOT NULL DEFAULT '[]',                               -- JSON array of source semantic node UUIDs
    source_tick_range   TEXT NOT NULL DEFAULT '{}',                               -- JSON: {start_tick, end_tick} of source material
    consolidation_id    TEXT NOT NULL,                                            -- UUID of the consolidation run that created this
    activation          REAL NOT NULL DEFAULT 0.4 CHECK (activation >= 0.0),      -- Current activation level
    decay_rate          REAL NOT NULL DEFAULT 0.000001,                           -- Per-tick decay (very slow — ~19h half-life)
    retrieval_count     INTEGER NOT NULL DEFAULT 0,                               -- Times decompressed and retrieved
    last_retrieval_tick INTEGER NOT NULL DEFAULT 0,                               -- Tick of last retrieval
    confidence          REAL NOT NULL DEFAULT 0.7 CHECK (confidence >= 0.0 AND confidence <= 1.0), -- How reliable this memory is
    emotional_valence   REAL NOT NULL DEFAULT 0.0 CHECK (emotional_valence >= -1.0 AND emotional_valence <= 1.0), -- Emotional tone at encoding
    importance          REAL NOT NULL DEFAULT 0.5 CHECK (importance >= 0.0 AND importance <= 1.0), -- Assessed importance
    status              TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
                            'active',       -- Available for retrieval
                            'dormant',      -- Very low activation, not searched
                            'pruned'        -- Marked for physical deletion
                        )),
    metadata            TEXT NOT NULL DEFAULT '{}',                               -- Additional JSON metadata
    created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find active memories for retrieval competition
CREATE INDEX idx_consolidated_activation ON consolidated_memories(activation DESC)
    WHERE status = 'active';

-- Query pattern: find memories by category
CREATE INDEX idx_consolidated_category ON consolidated_memories(category)
    WHERE status = 'active';

-- Query pattern: find memories by embedding model (for migration)
CREATE INDEX idx_consolidated_embedding_model ON consolidated_memories(embedding_model);

-- Query pattern: find dormant memories for potential pruning
CREATE INDEX idx_consolidated_status ON consolidated_memories(status);

-- Query pattern: find memories by importance (for priority retrieval)
CREATE INDEX idx_consolidated_importance ON consolidated_memories(importance DESC)
    WHERE status = 'active';

-- Query pattern: find memories by consolidation run
CREATE INDEX idx_consolidated_consolidation ON consolidated_memories(consolidation_id);

-- =============================================================================
-- Table: consolidation_log
-- Purpose: Records when and how each consolidation run occurred. Tracks the
--          dream engine's activity for debugging and monitoring.
-- =============================================================================

CREATE TABLE consolidation_log (
    id                  INTEGER PRIMARY KEY,
    consolidation_id    TEXT NOT NULL UNIQUE,                                     -- UUID of this consolidation run
    started_at_tick     INTEGER NOT NULL,                                         -- Tick when consolidation began
    ended_at_tick       INTEGER,                                                 -- Tick when consolidation ended (NULL if interrupted)
    trigger             TEXT NOT NULL CHECK (trigger IN (
                            'fatigue',          -- Fatigue > 0.6 triggered consolidation
                            'idle',             -- User idle > 60s
                            'buffer_full',      -- Episodic buffer approaching capacity
                            'scheduled',        -- Periodic maintenance schedule
                            'memory_agent',     -- MemoryAgent requested consolidation
                            'manual'            -- User triggered via command
                        )),
    status              TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN (
                            'in_progress',  -- Currently running
                            'completed',    -- Finished successfully
                            'interrupted',  -- User returned or system needed resources
                            'failed'        -- Error during consolidation
                        )),
    episodes_processed  INTEGER NOT NULL DEFAULT 0,                              -- Number of episodes processed
    episodes_sampled    INTEGER NOT NULL DEFAULT 0,                              -- Number of episodes sampled for replay
    patterns_extracted  INTEGER NOT NULL DEFAULT 0,                              -- Patterns found
    counterfactuals_run INTEGER NOT NULL DEFAULT 0,                              -- Counterfactual simulations executed
    memories_created    INTEGER NOT NULL DEFAULT 0,                              -- New LTM entries created
    nodes_created       INTEGER NOT NULL DEFAULT 0,                              -- New semantic nodes created
    procedures_updated  INTEGER NOT NULL DEFAULT 0,                              -- Procedural memory updates
    episodes_pruned     INTEGER NOT NULL DEFAULT 0,                              -- Episodes removed from episodic buffer
    fatigue_before      REAL NOT NULL DEFAULT 0.0,                               -- Fatigue level at start
    fatigue_after       REAL,                                                    -- Fatigue level at end
    duration_ticks      INTEGER NOT NULL DEFAULT 0,                              -- Total ticks spent
    error_message       TEXT,                                                    -- Error details if failed
    metadata            TEXT NOT NULL DEFAULT '{}',                               -- Additional JSON stats
    created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find recent consolidation runs
CREATE INDEX idx_consolidation_log_started ON consolidation_log(started_at_tick DESC);

-- Query pattern: find incomplete consolidation runs (for resume)
CREATE INDEX idx_consolidation_log_status ON consolidation_log(status)
    WHERE status = 'in_progress';

-- Query pattern: find consolidation runs by trigger type
CREATE INDEX idx_consolidation_log_trigger ON consolidation_log(trigger);

-- =============================================================================
-- Table: patterns
-- Purpose: Extracted patterns from the dream engine. Patterns are recurring
--          structures detected across multiple episodes. They feed into
--          semantic network nodes and procedural memory rules.
-- =============================================================================

CREATE TABLE patterns (
    id              INTEGER PRIMARY KEY,
    pattern_id      TEXT NOT NULL UNIQUE,                                         -- UUID for cross-db references
    consolidation_id TEXT NOT NULL,                                               -- UUID of consolidation run that found this
    pattern_type    TEXT NOT NULL CHECK (pattern_type IN (
                        'temporal',     -- "A always precedes B"
                        'causal',       -- "When I do X, Y happens"
                        'structural',   -- "These episodes share abstract structure"
                        'behavioral',   -- "User consistently does X in context Y"
                        'failure',      -- "This approach consistently fails"
                        'success'       -- "This approach consistently succeeds"
                    )),
    description     TEXT NOT NULL,                                                -- Human-readable pattern description
    abstract_form   TEXT NOT NULL DEFAULT '{}',                                   -- JSON: abstracted pattern structure
    source_episodes TEXT NOT NULL DEFAULT '[]',                                   -- JSON array of source episode UUIDs
    episode_count   INTEGER NOT NULL DEFAULT 0,                                  -- Number of supporting episodes
    confidence      REAL NOT NULL DEFAULT 0.5 CHECK (confidence >= 0.0 AND confidence <= 1.0), -- Pattern confidence
    generalizability REAL NOT NULL DEFAULT 0.5 CHECK (generalizability >= 0.0 AND generalizability <= 1.0), -- Cross-context applicability
    embedding       BLOB NOT NULL,                                               -- Pattern embedding for similarity search
    embedding_dim   INTEGER NOT NULL CHECK (embedding_dim IN (384, 768)),
    embedding_model TEXT NOT NULL,
    integrated      INTEGER NOT NULL DEFAULT 0 CHECK (integrated IN (0, 1)),      -- Whether written to semantic/procedural
    target_type     TEXT CHECK (target_type IN (
                        'semantic_node', 'procedural_rule', 'skill_candidate', NULL
                    )),                                                           -- Where this pattern was integrated
    target_id       TEXT,                                                         -- UUID of created target
    domain          TEXT NOT NULL DEFAULT 'general',                              -- Domain context
    status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
                        'active',       -- Valid pattern
                        'integrated',   -- Successfully written to target tier
                        'invalidated',  -- Contradicted by newer evidence
                        'pruned'        -- Removed
                    )),
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find patterns by type
CREATE INDEX idx_patterns_type ON patterns(pattern_type) WHERE status = 'active';

-- Query pattern: find unintegrated patterns (pending write to other tiers)
CREATE INDEX idx_patterns_integrated ON patterns(integrated)
    WHERE integrated = 0 AND status = 'active';

-- Query pattern: find patterns by consolidation run
CREATE INDEX idx_patterns_consolidation ON patterns(consolidation_id);

-- Query pattern: find high-confidence patterns
CREATE INDEX idx_patterns_confidence ON patterns(confidence DESC)
    WHERE status = 'active';

-- Query pattern: find patterns by domain
CREATE INDEX idx_patterns_domain ON patterns(domain) WHERE status = 'active';
