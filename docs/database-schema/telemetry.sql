-- =============================================================================
-- Kognisant Desktop — Telemetry Database Schema
-- Location: ~/.kc/projects/{project-id}/telemetry.db
-- Purpose:  Full cognitive tracing — event log for replay and audit.
--           Append-only in normal operation. No UPDATE/DELETE except during
--           scheduled maintenance. One database per project.
-- =============================================================================

-- SQLite Pragmas (applied at connection open, not stored in schema)
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;
PRAGMA cache_size = -64000;
PRAGMA mmap_size = 268435456;
PRAGMA temp_store = MEMORY;
PRAGMA auto_vacuum = INCREMENTAL;   -- Reclaim space without full VACUUM
PRAGMA page_size = 8192;            -- Larger pages for append-heavy workload

-- =============================================================================
-- Schema Version Tracking
-- =============================================================================

CREATE TABLE IF NOT EXISTS schema_version (
    version     INTEGER NOT NULL,
    applied_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    description TEXT NOT NULL
);

INSERT INTO schema_version (version, description) VALUES (1, 'Initial telemetry schema');

-- =============================================================================
-- Table: sessions
-- Purpose: Session boundaries. Each KC invocation creates a session. Sessions
--          group events for replay and provide temporal context.
-- =============================================================================

CREATE TABLE sessions (
    id              INTEGER PRIMARY KEY,
    session_id      TEXT NOT NULL UNIQUE,                                         -- UUID
    project_id      TEXT NOT NULL,                                                -- UUID of the project
    started_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')), -- Session start time
    ended_at        TEXT,                                                         -- Session end time (NULL if active)
    tick_count      INTEGER NOT NULL DEFAULT 0,                                  -- Total ticks in session
    event_count     INTEGER NOT NULL DEFAULT 0,                                  -- Total events logged
    start_tick      INTEGER NOT NULL DEFAULT 0,                                  -- First tick number
    end_tick        INTEGER,                                                     -- Last tick number (NULL if active)
    visibility_mode TEXT NOT NULL DEFAULT 'focus' CHECK (visibility_mode IN (
                        'focus', 'trace', 'paranoia'
                    )),                                                           -- Initial visibility mode
    exit_reason     TEXT CHECK (exit_reason IN (
                        'user_quit',    -- User pressed Ctrl+Q or /quit
                        'crash',        -- Kernel panic
                        'supervisor',   -- Supervisor shutdown
                        'signal',       -- OS signal (SIGTERM, SIGINT)
                        'error',        -- Unrecoverable error
                        NULL            -- Still active
                    )),
    recovery_from   TEXT,                                                         -- session_id of crashed session (if this is a recovery)
    metadata        TEXT NOT NULL DEFAULT '{}',                                   -- JSON: device info, config snapshot
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Query pattern: find sessions by project
CREATE INDEX idx_sessions_project ON sessions(project_id);

-- Query pattern: find active session
CREATE INDEX idx_sessions_active ON sessions(ended_at) WHERE ended_at IS NULL;

-- Query pattern: find sessions by time range (for replay selection)
CREATE INDEX idx_sessions_started ON sessions(started_at DESC);

-- =============================================================================
-- Table: events
-- Purpose: All telemetry events. This is the main append-only event log.
--          Supports ALL TelemetryEvent variants from the architecture.
--          Events are never updated or deleted during normal operation.
-- =============================================================================

CREATE TABLE events (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,                            -- Monotonic event ID
    event_id        TEXT NOT NULL UNIQUE,                                         -- UUID for deduplication
    session_id      TEXT NOT NULL,                                                -- FK to sessions (by UUID, not rowid for portability)
    tick            INTEGER NOT NULL,                                             -- Tick number when event occurred
    timestamp       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')), -- Wall-clock time
    event_type      TEXT NOT NULL CHECK (event_type IN (
                        -- User interactions
                        'UserInput',
                        'ApprovalDecision',
                        'ModeSwitch',
                        'CommandExecuted',
                        -- Agent actions
                        'ToolCall',
                        'FileWrite',
                        'LlmQuery',
                        -- State transitions
                        'GoalCreated',
                        'GoalCompleted',
                        'MemoryWrite',
                        'AffectChange',
                        'SkillStateChange',
                        -- Errors and pathologies
                        'Error',
                        'PathologyDetected',
                        'PanicRecovery',
                        -- Approval lifecycle
                        'ApprovalRequested',
                        'ApprovalTimedOut'
                    )),
    severity        TEXT NOT NULL DEFAULT 'info' CHECK (severity IN (
                        'debug', 'info', 'warn', 'error', 'critical'
                    )),
    payload         TEXT NOT NULL DEFAULT '{}',                                   -- JSON serialization of event-specific data
    -- Denormalized fields for common query patterns (avoid JSON parsing in queries)
    agent_id        TEXT,                                                         -- Agent that triggered event (if applicable)
    goal_id         TEXT,                                                         -- Related goal (if applicable)
    tool_name       TEXT,                                                         -- Tool name (for ToolCall events)
    subsystem       TEXT,                                                         -- Subsystem name (for Error events)
    cost_usd        REAL,                                                        -- Cost in USD (for LlmQuery events)
    latency_ms      INTEGER,                                                     -- Latency in ms (for LlmQuery, ToolCall)
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Primary query pattern: replay events in order within a session
CREATE INDEX idx_events_session_tick ON events(session_id, tick, id);

-- Query pattern: find events by type (e.g., all LlmQuery events for cost analysis)
CREATE INDEX idx_events_type ON events(event_type);

-- Query pattern: find events by tick range (scrubbing in replay)
CREATE INDEX idx_events_tick ON events(tick);

-- Query pattern: find events by timestamp (time-based queries)
CREATE INDEX idx_events_timestamp ON events(timestamp);

-- Query pattern: find events by severity (error investigation)
CREATE INDEX idx_events_severity ON events(severity) WHERE severity IN ('warn', 'error', 'critical');

-- Query pattern: find events by agent (agent performance analysis)
CREATE INDEX idx_events_agent ON events(agent_id) WHERE agent_id IS NOT NULL;

-- Query pattern: find events by goal (goal lifecycle analysis)
CREATE INDEX idx_events_goal ON events(goal_id) WHERE goal_id IS NOT NULL;

-- Query pattern: find tool calls by tool name
CREATE INDEX idx_events_tool ON events(tool_name) WHERE tool_name IS NOT NULL;

-- Query pattern: find LLM queries for cost tracking
CREATE INDEX idx_events_cost ON events(cost_usd) WHERE cost_usd IS NOT NULL;

-- Query pattern: find events by subsystem (for error analysis)
CREATE INDEX idx_events_subsystem ON events(subsystem) WHERE subsystem IS NOT NULL;

-- =============================================================================
-- Table: retention_meta
-- Purpose: Cleanup tracking. Stores retention policy state — when last cleanup
--          ran, what the retention window is, where archives are stored.
-- =============================================================================

CREATE TABLE retention_meta (
    id              INTEGER PRIMARY KEY,
    key             TEXT NOT NULL UNIQUE,                                         -- Setting key
    value           TEXT NOT NULL,                                                -- Setting value (JSON or plain text)
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Seed default retention settings
INSERT INTO retention_meta (key, value) VALUES
    ('retention_days', '30'),
    ('archive_days', '365'),
    ('max_db_size_mb', '500'),
    ('last_cleanup_at', ''),
    ('last_archive_at', ''),
    ('archive_path', ''),
    ('total_events_archived', '0'),
    ('total_events_deleted', '0');

-- =============================================================================
-- Payload Schema Documentation (JSON structure per event_type)
-- =============================================================================

-- UserInput:
--   { "content": "string", "input_type": "message|command|approval" }

-- ApprovalDecision:
--   { "request_id": "uuid", "decision": "approve|deny|modify|postpone",
--     "reason": "string?", "latency_ms": 123 }

-- ModeSwitch:
--   { "from": "focus|trace|paranoia", "to": "focus|trace|paranoia" }

-- CommandExecuted:
--   { "command": "string", "args": [], "result": "success|error" }

-- ToolCall:
--   { "tool": "string", "args": {}, "result": "success|failure|timeout|denied",
--     "stdout_preview": "string?", "exit_code": 0 }

-- FileWrite:
--   { "path": "string", "bytes": 123, "operation": "create|modify|delete" }

-- LlmQuery:
--   { "provider": "string", "model": "string", "tokens_in": 100,
--     "tokens_out": 200, "cost_usd": 0.01, "latency_ms": 500,
--     "purpose": "string", "cache_hit": false }

-- GoalCreated:
--   { "goal_id": "uuid", "source": "UserRequest|PredictionError|CuriosityGap|ValueGradient|Contradiction|Opportunity|SelfImprovement|SocialMaintenance|Bootstrap|Decomposition",
--     "priority": 0.8, "description": "string", "parent_goal_id": "uuid?" }

-- GoalCompleted:
--   { "goal_id": "uuid", "outcome": "resolved|abandoned|subsumed|failed",
--     "ticks_elapsed": 500, "agents_involved": ["uuid"], "reason": "string?" }

-- MemoryWrite:
--   { "tier": "episodic|semantic|procedural|ltm",
--     "key": "string", "size_bytes": 123, "operation": "create|update|delete" }

-- AffectChange:
--   { "dimension": "uncertainty|curiosity|frustration|fatigue|novelty_drive|reward_expectation",
--     "old_value": 0.3, "new_value": 0.6, "trigger": "string" }

-- SkillStateChange:
--   { "skill_id": "uuid", "from": "suggested|candidate|active|archived",
--     "to": "suggested|candidate|active|archived", "reason": "string" }

-- Error:
--   { "subsystem": "string", "message": "string",
--     "severity": "low|medium|high|critical", "stack_trace": "string?" }

-- PathologyDetected:
--   { "kind": "goal_flood|affective_stuck|infinite_bid_loop|obsession_loop|prediction_collapse|memory_saturation|contradiction_overload|self_mod_spiral",
--     "intervention": "string", "severity_level": 0-5, "details": {} }

-- PanicRecovery:
--   { "subsystem": "string", "tick": 12345, "recovered": true,
--     "recovery_method": "string", "data_lost": false }

-- ApprovalRequested:
--   { "request_id": "uuid", "category": "destructive|structural|external|persistent|autonomous",
--     "action_summary": "string", "risk_severity": "low|medium|high|critical",
--     "blast_radius": "single_file|project|system|external", "reversible": true }

-- ApprovalTimedOut:
--   { "request_id": "uuid", "timeout_secs": 300,
--     "category": "string", "action_summary": "string" }
