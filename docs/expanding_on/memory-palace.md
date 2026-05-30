# Memory Palace — Deep Dive

The Memory Palace is a 6-tier reconstructive memory system modeled after human cognitive architecture. Memories are not stored and retrieved — they compete for activation, decay without rehearsal, consolidate during idle periods, and are actively forgotten when no longer useful.

---

## Summary

Memory in Kognisant is not a database you query. It's a living ecosystem where memory traces compete for limited working memory slots, strengthen through use, weaken through neglect, and transform through consolidation. The system remembers by reconstructing, not by replaying.

---

## Tier Interactions — The Full Flow

### Encoding Path (New Information → Storage)

```
Sensory Input
    │
    ▼
Working Memory (immediate binding, capacity-limited)
    │
    ├── If rehearsed / high salience → Episodic Buffer (time-indexed sequence)
    │                                       │
    │                                       ├── Pattern extraction → Semantic Network
    │                                       │
    │                                       └── Action-outcome pairs → Procedural Memory
    │
    └── If not rehearsed → Decays within 1-3 ticks (lost)

During Consolidation (idle/sleep):
    Episodic Buffer → Dream Engine → {Semantic Network, Procedural Memory, LTM}
```

### Retrieval Path (Context → Activated Memories)

```
Current Context (surprise signals, active goals, WM contents)
    │
    ├── Cue → Episodic Buffer (temporal proximity search)
    ├── Cue → Semantic Network (spread activation + vector similarity)
    ├── Cue → Procedural Memory (condition matching)
    └── Cue → LTM (compressed embedding similarity)
    │
    ▼
All candidates compete (activation energy scoring)
    │
    ▼
Top-N enter Working Memory (losers are inhibited)
```

### Cross-Tier Promotion and Demotion

| Transition | Trigger | Mechanism |
|-----------|---------|-----------|
| WM → Episodic | Tick completes with WM contents | Automatic snapshot |
| Episodic → Semantic | Pattern detected across episodes | Dream engine extraction |
| Episodic → Procedural | Action-outcome pair repeated 3+ times | RL update |
| Semantic → LTM | Node stability > 0.8 for 50k ticks | Compression + archival |
| LTM → Semantic | LTM chunk wins activation competition | Decompression + reactivation |
| Any tier → Forgotten | Activation below threshold for too long | Pruning during reconciliation |

---

## Activation Decay Formulas

### Base Decay Model

Every memory trace has an activation level `A(t)` that decays exponentially:

```
A(t) = A₀ * e^(-λt) + Σᵢ boost_i * e^(-λ(t - t_i))
```

Where:
- `A₀` = initial activation at encoding
- `λ` = decay rate (tier-specific)
- `boost_i` = activation boost from retrieval event at time `t_i`

### Tier-Specific Decay Rates

| Tier | λ (per tick) | Half-life | Rationale |
|------|-------------|-----------|-----------|
| Working Memory | 0.1 | ~7 ticks | Rapid decay without rehearsal |
| Episodic Buffer | 0.001 | ~700 ticks (~70s) | Medium-term, time-indexed |
| Semantic Network | 0.00001 | ~70,000 ticks (~2h) | Slow decay, concept stability |
| Procedural Memory | 0.000005 | ~140,000 ticks (~4h) | Skills are durable |
| LTM | 0.000001 | ~700,000 ticks (~19h) | Long-term, compressed |

### Retrieval Boost

Each time a memory is successfully retrieved (wins activation competition):

```
boost = base_boost * (1 + emotional_salience) * precision_weight
```

Where `base_boost` varies by tier:
- WM: 1.0 (full refresh)
- Episodic: 0.5
- Semantic: 0.3
- Procedural: 0.2
- LTM: 0.4 (decompression is expensive, so reward it)

### Spacing Effect

Repeated retrievals with longer intervals produce stronger memories (mirrors human spacing effect):

```
effective_boost = boost * log(1 + interval_since_last_retrieval / 100)
```

This means a memory retrieved after 1000 ticks gets a stronger boost than one retrieved after 10 ticks, encouraging distributed practice.

---

## Consolidation Algorithms

### Dream Engine Pipeline

During idle periods (user inactive > 60s, or fatigue > 0.6):

1. **Sample**: Select 100 recent episodes from episodic buffer (weighted by surprise magnitude)
2. **Replay**: Re-run each episode through the predictive stack (offline, no actions emitted)
3. **Pattern Detection**: Identify recurring sequences across episodes
   - Temporal patterns: "A always precedes B"
   - Causal patterns: "When I do X, Y happens"
   - Structural patterns: "These 5 episodes share the same abstract structure"
4. **Counterfactual Generation**: For high-surprise episodes, generate "what if" alternatives
   - Swap one action in the sequence
   - Predict alternative outcome via world simulator
   - If alternative is better → update procedural memory
5. **Abstraction**: Replace specific details with category labels
   - "user asked about auth in project-foo" → "user asked about [security] in [active-project]"
6. **Integration**: Write patterns to semantic network, update procedural rules
7. **Compression**: Summarize processed episodes, reduce embedding precision, archive to LTM
8. **Pruning**: Remove fully-processed episodes from episodic buffer (keep 30% as anchors)

### Consolidation Scheduling

```
consolidation_urgency = (
    episodic_buffer_fullness * 0.4 +
    time_since_last_consolidation / max_interval * 0.3 +
    fatigue_level * 0.2 +
    contradiction_count / 10.0 * 0.1
)
```

If `consolidation_urgency > 0.7`, the MCC schedules a consolidation window.

---

## HNSW Configuration

### Index Parameters

For the semantic network's vector index (approximate nearest neighbor search):

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| M (max connections per node) | 16 | Balance between recall and memory usage |
| ef_construction | 200 | High quality index build (offline, can be slow) |
| ef_search | 50 (Standard), 100 (Performance) | Query-time accuracy vs speed |
| Distance metric | Cosine similarity | Standard for text embeddings |
| Dimension | 384 (MiniLM) or 768 (Nomic) | Device-tier dependent |

### Index Maintenance

- **Rebuild frequency**: Every 10,000 ticks or after consolidation (whichever comes first)
- **Incremental updates**: New nodes added with `ef_construction = 100` (faster, slightly lower quality)
- **Full rebuild trigger**: When recall@10 drops below 0.85 (measured by sampling known-good queries)

### Memory Budget for HNSW

```
index_memory_bytes ≈ num_nodes * dimension * 4 * (M + 1)
```

For 10,000 nodes at 384d with M=16:
- `10000 * 384 * 4 * 17 ≈ 261 MB` — fits comfortably in Standard tier
- Minimal tier caps at 500 nodes: `500 * 384 * 4 * 17 ≈ 13 MB`

---

## Embedding Model Selection

### Decision Matrix

| Model | Dimensions | Speed (CPU) | Quality | Size | Best For |
|-------|-----------|-------------|---------|------|----------|
| all-MiniLM-L6-v2 | 384 | ~5ms/embed | Good | 80MB | Standard tier, general use |
| nomic-embed-text-v1.5 | 768 | ~15ms/embed | Excellent | 270MB | Performance tier |
| BGE-small-en-v1.5 | 384 | ~5ms/embed | Good | 130MB | Alternative to MiniLM |
| API-only (no local) | varies | 100-300ms | Best | 0 | Minimal tier |

### Selection Logic

```
if device_tier == Minimal:
    use API embeddings only (Kognisant API or OpenAI)
elif device_tier == Standard:
    load MiniLM-L6 via ONNX Runtime (CPU)
elif device_tier == Performance:
    if has_gpu:
        load Nomic-embed via ONNX Runtime (GPU)
    else:
        load Nomic-embed via ONNX Runtime (CPU, batched)
```

### Embedding Cache Strategy

- Cache embeddings for all semantic network nodes (they don't change once computed)
- Cache recent episodic buffer embeddings (last 200 entries)
- Do NOT cache working memory embeddings (too transient)
- Invalidate cache on embedding model change (requires full re-embed)

---

## SQLite Schema Design Rationale

### Why SQLite (Not Postgres, Not Custom)

1. **Zero deployment**: No server process, no configuration, no ports
2. **Single-file per database**: Easy to backup, sync, and reason about
3. **WAL mode**: Concurrent reads during writes (critical for 10Hz tick + background consolidation)
4. **Bundled via rusqlite**: No system dependency, compiles into the kernel
5. **Proven at scale**: Handles millions of rows without issue for our use case

### Database Split Strategy

Rather than one monolithic database, the memory palace uses multiple SQLite files:

```
~/.kc/state/memory_palace/
├── episodic.db          # Ring buffer of time-indexed episodes
├── semantic.db          # Concept nodes, edges, embeddings
├── procedural.db        # Skills, rules, action-outcome pairs
├── ltm.db               # Compressed long-term memories
└── meta.db              # Cross-tier metadata, activation scores, indices
```

**Rationale**: Different tiers have different access patterns:
- Episodic: append-heavy, sequential reads, periodic bulk deletes
- Semantic: random reads, frequent updates to activation scores, graph traversals
- Procedural: read-heavy (condition matching), infrequent writes
- LTM: bulk reads during consolidation, rare individual access

Separate files allow independent WAL checkpointing, backup, and sync scheduling.

### Key Schema Decisions

1. **Embeddings stored as BLOBs**: `BLOB` of `f32` values (not JSON arrays). 4x more compact, direct memory mapping possible.

2. **Activation scores in separate table**: Updated every tick for active memories. Keeping them separate from the main content table avoids write amplification.

3. **Temporal indexing**: Episodic buffer uses `(tick_number, channel)` as primary key. Enables efficient range queries for "last N ticks" and "all events on channel X."

4. **Edge table denormalization**: Semantic edges store both `source_id` and `target_id` with indices on both. Enables bidirectional traversal without self-joins.

5. **Soft deletes**: Memories are never hard-deleted during normal operation. They get `status = 'pruned'` and are physically removed during scheduled maintenance (VACUUM).

---

## Competitive Inhibition Dynamics

### The Competition Model

When multiple memories are candidates for working memory, they don't just get ranked — they actively inhibit each other:

```
for each candidate_i:
    inhibition_i = Σ_j (activation_j * overlap(i, j) * inhibition_strength)
    effective_activation_i = activation_i - inhibition_i
```

Where `overlap(i, j)` is the cosine similarity between memory embeddings. Similar memories compete more strongly (you can't hold two contradictory beliefs in WM simultaneously).

### Inhibition Strength Parameters

| Relationship | Inhibition Strength | Effect |
|-------------|-------------------|--------|
| Same concept, different episodes | 0.8 | Only the most relevant version wins |
| Related concepts | 0.3 | Mild competition, both can coexist |
| Unrelated concepts | 0.0 | No competition |
| Contradictory beliefs | 1.0 | Maximum competition, forces resolution |

### Optimized Inhibition (Avoiding O(n²))

The naive inhibition algorithm is O(n²) over all candidates. With 50+ candidates, this exceeds tick budget. The optimized version reduces to O(K²/num_clusters) ≈ O(80) comparisons:

```rust
/// Optimized inhibition: only compute between top-K candidates
/// and only within the same semantic cluster
fn compute_inhibition_optimized(candidates: &mut [MemoryChunk], k: usize) {
    // 1. Sort by raw activation (pre-inhibition)
    candidates.sort_by(|a, b| b.activation.partial_cmp(&a.activation).unwrap());

    // 2. Only consider top-K for inhibition (rest are already losers)
    let top_k = &mut candidates[..k.min(candidates.len())];

    // 3. Cluster top-K by embedding similarity (cheap: K is small, ~20)
    let clusters = cluster_by_similarity(top_k, 0.7);

    // 4. Only compute inhibition WITHIN clusters (similar memories compete)
    for cluster in &clusters {
        for i in 0..cluster.len() {
            let mut inhibition = 0.0;
            for j in 0..cluster.len() {
                if i == j { continue; }
                inhibition += cluster[j].activation * cluster[i].overlap_with(&cluster[j]);
            }
            cluster[i].effective_activation -= inhibition;
        }
    }

    // 5. Re-sort by effective activation
    candidates.sort_by(|a, b| b.effective_activation.partial_cmp(&a.effective_activation).unwrap());
}
```

With K=20 and average cluster size 4, this reduces from O(n²) to O(K²/num_clusters) ≈ O(80) comparisons instead of O(2500) for 50 candidates.

### Refractory Period

After a memory loses competition, it enters a refractory period where its activation is suppressed:

```
refractory_suppression = 0.3 * e^(-ticks_since_loss / 50)
```

This prevents the same memory from repeatedly competing and losing (wasting computation). It must wait ~150 ticks before it can compete again at full strength.

---

## Open Questions / Design Decisions

1. **Working memory capacity formula**: Currently `min(context_budget / 500, ram_budget, 50)`. Is 500 tokens per chunk the right estimate? Need empirical measurement once the system is running.

2. **Episodic buffer ring size**: Fixed at 1000 ticks for Standard tier. Should this adapt based on how "eventful" recent ticks have been? Sparse ticks (no input) could be compressed.

3. **Semantic network graph storage**: `petgraph` in-memory vs SQLite-backed graph. In-memory is faster but limits size. Current plan: hybrid — hot subgraph in memory, cold nodes on disk.

4. **Procedural memory RL algorithm**: Simple Q-learning vs policy gradient vs contextual bandits? Q-learning is simplest but may not handle the continuous state space well. Contextual bandits seem most appropriate for "given this context, which action template works best?"

5. **Dream engine LLM usage**: Should counterfactual generation use the LLM? It's expensive but produces higher-quality alternatives. Current plan: use LLM only for high-surprise episodes (top 10% by free energy).

6. **Cross-project memory isolation**: Projects share the skill library but not episodic/semantic memory. Is there ever a case where semantic concepts should transfer? (e.g., "React patterns" learned in project A useful in project B)

---

## Research References

- **Baddeley, A. (2000)**. "The episodic buffer: a new component of working memory?" — Multi-component WM model
- **Anderson, J.R. (1983)**. "The Architecture of Cognition" — ACT-R activation-based memory
- **McClelland, J.L. et al. (1995)**. "Why there are complementary learning systems" — Hippocampal vs neocortical memory
- **Malkov & Yashunin (2018)**. "Efficient and robust approximate nearest neighbor using HNSW graphs" — HNSW algorithm
- **Walker & Stickgold (2004)**. "Sleep-dependent memory consolidation" — Consolidation during sleep
- **Relevant crates**: `rusqlite`, `hnsw_rs` or `instant-distance`, `ort` (ONNX), `petgraph`, `rkyv` (zero-copy serialization)

---

## Edge Cases and Failure Modes

1. **Working memory thrashing**: If competition is too fierce, WM contents change every tick (no stability). Mitigation: hysteresis — a memory must beat the current occupant by > 0.1 activation to displace it.

2. **Episodic buffer overflow**: If the system is highly active (many events per tick), the ring buffer fills faster than consolidation can process. Mitigation: emergency pruning of low-salience entries.

3. **Semantic network fragmentation**: After heavy pruning, the graph may become disconnected (isolated subgraphs). Mitigation: periodic connectivity check; orphaned subgraphs get boosted activation to reconnect or get archived to LTM.

4. **Embedding drift**: If the embedding model is updated (e.g., user upgrades from MiniLM to Nomic), all existing embeddings become incompatible. Mitigation: store model version with embeddings; trigger full re-embedding on model change (expensive but necessary).

5. **Consolidation interruption**: User returns during consolidation. Mitigation: consolidation is interruptible — each step is atomic. Partial consolidation is valid; remaining work queued for next window.

6. **Memory corruption**: SQLite WAL corruption (power loss during write). Mitigation: WAL mode with synchronous=NORMAL provides crash safety. Worst case: rebuild from last journal snapshot.

---

## Interaction with Other Subsystems

- **Predictive Processing**: Surprise signals are the primary retrieval cue. High surprise → broad memory search. Low surprise → narrow, confirmatory retrieval.
- **Affective Economy**: Emotional salience is a factor in activation scoring. High-affect memories persist longer and win competitions more easily.
- **Homunculus**: The self-model's "known unknowns" list is stored in semantic memory. Self-surprise triggers episodic encoding of the self-state.
- **Goal Market**: Active goals bias memory retrieval (goal-relevant memories get activation boost). Completed goals trigger episodic encoding of the full goal lifecycle.
- **Agent Society**: The MemoryAgent manages organization, triggers consolidation requests, and handles cross-tier promotion decisions.
- **World Simulator**: Beliefs in the world model are backed by semantic network nodes. Counterfactual reasoning queries procedural memory for "what would happen if."
- **Cognitive Homeostasis**: The MemoryReconciler runs during homeostasis scans, pruning stale memories and resolving contradictions.
- **TUI**: In Paranoia mode, the memory view shows current WM contents, competing candidates, and activation scores. Consolidation progress is visible during idle periods.
- **Project Context**: `.kc/memory/` provides project-local persistent context that seeds the semantic network on project load. Cross-project memory lives in `~/.kc/memory/`.
- **Skill Extraction**: Procedural memory patterns (repeated action-outcome pairs) feed into the SkillMiningAgent's detection pipeline.
