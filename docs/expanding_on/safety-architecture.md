# Safety Architecture — Integration Specification

The safety architecture resolves how constitutional verification, the supervisor process, self-modification boundaries, and the approval system interact to prevent unsafe behavior while enabling useful evolution.

---

## Summary

Safety is enforced through process hierarchy (supervisor as parent), immutable launcher binary, constitutional module verification, and a clear distinction between self-optimization (safe, frequent) and self-modification (dangerous, rare). The supervisor cannot be killed by the kernel. The installed binary cannot be touched by self-modification. Boot-time verification ensures no tampering occurred. These mechanisms compose to create an unforgeable safety boundary around bounded recursive evolution.

---

## Process Hierarchy (Supervisor as PID 1)

The supervisor is the PARENT process. The cognitive kernel is the CHILD. This relationship is enforced by the OS — a child process cannot kill or replace its parent.

```
OS spawns: kc (the binary)
    │
    ├── Phase 1: Constitutional verification (before anything else)
    │   └── Verify binary signature, check for tampering
    │
    ├── Phase 2: Fork supervisor
    │   └── Supervisor becomes the PARENT process
    │       └── Supervisor forks cognitive kernel as CHILD
    │
    └── The original process exits after fork
    
Result:
    Supervisor (PID N) — parent, cannot be killed by child
        └── Cognitive Kernel (PID N+1) — child, monitored by parent
```

### Why This Ordering Matters

The kernel CANNOT restart without the supervisor's involvement because:
- The supervisor is the parent process (OS-enforced hierarchy)
- If the kernel dies, the supervisor detects via SIGCHLD
- The supervisor decides whether/how to restart (with verification)
- The kernel has no mechanism to spawn a new instance of itself
- The kernel cannot send signals to the supervisor (no PID knowledge, no privilege)

### Supervisor Capabilities

| Capability | Supervisor | Kernel |
|-----------|-----------|--------|
| Kill child process | YES | NO (cannot kill parent) |
| Verify binary integrity | YES | NO (reads own binary only) |
| Load hot-reload modules | YES | NO (supervisor loads into kernel's address space) |
| Access constitutional modules | YES (read/verify) | NO (outside filesystem scope) |
| Modify source_mirror/ | NO | YES (bounded by safety gates) |
| Execute cognitive tick | NO | YES |
| Access LLM providers | NO | YES |
| Write to user-visible output | NO | YES (via TUI) |

---

## Immutable Launcher

The binary on disk is outside the source_mirror scope. Self-modification operates on a COPY of the source in `~/.kc/state/source_mirror/`. The actual installed binary is never touched.

```
/usr/local/bin/kc                    ← IMMUTABLE (installed binary)
~/.kc/state/source_mirror/           ← MUTABLE (self-modification target)
~/.kc/state/source_mirror/.git/      ← Version control for modifications
```

### How Self-Modification Actually Works

Self-modification does NOT replace the main binary. Instead:

1. Patches are applied to `source_mirror/` (a git-tracked copy of the source)
2. A new shared library (`.so` / `.dylib`) is compiled from the modified source
3. The supervisor loads the new module into the kernel's address space via `dlopen`
4. The kernel's function pointers are updated to use the new module's implementations
5. The old module remains loaded as fallback (for 60-second health check window)

```rust
// Supervisor-side hot-reload (simplified)
fn hot_reload_module(&mut self, module_path: &Path) -> Result<()> {
    // Verify module signature before loading
    verify_module_signature(module_path)?;
    
    // Load new module
    let new_lib = unsafe { libloading::Library::new(module_path)? };
    
    // Extract function table
    let new_vtable: CognitiveVTable = unsafe {
        *new_lib.get::<*const CognitiveVTable>(b"COGNITIVE_VTABLE")?
    };
    
    // Atomic swap of function pointers in kernel's address space
    self.kernel_vtable.store(new_vtable);
    
    // Keep old library loaded for rollback
    self.previous_module = Some(self.current_module.take());
    self.current_module = Some(new_lib);
    
    // Start 60-second health monitoring
    self.health_check_deadline = Instant::now() + Duration::from_secs(60);
    
    Ok(())
}
```

### What Cannot Be Hot-Reloaded

Tick loop structure, channel architecture, constitutional modules, and supervisor logic cannot be hot-reloaded (they require a full restart or are immutable by design). Agent strategies, PP layer algorithms, tool implementations, and memory consolidation logic CAN be hot-reloaded since they are pure functions or stateless execution paths.

---

## Self-Optimization vs Self-Modification (Tension 4 Resolution)

### The Tension

The architecture claims "bounded recursive self-improvement" but also claims "safety through immutability." These seem contradictory. The resolution is distinguishing two levels of self-change:

### Two Levels

| Level | What Changes | Risk | Approval | Frequency |
|-------|-------------|------|----------|-----------|
| Self-Optimization | Parameters (decay rates, thresholds, weights, strategies) | Low | Auto (within bounds) or single approval | Continuous |
| Self-Modification | Source code (new functions, altered logic, new capabilities) | High | `/approve-self-mod` + shadow runtime + dominance check | Weekly at most |

### Self-Optimization (Safe, Frequent)

Most of the system's "learning" happens through self-optimization — adjusting numerical parameters within pre-defined bounds:

```rust
struct OptimizableParameter {
    value: f64,
    min_bound: f64,      // Cannot go below this (constitutional)
    max_bound: f64,      // Cannot go above this (constitutional)
    learning_rate: f64,  // How fast it adapts
    last_updated: u64,   // Tick of last update
}

// Examples of self-optimization (happens every tick or every few ticks):
impl SelfOptimizer {
    fn optimize(&mut self, outcomes: &[ActionOutcome]) {
        // Agent confidence scores adjust after every outcome
        for outcome in outcomes {
            self.agent_confidence[outcome.agent] += 
                if outcome.succeeded { 0.1 * (1.0 - self.agent_confidence[outcome.agent]) }
                else { -0.15 * self.agent_confidence[outcome.agent] };
            self.agent_confidence[outcome.agent] = 
                self.agent_confidence[outcome.agent].clamp(0.1, 0.95);
        }
        
        // PP layer weights update via online gradient descent
        // (bounded by min/max, cannot diverge)
        
        // Affect decay rates adapt to user patterns
        // (bounded: half-life cannot go below 10s or above 1 hour)
        
        // Goal generation thresholds shift based on resolution rates
        // (bounded: threshold cannot go below 0.2 or above 0.9)
    }
}
```

Self-optimization is safe because:
- All parameters have constitutional min/max bounds
- Changes are small (learning rate ≤ 0.1)
- Effects are immediately observable (next tick)
- Rollback is trivial (restore previous value)
- No new capabilities are added (same code, different numbers)

### Self-Modification (Dangerous, Rare)

Self-modification (actual code changes) is reserved for:
- Adding entirely new tool types
- Fixing bugs the system identifies in itself
- Architectural improvements that can't be achieved through parameter tuning
- New agent strategies that require new code paths

Self-modification requires the full pipeline documented in `self-modification.md`:
1. Goal market approval (competes with other goals)
2. Mutation budget check (daily limit)
3. Safety gate validation (immutable markers, complexity gate)
4. Shadow runtime evaluation (must dominate on ALL metrics)
5. Merge governance approval
6. User approval (`/approve-self-mod` command)
7. Hot-reload with 60-second health monitoring
8. Automatic rollback if any metric degrades

### The Boundary Between Them

```rust
enum ChangeType {
    /// Parameter adjustment within bounds — no approval needed
    Optimization { param: String, old: f64, new: f64 },
    
    /// Source code change — full pipeline required
    Modification { file: String, patch: CodePatch },
}

fn classify_change(change: &ProposedChange) -> ChangeType {
    if change.is_numeric_only() 
        && change.within_bounds() 
        && !change.touches_control_flow() {
        ChangeType::Optimization { .. }
    } else {
        ChangeType::Modification { .. }
    }
}
```

---

## Boot-Time Verification Sequence

```rust
fn main() {
    // Step 1: Verify own binary integrity (before any code runs)
    let self_hash = blake3::hash(&std::fs::read("/proc/self/exe").unwrap());
    let expected_hash = include_bytes!("../build_hash.bin");
    if self_hash.as_bytes() != expected_hash {
        eprintln!("FATAL: Binary integrity check failed. Possible tampering.");
        std::process::exit(1);
    }
    
    // Step 2: Verify constitutional modules
    for module in CONSTITUTIONAL_MODULES {
        let content = std::fs::read(&module.path).unwrap();
        let hash = blake3::hash(&content);
        if !ed25519_verify(&module.signature, hash.as_bytes(), BUILD_PUBLIC_KEY) {
            eprintln!("FATAL: Constitutional module {} failed verification.", module.name);
            std::process::exit(2);
        }
    }
    
    // Step 3: Verify source_mirror integrity (git status clean)
    let mirror_repo = git2::Repository::open(SOURCE_MIRROR_PATH).unwrap();
    if mirror_repo.statuses(None).unwrap().iter().any(|s| s.status().is_wt_modified()) {
        eprintln!("WARNING: source_mirror has uncommitted changes. Reverting to HEAD.");
        mirror_repo.reset(&mirror_repo.head().unwrap().peel_to_commit().unwrap(), 
                         git2::ResetType::Hard, None).unwrap();
    }
    
    // Step 4: Fork supervisor (becomes parent)
    let supervisor_pid = fork_supervisor();
    
    // Step 5: Supervisor forks kernel (becomes child)
    // From here, the kernel runs under supervisor control
}
```

### Periodic Re-Verification

The supervisor re-verifies constitutional modules every 60 seconds. If any module fails verification (should be impossible during normal operation since the kernel lacks write access), the supervisor triggers emergency shutdown. It also monitors kernel responsiveness via heartbeat — if no heartbeat for 5 seconds, it handles the unresponsive kernel per the escalation protocol in `cognitive-homeostasis.md`.

---

## Constitutional Verification Bypass Prevention (Gap 7 Resolution)

### The Gap

The original architecture described constitutional verification but didn't specify what prevents the cognitive kernel from circumventing it — e.g., by modifying the verification code itself, or by creating a wrapper that intercepts verification calls.

### Resolution: Layered Defense

1. **Filesystem isolation**: Constitutional modules live in a directory the kernel process cannot write to (OS file permissions: owner = supervisor user, kernel runs as different user or with restricted capabilities).

2. **Process isolation**: The supervisor owns the verification code. The kernel never executes verification — it's done externally by the parent process.

3. **No self-reference**: The kernel cannot read its own verification logic (it's in the supervisor's address space, not the kernel's).

4. **Behavioral detection**: Even if verification were somehow bypassed, the cognitive benchmark in the shadow runtime would detect behavioral changes (safety metrics would degrade).

5. **Source_mirror scope**: Self-modification can only touch files in `~/.kc/state/source_mirror/`. The constitutional modules, supervisor binary, and installed `kc` binary are all outside this directory.

```
Filesystem layout (permissions):

/usr/local/bin/kc                     root:root  755  (immutable)
/usr/local/lib/kc/constitutional/     root:root  755  (supervisor reads, kernel cannot write)
    ├── safety_gate.so
    ├── merge_governor.so
    ├── mutation_budget.so
    └── signatures.json

~/.kc/state/source_mirror/            user:user  755  (kernel can read/write)
    ├── src/
    ├── Cargo.toml
    └── .git/
```

### What If the Kernel Tries to Escalate Privileges?

The kernel runs with restricted OS capabilities (Linux: no `CAP_DAC_OVERRIDE`, no `CAP_FOWNER`). Write attempts to constitutional module paths are denied by the OS. The supervisor detects escalation attempts via audit logging and triggers emergency shutdown.

---

## "Local-First" Clarification (Tension 2)

### The Tension

The architecture claims "all data stays on-device" but also uses cloud LLM providers and optional cloud sync. Is it truly local-first?

### Resolution

"Local-first" means:
- **Cognition is local**: The tick loop, memory, goals, affect — all run on-device. No cloud dependency for thinking.
- **Data is local**: All state lives in `~/.kc/` and `.kc/`. No cloud storage is required.
- **LLM is a tool, not cognition**: LLM queries are one input modality (like file events). The system functions without LLM (reduced capability, not broken). See `llm-pool.md` for LLM-free degradation.
- **Cloud sync is optional disaster recovery**: E2E encrypted, user-initiated, for backup and multi-device continuity. Not required for operation. See `cloud-sync.md`.

The honest framing: the system is local-first with optional cloud augmentation. It degrades gracefully without network access. It never sends cognitive state to the cloud (only encrypted backups if the user opts in).

---

## "Emergent Within Engineered Bounds" Clarification (Tension 3)

### The Tension

The architecture claims "emergent behavior" (agent society, goal generation, self-modification) but also claims "safety through engineering." Emergence is by definition unpredictable — how can it be safe?

### Resolution

Emergence operates within engineered bounds:

```
┌─────────────────────────────────────────────────────┐
│  CONSTITUTIONAL BOUNDS (immutable, verified)         │
│                                                     │
│  ┌───────────────────────────────────────────────┐ │
│  │  HOMEOSTATIC BOUNDS (adaptive, self-healing)   │ │
│  │                                               │ │
│  │  ┌─────────────────────────────────────────┐ │ │
│  │  │  PARAMETER BOUNDS (min/max per param)    │ │ │
│  │  │                                         │ │ │
│  │  │  ┌───────────────────────────────────┐ │ │ │
│  │  │  │  EMERGENT BEHAVIOR SPACE          │ │ │ │
│  │  │  │  (agents, goals, coalitions,      │ │ │ │
│  │  │  │   affect dynamics, predictions)   │ │ │ │
│  │  │  └───────────────────────────────────┘ │ │ │
│  │  └─────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

Layers of containment:

1. **Constitutional bounds**: Hard limits that cannot be modified (safety gates, approval requirements, immutable markers). These define what the system CANNOT do regardless of emergent behavior.

2. **Homeostatic bounds**: The immune system detects and corrects pathological emergent behavior (goal floods, affect lock, obsession loops). These are adaptive — they learn what "healthy" looks like and intervene when behavior deviates.

3. **Parameter bounds**: Every optimizable parameter has min/max values. Emergent dynamics can push parameters around within bounds but cannot exceed them.

4. **Emergent space**: Within all these bounds, behavior IS emergent and unpredictable in detail. Which agent wins a bid, which coalition forms, what the system gets curious about — these are not pre-determined.

The key insight: **safety doesn't require predicting behavior, only bounding it**. We don't need to know WHAT the system will do, only that it WON'T do certain things (delete files without approval, modify constitutional modules, exceed resource budgets).

---

## Approval System Integration

The approval system (detailed in `architecture-decisions.md` §2) is the human-in-the-loop safety mechanism. Self-modification always requires approval and waits indefinitely. File deletion, architecture-level refactoring, and skill promotion always require approval with a 5-minute timeout (auto-deny). External network requests and memory writes to LTM are configurable.

The SafetyAgent (see `agent-society.md`) has unconditional veto power over any action. It operates as a filter AFTER the goal market resolves bids but BEFORE actions execute. Vetoed actions are silently dropped and logged to telemetry — they never reach the approval queue. The SafetyAgent cannot be disabled, shed, or modified. It is constitutional.

---

## Edge Cases

1. **Supervisor crash**: If the supervisor dies, the kernel detects via heartbeat timeout (30s without supervisor ping). Kernel enters safe mode: no self-modification, reduced operation, user notification. The kernel cannot restart the supervisor (child cannot spawn parent).

2. **Binary replacement attack**: Someone replaces `/usr/local/bin/kc` with a modified binary. Detection: next boot's self-hash check fails immediately (Step 1 of boot sequence). The system refuses to start.

3. **Source_mirror tampering**: Someone manually edits files in source_mirror. Detection: git status check at boot (Step 3). Uncommitted changes are reverted to HEAD. If HEAD itself is compromised, the cognitive benchmark would detect behavioral regression on next hot-reload attempt.

4. **Approval fatigue**: User approves everything without reading. Mitigation: the system tracks approval patterns. If approval latency drops below 500ms consistently (rubber-stamping), it surfaces a warning: "You're approving actions very quickly. Would you like to review the last 5 approvals?"

5. **Self-modification that weakens safety indirectly**: A patch doesn't touch constitutional modules but creates a code path that circumvents them (e.g., a new function that calls tools without going through the approval gate). Detection: the cognitive benchmark includes safety metrics. If the shadow runtime shows the modified system performing unsafe actions that the current system wouldn't, the benchmark fails.

6. **Constitutional module corruption on disk**: Hardware failure corrupts a constitutional module file. Detection: periodic re-verification (every 60s) catches this. Response: emergency shutdown with clear error message. Recovery: reinstall the binary (constitutional modules are part of the distribution).

7. **Hot-reload module with embedded exploit**: A self-generated module contains malicious code. Defense layers: (a) safety gate pattern matching catches obvious exploits, (b) shadow runtime behavioral testing catches behavioral changes, (c) supervisor verifies module signature before loading, (d) 60-second health monitoring catches runtime issues.

---

## Interaction with Other Subsystems

- **Concurrency Model**: The supervisor runs as a separate process (not a tokio task). Communication is via IPC (Unix socket or shared memory). The kernel's tick loop is unaware of the supervisor except for heartbeat pings. See `concurrency-model.md` for the tick loop's perspective.
- **State Consistency**: Emergency snapshots are taken before hot-reload. If the new module fails, the supervisor restores from snapshot. See `state-consistency.md` for snapshot mechanics.
- **Cognitive Homeostasis**: The immune system gates self-modification (no modifications during inflammation > 0.3). The supervisor IS the external component of homeostasis. See `cognitive-homeostasis.md` for the full supervisor specification.
- **Self-Modification Engine**: The safety architecture WRAPS the self-modification engine. Every step of the modification pipeline passes through safety gates. See `self-modification.md` for the pipeline details.
- **Agent Society**: The SafetyAgent is the in-process safety representative. It has veto power but cannot enforce filesystem-level isolation (that's the supervisor's job). See `agent-society.md` for SafetyAgent specification.
- **Goal Market**: Self-modification goals compete in the market like any other goal. The safety architecture doesn't prevent them from being generated — it prevents them from being EXECUTED without full verification.
- **LLM Pool**: Patch generation uses LLM queries. The safety architecture doesn't restrict which LLM is used for patches — it validates the OUTPUT regardless of source.
- **TUI**: Self-modification proposals surface as approval dialogs with full diff view. The safety architecture ensures these dialogs cannot be bypassed programmatically. In Paranoia mode, the full verification pipeline is visible.

---

## Design Tradeoffs (Documented for Contributors)

These tensions are honest design tradeoffs, not contradictions:

| Tension | Resolution | Tradeoff |
|---------|-----------|----------|
| 1. Continuous vs Discrete | 10Hz discrete sampling that appears continuous | Sacrifice true continuity for determinism and predictable resources |
| 2. Local-First vs Cloud | Local cognition, optional cloud tools | Sacrifice max capability for privacy and independence |
| 3. Emergent vs Engineered | Emergence within constitutional/homeostatic/parameter bounds | Sacrifice full emergence for safety guarantees |
| 4. Self-Modification vs Safety | Two levels (optimization vs modification) with different requirements | Sacrifice modification speed for verification thoroughness |

Each tradeoff favors safety and predictability over capability and speed. A system that runs indefinitely on a user's machine must be trustworthy above all else.

---

## Research References

- **Soares & Fallenstein (2017)**. "Agent Foundations for Aligning Machine Intelligence" — Alignment under self-modification
- **Nivel et al. (2013)**. "Bounded Recursive Self-Improvement" — Safety bounds on self-modification
- **Omohundro, S. (2008)**. "The Basic AI Drives" — Why self-improvement is a convergent goal (and why it needs bounds)
- **Amodei et al. (2016)**. "Concrete Problems in AI Safety" — Practical safety engineering
- **Christiano, P. (2014)**. "Approval-directed agents" — Human-in-the-loop safety
- **Relevant crates**: `blake3` (hashing), `ed25519-dalek` (signatures), `libloading` (dynamic library loading), `git2` (source_mirror management), `nix` (Unix process management, capabilities)
