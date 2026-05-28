-- ============================================================================
-- Kognisant Cloud Sync Schema
-- Location: ~/.kognisant/global.db (sync-related tables)
-- Purpose: Metadata for E2E encrypted cloud sync. Tracks file manifests,
--          device registry, conflict resolution, and sync history.
--          Enables disaster recovery and multi-device continuity.
--
-- NOTE: These tables live in global.db alongside settings and auth.
--       The actual sync is E2E encrypted — only metadata is stored here.
--       File contents are encrypted with device keys before upload.
-- ============================================================================

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA synchronous = NORMAL;

-- ============================================================================
-- FILE MANIFEST
-- Tracks every file that participates in sync. Each entry records the file's
-- current state (hash, size, modified time) and sync status.
-- ============================================================================

CREATE TABLE IF NOT EXISTS sync_file_manifest (
    id              INTEGER PRIMARY KEY,
    -- File identification
    file_path       TEXT NOT NULL,           -- Relative path within ~/.kognisant/
    project_id      TEXT,                    -- NULL = global, else project-scoped
    -- Current local state
    local_hash      TEXT NOT NULL,           -- BLAKE3 hash of file content
    local_size_bytes INTEGER NOT NULL,
    local_modified_at INTEGER NOT NULL,      -- Epoch ms of last local modification
    -- Remote state (last known)
    remote_hash     TEXT,                    -- Hash on cloud (NULL = never synced)
    remote_size_bytes INTEGER,
    remote_modified_at INTEGER,
    remote_version  INTEGER NOT NULL DEFAULT 0, -- Monotonic version counter
    -- Sync status
    sync_status     TEXT NOT NULL DEFAULT 'pending', -- 'synced', 'pending_push', 'pending_pull',
                                                      -- 'conflict', 'excluded', 'deleted_local',
                                                      -- 'deleted_remote'
    last_synced_at  INTEGER,                 -- Epoch ms of last successful sync
    last_sync_direction TEXT,                -- 'push', 'pull'
    -- Encryption
    encrypted_hash  TEXT,                    -- Hash of encrypted blob (for verification)
    encryption_key_id TEXT,                  -- Which key was used to encrypt
    -- Metadata
    file_type       TEXT,                    -- 'database', 'config', 'binary', 'json', 'text'
    is_critical     INTEGER NOT NULL DEFAULT 0, -- 1 = must sync (settings, keys), 0 = optional
    sync_priority   INTEGER NOT NULL DEFAULT 50, -- Lower = sync first (0-100)
    -- Exclusion
    is_excluded     INTEGER NOT NULL DEFAULT 0, -- 1 = explicitly excluded from sync
    exclude_reason  TEXT,
    -- Lifecycle
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    UNIQUE(file_path, project_id)
);

-- Access pattern: find files needing sync
CREATE INDEX idx_manifest_status ON sync_file_manifest(sync_status)
    WHERE sync_status IN ('pending_push', 'pending_pull', 'conflict');
-- Access pattern: project-scoped manifest
CREATE INDEX idx_manifest_project ON sync_file_manifest(project_id, file_path);
-- Access pattern: priority-ordered sync queue
CREATE INDEX idx_manifest_priority ON sync_file_manifest(sync_priority ASC, local_modified_at DESC)
    WHERE sync_status = 'pending_push';
-- Access pattern: find conflicts
CREATE INDEX idx_manifest_conflicts ON sync_file_manifest(sync_status)
    WHERE sync_status = 'conflict';
-- Access pattern: find critical files
CREATE INDEX idx_manifest_critical ON sync_file_manifest(is_critical DESC, sync_priority ASC)
    WHERE is_excluded = 0;

-- ============================================================================
-- DEVICE REGISTRY
-- Tracks all devices that participate in sync for this account.
-- Enables multi-device continuity and conflict resolution.
-- ============================================================================

CREATE TABLE IF NOT EXISTS sync_device_registry (
    id              INTEGER PRIMARY KEY,
    device_id       TEXT NOT NULL UNIQUE,    -- Stable device identifier (hardware-derived)
    -- Device info
    device_name     TEXT NOT NULL,           -- User-friendly name (e.g., "MacBook Pro")
    device_tier     TEXT NOT NULL,           -- 'minimal', 'standard', 'performance', 'server'
    os_type         TEXT NOT NULL,
    os_version      TEXT,
    app_version     TEXT NOT NULL,           -- Kognisant version on this device
    -- Cryptographic identity
    key_id          TEXT NOT NULL,           -- Public key fingerprint for this device
    public_key      BLOB NOT NULL,           -- Ed25519 public key (for verifying sync signatures)
    -- Status
    status          TEXT NOT NULL DEFAULT 'active', -- 'active', 'inactive', 'revoked', 'pending_approval'
    is_current      INTEGER NOT NULL DEFAULT 0,     -- 1 = this is the current device
    -- Activity
    last_seen_at    INTEGER,                 -- Epoch ms of last sync activity
    last_push_at    INTEGER,
    last_pull_at    INTEGER,
    total_syncs     INTEGER NOT NULL DEFAULT 0,
    total_bytes_pushed INTEGER NOT NULL DEFAULT 0,
    total_bytes_pulled INTEGER NOT NULL DEFAULT 0,
    -- Trust
    trust_level     TEXT NOT NULL DEFAULT 'full', -- 'full', 'read_only', 'pending', 'revoked'
    approved_at     INTEGER,                 -- When this device was approved for sync
    approved_by     TEXT,                    -- Device that approved this one
    -- Lifecycle
    registered_at   INTEGER NOT NULL,
    revoked_at      INTEGER,
    revoke_reason   TEXT,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: find active devices
CREATE INDEX idx_devices_active ON sync_device_registry(status) WHERE status = 'active';
-- Access pattern: find current device
CREATE INDEX idx_devices_current ON sync_device_registry(is_current) WHERE is_current = 1;
-- Access pattern: find by key (for signature verification)
CREATE INDEX idx_devices_key ON sync_device_registry(key_id);

-- ============================================================================
-- CONFLICT LOG
-- Records sync conflicts: when the same file was modified on multiple devices
-- between syncs. Tracks the resolution strategy and outcome.
-- ============================================================================

CREATE TABLE IF NOT EXISTS sync_conflict_log (
    id              INTEGER PRIMARY KEY,
    conflict_id     TEXT NOT NULL UNIQUE,    -- UUID
    -- File in conflict
    file_path       TEXT NOT NULL,
    project_id      TEXT,
    -- Conflicting versions
    local_hash      TEXT NOT NULL,           -- Local version hash
    local_modified_at INTEGER NOT NULL,
    local_device_id TEXT NOT NULL,
    remote_hash     TEXT NOT NULL,           -- Remote version hash
    remote_modified_at INTEGER NOT NULL,
    remote_device_id TEXT NOT NULL,
    -- Base version (common ancestor)
    base_hash       TEXT,                    -- Last synced version (before divergence)
    base_synced_at  INTEGER,
    -- Resolution
    resolution_strategy TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'local_wins', 'remote_wins',
                                                          -- 'merge', 'manual', 'newest_wins',
                                                          -- 'largest_wins', 'duplicate'
    resolved_at     INTEGER,
    resolved_by     TEXT,                    -- 'auto', 'user', device_id
    -- Outcome
    winning_hash    TEXT,                    -- Hash of the version that won
    merge_result_hash TEXT,                  -- Hash of merged result (if merge strategy)
    data_loss       INTEGER NOT NULL DEFAULT 0, -- 1 = some data was lost in resolution
    backup_path     TEXT,                    -- Path to backup of losing version
    -- Metadata
    conflict_type   TEXT NOT NULL,           -- 'edit_edit', 'edit_delete', 'delete_delete', 'create_create'
    severity        TEXT NOT NULL DEFAULT 'low', -- 'low', 'medium', 'high' (based on file criticality)
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: find unresolved conflicts
CREATE INDEX idx_conflicts_pending ON sync_conflict_log(resolution_strategy)
    WHERE resolution_strategy = 'pending';
-- Access pattern: conflict history for a file
CREATE INDEX idx_conflicts_file ON sync_conflict_log(file_path, created_at DESC);
-- Access pattern: recent conflicts
CREATE INDEX idx_conflicts_time ON sync_conflict_log(created_at DESC);
-- Access pattern: find data loss events
CREATE INDEX idx_conflicts_loss ON sync_conflict_log(data_loss) WHERE data_loss = 1;

-- ============================================================================
-- SYNC HISTORY
-- Chronological record of all sync operations. Enables debugging sync issues
-- and tracking bandwidth usage over time.
-- ============================================================================

CREATE TABLE IF NOT EXISTS sync_history (
    id              INTEGER PRIMARY KEY,
    sync_id         TEXT NOT NULL UNIQUE,    -- UUID for this sync operation
    -- Operation
    direction       TEXT NOT NULL,           -- 'push', 'pull', 'bidirectional'
    scope           TEXT NOT NULL,           -- 'full', 'incremental', 'selective', 'emergency'
    trigger         TEXT NOT NULL,           -- 'scheduled', 'manual', 'file_change', 'startup', 'shutdown'
    -- Timing
    started_at      INTEGER NOT NULL,        -- Epoch ms
    completed_at    INTEGER,                 -- Epoch ms
    duration_ms     INTEGER,
    -- Transfer stats
    files_pushed    INTEGER NOT NULL DEFAULT 0,
    files_pulled    INTEGER NOT NULL DEFAULT 0,
    files_skipped   INTEGER NOT NULL DEFAULT 0,
    bytes_uploaded  INTEGER NOT NULL DEFAULT 0,
    bytes_downloaded INTEGER NOT NULL DEFAULT 0,
    -- Encryption overhead
    encryption_ms   INTEGER,                 -- Time spent encrypting
    decryption_ms   INTEGER,                 -- Time spent decrypting
    -- Network
    endpoint_url    TEXT,
    network_latency_ms INTEGER,
    -- Outcome
    status          TEXT NOT NULL DEFAULT 'running', -- 'running', 'completed', 'partial', 'failed', 'cancelled'
    error_message   TEXT,
    error_code      TEXT,
    retry_count     INTEGER NOT NULL DEFAULT 0,
    -- Conflicts
    conflicts_detected INTEGER NOT NULL DEFAULT 0,
    conflicts_auto_resolved INTEGER NOT NULL DEFAULT 0,
    conflicts_manual INTEGER NOT NULL DEFAULT 0,
    -- Device context
    device_id       TEXT NOT NULL,           -- Which device initiated this sync
    remote_device_id TEXT,                   -- Which device we synced with (if peer-to-peer)
    -- Manifest state
    manifest_version_before INTEGER,
    manifest_version_after INTEGER,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: recent sync history
CREATE INDEX idx_sync_hist_time ON sync_history(started_at DESC);
-- Access pattern: find failures
CREATE INDEX idx_sync_hist_status ON sync_history(status) WHERE status IN ('failed', 'partial');
-- Access pattern: per-device sync history
CREATE INDEX idx_sync_hist_device ON sync_history(device_id, started_at DESC);
-- Access pattern: bandwidth tracking
CREATE INDEX idx_sync_hist_bytes ON sync_history(bytes_uploaded, bytes_downloaded);

-- ============================================================================
-- SYNC QUEUE
-- Pending sync operations waiting to be executed. Prioritized by file
-- criticality and modification recency.
-- ============================================================================

CREATE TABLE IF NOT EXISTS sync_queue (
    id              INTEGER PRIMARY KEY,
    -- File to sync
    file_path       TEXT NOT NULL,
    project_id      TEXT,
    -- Operation
    operation       TEXT NOT NULL,           -- 'push', 'pull', 'delete_remote', 'delete_local'
    priority        INTEGER NOT NULL DEFAULT 50, -- 0=highest, 100=lowest
    -- State
    status          TEXT NOT NULL DEFAULT 'queued', -- 'queued', 'in_progress', 'completed', 'failed', 'cancelled'
    attempts        INTEGER NOT NULL DEFAULT 0,
    max_attempts    INTEGER NOT NULL DEFAULT 3,
    last_attempt_at INTEGER,
    last_error      TEXT,
    -- Scheduling
    queued_at       INTEGER NOT NULL,        -- Epoch ms
    scheduled_for   INTEGER,                 -- Epoch ms (NULL = ASAP)
    -- Dependencies
    depends_on      TEXT,                    -- JSON array of sync_queue IDs that must complete first
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Access pattern: get next items to sync
CREATE INDEX idx_sync_queue_pending ON sync_queue(priority ASC, queued_at ASC)
    WHERE status = 'queued';
-- Access pattern: find failed items for retry
CREATE INDEX idx_sync_queue_failed ON sync_queue(status, last_attempt_at)
    WHERE status = 'failed' AND attempts < max_attempts;
-- Access pattern: in-progress items (for timeout detection)
CREATE INDEX idx_sync_queue_progress ON sync_queue(status, last_attempt_at)
    WHERE status = 'in_progress';
