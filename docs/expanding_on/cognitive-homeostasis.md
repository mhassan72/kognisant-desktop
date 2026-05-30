# Cognitive Homeostasis — Deep Dive

The Cognitive Homeostasis layer is what separates a "persistent agent" from an "artificial organism." It continuously maintains viable operating equilibrium over indefinite runtime, detecting and correcting pathological cognition patterns before they destabilize the system.

---

## Summary

Without homeostasis, a continuous cognitive system inevitably drifts toward entropy: corrupted state, runaway feedback loops, memory fragmentation, degraded predictions, unstable emergent behavior. This layer provides structural integrity healing (crash recovery), cognitive stability healing (pathology detection), epistemic healing (belief maintenance), and runtime survival (resource management).

---

## Supervisor Process Architecture

### Process Hierarchy

```
kognisant-supervisor (PID 1 of the application)
    │
    ├── Heartbeat listener (UDP socket or shared memory)
    ├── Health snapshot recorder
    ├── Panic handler (SIGCHLD listener)
    ├── Resource watchdog
    ├── Zombie reaper
    ├── Constitutional verifier
    │
    └── cognitive-kernel (child process)
            ├── Main tick loop
            ├── Cognitive Immune System (internal)
            ├── Integrity Verifier (internal)
            └── All cognitive subsystems
```

### Supervisor Responsibilities

| Responsibility | Mechanism | Frequency |
|---------------|-----------|-----------|
| Heartbeat monitoring | Expect ping every tick (100ms) | Continuous |
| Crash recovery | SIGCHLD → journal replay → restart | On crash |
| Resource monitoring | /proc/PID/status or equivalent | Every 500ms |
| Zombie reaping | Check child process table | Every 5s |
| Constitutional verification | BLAKE3 hash + Ed25519 signature check | Every 60s |
| Health history | Record HealthSnapshot | Every 500ms |
| Disk pressure | Check available space | Every 30s |
| Memory leak detection | RSS trend analysis | Every 10s |

### Supervisor-Kernel Communication

```
// Kernel → Supervisor (heartbeat + state)
struct HeartbeatMessage {
    tick_number: u64,
    tick_duration_ms: u16,
    inflammation_level: f32,
    active_agents: u8,
    memory_rss_mb: u32,
    pending_goals: u16,
}

// Supervisor → Kernel (commands)
enum SupervisorCommand {
    ReduceLoad,          // Shed agents, reduce tick rate
    ForceConsolidate,    // Enter consolidation immediately
    PauseModification,   // Disable self-modification
    Checkpoint,          // Take immediate snapshot
    Shutdown,            // Graceful shutdown
}
```

### Crash Recovery Flow

```
1. Supervisor detects kernel death (heartbeat timeout or SIGCHLD)
2. Log crash event with last known tick number
3. Find last healthy journal checkpoint
4. Spawn new kernel process
5. Kernel loads checkpoint state
6. Replay valid journal deltas since checkpoint
7. Resume tick loop from recovered state
8. Record recovery event in telemetry

Recovery time target: < 5 seconds from crash to resumed operation
```

---

## Journal Format Specification

### Journal File Structure

The cognitive journal is an append-only binary file:

```
~/.kc/state/journal.bin

Format:
[Header: 32 bytes]
  magic: "KGNJ" (4 bytes)
  version: u16
  created_at: i64
  device_id: [u8; 16]

[Entry 0]
  entry_type: u8
  tick: u64
  timestamp: i64
  payload_len: u32
  payload: [u8; payload_len]
  checksum: u32 (CRC32 of entry_type..payload)

[Entry 1]
...
```

### Entry Types

```
enum JournalEntryType {
    Snapshot = 0x01,        // Full state serialization (rkyv binary)
    Delta = 0x02,           // Incremental state change
    Verification = 0x03,    // Integrity check result
    Commit = 0x04,          // Batch of deltas confirmed valid
    Rollback = 0x05,        // State reverted to earlier point
    KernelPanic = 0x06,     // Crash recorded
    Recovery = 0x07,        // Successful recovery from crash
    Intervention = 0x08,    // Immune system intervention applied
    Consolidation = 0x09,   // Consolidation window start/end
}
```

### Snapshot Format

Full snapshots use `rkyv` (zero-copy deserialization) for speed:

```
struct JournalSnapshot {
    tick: u64,
    state_hash: [u8; 32],           // BLAKE3 of serialized state
    compressed_state: Vec<u8>,       // zstd-compressed rkyv bytes
    subsystem_hashes: HashMap<String, [u8; 32]>,  // Per-subsystem integrity
}
```

Snapshot frequency: every 1000 ticks (~100s at 10Hz). Size: typically 1-5 MB compressed.

### Delta Format

Deltas record what changed between ticks:

```
struct JournalDelta {
    tick: u64,
    subsystem: String,              // "memory", "affect", "goals", etc.
    mutation_type: MutationType,    // Add, Remove, Update, Clear
    key: String,                    // What was changed
    old_value_hash: [u8; 32],       // Hash of previous value (for verification)
    new_value: Vec<u8>,             // Serialized new value
}
```

Delta frequency: every 100 ticks. Only records subsystems that actually changed.

### Journal Compaction

The journal grows indefinitely. Compaction runs during consolidation:

```
1. Find oldest snapshot that is still needed (last 3 snapshots kept)
2. Delete all entries before that snapshot
3. Verify remaining entries form a valid chain
4. Truncate file (or create new file and swap)
```

Retention: ~30 minutes of history (enough for recovery from any recent crash).

---

## Pathology Detector Implementations

### 1. GoalFloodDetector

**Detects**: Goals generated faster than resolved (runaway goal generation).

```
Trigger condition:
    generation_rate > resolution_rate * 5.0
    AND generation_rate > 0.1 goals/tick

Typical cause:
    - High curiosity + low generation threshold
    - Surprise cascade (one event triggers many goals)
    - Feedback loop (goal failure generates new goals about the failure)
```

### 2. AffectiveStuckDetector

**Detects**: Affect dimensions locked at extremes for extended periods.

```
Trigger condition:
    dimension_value > 0.95 OR dimension_value < 0.05
    AND stuck_duration > 3000 ticks (5 minutes)

Typical cause:
    - Continuous failure without any success signal (frustration lock)
    - No user input for extended period (uncertainty lock)
    - Rapid success without challenge (reward expectation ceiling)
```

### 3. InfiniteBidLoopDetector

**Detects**: An agent generating bids every tick without ever executing.

```
Trigger condition:
    agent.bids_last_100_ticks > 90
    AND agent.executions_last_100_ticks == 0

Typical cause:
    - Agent's bid is always outscored (confidence too low)
    - Agent bids on goals that are always blocked by dependencies
    - Bug in agent's perception (always sees opportunity, never wins)
```

### 4. ObsessionLoopDetector

**Detects**: Same topic/concept dominating working memory for too long.

```
Trigger condition:
    topic.wm_presence_ratio > 0.8 (in WM 80%+ of ticks)
    AND duration > 5000 ticks (8+ minutes)
    AND no progress on related goals

Typical cause:
    - Memory activation loop (concept keeps winning competition)
    - Unresolvable goal keeps re-activating related memories
    - User topic that the system cannot make progress on
```

### 5. PredictionCollapseDetector

**Detects**: Prediction accuracy dropping below useful levels.

```
Trigger condition:
    homunculus.accuracy_10min < 0.2
    AND ticks_since_last_calibration > 3000

Typical cause:
    - Major context shift (new project, different domain)
    - Self-modification that degraded prediction models
    - Corrupted state in predictive stack
```

### 6. MemorySaturationDetector

**Detects**: Memory tier approaching capacity limits.

```
Trigger condition:
    tier.usage_ratio > 0.9

Typical cause:
    - Consolidation not running (fatigue never triggers)
    - High-activity period without idle time
    - Memory leak (entries not being pruned)
```

### 7. SemanticContradictionOverloadDetector

**Detects**: Too many unresolved contradictions in the semantic network.

```
Trigger condition:
    contradiction_count > 20

Typical cause:
    - Rapid belief updates from conflicting sources
    - Stale beliefs contradicting new observations
    - Consolidation not resolving contradictions fast enough
```

### 8. SelfModificationSpiralDetector

**Detects**: Repeated self-modification attempts with high failure rate.

```
Trigger condition:
    attempts_last_24h > 5
    AND failure_rate > 0.6

Typical cause:
    - Modification target is fundamentally wrong approach
    - Test suite is flaky (random pass/fail)
    - Patch generation quality is poor for this domain
```

---

## Intervention Severity Levels

| Level | Name | Actions | Recovery Time |
|-------|------|---------|---------------|
| 0 | Observation | Log only, no intervention | N/A |
| 1 | Gentle | Adjust parameters (decay rates, thresholds) | 1-5 minutes |
| 2 | Moderate | Suppress specific subsystem, force consolidation | 5-15 minutes |
| 3 | Aggressive | Shed agents, reduce tick rate, clear WM | 15-60 minutes |
| 4 | Emergency | Survival mode (2 agents, 1Hz, no self-mod, force consolidate) | 1-4 hours |
| 5 | Critical | Supervisor restart, factory state restore | Manual intervention |

### Intervention Escalation

```
if pathology persists after Level N intervention for 1000 ticks:
    escalate to Level N+1

if pathology resolves:
    de-escalate one level every 5000 ticks
    (gradual return to normal, not instant)
```

---

## Inflammation Model Dynamics

### The Inflammation Metaphor

Like biological inflammation, cognitive inflammation is a protective response that becomes harmful if sustained:

```
inflammation_level = detected_pathologies.len() as f64 / 5.0

// Inflammation affects the whole system:
if inflammation > 0.3:
    self_modification_allowed = false  // No evolution during illness
if inflammation > 0.5:
    goal_generation_threshold *= 1.5   // Reduce new goals
if inflammation > 0.8:
    emergency_stabilization()          // Survival mode
```

### Inflammation Decay

After pathologies are resolved:

```
inflammation_decay_rate = 0.001 per tick  // Slow recovery
// Full recovery from 0.8 → 0.0 takes ~800 ticks (80 seconds)
// This prevents premature return to full operation
```

### Chronic vs Acute Inflammation

```
if inflammation > 0.5 for > 50,000 ticks (83 minutes):
    // Chronic inflammation — something is fundamentally wrong
    trigger_deep_diagnostic()
    notify_user("I'm experiencing persistent cognitive instability. May need attention.")
    consider_factory_reset_of_affected_subsystem()
```

---

## Epistemic Healing Algorithms

### Belief Confidence Decay

Every belief loses confidence over time unless re-confirmed:

```
confidence(t) = confidence(t₀) * 0.5^((t - t₀) / half_life)

half_life varies by belief type:
    - Tool behavior: 50,000 ticks (~83 min) — tools change
    - Code structure: 200,000 ticks (~5.5 hours) — code is relatively stable
    - User preferences: 500,000 ticks (~14 hours) — preferences are durable
    - Domain knowledge: 1,000,000 ticks (~28 hours) — concepts are stable
```

### Contradiction Resolution Priority

When contradictions are detected, resolve in this order:

```
1. Safety-relevant contradictions (immediate — could cause harm)
2. User-model contradictions (high priority — affects interaction quality)
3. Causal model contradictions (medium — affects simulation accuracy)
4. Semantic network contradictions (low — affects memory quality)
5. Procedural contradictions (lowest — affects strategy selection)
```

### Memory Reconciliation Scheduling

```
reconciliation runs every 10,000 ticks (~17 minutes):
    1. Deduplicate episodic buffer (merge entries with similarity > 0.95)
    2. Abstract old episodes into patterns
    3. Prune low-activation memories (activation < 0.01, age > 50,000 ticks)
    4. Compress old embeddings (reduce precision from f32 to f16 for entries > 200,000 ticks old)
    5. Rebuild vector indices
    6. Run contradiction resolver on semantic network
    7. Decay belief confidences
    8. Prune dead edges from semantic graph (strength < 0.05)
    9. Remove orphan nodes (no edges, no recent activation)
    10. Normalize confidence distribution
```

---

## Open Questions / Design Decisions

1. **Supervisor communication**: Shared memory vs Unix socket vs pipe? Shared memory is fastest but platform-specific. Current plan: platform-abstracted IPC (Unix socket on macOS/Linux, named pipe on Windows).

2. **Journal size management**: How much history to keep? Current plan: 30 minutes of deltas + last 3 snapshots. But for debugging, more history is useful. Solution: configurable retention with disk-space-aware defaults.

3. **Intervention aggressiveness**: How quickly should the system escalate? Too fast = unnecessary disruption. Too slow = pathology causes damage. Current plan: 1000 ticks (100s) per escalation level. Needs empirical tuning.

4. **User notification**: When should the user be told about homeostasis events? Current plan: Level 3+ interventions are shown in the TUI (Trace mode and above). Level 1-2 are silent (logged in telemetry only). In Focus mode, only Level 4+ surfaces as a status bar warning.

5. **Factory reset scope**: What does "factory reset" mean for a subsystem? Reset to initial state? Reset to last known good? Current plan: per-subsystem reset to last healthy snapshot, not full factory reset (which would lose all learning).

6. **Multi-device homeostasis**: If the system runs on multiple devices (via sync), should homeostasis state sync? Current plan: no — each device maintains independent homeostasis. Pathologies are device-specific.

---

## Research References

- **Ashby, W.R. (1960)**. "Design for a Brain" — Homeostatic mechanisms in adaptive systems
- **Cannon, W.B. (1932)**. "The Wisdom of the Body" — Original homeostasis concept
- **Sterling, P. (2012)**. "Allostasis: A model of predictive regulation" — Predictive homeostasis
- **Friston, K. (2010)**. "The free-energy principle: a unified brain theory?" — Free energy as homeostatic set-point
- **Seth, A.K. (2015)**. "The Cybernetic Bayesian Brain" — Predictive processing as homeostasis
- **Relevant crates**: `rkyv` (zero-copy serialization for snapshots), `blake3` (fast hashing), `zstd` (compression), `tokio` (async supervisor loop), `nix` (Unix process management)

---

## Edge Cases and Failure Modes

1. **Supervisor crash**: If the supervisor itself crashes, the kernel continues running unsupervised. Mitigation: the kernel has a "supervisor heartbeat" check — if it doesn't hear from the supervisor for 30s, it enters safe mode (reduced operation, no self-modification).

2. **Journal corruption**: Power loss during journal write. Mitigation: each entry has a CRC32 checksum. Corrupted entries are skipped during recovery. Worst case: lose deltas since last snapshot.

3. **False positive pathology**: The immune system detects a "pathology" that is actually normal behavior in a new context. Mitigation: pathology thresholds adapt over time (if a "pathology" keeps being detected and the system is otherwise healthy, raise the threshold).

4. **Intervention side effects**: An intervention to fix one pathology causes another. Mitigation: after any intervention, re-scan for new pathologies. If intervention caused new issues, revert the intervention.

5. **Chronic low-grade inflammation**: System operates at inflammation 0.2-0.3 indefinitely — not enough to trigger emergency measures, but enough to suppress self-modification and reduce performance. Mitigation: if inflammation stays > 0.2 for > 100,000 ticks, trigger deep diagnostic regardless.

6. **State divergence after recovery**: Recovered state (from snapshot + deltas) may differ slightly from the state that would have existed without the crash. Mitigation: post-recovery validation — run integrity checks on all subsystems, flag any inconsistencies.

---

## Interaction with Other Subsystems

- **Self-Modification**: Homeostasis gates self-modification. No modifications during inflammation > 0.3. Post-modification health monitoring is a homeostasis function.
- **Memory Palace**: Memory reconciliation is a homeostasis function. The MemoryReconciler runs during scheduled maintenance windows.
- **Predictive Processing**: PredictionCollapseDetector monitors PP stack health. Intervention: force recalibration.
- **Affective Economy**: AffectiveStuckDetector monitors affect. Intervention: AffectRebalancer pulls toward neutral.
- **Goal Market**: GoalFloodDetector monitors goal generation. Intervention: raise generation threshold, force abandonment of low-priority goals.
- **Agent Society**: InfiniteBidLoopDetector monitors agents. Intervention: temporarily disable stuck agent.
- **Telemetry**: All interventions are recorded with full context (pathology detected, intervention applied, outcome).
- **Supervisor**: The supervisor IS the homeostasis layer's external component. It provides crash recovery and resource monitoring that the kernel cannot provide for itself.
- **TUI**: Paranoia mode shows inflammation level and active pathology detectors. Level 3+ interventions surface in Trace mode as warnings.
- **Project Context**: Homeostasis state is stored in `~/.kc/state/` (not per-project). Each device maintains independent homeostasis.
- **Journal**: Significant homeostasis events (Level 3+) are automatically recorded as system journal entries for post-mortem analysis.
