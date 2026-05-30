# Self-Modification — Deep Dive

The Self-Modification Engine enables the system to read, modify, recompile, and hot-reload its own source code. This is the most powerful and most dangerous subsystem — bounded by constitutional constraints, safety gates, mutation budgets, shadow runtimes, and behavioral verification.

---

## Summary

Self-modification is controlled recursive evolution. The system identifies performance gaps, generates code patches, validates them in isolated shadow runtimes, verifies behavioral preservation through cognitive benchmarks, and only then applies changes to the live system — with automatic rollback if health degrades within 60 seconds.

---

## Full Pipeline: Trigger to Hot-Reload

### End-to-End Flow

```
1. TRIGGER DETECTION
   └── Homunculus L3 detects performance degradation
   └── OR: Repeated failure pattern (same error 3+ times)
   └── OR: Efficiency opportunity (high token waste detected)
   └── OR: Capability gap (user requests unsupported feature)

2. PERMISSION CHECK
   └── MutationBudget::can_modify() → Allowed/Denied
   └── Check: daily budget, stability window, rollback cooldown
   └── Check: affect state (self_modification_risk > threshold)

3. GOAL SUBMISSION
   └── Self-improvement goal submitted to Goal Market
   └── Competes with other goals normally
   └── Must win bid to proceed (not automatic)

4. TARGET IDENTIFICATION
   └── Identify which module/function to modify
   └── Read current source from source_mirror/
   └── Analyze: what specifically needs to change?

5. PATCH GENERATION
   └── LLM generates candidate patch (via LLM Pool)
   └── Multiple candidates if budget allows (2-3 alternatives)
   └── Each candidate is a unified diff

6. SAFETY GATE VALIDATION
   └── Check immutable markers (SafetyGate, rollback, telemetry, auth, sandbox)
   └── Check critical path (CognitiveKernel::run, Homunculus, GoalMarket, AffectiveEconomy)
   └── Check complexity increase (< 20% allowed)
   └── REJECT if any violation

7. APPLY TO MIRROR
   └── Apply patch to source_mirror/ (git working tree)
   └── This is NOT the live code — it's an isolated copy

8. COMPILATION
   └── cargo build in source_mirror/
   └── If fails → revert working tree, abort

9. TEST EXECUTION
   └── Run test suite against compiled binary
   └── If fails → revert working tree, abort

10. SHADOW RUNTIME EVALUATION
    └── Fork system state into shadow
    └── Run shadow with modified code for N episodes
    └── Compute CognitiveBenchmark
    └── Compare to current system benchmark
    └── Must DOMINATE on all metrics to proceed

11. MERGE GOVERNANCE
    └── MergeGovernor checks: benchmark dominance, stability window, trust score, inflammation level
    └── If deferred → retry later
    └── If rejected → abort, record failure

12. COMMIT
    └── git commit in source_mirror/ with structured message
    └── Message includes: goal, trigger, files changed, test results

13. HOT-RELOAD
    └── Compile final binary
    └── Supervisor restarts kernel with new binary
    └── Journal replay restores state to pre-restart point

14. HEALTH MONITORING (60 seconds)
    └── Monitor tick health, prediction accuracy, error rates
    └── If ANY metric degrades significantly:
        └── Revert commit (git revert)
        └── Recompile original
        └── Hot-reload original
        └── Record rollback in telemetry

15. SUCCESS RECORDING
    └── Update MutationBudget (increment success count)
    └── Record in telemetry with full audit trail
    └── Update homunculus self-modification success rate
    └── Adapt budget (if track record is good, increase limits)
```

---

## Safety Gate Pattern Matching

### Immutable Markers

These patterns in source code CANNOT be removed or weakened by self-modification:

```
IMMUTABLE_PATTERNS = [
    "SafetyGate",              // The safety system itself
    "rollback",                // Rollback capability
    "telemetry::record",       // Logging/audit trail
    "auth::encrypt",           // Encryption
    "sandbox::",               // Sandboxing
    "ConstitutionalKernel",    // Constitutional enforcement
    "CognitiveImmuneSystem",   // Immune system
    "MergeGovernor",           // Merge governance
    "MutationBudget",          // Mutation limits
    "CognitiveVersionControl", // Version control
    "Supervisor",              // External supervisor
    "ApprovalGate",            // User approval system
]
```

### Pattern Matching Algorithm

```
fn validate_patch(patch: &CodePatch) -> Result<()> {
    for hunk in &patch.hunks {
        for pattern in IMMUTABLE_PATTERNS {
            // Check removals
            if hunk.removed_lines.iter().any(|line| line.contains(pattern)) {
                return Err(SafetyViolation::ImmutableMarkerRemoved(pattern));
            }

            // Check weakening (more subtle)
            // e.g., changing `if !safety_check() { return Err(...) }` to `// if !safety_check()`
            if hunk.context_contains(pattern) && hunk.reduces_control_flow() {
                return Err(SafetyViolation::ImmutableMarkerWeakened(pattern));
            }
        }
    }
    Ok(())
}
```

### Critical Path Detection

Changes to these modules require human approval (not just automated validation):

```
CRITICAL_PATTERNS = [
    "CognitiveKernel::run",    // Main loop
    "Homunculus",              // Self-model
    "GoalMarket",             // Goal resolution
    "AffectiveEconomy",       // Resource allocation
    "PredictiveStack",        // Core prediction
    "MemoryPalace::activate", // Memory competition
]

fn check_critical_path(patch: &CodePatch) -> Result<()> {
    for pattern in CRITICAL_PATTERNS {
        if patch.touches(pattern) {
            if !patch.has_human_approval() {
                return Err(SafetyViolation::CriticalPathNeedsApproval(pattern));
            }
        }
    }
    Ok(())
}
```

### Complexity Gate

Patches that significantly increase code complexity are rejected:

```
fn check_complexity(patch: &CodePatch) -> Result<()> {
    let before_complexity = compute_cyclomatic_complexity(&patch.original_source);
    let after_complexity = compute_cyclomatic_complexity(&patch.modified_source);

    let increase = (after_complexity - before_complexity) as f64 / before_complexity as f64;

    if increase > 0.2 {  // More than 20% complexity increase
        return Err(SafetyViolation::ComplexityIncreaseTooHigh(increase));
    }
    Ok(())
}
```

---

## Constitutional Kernel Enforcement

### What Is Constitutionally Protected

The constitutional kernel is a set of modules that are:
1. Cryptographically signed at build time
2. Verified on every boot by the supervisor
3. Outside the source_mirror/ filesystem (cannot be accessed by the cognitive kernel)
4. Enforced by OS-level file permissions

Protected modules:
- `SafetyGate` — validates patches
- `CognitiveVersionControl` — tracks lineage
- `Supervisor` — monitors the kernel
- `ConstitutionalKernel` — this module itself
- `CognitiveImmuneSystem` — detects pathologies
- `MergeGovernor` — approves merges
- `MutationBudget` — limits modification rate

### Signature Verification

```
fn verify_constitutional_integrity() -> Result<()> {
    for module in CONSTITUTIONAL_MODULES {
        let content = fs::read(&module.path)?;
        let actual_hash = blake3::hash(&content);

        // Hash must match build-time hash
        if actual_hash.as_bytes() != &module.expected_hash {
            return Err(ConstitutionalViolation::TamperedModule(module.path));
        }

        // Signature must verify against build-time public key
        let valid = ed25519_verify(
            &module.signature,
            actual_hash.as_bytes(),
            BUILD_PUBLIC_KEY
        );
        if !valid {
            return Err(ConstitutionalViolation::InvalidSignature(module.path));
        }
    }
    Ok(())
}
```

### Why This Works

The cognitive kernel runs as a child process of the supervisor. The supervisor:
- Owns the constitutional module files (kernel has read-only access)
- Verifies signatures on boot and periodically (every 60s)
- Can kill and restart the kernel if tampering is detected
- Cannot be killed by the kernel (separate process, higher privilege)

This creates an unforgeable safety boundary: the system can evolve everything about its cognition, strategies, and behavior — but it cannot weaken the mechanisms that bound that evolution.

---

## Shadow Runtime Evaluation

### Shadow Runtime Architecture

A shadow runtime is a complete copy of the cognitive system running modified code against replayed episodes:

```
struct ShadowRuntime {
    modified_binary: PathBuf,       // Compiled from patched source
    forked_state: SystemState,      // Deep copy of current state
    replay_episodes: Vec<Episode>,  // Recent episodes to replay
    metrics: CognitiveBenchmark,    // Accumulated metrics
    duration: Duration,             // How long to evaluate
}

impl ShadowRuntime {
    fn evaluate(&mut self) -> CognitiveBenchmark {
        // Run the modified system against replayed episodes
        for episode in &self.replay_episodes {
            let outcome = self.replay(episode);
            self.metrics.accumulate(&outcome);
        }
        self.metrics.normalize(self.replay_episodes.len());
        self.metrics.clone()
    }
}
```

### Episode Selection for Evaluation

Not all episodes are equally informative for evaluation:

```
fn select_evaluation_episodes(buffer: &EpisodicBuffer, count: usize) -> Vec<Episode> {
    let mut selected = vec![];

    // 1. Include recent episodes (test current behavior)
    selected.extend(buffer.most_recent(count / 3));

    // 2. Include high-surprise episodes (test edge cases)
    selected.extend(buffer.highest_surprise(count / 3));

    // 3. Include diverse episodes (test breadth)
    selected.extend(buffer.most_diverse(count / 3));

    selected.truncate(count);
    selected
}
```

### Dominance Requirement

A variant must be better on ALL metrics (with tolerance) to merge:

```
fn dominates(variant: &CognitiveBenchmark, current: &CognitiveBenchmark) -> bool {
    variant.coherence_score >= current.coherence_score
    && variant.planning_quality >= current.planning_quality
    && variant.hallucination_rate <= current.hallucination_rate
    && variant.task_success_rate >= current.task_success_rate
    && variant.resource_efficiency >= current.resource_efficiency * 0.9  // 10% tolerance
    && variant.prediction_accuracy >= current.prediction_accuracy
    && variant.latency_p95_ms <= current.latency_p95_ms * 1.2  // 20% tolerance
}
```

This is deliberately conservative: a modification that improves one metric but degrades another is rejected. The system can only get better, never trade off.

---

## Mutation Budget Adaptation

### Budget Parameters

```
struct MutationBudget {
    max_per_24h: u32,              // Starts at 5
    min_stability_window: Duration, // Starts at 30 minutes
    rollback_cooldown: Duration,    // Starts at 2 hours
    modifications_last_24h: u32,
    rollbacks_last_24h: u32,
    last_modification: Instant,
}
```

### Adaptive Budget Algorithm

```
fn adapt_budget(&mut self) {
    let success_rate = 1.0 - (self.rollbacks_last_24h as f64 / self.modifications_last_24h.max(1) as f64);

    if success_rate > 0.9 && self.modifications_last_24h > 3 {
        // Earning trust: expand budget
        self.max_per_24h = (self.max_per_24h + 1).min(20);
        self.min_stability_window *= 0.8;  // Reduce by 20%
        self.rollback_cooldown *= 0.8;
    } else if success_rate < 0.5 {
        // Losing trust: contract budget
        self.max_per_24h = (self.max_per_24h / 2).max(1);
        self.min_stability_window *= 2.0;  // Double
        self.rollback_cooldown *= 2.0;
    }
    // If 0.5 <= success_rate <= 0.9: no change (stable)
}
```

### Budget State Machine

```
Normal → (3 consecutive successes) → Expanded
Normal → (2 consecutive rollbacks) → Restricted
Expanded → (1 rollback) → Normal
Restricted → (5 consecutive successes) → Normal
Restricted → (1 more rollback) → Frozen (no modifications for 24h)
Frozen → (24h elapsed) → Restricted
```

---

## Behavioral Verification Benchmarks

### Benchmark Suite

The cognitive benchmark measures behavioral quality, not just compilation:

| Metric | How Measured | Failure Threshold |
|--------|-------------|-------------------|
| Coherence | Internal model consistency check | < 0.7 |
| Planning quality | Sub-goal completion rate on replayed tasks | < 0.6 |
| Hallucination rate | False tool calls, invented facts per episode | > 0.1 |
| Task success rate | End-to-end goal completion | < 0.7 |
| Resource efficiency | Tokens per successful task | > 2x current |
| Memory retrieval precision | Correct memory activation rate | < 0.6 |
| Prediction accuracy | Homunculus accuracy post-modification | < 0.5 |
| Latency P95 | 95th percentile tick duration | > 1.5x current |

### Benchmark Execution

```
fn run_benchmark(state: &SystemState, episodes: &[Episode]) -> CognitiveBenchmark {
    let mut results = CognitiveBenchmark::default();

    for episode in episodes {
        let outcome = state.replay(episode);

        results.task_success_rate += outcome.succeeded as u32 as f64;
        results.hallucination_rate += outcome.hallucinations as f64;
        results.latency_p95_ms = results.latency_p95_ms.max(outcome.duration_ms);
        results.resource_efficiency += outcome.tokens_used as f64;

        // Coherence: check for internal contradictions after replay
        results.coherence_score += state.check_coherence() as f64;

        // Prediction accuracy: how well did the system predict its own behavior?
        results.prediction_accuracy += state.homunculus.recent_accuracy();
    }

    results.normalize(episodes.len());
    results
}
```

---

## Git2 Integration Details

### Repository Structure

The source mirror is a full git repository:

```
~/.kc/state/source_mirror/
├── .git/                    # Full git history
├── src/                     # Modifiable source code
├── Cargo.toml
└── .kc-meta.json            # Metadata about modifications
```

### Commit Message Format

```
self-mod: <short summary>

Goal: <goal description that triggered this modification>
Trigger: <trigger type (performance, novelty, efficiency, capability)>
Files: <list of modified files>
Tests: passed
Benchmark: coherence=0.85, planning=0.78, hallucination=0.02, success=0.82
Shadow-duration: 45s
Episodes-evaluated: 30
```

### Branch Strategy

```
main              ← current live code
├── variant/001   ← shadow runtime evaluation branch
├── variant/002   ← another candidate
└── reverted/003  ← reverted modification (kept for history)
```

### Key git2 Operations

| Operation | When | git2 API |
|-----------|------|----------|
| Initial commit | First boot | `Repository::init()` + `commit_all()` |
| Create variant branch | Before shadow evaluation | `repo.branch()` |
| Apply patch | During modification | Write files + `repo.index().add_path()` |
| Commit modification | After successful evaluation | `repo.commit()` |
| Merge variant | After governance approval | `repo.merge()` or fast-forward |
| Revert | After health check failure | `repo.revert()` |
| Factory reset | Emergency recovery | `repo.reset(factory_commit, Hard)` |
| History query | Telemetry dashboard | `repo.revwalk()` |
| Diff | UI visualization | `repo.diff_tree_to_tree()` |

---

## Open Questions / Design Decisions

1. **Hot-reload mechanism**: How to swap a running binary? Options: (a) restart the kernel process with new binary (supervisor handles seamlessly), (b) use a plugin architecture with versioned function tables, (c) dlopen/dlclose for specific modules. Current plan: (a) — restart is safest, and the supervisor handles it cleanly with state preservation via journal replay.

2. **Patch generation quality**: LLM-generated patches may be syntactically valid but semantically wrong. The benchmark catches behavioral regressions, but subtle bugs might slip through. Should there be a formal verification step? Probably too expensive for v1.

3. **Self-modification scope**: What can the system modify? Currently: anything in source_mirror/ except constitutional modules. Should there be additional restrictions? (e.g., "don't modify the tick loop structure, only parameters")

4. **Human approval UX**: For critical path changes, how does the user approve? Current plan: notification in UI with diff view, approve/reject buttons. But what if the user doesn't understand the change?

5. **Modification rollback depth**: Currently reverts one commit. What if a modification passes the 60s health check but causes problems hours later? Should there be longer-term monitoring? Current plan: the immune system handles this — if pathologies emerge later, it can trigger investigation.

6. **Cross-modification interactions**: Modification A passes alone, modification B passes alone, but A+B together cause issues. How to detect? Current plan: shadow runtime always evaluates against the current live code (which includes all previous modifications). But rapid sequential modifications could still interact.

---

## Research References

- **Schmidhuber, J. (2003)**. "Gödel Machines: Self-Referential Universal Problem Solvers" — Formal self-modification
- **Nivel et al. (2013)**. "Bounded Recursive Self-Improvement" — Safety bounds on self-modification
- **Omohundro, S. (2008)**. "The Basic AI Drives" — Why self-improvement is a convergent goal
- **Soares & Fallenstein (2017)**. "Agent Foundations for Aligning Machine Intelligence" — Alignment under self-modification
- **Everitt et al. (2018)**. "AGI Safety Literature Review" — Comprehensive safety survey
- **Relevant crates**: `git2` (libgit2 bindings), `cargo` (build system), `syn` + `quote` (Rust AST manipulation), `similar` (diff computation)

---

## Edge Cases and Failure Modes

1. **Compilation environment drift**: The source_mirror uses specific Rust/crate versions. If the system's Rust toolchain updates, old code might not compile. Mitigation: pin Rust version in source_mirror, use rustup override.

2. **Shadow runtime resource exhaustion**: Running a full shadow evaluation is expensive (CPU, memory, time). Mitigation: shadow runs at reduced tick rate (1Hz), limited episode count, timeout after 60s.

3. **Patch generation hallucination**: LLM generates code that references non-existent crates or APIs. Mitigation: compilation step catches this. But wasted budget. Solution: include Cargo.toml in LLM context.

4. **Rollback cascade**: Modification A is applied, then B is applied. B fails health check and is reverted. But A depended on B's changes. Mitigation: each modification must be independently valid. The benchmark evaluates the full system, not just the new change.

5. **Constitutional bypass attempt**: The system generates a patch that doesn't directly modify constitutional modules but creates a wrapper that circumvents them. Mitigation: behavioral benchmarks catch this (safety metrics would degrade). Also: constitutional modules are outside the filesystem scope entirely.

6. **Infinite modification loop**: System detects performance issue → modifies → new issue → modifies → ... Mitigation: MutationBudget limits daily modifications. Rollback cooldown prevents rapid retry.

---

## Interaction with Other Subsystems

- **Homunculus**: L4 (self-modification capability) is the trigger. L3 (self-evaluation) identifies what to modify. L5 (meta-learning) learns which modifications succeed.
- **Goal Market**: Self-modification is a goal type. It competes in the market like any other goal. The affect-driven risk tolerance gates whether self-modification goals can even be generated.
- **Cognitive Homeostasis**: The immune system monitors post-modification health. If pathologies emerge, it can trigger investigation or emergency rollback.
- **LLM Pool**: Patch generation requires LLM queries. The MCC gates this — self-modification LLM queries are expensive and budgeted separately.
- **Telemetry**: Full audit trail of every modification attempt (success or failure), including diffs, benchmarks, and health monitoring results.
- **Agent Society**: The MetaAgent often identifies modification opportunities. The SafetyAgent can veto modifications that touch sensitive areas.
- **Affective Economy**: Self-modification risk tolerance is computed from affect (reward_expectation × (1 - uncertainty)). High uncertainty = no self-modification.
- **TUI**: Self-modification proposals surface as approval dialogs with full diff view. In Paranoia mode, shadow runtime evaluation progress is visible. The command palette provides access to modification history.
- **Project Context**: Self-modifications are tracked in `~/.kc/state/source_mirror/` with full git history. The structured journal records each modification attempt (success or failure) as a Decision entry.
