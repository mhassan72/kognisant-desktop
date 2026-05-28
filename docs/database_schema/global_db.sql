-- ============================================================================
-- Kognisant Global Database Schema
-- Location: ~/.kognisant/global.db
-- Purpose: Cross-project settings, authentication, device profile, LLM config,
--          and the shared skill library.
-- ============================================================================

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA synchronous = NORMAL;

-- ============================================================================
-- USER SETTINGS & PREFERENCES
-- Stores all user-configurable settings as key-value pairs with type metadata.
-- The cognitive kernel reads these on boot and watches for changes.
-- ============================================================================

CREATE TABLE IF NOT EXISTS settings (
    id          INTEGER PRIMARY KEY,
    category    TEXT NOT NULL,               -- 'ui', 'kernel', 'llm', 'sync', 'privacy'
    key         TEXT NOT NULL,               -- Setting identifier
    value       TEXT NOT NULL,               -- JSON-encoded value (supports any type)
    value_type  TEXT NOT NULL DEFAULT 'string', -- 'string', 'number', 'boolean', 'json'
    description TEXT,                        -- Human-readable description
    is_secret   INTEGER NOT NULL DEFAULT 0,  -- 1 = encrypted at rest
    created_at  INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at  INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    UNIQUE(category, key)
);

CREATE INDEX idx_settings_category ON settings(category);

-- ============================================================================
-- AUTHENTICATION TOKENS & DEVICE KEYS
-- Manages API keys, OAuth tokens, and device-level encryption keys.
-- All token values are encrypted at rest (AES-256-GCM with device master key).
-- ============================================================================

CREATE TABLE IF NOT EXISTS auth_tokens (
    id              INTEGER PRIMARY KEY,
    provider        TEXT NOT NULL,           -- 'kognisant', 'openai', 'anthropic', 'ollama', 'custom'
    token_type      TEXT NOT NULL,           -- 'api_key', 'oauth_access', 'oauth_refresh', 'device_key'
    encrypted_value TEXT NOT NULL,           -- AES-256-GCM encrypted token
    nonce           BLOB NOT NULL,           -- Encryption nonce (12 bytes)
    expires_at      INTEGER,                 -- Epoch ms, NULL = never expires
    scopes          TEXT,                    -- JSON array of granted scopes
    last_used_at    INTEGER,                 -- Epoch ms of last successful use
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE INDEX idx_auth_provider ON auth_tokens(provider, token_type);
CREATE INDEX idx_auth_active ON auth_tokens(is_active) WHERE is_active = 1;

-- Device-level cryptographic keys (for E2E sync encryption)
CREATE TABLE IF NOT EXISTS device_keys (
    id              INTEGER PRIMARY KEY,
    key_type        TEXT NOT NULL,           -- 'master', 'sync_encrypt', 'sync_sign', 'backup'
    public_key      BLOB,                   -- Ed25519/X25519 public key (32 bytes)
    encrypted_private_key BLOB NOT NULL,    -- Private key encrypted with OS keychain-derived key
    key_nonce       BLOB NOT NULL,          -- Nonce for private key encryption
    fingerprint     TEXT NOT NULL,           -- BLAKE3 hash of public key (for identification)
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    rotated_at      INTEGER,                -- When this key was last rotated

    UNIQUE(key_type)
);

-- ============================================================================
-- DEVICE PROFILE & HARDWARE TIER
-- Detected on first boot, updated periodically. Drives all dynamic resource
-- bounds in the cognitive kernel (tick rate, agent count, memory capacity).
-- ============================================================================

CREATE TABLE IF NOT EXISTS device_profile (
    id              INTEGER PRIMARY KEY,
    device_id       TEXT NOT NULL UNIQUE,    -- Stable device identifier (hardware-derived)
    tier            TEXT NOT NULL,           -- 'minimal', 'standard', 'performance', 'server'
    cpu_cores       INTEGER NOT NULL,
    cpu_arch        TEXT NOT NULL,           -- 'x86_64', 'aarch64'
    ram_mb          INTEGER NOT NULL,
    has_gpu         INTEGER NOT NULL DEFAULT 0,
    gpu_name        TEXT,                   -- e.g., 'Apple M3 Pro', 'NVIDIA RTX 4090'
    gpu_vram_mb     INTEGER,
    disk_type       TEXT NOT NULL,           -- 'ssd', 'hdd', 'sd_card'
    disk_free_mb    INTEGER,
    os_type         TEXT NOT NULL,           -- 'macos', 'linux', 'windows'
    os_version      TEXT,
    hostname        TEXT,
    -- Dynamic bounds (recomputed from hardware)
    effective_tick_rate_hz  INTEGER NOT NULL DEFAULT 10,
    effective_max_agents    INTEGER NOT NULL DEFAULT 8,
    effective_wm_capacity   INTEGER NOT NULL DEFAULT 15,
    -- Thermal/performance state
    last_thermal_check      INTEGER,
    thermal_throttled       INTEGER NOT NULL DEFAULT 0,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- ============================================================================
-- LLM PROVIDER CONFIGURATIONS
-- Multi-provider routing configuration. The LLM Pool uses these to decide
-- which provider handles each query based on capability, cost, and latency.
-- ============================================================================

CREATE TABLE IF NOT EXISTS llm_providers (
    id              INTEGER PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,    -- 'kognisant', 'ollama', 'openai', 'custom_1'
    provider_type   TEXT NOT NULL,           -- 'kognisant_api', 'ollama_local', 'openai_compat', 'custom'
    base_url        TEXT NOT NULL,           -- Endpoint URL
    is_local        INTEGER NOT NULL DEFAULT 0, -- 1 = no network required
    is_active       INTEGER NOT NULL DEFAULT 1,
    priority        INTEGER NOT NULL DEFAULT 50, -- Lower = preferred (0-100)
    auth_token_id   INTEGER,                -- FK to auth_tokens
    -- Capabilities
    max_context_tokens  INTEGER,
    supports_streaming  INTEGER NOT NULL DEFAULT 1,
    supports_functions  INTEGER NOT NULL DEFAULT 0,
    supports_vision     INTEGER NOT NULL DEFAULT 0,
    -- Cost tracking
    cost_per_1k_input   REAL DEFAULT 0.0,   -- USD per 1000 input tokens
    cost_per_1k_output  REAL DEFAULT 0.0,   -- USD per 1000 output tokens
    -- Performance metrics (rolling averages)
    avg_latency_ms      REAL,
    avg_tokens_per_sec  REAL,
    error_rate_7d       REAL DEFAULT 0.0,
    -- Rate limits
    requests_per_minute INTEGER,
    tokens_per_minute   INTEGER,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (auth_token_id) REFERENCES auth_tokens(id) ON DELETE SET NULL
);

-- Models available per provider
CREATE TABLE IF NOT EXISTS llm_models (
    id              INTEGER PRIMARY KEY,
    provider_id     INTEGER NOT NULL,
    model_id        TEXT NOT NULL,           -- 'gpt-4o', 'claude-3.5-sonnet', 'llama3:70b'
    display_name    TEXT,
    context_window  INTEGER NOT NULL,        -- Max tokens
    -- Capability tags for routing decisions
    capabilities    TEXT NOT NULL DEFAULT '[]', -- JSON array: ['code','reasoning','creative','fast']
    -- Quality/speed tradeoff score (0-1, higher = better quality, slower)
    quality_score   REAL NOT NULL DEFAULT 0.5,
    speed_score     REAL NOT NULL DEFAULT 0.5,
    -- Usage stats
    total_queries   INTEGER NOT NULL DEFAULT 0,
    total_tokens    INTEGER NOT NULL DEFAULT 0,
    avg_satisfaction REAL,                   -- User/system satisfaction (0-1)
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    UNIQUE(provider_id, model_id),
    FOREIGN KEY (provider_id) REFERENCES llm_providers(id) ON DELETE CASCADE
);

CREATE INDEX idx_models_capability ON llm_models(provider_id, is_active);

-- ============================================================================
-- CROSS-PROJECT SKILL LIBRARY
-- Transferable capabilities learned in one project that can apply to others.
-- Skills are condition→action→outcome patterns with confidence scores.
-- ============================================================================

CREATE TABLE IF NOT EXISTS skill_library (
    id              INTEGER PRIMARY KEY,
    name            TEXT NOT NULL,           -- Human-readable skill name
    slug            TEXT NOT NULL UNIQUE,    -- URL-safe identifier
    category        TEXT NOT NULL,           -- 'tool_use', 'pattern', 'strategy', 'prompt', 'workflow'
    -- Skill definition
    description     TEXT NOT NULL,           -- What this skill does
    condition       TEXT NOT NULL,           -- JSON: when to activate (context pattern)
    action_template TEXT NOT NULL,           -- JSON: what to do (parameterized action)
    expected_outcome TEXT,                   -- JSON: predicted result
    -- Quality metrics
    confidence      REAL NOT NULL DEFAULT 0.5, -- 0-1, updated by RL
    success_count   INTEGER NOT NULL DEFAULT 0,
    failure_count   INTEGER NOT NULL DEFAULT 0,
    last_success_at INTEGER,
    last_failure_at INTEGER,
    -- Transfer metadata
    source_project_id TEXT,                 -- Project where skill was learned
    transfer_count  INTEGER NOT NULL DEFAULT 0, -- Times transferred to other projects
    generality_score REAL NOT NULL DEFAULT 0.5, -- How domain-independent (0=specific, 1=universal)
    -- Embedding for similarity search
    embedding       BLOB,                   -- f32 array for semantic matching
    embedding_dim   INTEGER,
    -- Lifecycle
    is_active       INTEGER NOT NULL DEFAULT 1,
    archived_at     INTEGER,
    ttl_days        INTEGER,                -- NULL = never expires
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE INDEX idx_skills_category ON skill_library(category, is_active);
CREATE INDEX idx_skills_confidence ON skill_library(confidence DESC) WHERE is_active = 1;
CREATE INDEX idx_skills_generality ON skill_library(generality_score DESC) WHERE is_active = 1;

-- Skill dependencies (some skills require others)
CREATE TABLE IF NOT EXISTS skill_dependencies (
    id              INTEGER PRIMARY KEY,
    skill_id        INTEGER NOT NULL,
    depends_on_id   INTEGER NOT NULL,
    dependency_type TEXT NOT NULL DEFAULT 'requires', -- 'requires', 'enhances', 'conflicts'
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    UNIQUE(skill_id, depends_on_id),
    FOREIGN KEY (skill_id) REFERENCES skill_library(id) ON DELETE CASCADE,
    FOREIGN KEY (depends_on_id) REFERENCES skill_library(id) ON DELETE CASCADE
);

-- ============================================================================
-- PROJECT REGISTRY
-- Tracks all known projects and their storage locations.
-- ============================================================================

CREATE TABLE IF NOT EXISTS projects (
    id              TEXT PRIMARY KEY,        -- UUID
    name            TEXT NOT NULL,
    path            TEXT NOT NULL,           -- Absolute path to project root
    storage_path    TEXT NOT NULL,           -- ~/.kognisant/projects/{id}/
    -- State
    is_active       INTEGER NOT NULL DEFAULT 1,
    last_opened_at  INTEGER,
    total_ticks     INTEGER NOT NULL DEFAULT 0,
    total_sessions  INTEGER NOT NULL DEFAULT 0,
    -- Size tracking (for disk management)
    storage_bytes   INTEGER NOT NULL DEFAULT 0,
    telemetry_bytes INTEGER NOT NULL DEFAULT 0,
    -- Metadata
    language        TEXT,                    -- Primary language detected
    framework       TEXT,                    -- Primary framework detected
    description     TEXT,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE INDEX idx_projects_active ON projects(is_active, last_opened_at DESC);

-- ============================================================================
-- SYNC MANIFEST & CLOUD STATE
-- Tracks what has been synced to cloud for disaster recovery.
-- See sync_schema.sql for full sync metadata tables.
-- ============================================================================

CREATE TABLE IF NOT EXISTS sync_state (
    id              INTEGER PRIMARY KEY,
    is_enabled      INTEGER NOT NULL DEFAULT 0,
    cloud_endpoint  TEXT,                    -- E2E encrypted sync endpoint
    last_push_at    INTEGER,                 -- Epoch ms
    last_pull_at    INTEGER,                 -- Epoch ms
    bytes_uploaded  INTEGER NOT NULL DEFAULT 0,
    bytes_downloaded INTEGER NOT NULL DEFAULT 0,
    sync_errors_24h INTEGER NOT NULL DEFAULT 0,
    -- Encryption
    sync_key_id     INTEGER,                -- FK to device_keys
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (sync_key_id) REFERENCES device_keys(id) ON DELETE SET NULL
);

-- ============================================================================
-- PROMPT ONTOLOGY REGISTRY
-- Index of evolved prompt fragments stored in ~/.kognisant/shared/prompt_ontology/
-- The actual prompts are files; this table tracks metadata and lineage.
-- ============================================================================

CREATE TABLE IF NOT EXISTS prompt_ontology (
    id              INTEGER PRIMARY KEY,
    slug            TEXT NOT NULL UNIQUE,    -- Filename stem
    category        TEXT NOT NULL,           -- 'system', 'agent', 'tool', 'reasoning', 'creative'
    version         INTEGER NOT NULL DEFAULT 1,
    -- Content reference
    file_path       TEXT NOT NULL,           -- Relative path within prompt_ontology/
    content_hash    TEXT NOT NULL,           -- BLAKE3 hash of file content
    -- Evolution tracking
    parent_id       INTEGER,                -- Previous version (lineage)
    mutation_type   TEXT,                    -- 'manual', 'evolved', 'merged', 'pruned'
    fitness_score   REAL,                   -- Measured effectiveness (0-1)
    usage_count     INTEGER NOT NULL DEFAULT 0,
    -- Metadata
    description     TEXT,
    tags            TEXT,                    -- JSON array of tags
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    FOREIGN KEY (parent_id) REFERENCES prompt_ontology(id) ON DELETE SET NULL
);

CREATE INDEX idx_prompts_category ON prompt_ontology(category, is_active);
CREATE INDEX idx_prompts_fitness ON prompt_ontology(fitness_score DESC) WHERE is_active = 1;
