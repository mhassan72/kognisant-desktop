# Kognisant Database Schema — Overview

> Last updated: 2026-05-28

## Architecture

Kognisant uses a **zero-server, all-local** storage architecture built on SQLite. All databases live under `~/.kognisant/` with strict separation between global state, per-project state, and shared resources.

## Storage Layout

```
~/.kognisant/
├── global.db                    ← Single global database
├── projects/{project_id}/
│   ├── memory_palace.db         ← Per-project memory (episodic, semantic, procedural, LTM)
│   ├── cognitive_state.db       ← Running cognitive state snapshots
│   ├── telemetry.db             ← Full execution traces (append-only)
│   ├── world_model.db           ← Beliefs, causal chains, social model
│   ├── artifacts/               ← Generated files (not DB-managed)
│   └── source_mirror/           ← Git repo for self-modification lineage
└── shared/
    ├── skill_library.db         ← Cross-project transferable skills (in global.db)
    └── prompt_ontology/         ← Evolved prompt fragments (file-based)
```

## Database Relationships

```
┌─────────────────────────────────────────────────────────────────────┐
│                          global.db                                    │
│                                                                       │
│  settings ─── device_profile ─── llm_providers                       │
│  auth_tokens    sync_manifest    skill_library                       │
│                       │                  │                            │
└───────────────────────┼──────────────────┼───────────────────────────┘
                        │                  │
            references  │                  │ cross-project transfer
                        ▼                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   projects/{id}/ (per-project cluster)                │
│                                                                       │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐    │
│  │memory_palace │   │cognitive_state│   │    telemetry.db      │    │
│  │              │   │              │   │   (append-only)       │    │
│  │ episodic ────┼───┼── snapshots  │   │                      │    │
│  │ semantic ────┼───┼── predictive │   │ tick_traces ◄────────┼─┐  │
│  │ procedural ──┼───┼── affect     │   │ llm_queries          │ │  │
│  │ ltm ─────────┼───┼── goals     │   │ tool_executions      │ │  │
│  │ dream_log    │   │  agents     │   │ goal_lifecycle       │ │  │
│  └──────────────┘   └──────────────┘   │ memory_activations   │ │  │
│                                         │ self_modifications   │ │  │
│  ┌──────────────┐                      │ prediction_accuracy  │ │  │
│  │ world_model  │                      │ affect_log           │ │  │
│  │              │                      │ agent_bids           │ │  │
│  │ beliefs ─────┼──────────────────────┼─error_pathology      │ │  │
│  │ causal_chains│                      │ sync_events          │ │  │
│  │ social_model │                      │ sessions ────────────┼─┘  │
│  │ simulations  │                      └──────────────────────┘    │
│  └──────────────┘                                                    │
└─────────────────────────────────────────────────────────────────────┘
```

## Design Principles

1. **Timestamps everywhere** — All tables have `created_at` and `updated_at` (epoch milliseconds)
2. **INTEGER PRIMARY KEY** — SQLite rowid alias for auto-increment
3. **Indexed for access patterns** — Time-range on telemetry, vector lookups on embeddings, graph traversals on semantic network
4. **Embeddings as BLOB** — f32 arrays serialized (little-endian), dimension stored alongside
5. **JSON for flexible data** — SQLite JSON1 extension for nested/variable structures
6. **Append-only telemetry** — No UPDATE/DELETE in normal operation; pruning is a separate maintenance pass
7. **Retention metadata** — TTL fields, archive flags, last_accessed timestamps for pruning decisions
8. **Foreign keys** — Enforced where relationships exist (`PRAGMA foreign_keys = ON`)
9. **Documented tables** — SQL comments explain each table's cognitive architecture role
10. **Time-partitioned telemetry** — Strategy: one logical table with time-based indexes; archival moves old data to compressed files

## Telemetry Traceability Model

Every telemetry event carries these correlation fields:

| Field | Type | Purpose |
|-------|------|---------|
| `tick_number` | INTEGER | Global monotonic counter (links to cognitive tick) |
| `session_id` | TEXT | Links to session boundary record |
| `timestamp_ms` | INTEGER | Wall clock (epoch ms) for time-range queries |
| `correlation_id` | TEXT | UUID linking related events across subsystems |
| `causation_chain` | TEXT (JSON) | Array of upstream event IDs that caused this event |

This enables:
- **Full cognitive trace replay** — Reconstruct what the system was "thinking" at any tick
- **Causal attribution** — Trace any action back to the surprise/goal/bid that caused it
- **Performance regression detection** — Compare metrics across time windows
- **Self-modification audit trail** — Every code change with before/after benchmarks
- **User interaction correlation** — Link user messages to cognitive responses
- **Cross-session continuity** — Link sessions, track state across restarts

## SQLite Configuration

All databases are opened with these pragmas:

```sql
PRAGMA journal_mode = WAL;          -- Write-ahead logging for concurrent reads
PRAGMA synchronous = NORMAL;        -- Balance durability vs performance
PRAGMA foreign_keys = ON;           -- Enforce referential integrity
PRAGMA busy_timeout = 5000;         -- 5s wait on lock contention
PRAGMA cache_size = -64000;         -- 64MB page cache
PRAGMA mmap_size = 268435456;       -- 256MB memory-mapped I/O
PRAGMA temp_store = MEMORY;         -- Temp tables in RAM
```

Telemetry databases additionally use:
```sql
PRAGMA auto_vacuum = INCREMENTAL;   -- Reclaim space after pruning
PRAGMA page_size = 8192;            -- Larger pages for sequential scan
```

## Embedding Storage Convention

Embeddings are stored as BLOBs containing packed f32 arrays (little-endian IEEE 754):

```
BLOB layout: [f32_0][f32_1]...[f32_N-1]
Size: dimension * 4 bytes
Example: 384-dim embedding = 1536 bytes
```

The `embedding_dim` column always accompanies an embedding BLOB to allow dimension changes over time (e.g., upgrading from MiniLM-384d to Nomic-768d).

## Pruning & Retention Strategy

| Database | Retention | Pruning Trigger | Archive Strategy |
|----------|-----------|-----------------|------------------|
| memory_palace | Indefinite (consolidated) | Staleness score > threshold | Compress to LTM |
| cognitive_state | Last 1000 snapshots | Ring buffer overflow | Discard oldest |
| telemetry | Device-tier dependent (3-365 days) | Daily maintenance tick | Export to compressed parquet |
| world_model | Indefinite (pruned by confidence) | Confidence < 0.1 | Soft delete (archived flag) |
| global | Indefinite | Manual cleanup | N/A |

## File Index

| File | Database | Scope |
|------|----------|-------|
| `global_db.sql` | `~/.kognisant/global.db` | Cross-project settings, auth, skills, device |
| `memory_palace.sql` | `projects/{id}/memory_palace.db` | All memory tiers |
| `cognitive_state.sql` | `projects/{id}/cognitive_state.db` | Running state snapshots |
| `telemetry.sql` | `projects/{id}/telemetry.db` | Full execution traces |
| `world_model.sql` | `projects/{id}/world_model.db` | Beliefs, causality, social model |
| `sync_schema.sql` | `~/.kognisant/global.db` (sync tables) | Cloud sync metadata |
