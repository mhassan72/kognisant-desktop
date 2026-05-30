-- =============================================================================
-- Kognisant Desktop — Episodic Memory Database Schema
-- Location: ~/.kc/state/memory_palace/episodic.db
-- Purpose:  Tier 2 episodic buffer — ring buffer of time-indexed sensory
--           sequences. Append-heavy, sequential reads, periodic bulk deletes.
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

INSERT INTO schema_version (version, description) VALUES (1, 'Initial episodic memory schema');

-- =============================================================================
-- Table: episodes
-- Purpose: Each sensory event captured by the episodic buffer. Time-indexed
--          by tick number and sensory channel. This is the primary content
--          table — written once per event, rarely updated.
-- =============================================================================

CREATE TABLE episodes (
    id              INTEGER PRIMARY KEY,                                          -- SQLite rowid alias
    episode_id      TEXT NOT NULL UNIQUE,                                         -- UUID for cross-db references
    tick            INTEGER NOT NULL,                                             -- Tick number when event occurred
    channel         TEXT NOT NULL CHECK (channel IN (
                        'user_message', 'user_typing', 'file_change',
                        'process_output', 'timer_tick', 'llm_response',
                        'self_state', 'error_signal', 'market_signal'
                    )),                                                           -- Sensory channel source
    content         TEXT NOT NULL,                                                -- Serialized event content (JSON)
    content_summary TEXT NOT NULL DEFAULT '',                                     -- Human-readable summary for retrieval
    surprise_value  REAL NOT NULL DEFAULT 0.0 CHECK (surprise_value >= 0.0),      -- Free energy at encoding time
    salience        REAL NOT NULL DEFAULT 0.5 CHECK (salience >= 0.0 AND salience <= 1.0), -- Emotional salience at encoding
    precision       REAL NOT NULL DEFAULT 0.5 CHECK (precision >= 0.0 AND precision <= 1.0), -- Prediction precision weight
    pp_layer        INTEGER NOT NULL DEFAULT 0 CHECK (pp_layer >= 0 AND pp_layer <= 4), -- PP layer that detected surprise
    status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
                        'active', 'consolidated', 'pruned', 'archived'
                    )),                                                           -- Lifecycle state
    consolidation_pass INTEGER NOT NULL DEFAULT 0,                               -- How many times dream engine processed this
    related_node_id TEXT,                                                         -- UUID ref to semantic.db node (if linked)
    source_goal_id  TEXT,                                                         -- UUID ref to goal that generated this event
    session_id      TEXT NOT NULL,                                                -- Session boundary identifier
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Primary query pattern: "last N ticks" and "all events on channel X"
CREATE INDEX idx_episodes_tick_channel ON episodes(tick, channel);

-- Query pattern: find active episodes for consolidation
CREATE INDEX idx_episodes_status ON episodes(status) WHERE status = 'active';

-- Query pattern: find high-surprise episodes for dream engine sampling
CREATE INDEX idx_episodes_surprise ON episodes(surprise_value DESC) WHERE status = 'active';

-- Query pattern: session-based replay
CREATE INDEX idx_episodes_session_tick ON episodes(session_id, tick);

-- Query pattern: find episodes related to a semantic node
CREATE INDEX idx_episodes_related_node ON episodes(related_node_id) WHERE related_node_id IS NOT NULL;

-- Query pattern: temporal range queries
CREATE INDEX idx_episodes_created_at ON episodes(created_at);

-- =============================================================================
-- Table: episode_embeddings
-- Purpose: BLOB storage for f32 embeddings. Separated from episodes table to
--          allow independent access patterns (embeddings are large, not always
--          needed when scanning episode metadata).
-- =============================================================================

CREATE TABLE episode_embeddings (
    id              INTEGER PRIMARY KEY,
    episode_id      INTEGER NOT NULL UNIQUE REFERENCES episodes(id) ON DELETE CASCADE,
    embedding       BLOB NOT NULL,                                               -- Packed f32 little-endian IEEE 754
    embedding_dim   INTEGER NOT NULL CHECK (embedding_dim IN (384, 768)),         -- Dimension count (MiniLM=384, Nomic=768)
    embedding_model TEXT NOT NULL,                                                -- e.g., 'all-MiniLM-L6-v2', 'nomic-embed-text-v1.5'
    embedding_v2    BLOB,                                                        -- Migration target (NULL until migrated)
    embedding_v2_model TEXT,                                                     -- Migration target model name
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: batch load embeddings for HNSW rebuild or similarity search
CREATE INDEX idx_episode_embeddings_model ON episode_embeddings(embedding_model);

-- =============================================================================
-- Table: activation_scores
-- Purpose: Per-tick activation updates for episodes. SEPARATE from content
--          table to avoid write amplification — activations update frequently
--          (potentially every tick for active episodes), content rarely changes.
-- =============================================================================

CREATE TABLE activation_scores (
    id              INTEGER PRIMARY KEY,
    episode_id      INTEGER NOT NULL UNIQUE REFERENCES episodes(id) ON DELETE CASCADE,
    activation      REAL NOT NULL DEFAULT 1.0 CHECK (activation >= 0.0),          -- Current activation energy
    last_activated_tick INTEGER NOT NULL DEFAULT 0,                               -- Tick of last activation boost
    retrieval_count INTEGER NOT NULL DEFAULT 0,                                   -- Times successfully retrieved into WM
    last_retrieval_tick INTEGER NOT NULL DEFAULT 0,                               -- Tick of last retrieval
    decay_rate      REAL NOT NULL DEFAULT 0.001,                                  -- Per-tick exponential decay rate (λ)
    boost_sum       REAL NOT NULL DEFAULT 0.0,                                    -- Cumulative boost from retrievals
    inhibited_until_tick INTEGER NOT NULL DEFAULT 0,                              -- Refractory period end tick
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find top-K activated episodes for WM competition
CREATE INDEX idx_activation_scores_activation ON activation_scores(activation DESC);

-- Query pattern: find episodes past refractory period
CREATE INDEX idx_activation_scores_inhibited ON activation_scores(inhibited_until_tick);

-- Query pattern: find episodes that haven't been activated recently (decay candidates)
CREATE INDEX idx_activation_scores_last_activated ON activation_scores(last_activated_tick);

-- =============================================================================
-- Table: consolidation_state
-- Purpose: Tracks which episodes have been processed by the dream engine and
--          what stage of consolidation they are in. Used to avoid re-processing
--          and to resume interrupted consolidation.
-- =============================================================================

CREATE TABLE consolidation_state (
    id                  INTEGER PRIMARY KEY,
    episode_id          INTEGER NOT NULL UNIQUE REFERENCES episodes(id) ON DELETE CASCADE,
    consolidation_stage TEXT NOT NULL DEFAULT 'pending' CHECK (consolidation_stage IN (
                            'pending',          -- Not yet processed
                            'replayed',         -- Re-run through predictive stack
                            'pattern_extracted', -- Patterns identified
                            'counterfactual',   -- Counterfactuals generated
                            'abstracted',       -- Details replaced with categories
                            'integrated',       -- Written to semantic/procedural
                            'compressed',       -- Archived to LTM
                            'complete'          -- Fully processed
                        )),
    last_processed_tick INTEGER NOT NULL DEFAULT 0,                               -- Tick when last stage completed
    patterns_found      INTEGER NOT NULL DEFAULT 0,                               -- Count of patterns extracted
    counterfactuals_run INTEGER NOT NULL DEFAULT 0,                               -- Count of counterfactuals generated
    target_tier         TEXT CHECK (target_tier IN ('semantic', 'procedural', 'ltm', NULL)), -- Where consolidated output went
    target_id           TEXT,                                                     -- UUID of created node/procedure/memory
    error_message       TEXT,                                                     -- If consolidation failed, why
    created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find episodes ready for next consolidation stage
CREATE INDEX idx_consolidation_state_stage ON consolidation_state(consolidation_stage)
    WHERE consolidation_stage != 'complete';

-- Query pattern: find recently consolidated episodes
CREATE INDEX idx_consolidation_state_processed ON consolidation_state(last_processed_tick DESC);
