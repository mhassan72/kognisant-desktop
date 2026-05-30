-- =============================================================================
-- Kognisant Desktop — Semantic Network Database Schema
-- Location: ~/.kc/state/memory_palace/semantic.db
-- Purpose:  Tier 3 semantic network — concept nodes and typed edges.
--           Random reads, frequent activation updates, graph traversals.
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

INSERT INTO schema_version (version, description) VALUES (1, 'Initial semantic network schema');

-- =============================================================================
-- Table: nodes
-- Purpose: Concept nodes in the semantic network. Each node represents a
--          concept, entity, pattern, or abstraction. Nodes have embeddings
--          for vector similarity search and metadata for graph operations.
-- =============================================================================

CREATE TABLE nodes (
    id              INTEGER PRIMARY KEY,                                          -- SQLite rowid alias
    node_id         TEXT NOT NULL UNIQUE,                                         -- UUID for cross-db references
    label           TEXT NOT NULL,                                                -- Human-readable concept label
    category        TEXT NOT NULL CHECK (category IN (
                        'concept',      -- Abstract concept (e.g., "authentication")
                        'entity',       -- Named entity (e.g., "React", "PostgreSQL")
                        'pattern',      -- Extracted pattern from dream engine
                        'abstraction',  -- Generalized from multiple episodes
                        'belief',       -- Proposition about the world
                        'preference',   -- User preference
                        'skill',        -- Skill-related concept
                        'project',      -- Project-specific concept
                        'domain'        -- Domain knowledge
                    )),
    content         TEXT NOT NULL DEFAULT '',                                     -- Full text content for embedding
    embedding       BLOB NOT NULL,                                               -- Packed f32 little-endian IEEE 754
    embedding_dim   INTEGER NOT NULL CHECK (embedding_dim IN (384, 768)),         -- Dimension count
    embedding_model TEXT NOT NULL,                                                -- Model identifier
    embedding_v2    BLOB,                                                        -- Migration target embedding
    embedding_v2_model TEXT,                                                     -- Migration target model name
    stability       REAL NOT NULL DEFAULT 0.0 CHECK (stability >= 0.0 AND stability <= 1.0), -- How established this concept is
    usage_count     INTEGER NOT NULL DEFAULT 0,                                  -- Times retrieved successfully
    last_used_tick  INTEGER NOT NULL DEFAULT 0,                                  -- Tick of last successful retrieval
    source_type     TEXT NOT NULL DEFAULT 'inferred' CHECK (source_type IN (
                        'inferred',     -- Extracted by dream engine
                        'explicit',     -- User explicitly stated
                        'observed',     -- Observed from environment
                        'consolidated'  -- Promoted from episodic
                    )),
    source_episode_id TEXT,                                                      -- UUID of originating episode (if any)
    confidence      REAL NOT NULL DEFAULT 0.5 CHECK (confidence >= 0.0 AND confidence <= 1.0), -- Belief confidence
    volatility      REAL NOT NULL DEFAULT 0.5 CHECK (volatility >= 0.0 AND volatility <= 1.0), -- How often this changes
    half_life_ticks INTEGER NOT NULL DEFAULT 70000,                              -- Decay half-life in ticks (~2h default)
    status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
                        'active', 'dormant', 'pruned', 'archived'
                    )),
    metadata        TEXT NOT NULL DEFAULT '{}',                                   -- Additional JSON metadata
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find nodes by category
CREATE INDEX idx_nodes_category ON nodes(category);

-- Query pattern: find active nodes for HNSW rebuild
CREATE INDEX idx_nodes_status ON nodes(status) WHERE status = 'active';

-- Query pattern: find nodes by stability (for LTM promotion)
CREATE INDEX idx_nodes_stability ON nodes(stability DESC) WHERE status = 'active';

-- Query pattern: find nodes by label (text search)
CREATE INDEX idx_nodes_label ON nodes(label);

-- Query pattern: find nodes by embedding model (for migration)
CREATE INDEX idx_nodes_embedding_model ON nodes(embedding_model);

-- Query pattern: find recently used nodes
CREATE INDEX idx_nodes_last_used ON nodes(last_used_tick DESC);

-- =============================================================================
-- Table: edges
-- Purpose: Typed weighted edges between concept nodes. Edges represent semantic
--          relationships. Both source_id and target_id are indexed for
--          bidirectional traversal without self-joins.
-- =============================================================================

CREATE TABLE edges (
    id              INTEGER PRIMARY KEY,
    edge_id         TEXT NOT NULL UNIQUE,                                         -- UUID for cross-db references
    source_id       INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,      -- Source node
    target_id       INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,      -- Target node
    edge_type       TEXT NOT NULL CHECK (edge_type IN (
                        'IsA',          -- Taxonomic: X is a kind of Y
                        'PartOf',       -- Mereological: X is part of Y
                        'Causes',       -- Causal: X causes Y
                        'Enables',      -- Enabling: X enables Y
                        'SimilarTo',    -- Similarity: X is similar to Y
                        'Contradicts',  -- Contradiction: X contradicts Y
                        'Precedes',     -- Temporal: X precedes Y
                        'UsedFor',      -- Functional: X is used for Y
                        'Implies',      -- Logical: X implies Y
                        'DerivedFrom',  -- Provenance: X was derived from Y
                        'CoOccurs',     -- Statistical: X co-occurs with Y
                        'Requires'      -- Dependency: X requires Y
                    )),
    weight          REAL NOT NULL DEFAULT 0.5 CHECK (weight >= 0.0 AND weight <= 1.0), -- Edge strength
    evidence_count  INTEGER NOT NULL DEFAULT 1,                                  -- Times this relationship observed
    last_confirmed_tick INTEGER NOT NULL DEFAULT 0,                              -- Tick of last confirmation
    confidence      REAL NOT NULL DEFAULT 0.5 CHECK (confidence >= 0.0 AND confidence <= 1.0), -- How certain this edge is
    bidirectional   INTEGER NOT NULL DEFAULT 0 CHECK (bidirectional IN (0, 1)),   -- Whether edge applies both ways
    metadata        TEXT NOT NULL DEFAULT '{}',                                   -- Additional JSON (mechanism, context)
    status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
                        'active', 'weakened', 'pruned'
                    )),
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find all edges FROM a node (forward traversal)
CREATE INDEX idx_edges_source ON edges(source_id, edge_type) WHERE status = 'active';

-- Query pattern: find all edges TO a node (backward traversal)
CREATE INDEX idx_edges_target ON edges(target_id, edge_type) WHERE status = 'active';

-- Query pattern: find edges by type (e.g., all Contradicts edges)
CREATE INDEX idx_edges_type ON edges(edge_type) WHERE status = 'active';

-- Query pattern: find weak edges for pruning
CREATE INDEX idx_edges_weight ON edges(weight) WHERE status = 'active';

-- Prevent duplicate edges between same nodes of same type
CREATE UNIQUE INDEX uq_edges_source_target_type ON edges(source_id, target_id, edge_type)
    WHERE status = 'active';

-- =============================================================================
-- Table: node_activations
-- Purpose: Separate activation tracking for nodes. Updated frequently (every
--          tick for active nodes). Separated from nodes table to avoid write
--          amplification on the content-heavy nodes table.
-- =============================================================================

CREATE TABLE node_activations (
    id                  INTEGER PRIMARY KEY,
    node_id             INTEGER NOT NULL UNIQUE REFERENCES nodes(id) ON DELETE CASCADE,
    activation          REAL NOT NULL DEFAULT 0.5 CHECK (activation >= 0.0),      -- Current activation energy
    effective_activation REAL NOT NULL DEFAULT 0.5,                               -- After inhibition computation
    last_activated_tick INTEGER NOT NULL DEFAULT 0,                               -- Tick of last activation boost
    retrieval_count     INTEGER NOT NULL DEFAULT 0,                               -- Times retrieved into WM
    last_retrieval_tick INTEGER NOT NULL DEFAULT 0,                               -- Tick of last WM entry
    decay_rate          REAL NOT NULL DEFAULT 0.00001,                            -- Per-tick decay (λ) — slow for semantic
    boost_sum           REAL NOT NULL DEFAULT 0.0,                                -- Cumulative retrieval boosts
    inhibited_until_tick INTEGER NOT NULL DEFAULT 0,                              -- Refractory period end
    spread_activation   REAL NOT NULL DEFAULT 0.0,                                -- Activation received from neighbors
    created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find top-K activated nodes for WM competition
CREATE INDEX idx_node_activations_activation ON node_activations(activation DESC);

-- Query pattern: find nodes past refractory period
CREATE INDEX idx_node_activations_inhibited ON node_activations(inhibited_until_tick);

-- Query pattern: find stale nodes for pruning (low activation, old)
CREATE INDEX idx_node_activations_last_activated ON node_activations(last_activated_tick);

-- =============================================================================
-- Table: contradictions
-- Purpose: Detected contradictions in the semantic network pending resolution.
--          Contradictions are pairs of nodes/edges that assert incompatible
--          propositions. Resolved during consolidation or epistemic healing.
-- =============================================================================

CREATE TABLE contradictions (
    id              INTEGER PRIMARY KEY,
    contradiction_id TEXT NOT NULL UNIQUE,                                        -- UUID
    node_a_id       INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,      -- First contradicting node
    node_b_id       INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,      -- Second contradicting node
    edge_id         INTEGER REFERENCES edges(id) ON DELETE SET NULL,              -- The Contradicts edge (if exists)
    severity        TEXT NOT NULL DEFAULT 'low' CHECK (severity IN (
                        'low',          -- Minor inconsistency
                        'medium',       -- Affects reasoning quality
                        'high',         -- Could cause incorrect actions
                        'critical'      -- Safety-relevant contradiction
                    )),
    category        TEXT NOT NULL DEFAULT 'semantic' CHECK (category IN (
                        'semantic',     -- Meaning contradiction
                        'causal',       -- Causal model contradiction
                        'user_model',   -- User preference contradiction
                        'procedural',   -- Action recommendation contradiction
                        'safety'        -- Safety-relevant contradiction
                    )),
    description     TEXT NOT NULL DEFAULT '',                                     -- Human-readable explanation
    detected_tick   INTEGER NOT NULL,                                             -- When detected
    resolution_status TEXT NOT NULL DEFAULT 'pending' CHECK (resolution_status IN (
                        'pending',      -- Awaiting resolution
                        'investigating', -- Being analyzed
                        'resolved',     -- Resolved (see resolution_action)
                        'deferred',     -- Deferred to user
                        'accepted'      -- Accepted as valid ambiguity
                    )),
    resolution_action TEXT,                                                       -- What was done to resolve
    resolved_tick   INTEGER,                                                     -- When resolved
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find unresolved contradictions by severity
CREATE INDEX idx_contradictions_pending ON contradictions(severity DESC)
    WHERE resolution_status IN ('pending', 'investigating');

-- Query pattern: find contradictions involving a specific node
CREATE INDEX idx_contradictions_node_a ON contradictions(node_a_id);
CREATE INDEX idx_contradictions_node_b ON contradictions(node_b_id);

-- Query pattern: count unresolved contradictions (for pathology detection)
CREATE INDEX idx_contradictions_status ON contradictions(resolution_status);
