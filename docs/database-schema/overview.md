# Database Schema Overview — Kognisant Desktop

> Comprehensive SQLite schema documentation for all persistent stores in the Kognisant cognitive runtime.

Last updated: 2025-01-15

---

## Database Inventory

| Database | Location | Purpose | Access Pattern |
|----------|----------|---------|----------------|
| `episodic.db` | `~/.kc/state/memory_palace/episodic.db` | Tier 2 episodic buffer — ring buffer of time-indexed sensory sequences | Append-heavy, sequential reads, periodic bulk deletes |
| `semantic.db` | `~/.kc/state/memory_palace/semantic.db` | Tier 3 semantic network — concept nodes and typed edges | Random reads, frequent activation updates, graph traversals |
| `procedural.db` | `~/.kc/state/memory_palace/procedural.db` | Tier 4 procedural memory — condition→action→outcome chains | Read-heavy (condition matching), infrequent writes |
| `ltm.db` | `~/.kc/state/memory_palace/ltm.db` | Tier 5 consolidated long-term memory | Bulk reads during consolidation, rare individual access |
| `telemetry.db` | `~/.kc/projects/{project-id}/telemetry.db` | Full cognitive tracing — event log for replay and audit | Append-only, sequential reads for replay, periodic cleanup |
| `world_model.db` | `~/.kc/state/world_model.db` | Beliefs, causal chains, social model, simulation results | Mixed reads/writes, graph traversals, frequent belief updates |
| `goals.db` | `~/.kc/state/goals.db` | Goal market state — active goals, hierarchy, bid history | Frequent reads/writes during deliberation phase |
| `agents.db` | `~/.kc/state/agents.db` | Agent society persistent state — configs, metrics, coalitions | Read-heavy with periodic metric updates |

---

## Directory Layout

```
~/.kc/
├── state/
│   ├── memory_palace/
│   │   ├── episodic.db
│   │   ├── semantic.db
│   │   ├── procedural.db
│   │   └── ltm.db
│   ├── world_model.db
│   ├── goals.db
│   ├── agents.db
│   └── snapshots/          # rkyv state snapshots (not SQLite)
└── projects/
    └── {project-id}/
        └── telemetry.db
```

---

## Relationships Between Databases

Databases are intentionally **isolated** — no cross-database foreign keys. Relationships are maintained at the application layer via UUIDs:

- `episodic.db` episodes reference `semantic.db` nodes via `related_node_id` (UUID, not FK)
- `semantic.db` nodes may originate from `episodic.db` consolidation (tracked via `source_episode_id`)
- `procedural.db` procedures reference `semantic.db` concepts in their conditions (JSON)
- `ltm.db` consolidated memories reference their source episodes and semantic nodes (UUIDs)
- `telemetry.db` events reference goals, agents, and memory entries by UUID
- `goals.db` goals reference agents by UUID for assignment tracking
- `world_model.db` beliefs may reference `semantic.db` nodes as evidence

**Rationale**: Separate files allow independent WAL checkpointing, backup, sync scheduling, and different access pattern optimization. Cross-database JOINs are never needed in the hot path.

---

## SQLite Pragmas

All databases use these pragmas at connection open:

```sql
PRAGMA journal_mode = WAL;          -- Write-ahead logging for concurrent reads during writes
PRAGMA synchronous = NORMAL;        -- Crash-safe with WAL (not FULL — acceptable risk for performance)
PRAGMA foreign_keys = ON;           -- Enforce referential integrity within each database
PRAGMA busy_timeout = 5000;         -- Wait up to 5s for locks (background tasks vs tick loop)
PRAGMA cache_size = -64000;         -- 64MB page cache per connection
PRAGMA mmap_size = 268435456;       -- 256MB memory-mapped I/O
PRAGMA temp_store = MEMORY;         -- Temp tables in RAM (faster sorts, joins)
```

**Telemetry-specific** additional pragmas:

```sql
PRAGMA auto_vacuum = INCREMENTAL;   -- Reclaim space without full VACUUM
PRAGMA page_size = 8192;            -- Larger pages for append-heavy workload
```

---

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Tables | `snake_case`, plural | `episodes`, `activation_scores` |
| Columns | `snake_case` | `created_at`, `embedding_dim` |
| Primary keys | `id INTEGER PRIMARY KEY` | SQLite rowid alias |
| Foreign keys | `{referenced_table_singular}_id` | `node_id`, `episode_id` |
| Indexes | `idx_{table}_{columns}` | `idx_episodes_tick_channel` |
| Unique indexes | `uq_{table}_{columns}` | `uq_nodes_label_category` |
| CHECK constraints | Inline or named `chk_{table}_{column}` | `CHECK (severity IN (...))` |
| Timestamps | ISO 8601 UTC `TEXT` | `'2026-05-30T14:30:00.000Z'` |
| UUIDs | Hyphenated lowercase `TEXT` | `'550e8400-e29b-41d4-a716-446655440000'` |
| Booleans | `INTEGER` (0/1) | `is_active INTEGER NOT NULL DEFAULT 1` |
| Embeddings | `BLOB` (packed f32 LE) | Size = dimension × 4 bytes |
| JSON data | `TEXT` with JSON1 functions | `DEFAULT '{}'` |
| Enums | `TEXT` with CHECK constraint | `CHECK (status IN ('active', 'archived'))` |

---

## Migration Strategy

### Approach: Versioned SQL Scripts

Each database tracks its schema version in a `schema_version` table:

```sql
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER NOT NULL,
    applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    description TEXT NOT NULL
);
```

### Migration Rules

1. Migrations are forward-only (no rollback scripts — SQLite ALTER TABLE is limited)
2. Each migration is a numbered `.sql` file: `001_initial.sql`, `002_add_activation_index.sql`
3. Migrations run at application startup if `schema_version` is behind
4. All migrations run within a transaction (atomic — either fully applied or not at all)
5. New columns added with `DEFAULT` values (no data migration needed for simple additions)
6. Destructive changes (column removal, type change) require a new table + data copy

### Version Check at Startup

```
1. Open database connection
2. Check schema_version table exists (CREATE IF NOT EXISTS)
3. Read max(version)
4. If version < EXPECTED_VERSION:
   a. Run migrations sequentially from current+1 to expected
   b. Each migration inserts into schema_version on success
5. If version > EXPECTED_VERSION:
   a. Log warning: "Database newer than application — possible downgrade"
   b. Continue with best-effort compatibility
```

---

## Embedding Storage Format

Embeddings are stored as BLOBs of packed IEEE 754 single-precision floats (f32), little-endian byte order:

```
BLOB size = embedding_dim × 4 bytes

Example: 384-dimensional embedding = 1,536 bytes
Example: 768-dimensional embedding = 3,072 bytes
```

Every table with embeddings includes companion columns:
- `embedding BLOB NOT NULL` — the raw vector data
- `embedding_dim INTEGER NOT NULL` — dimension count (for validation)
- `embedding_model TEXT NOT NULL` — model identifier (for migration tracking)

---

## Common Patterns

### Soft Deletes

Memories are never hard-deleted during normal operation:

```sql
status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pruned', 'archived'))
```

Physical deletion happens only during scheduled maintenance (VACUUM).

### Activation Separation

Activation scores are stored in separate tables to avoid write amplification. Content tables are written once; activation tables are updated every tick for active entries.

### Timestamp Triggers

All tables use ISO 8601 timestamps with millisecond precision. The `updated_at` column is maintained by application code (SQLite triggers are avoided for performance in the hot path).

---

## Backup & Recovery

- **WAL mode** provides crash consistency — SQLite automatically recovers on next connection open
- **rkyv snapshots** capture volatile in-memory state (affect, WM, goals, agent state)
- **Journal** (`.kc/journal.md`) is the ultimate source of truth — memory can be rebuilt from it
- **HNSW index** is derived data — rebuilt from `semantic.db` embeddings on startup (~2-5s)

Recovery priority:
1. SQLite WAL recovery (automatic, transparent)
2. rkyv snapshot restore (volatile cognitive state)
3. Journal replay (if SQLite databases are corrupted)
4. Fresh start (if all durable stores are lost)
