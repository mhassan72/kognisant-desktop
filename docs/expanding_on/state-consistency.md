# State Consistency — Integration Specification

The state consistency model resolves how in-memory cognitive state, durable SQLite stores, and the replay system interact to provide crash recovery, embedding migration, and deterministic replay.

---

## Summary

Cognitive state is split between in-memory structs (snapshotted via rkyv) and SQLite databases (crash-safe via WAL). On recovery, rkyv restores the volatile cognitive state while SQLite recovers automatically. The HNSW index is rebuilt from SQLite embeddings. Embedding model migration runs as a background task with atomic swap. Replay is deterministic given recorded inputs — all non-determinism (LLM responses, tool outputs) is captured at the perception boundary.

---

## State Ownership Map

Every piece of state has exactly one owner, one format, and one durability guarantee:

| Data | Owner | Format | Durability | Snapshot? |
|------|-------|--------|-----------|-----------|
| Affect vector | Kernel (in-memory) | Rust struct | rkyv snapshot | YES |
| Working memory | Kernel (in-memory) | Rust struct | rkyv snapshot | YES |
| Active goals | Kernel (in-memory) | Rust struct | rkyv snapshot | YES |
| Agent internal state | Each agent (in-memory) | Rust struct | rkyv snapshot | YES |
| PP layer weights | Kernel (in-memory) | ndarray | rkyv snapshot | YES |
| Tick counter | Kernel (in-memory) | u64 | rkyv snapshot | YES |
| Precision weights | Kernel (in-memory) | Vec<f64> per layer | rkyv snapshot | YES |
| Episodic buffer | SQLite (episodic.db) | Rows + BLOBs | WAL crash-safe | NO |
| Semantic network | SQLite (semantic.db) | Rows + BLOBs | WAL crash-safe | NO |
| Procedural memory | SQLite (procedural.db) | Rows | WAL crash-safe | NO |
| LTM | SQLite (ltm.db) | Rows + BLOBs | WAL crash-safe | NO |
| HNSW index | In-memory (rebuilt from SQLite) | hnsw_rs struct | Rebuilt on load | NO |
| World model beliefs | SQLite (world_model.db) | Rows | WAL crash-safe | NO |
| Project journal | Markdown file (.kc/journal.md) | Text | Filesystem | NO |
| Skills | TOML files (~/.kc/skills/) | Text | Filesystem | NO |
| Config | TOML files | Text | Filesystem | NO |
| Telemetry | SQLite (telemetry.db) | Rows | WAL crash-safe | NO |
| Replay log | Binary file (replay.log) | Custom binary | Append-only | NO |

### Design Rationale

The split between rkyv-snapshotted state and SQLite state follows one principle: **snapshot what can't be reconstructed from durable stores**.

- Affect, working memory, goals, agent state, PP weights — these are volatile cognitive state that evolves every tick. If lost, the system loses its "train of thought." Must be snapshotted.
- Episodic buffer, semantic network, procedural memory — these are durable knowledge stores. SQLite WAL mode guarantees crash consistency. No need to duplicate in rkyv.
- HNSW index — derived data. Can always be rebuilt from the embeddings stored in semantic.db. Rebuilding is expensive (~2-5s) but correct.

---

## What Gets Snapshotted (rkyv)

ONLY in-memory cognitive state that can't be reconstructed from durable stores:

```rust
#[derive(Archive, Serialize, Deserialize)]
struct CognitiveSnapshot {
    // Timing
    tick_number: u64,
    snapshot_timestamp: i64,
    
    // Affect (current emotional state)
    affect: AffectVector,
    
    // Working memory (what's currently "in mind")
    wm_contents: Vec<MemoryChunkSnapshot>,
    wm_activation_scores: Vec<f64>,
    
    // Goals (active priorities and assignments)
    active_goals: Vec<GoalSnapshot>,
    goal_priorities: Vec<f64>,
    
    // Agent state (confidence, strategies, pending queries)
    agent_states: Vec<AgentStateSnapshot>,
    
    // PP layer weights and precision
    pp_weights: Vec<LayerWeights>,
    pp_precisions: Vec<Vec<f64>>,
    
    // Scheduling state
    last_consolidation_tick: u64,
    adaptive_tick_rate_ms: u64,
    
    // Immune system state
    inflammation_level: f64,
    active_pathologies: Vec<PathologyId>,
}
```

### Snapshot Frequency

- **Full snapshot**: Every 1000 ticks (~100s at 10Hz). Size: 1-5 MB compressed.
- **Delta snapshot**: Every 100 ticks (~10s). Records only changed fields. Size: 10-100 KB.
- **Emergency snapshot**: On graceful shutdown, before self-modification hot-reload, on supervisor request.

### Snapshot Storage

```
~/.kc/state/snapshots/
├── latest.rkyv.zst          # Most recent full snapshot (zstd compressed)
├── deltas/                   # Delta snapshots since last full
│   ├── delta_1001.rkyv.zst
│   ├── delta_1100.rkyv.zst
│   └── delta_1200.rkyv.zst
└── previous.rkyv.zst        # Previous full snapshot (fallback)
```

Retention: last 2 full snapshots + all deltas since the older one. Older data is discarded during maintenance.

---

## What Does NOT Get Snapshotted

Everything in SQLite is already crash-safe via WAL mode. No need to duplicate it in rkyv.

### SQLite WAL Mode Guarantees

- **Atomic commits**: A transaction either fully commits or fully rolls back. No partial writes.
- **Crash recovery**: On restart, SQLite automatically replays the WAL to restore consistency.
- **Concurrent reads**: The tick loop can read while background tasks write (consolidation, telemetry).
- **No explicit recovery code needed**: `rusqlite` handles WAL recovery transparently on connection open.

### Recovery Sequence

On startup after crash:

```rust
fn recover() -> CognitiveKernel {
    // Step 1: Load rkyv snapshot → restore in-memory cognitive state
    let snapshot = load_latest_snapshot()?;
    let mut kernel = CognitiveKernel::from_snapshot(snapshot);
    
    // Step 2: Apply delta snapshots (if any newer than the full snapshot)
    for delta in load_deltas_after(snapshot.tick_number)? {
        kernel.apply_delta(delta);
    }
    
    // Step 3: SQLite databases are already consistent (WAL recovery is automatic)
    // Just open connections — rusqlite handles the rest
    kernel.episodic_db = Database::open("episodic.db")?;
    kernel.semantic_db = Database::open("semantic.db")?;
    kernel.procedural_db = Database::open("procedural.db")?;
    
    // Step 4: Rebuild HNSW index from semantic.db embeddings
    let embeddings = kernel.semantic_db.load_all_embeddings()?;
    kernel.hnsw_index = HnswIndex::build_from(embeddings); // ~2-5s on Standard tier
    
    // Step 5: Validate consistency
    kernel.validate_cross_store_consistency()?;
    
    // Step 6: Resume ticking from recovered state
    kernel.tick_number = snapshot.tick_number + 1;
    kernel
}
```

### Cross-Store Consistency Validation

After recovery, the kernel validates that in-memory state and SQLite state are coherent: active goals still reference valid memory entries, WM contents reference existing semantic nodes, and agent pending queries haven't already been answered. Stale references are cleaned up with warnings logged to telemetry.

---

## Embedding Model Migration Protocol

When the user upgrades their device tier (e.g., Standard → Performance) or a better embedding model becomes available, all existing embeddings must be re-computed.

```rust
struct EmbeddingMigration {
    old_model: String,
    new_model: String,
    state: MigrationState,
}

enum MigrationState {
    /// Not started
    Pending,
    /// Building new index in background
    Building { progress: f64, new_index: HnswIndex },
    /// New index ready, waiting for atomic swap
    Ready { new_index: HnswIndex },
    /// Migration complete
    Complete,
}

impl EmbeddingMigration {
    /// Runs as a background task (NOT in the tick loop)
    async fn run(&mut self, semantic_db: &Database, new_model: &EmbeddingModel) {
        let total_nodes = semantic_db.count_nodes();
        let mut new_index = HnswIndex::new(new_model.dimensions());
        
        // Process in batches of 100 (interruptible)
        for batch in semantic_db.iter_nodes_batched(100) {
            for node in batch {
                let new_embedding = new_model.embed(&node.content).await;
                new_index.add(node.id, &new_embedding);
                // Write new embedding alongside old one (dual-column)
                semantic_db.update_embedding(
                    node.id, 
                    &new_embedding, 
                    &new_model.name()
                );
            }
            self.state = MigrationState::Building {
                progress: new_index.len() as f64 / total_nodes as f64,
                new_index: new_index.clone(),
            };
            
            // Yield to allow other background tasks
            tokio::task::yield_now().await;
        }
        
        self.state = MigrationState::Ready { new_index };
        // Kernel swaps on next tick when it sees Ready state
    }
}
```

### During Migration

- Old index remains active for queries (slightly degraded quality for already-re-embedded nodes, but functional)
- New embeddings are written to SQLite alongside old ones (dual-column: `embedding_v1 BLOB`, `embedding_v2 BLOB`)
- The tick loop checks migration state every 100 ticks. When `Ready`, it atomically swaps the HNSW index pointer
- Old embedding column is dropped in next maintenance window (after confirming new index is healthy)

### Migration Interruption

If the system shuts down during migration:
- Progress is persisted in `~/.kc/state/migration_state.json`
- On next boot, migration resumes from last completed batch
- Partially-migrated state is valid: old index still works, new embeddings are bonus data

### Embedding Version Tracking

```sql
-- In semantic.db
CREATE TABLE nodes (
    id TEXT PRIMARY KEY,
    content TEXT NOT NULL,
    embedding BLOB NOT NULL,           -- Current active embedding
    embedding_model TEXT NOT NULL,      -- e.g., "all-MiniLM-L6-v2"
    embedding_v2 BLOB,                 -- Migration target (NULL until migrated)
    embedding_v2_model TEXT,           -- e.g., "nomic-embed-text-v1.5"
    created_at INTEGER NOT NULL,
    last_activated INTEGER NOT NULL
);
```

---

## Replay Determinism

### The Guarantee

Replay is deterministic GIVEN recorded inputs. The cognitive loop is a pure function of its inputs:

```
cognitive_state(tick N+1) = f(cognitive_state(tick N), perception(tick N))
```

All non-determinism enters through the perception channel. If we record everything that enters perception, we can replay the exact same cognitive trajectory.

### What Constitutes Non-Determinism

| Source | How Recorded | Replay Behavior |
|--------|-------------|-----------------|
| User input | Logged as SensoryInput event | Replayed from log |
| File system events | Logged as SensoryInput event | Replayed from log |
| Timer ticks | Implicit (tick counter) | Deterministic |
| LLM responses | Logged as LlmResponse event | Served from log (no API call) |
| Tool outputs | Logged as ToolOutput event | Served from log (no shell exec) |
| Random numbers | Seeded PRNG (seed in snapshot) | Deterministic given seed |

### Replay Log Format

```rust
struct ReplayLog {
    header: ReplayHeader,
    events: Vec<ReplayEvent>,
}

struct ReplayHeader {
    start_tick: u64,
    end_tick: u64,
    initial_state_hash: [u8; 32],  // BLAKE3 of starting snapshot
    recording_version: u16,
}

enum ReplayEvent {
    /// External input (user, file, timer)
    SensoryInput { 
        tick: u64, 
        channel: SensoryChannel, 
        data: Vec<u8>,
        timestamp: i64,
    },
    /// LLM response (recorded for deterministic replay)
    LlmResponse { 
        tick: u64, 
        query_id: Uuid, 
        response: LlmResponse,
        provider: String,
        latency_ms: u32,
    },
    /// Tool output (recorded for deterministic replay)
    ToolOutput { 
        tick: u64, 
        tool: String, 
        args: Vec<String>,
        result: ToolResult,
        duration_ms: u32,
    },
}
```

### Replay Execution

```rust
struct ReplayRuntime {
    log: ReplayLog,
    event_index: usize,
    mode: ReplayMode,
}

enum ReplayMode {
    /// Exact replay — all inputs from log, no live calls
    Deterministic,
    /// Counterfactual — modify some inputs, use live LLM for changed paths
    Counterfactual { modifications: Vec<ReplayModification> },
}

impl ReplayRuntime {
    /// Intercepts perception to serve recorded events
    fn get_perception_for_tick(&mut self, tick: u64) -> Vec<SensoryEvent> {
        let mut events = vec![];
        while self.event_index < self.log.events.len() {
            let event = &self.log.events[self.event_index];
            if event.tick() > tick { break; }
            events.push(event.to_sensory_event());
            self.event_index += 1;
        }
        events
    }
    
    /// Intercepts LLM queries to serve recorded responses
    fn intercept_llm_query(&self, query_id: Uuid) -> Option<LlmResponse> {
        self.log.events.iter()
            .find_map(|e| match e {
                ReplayEvent::LlmResponse { query_id: id, response, .. } 
                    if *id == query_id => Some(response.clone()),
                _ => None,
            })
    }
}
```

### Deterministic Replay Guarantees

During deterministic replay:
- Sensory inputs are replayed from the log (not from live sources)
- LLM queries are intercepted and answered from the log (no live API calls)
- Tool executions are intercepted and answered from the log (no live shell commands)
- The cognitive loop runs identically because all inputs are identical
- The PRNG seed is restored from the snapshot, ensuring identical random choices

### Counterfactual Replay

Counterfactual replay (modifying inputs) is explicitly NON-deterministic — modified inputs may trigger different LLM queries not in the log, requiring live API calls that produce different responses each run. Useful for "what if" analysis but NOT for debugging (use deterministic mode for that).

### Replay Storage and Retention

Replay logs are stored in `~/.kc/state/replay/`. Retention: current session (always recording), last 24 hours of completed sessions, and user-bookmarked segments (kept indefinitely). Size estimate: ~1 MB per hour of active use (mostly LLM responses). Maximum log size is configurable (default 500 MB); when exceeded, oldest events are dropped.

---

## Edge Cases

1. **Snapshot corruption**: rkyv file is truncated or invalid (power loss during write). Mitigation: write to temp file, then atomic rename. Keep previous snapshot as fallback. If both corrupt, start from SQLite-only state (lose volatile cognitive state, keep all knowledge).

2. **SQLite WAL overflow**: Very long session without checkpoint. Mitigation: force WAL checkpoint every 10,000 ticks. SQLite handles this automatically with `PRAGMA wal_autocheckpoint`.

3. **HNSW rebuild failure**: Not enough memory to hold full index during rebuild. Mitigation: build incrementally (batch insert), or reduce index parameters (lower M, lower ef_construction) on memory-constrained devices.

4. **Embedding migration + crash**: System crashes mid-migration. Mitigation: migration progress is persisted. On recovery, resume from last batch. Dual-column schema means partially-migrated state is always queryable.

5. **Replay log grows unbounded**: Long session produces huge replay log. Mitigation: configurable max size (default 500 MB). When exceeded, oldest events are dropped (replay can only go back to the oldest retained event).

6. **Clock skew during replay**: System clock differs between recording and replay. Mitigation: replay uses tick numbers, not wall-clock time. Timer events are replayed by tick, not by timestamp.

7. **State divergence after recovery**: Recovered state may differ slightly from pre-crash state (lost ticks between last snapshot and crash). Mitigation: the system accepts this gracefully — PP layers recalibrate within ~50 ticks, affect drifts back to appropriate levels, agents re-assess their pending work.

---

## Interaction with Other Subsystems

- **Concurrency Model**: Snapshots are taken synchronously at the END of a tick (Phase 7). No concurrent access during snapshot. See `concurrency-model.md` for tick phase ordering.
- **Cognitive Homeostasis**: The supervisor uses the state checkpoint log (binary format, see `cognitive-homeostasis.md`) for crash recovery. The rkyv snapshot is the kernel's own recovery mechanism. They serve different purposes: supervisor log = external monitoring, rkyv snapshot = internal state restoration.
- **Memory Palace**: SQLite databases ARE the memory palace's durable storage. The HNSW index is a derived acceleration structure. See `memory-palace.md` for schema details.
- **Self-Modification**: Before hot-reload, an emergency snapshot is taken. If the new binary fails health checks, the supervisor restores from this snapshot. See `self-modification.md` for the full pipeline.
- **LLM Pool**: LLM responses are recorded in the replay log at the perception boundary. The pool itself is stateless (no recovery needed). See `llm-pool.md` for provider state.
- **TUI**: Replay mode in Paranoia view reads from the replay log and re-renders historical ticks. The TUI never modifies replay data.
- **Telemetry**: Telemetry is a separate SQLite database. It records events for analytics but is NOT used for recovery. Loss of telemetry.db is acceptable (no cognitive impact).
- **Safety Architecture**: Constitutional verification runs against the binary on disk, not against snapshotted state. See `safety-architecture.md` for the verification sequence.

---

## Research References

- **rkyv documentation** — Zero-copy deserialization, archive format stability
- **SQLite WAL mode** — Write-ahead logging guarantees, checkpoint behavior
- **Malkov & Yashunin (2018)**. "Efficient and robust approximate nearest neighbor using HNSW graphs" — Index rebuild characteristics
- **Lamport, L. (1978)**. "Time, Clocks, and the Ordering of Events" — Deterministic replay via logical clocks
- **Relevant crates**: `rkyv` (zero-copy serialization), `rusqlite` (SQLite bindings), `zstd` (compression), `blake3` (hashing), `hnsw_rs` (vector index)
