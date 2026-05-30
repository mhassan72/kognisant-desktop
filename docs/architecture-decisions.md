# Architecture Decisions — Implementation Specifications

> These decisions resolve ambiguities in the architecture that would cause implementation conflicts.
> Each section answers "how" for a specific system boundary. Pseudocode is Rust-flavored
> and intended to communicate structure, not compile.

Last updated: 2026-05-30

---

## Table of Contents

- [1. TUI ↔ Kernel Communication Protocol](#1-tui--kernel-communication-protocol)
- [2. Approval Dialog State Machine](#2-approval-dialog-state-machine)
- [3. Skill Mining Pipeline — Stage Transitions](#3-skill-mining-pipeline--stage-transitions)
- [4. Journal Schema & Parser Contract](#4-journal-schema--parser-contract)
- [5. Project Initialization & Directory Boundaries](#5-project-initialization--directory-boundaries)
- [6. LLM Pool Routing & Fallback Strategy](#6-llm-pool-routing--fallback-strategy)
- [7. Telemetry & Replay System](#7-telemetry--replay-system)
- [8. Self-Modification Boundaries](#8-self-modification-boundaries)
- [9. Error Handling & Graceful Degradation](#9-error-handling--graceful-degradation)
- [10. Configuration, Deployment & Updates](#10-configuration-deployment--updates)

---

## 1. TUI ↔ Kernel Communication Protocol

The kernel and TUI communicate via bounded mpsc channels within a single process. No serialization, no IPC, no network — shared types via `Arc` across tokio tasks.

---

### Threading Model

- **Main thread**: TUI render loop (ratatui + crossterm). Owns the terminal.
- **Kernel task**: Spawned via `tokio::spawn`. Runs the 10Hz cognitive tick loop.
- **Shared state**: None. All communication is message-passing. No mutexes on the hot path.

### Channel Architecture

```rust
// Tick state: watch channel (always has latest, never blocks kernel)
let (state_tx, state_rx) = tokio::sync::watch::channel(TickSnapshot::default());

// Discrete events: mpsc (approval requests, health events, etc.)
let (event_tx, event_rx) = tokio::sync::mpsc::channel::<KernelEvent>(16);

// User input: mpsc (never dropped)
let (cmd_tx, cmd_rx) = tokio::sync::mpsc::channel::<UserCommand>(32);
```

### Why `watch` for TickSnapshot

The TUI always wants the *latest* tick state, not a queue of stale snapshots. `tokio::sync::watch` provides exactly this: single-producer, multi-consumer, latest-value semantics. The kernel writes every tick; the TUI reads whenever it renders. No backpressure, no dropped messages, no blocking the kernel. Multiple consumers (TUI, telemetry) can each read at their own pace.

### Why `mpsc` for discrete events

Events like `ApprovalRequest`, `HealthEvent`, and `AgentBidEvent` are discrete occurrences that must not be lost. An mpsc channel with capacity 16 provides ordered delivery with backpressure. If the TUI falls behind on processing events, the kernel slows down — which is acceptable because these events are infrequent (not per-tick).

### Why capacity 32 for user input

User input is sacred. A burst of keystrokes (typing a command, rapid approvals) must never be lost. 32 is generous — a human cannot generate more than ~10 commands per second. If the channel somehow fills (kernel is stuck), the TUI blocks on send, which is acceptable because it means the kernel is unresponsive and the user should see that.

### Message Types

```rust
/// Events pushed from kernel to TUI (via mpsc — discrete events only)
#[derive(Clone)]
enum KernelEvent {
    /// Action requires user approval
    ApprovalRequest(ApprovalRequest),

    /// Memory system update (new activation, consolidation progress)
    MemoryUpdate(MemoryEvent),

    /// Agent won a bid, starting execution
    AgentBid(AgentBidEvent),

    /// Goal lifecycle event
    GoalEvent(GoalLifecycleEvent),

    /// LLM query started/completed
    LlmEvent(LlmLifecycleEvent),

    /// System health change (provider down, pathology detected)
    HealthEvent(HealthEvent),

    /// Self-modification proposal
    SelfModEvent(SelfModEvent),
}

/// Snapshot of one tick's output (cheap to clone via Arc internals)
struct TickSnapshot {
    tick_number: u64,
    active_goals: Vec<GoalSummary>,
    agent_states: Vec<AgentSummary>,
    affect_vector: AffectVector,
    prediction_errors: Vec<PredictionError>,
    pending_actions: Vec<ActionSummary>,
    wm_contents: Vec<MemorySummary>,
    system_health: SystemHealth,
    llm_status: LlmPoolStatus,
}

/// Commands sent from TUI to kernel
enum UserCommand {
    /// Raw text input from user
    Input(String),

    /// Approval response
    Approval(ApprovalResponse),

    /// Mode switch (Focus/Trace/Paranoia)
    SetMode(VisibilityMode),

    /// Command palette action
    Command(PaletteCommand),

    /// Shutdown request
    Quit,
}
```

### TUI Main Loop

```rust
async fn tui_main(
    mut state_rx: watch::Receiver<TickSnapshot>,
    mut event_rx: mpsc::Receiver<KernelEvent>,
    cmd_tx: mpsc::Sender<UserCommand>,
    mut terminal: Terminal<CrosstermBackend<Stdout>>,
) {
    // Ring buffer: last 1000 events for Paranoia mode rendering
    let mut event_ring = RingBuffer::<KernelEvent>::new(1000);
    let mut approval_queue: Vec<ApprovalRequest> = vec![];

    loop {
        tokio::select! {
            // Branch 1: tick state updated (watch — always has latest)
            Ok(()) = state_rx.changed() => {
                // No-op here — we read the latest state at render time
                // via state_rx.borrow(). This branch just wakes us up.
            }

            // Branch 2: discrete event from kernel (mpsc — never lost)
            Some(event) = event_rx.recv() => {
                event_ring.push(event.clone());
                match event {
                    KernelEvent::ApprovalRequest(req) => {
                        approval_queue.push(req);
                    }
                    _ => {} // Other events stored in ring buffer
                }
            }

            // Branch 3: user input (polled with 50ms timeout)
            _ = tokio::time::sleep(Duration::from_millis(50)) => {
                if crossterm::event::poll(Duration::ZERO).unwrap_or(false) {
                    if let Ok(event) = crossterm::event::read() {
                        let cmd = translate_input(event, &approval_queue);
                        if let Some(cmd) = cmd {
                            if matches!(cmd, UserCommand::Quit) {
                                break;
                            }
                            cmd_tx.send(cmd).await.ok();
                        }
                    }
                }
            }
        }

        // Render (reads latest tick state via watch — never stale)
        let state = state_rx.borrow().clone();
        terminal.draw(|frame| {
            render_frame(frame, &state, &approval_queue, &event_ring);
        }).ok();
    }
}
```

### Paranoia Mode Ring Buffer

The ring buffer stores the last 1000 events regardless of TUI render speed. In Paranoia mode, the user can scroll through this buffer to inspect recent history. This is purely in-memory — not persisted (telemetry handles persistence separately).

```rust
struct RingBuffer<T> {
    buffer: VecDeque<T>,
    capacity: usize,
}

impl<T> RingBuffer<T> {
    fn push(&mut self, item: T) {
        if self.buffer.len() >= self.capacity {
            self.buffer.pop_front(); // Drop oldest
        }
        self.buffer.push_back(item);
    }

    fn iter_recent(&self, count: usize) -> impl Iterator<Item = &T> {
        self.buffer.iter().rev().take(count)
    }
}
```

### Edge Cases

1. **Kernel panic**: If the kernel task panics, `tui_rx.recv()` returns `None`. TUI detects this, displays "Kernel crashed — recovering..." and waits for supervisor restart.
2. **TUI resize during render**: Crossterm resize events are handled in the input branch. Layout recomputes on next frame.
3. **Channel backpressure on user input**: If kernel_rx is full (32 items), `tui_tx.send()` will await. This means the TUI blocks — which is correct because it signals kernel unresponsiveness.
4. **Multiple TickState events between renders**: Only the latest is used. Intermediate states are still in the ring buffer for Paranoia mode inspection.

### State Access Strategy

- The kernel uses `tokio::sync::watch` for the TickSnapshot (single-producer, multi-consumer, always has latest value). Consumers (TUI, telemetry) call `watch::Receiver::borrow()` to read the most recent snapshot without blocking the kernel. The watch channel never blocks the producer — if no consumer has read the previous value, it is simply overwritten.
- Discrete events (ApprovalRequest, HealthEvent, AgentBidEvent, etc.) use `tokio::sync::mpsc` with capacity 16. These are events that must not be lost and must be processed in order.
- User commands use `tokio::sync::mpsc` with capacity 32 (user input is never dropped).
- No `Mutex` or `RwLock` on the hot path (tick loop). The tick loop owns all mutable state and never contends with readers.
- Each tick phase operates on owned data, not shared references. Phase outputs are passed by value to the next phase.
- The only shared state is the `watch::Sender<TickSnapshot>` held by the kernel task. All other state is task-local.
- If a phase needs to read another phase's output, it receives it via function parameter (data flows through the tick, not via shared state). Example: the Deliberation phase receives `surprises` computed by the Comparison phase as a function argument, not by reading a shared field.

### Tick Scheduling

Not all subsystems need to run every tick. To stay within the 100ms budget at 10Hz, subsystems are scheduled at different frequencies:

```rust
struct TickSchedule {
    // Runs EVERY tick (10Hz)
    perception: Always,
    prediction_l0_l1: Always,
    affect_dynamics: Always,
    approval_processing: Always,
    tui_render: Always,

    // Runs every 2 ticks (5Hz)
    prediction_l2: EveryN(2),
    memory_activation: EveryN(2),
    goal_market: EveryN(2),

    // Runs every 5 ticks (2Hz)
    prediction_l3_l4: EveryN(5),
    agent_bidding: EveryN(5),
    world_update: EveryN(5),

    // Runs every 10 ticks (1Hz)
    homunculus: EveryN(10),
    immune_system: EveryN(10),
    telemetry_flush: EveryN(10),

    // Runs every 100 ticks (0.1Hz)
    skill_mining_check: EveryN(100),
    health_metrics: EveryN(100),

    // Runs on trigger only
    consolidation: OnTrigger, // idle > 60s AND buffer > threshold
    self_modification: OnTrigger, // goal + budget + approval
}

enum SchedulePolicy {
    Always,
    EveryN(u32),
    OnTrigger,
}

impl TickSchedule {
    fn should_run(&self, subsystem: Subsystem, tick: u64) -> bool {
        match self.policy(subsystem) {
            Always => true,
            EveryN(n) => tick % n as u64 == 0,
            OnTrigger => false, // Caller checks trigger conditions separately
        }
    }
}
```

This ensures the 100ms budget is achievable. Core perception and affect run every tick (~20ms combined). Expensive operations (agent bidding, world simulation) run less frequently. The scheduler is deterministic — given a tick number, the set of active subsystems is always the same.

---

## 2. Approval Dialog State Machine

The tick NEVER pauses. Continuous cognition is non-negotiable. Approval is an asynchronous queue that the kernel processes alongside normal tick phases.

---

### Core Invariant

When an action requires approval, the kernel does NOT block. It:
1. Places the action in the `ApprovalQueue`
2. Continues ticking (skips that specific action, processes everything else)
3. Waits for the TUI to relay the user's decision
4. Re-injects approved actions into the next tick's action phase

### ApprovalQueue

```rust
struct ApprovalQueue {
    pending: VecDeque<ApprovalEntry>,
    capacity: usize, // 8
}

struct ApprovalEntry {
    id: Uuid,
    request: ApprovalRequest,
    submitted_at: Instant,
    timeout: Duration,
    priority: ApprovalPriority,
    state: ApprovalState,
}

#[derive(Clone)]
struct ApprovalRequest {
    id: Uuid,
    category: ApprovalCategory,
    action: ActionDescription,
    context: ApprovalContext,
    risk_assessment: RiskAssessment,
    suggested_response: Option<ApprovalDecision>,
    timeout_behavior: TimeoutBehavior,
}

struct ApprovalContext {
    triggering_goal: GoalId,
    agent: AgentId,
    affected_files: Vec<PathBuf>,
    affected_memory: Vec<MemoryRef>,
    estimated_cost: Option<f64>,
    reversible: bool,
}

struct RiskAssessment {
    severity: Severity,       // Low, Medium, High, Critical
    blast_radius: BlastRadius, // Single file, project, system, external
    reversibility: f64,        // 0.0 = irreversible, 1.0 = trivially reversible
}
```

### State Machine

```
                    ┌─────────────┐
                    │   QUEUED    │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
       ┌──────────┐ ┌──────────┐ ┌──────────┐
       │ RENDERED │ │ TIMEOUT  │ │ EXPIRED  │
       │ (in TUI) │ │ (5 min)  │ │ (queue   │
       └────┬─────┘ └────┬─────┘ │  full)   │
            │             │       └────┬─────┘
    ┌───────┼───────┐     │            │
    │       │       │     ▼            ▼
    ▼       ▼       ▼  ┌──────┐   ┌──────┐
┌──────┐┌──────┐┌──────┐│DENIED│   │DENIED│
│APPRVD││DENIED││MODIFY││(auto)│   │(drop)│
└──┬───┘└──┬───┘└──┬───┘└──┬───┘   └──┬───┘
   │       │       │       │          │
   ▼       ▼       ▼       ▼          ▼
┌──────────────────────────────────────────┐
│              RESOLVED                     │
│  (logged to telemetry, removed from queue)│
└──────────────────────────────────────────┘
```

### Approval Categories & Thresholds

```rust
enum ApprovalCategory {
    /// File deletion, data loss, destructive git operations
    Destructive,

    /// Architecture-level refactoring, module restructuring
    Structural,

    /// Network requests, API calls, external service interaction
    External,

    /// Memory writes, skill promotion, preference changes
    Persistent,

    /// Self-modification of any kind
    Autonomous,
}

impl ApprovalCategory {
    fn requires_approval(&self, config: &ApprovalConfig) -> bool {
        match self {
            Self::Destructive => true,  // ALWAYS
            Self::Structural => true,   // ALWAYS
            Self::External => config.external_approval_required(),
            Self::Persistent => config.persistent_approval_required(),
            Self::Autonomous => true,   // ALWAYS
        }
    }

    fn timeout(&self) -> Duration {
        match self {
            Self::Autonomous => Duration::MAX, // Never times out — waits indefinitely
            _ => Duration::from_secs(300),     // 5 minutes default
        }
    }

    fn timeout_behavior(&self) -> TimeoutBehavior {
        match self {
            Self::Autonomous => TimeoutBehavior::WaitIndefinitely,
            _ => TimeoutBehavior::DenyWithReason("timeout"),
        }
    }
}
```

### Approval Response Types

```rust
enum ApprovalDecision {
    /// Execute the action as proposed
    Approve,

    /// Reject the action entirely
    Deny { reason: String },

    /// Approve with modifications (user edits parameters)
    Modify { modifications: ActionModification },

    /// Push to back of queue, ask again later
    Postpone,
}

struct ActionModification {
    /// Modified parameters (e.g., change target file, reduce scope)
    params: HashMap<String, serde_json::Value>,
    /// User's note explaining the modification
    note: String,
}
```

### Kernel-Side Processing

```rust
impl CognitiveKernel {
    async fn process_approvals(&mut self) {
        // Check for timeout on all pending entries
        let now = Instant::now();
        let mut timed_out = vec![];

        for entry in self.approval_queue.pending.iter_mut() {
            if now.duration_since(entry.submitted_at) > entry.timeout {
                entry.state = ApprovalState::TimedOut;
                timed_out.push(entry.id);
            }
        }

        // Process timed-out entries
        for id in timed_out {
            self.telemetry.log(TelemetryEvent::ApprovalTimeout { id });
            self.approval_queue.remove(id);
        }

        // Check for user responses (non-blocking)
        while let Ok(cmd) = self.kernel_rx.try_recv() {
            if let UserCommand::Approval(response) = cmd {
                match response.decision {
                    ApprovalDecision::Approve => {
                        let action = self.approval_queue.take(response.id);
                        self.action_queue.inject(action); // Re-inject for next tick
                    }
                    ApprovalDecision::Deny { reason } => {
                        self.telemetry.log(TelemetryEvent::ApprovalDenied {
                            id: response.id, reason
                        });
                        self.approval_queue.remove(response.id);
                    }
                    ApprovalDecision::Modify { modifications } => {
                        let mut action = self.approval_queue.take(response.id);
                        action.apply_modifications(modifications);
                        self.action_queue.inject(action);
                    }
                    ApprovalDecision::Postpone => {
                        self.approval_queue.move_to_back(response.id);
                    }
                }
            }
        }
    }
}
```

### TUI Rendering

- **Focus mode**: Modal overlay. Blocks conversation view. Shows action summary, risk assessment, and [a]pprove / [d]eny / [m]odify / [p]ostpone keybindings.
- **Trace mode**: Inline panel in the action pipeline view. Non-blocking — user can still see other activity.
- **Paranoia mode**: Same as Trace, plus full action context (affected files, memory refs, cost estimate).

Multiple pending approvals show a counter: `⚠ 3 pending approvals [Tab to cycle]`. User processes one at a time. Priority ordering: Autonomous > Destructive > Structural > External > Persistent.

### Edge Cases

1. **Queue full (8 items)**: Oldest non-Autonomous entry is auto-denied with reason "queue_overflow". Autonomous entries are never auto-denied.
2. **Rapid approvals**: User presses [a] multiple times quickly. Each approval is processed in order. No double-approval possible (entry removed from queue on first response).
3. **Action becomes stale**: If the context that triggered an action changes while waiting for approval (e.g., file was deleted), the action is marked stale and auto-denied on re-injection.
4. **Kernel restart during pending approval**: Approval queue is NOT persisted. Pending approvals are lost on restart. Actions that needed approval must be re-triggered by the kernel's normal goal/action pipeline.

---

## 3. Skill Mining Pipeline — Stage Transitions

Skills are extracted from journal entries through a 4-stage pipeline: TAG → CLUSTER → SUGGEST → REVIEW. Each stage is idempotent and can be re-run independently.

---

### Trigger Conditions

```rust
enum MiningTrigger {
    /// User explicitly invokes `/mine`
    Manual,

    /// Project session ends (user closes KC or switches project)
    ProjectClose,

    /// Weekly cron (if KC runs as daemon)
    Scheduled { cron: "0 3 * * 0" }, // Sunday 3am

    /// Threshold: 20+ unprocessed journal entries accumulated
    EntryThreshold(usize),
}
```

### Stage 1: TAG

Classify each unprocessed journal entry with a fixed (non-self-modifiable) prompt.

```rust
struct TagStage {
    /// Entries that haven't been tagged yet
    unprocessed: Vec<JournalEntryRef>,
    /// The classification prompt — CONSTITUTIONAL, cannot be modified by self-mod
    prompt_template: &'static str,
}

/// Classification output
enum EntryTag {
    Pattern,        // Recurring behavior or approach
    AntiPattern,    // Recurring mistake or suboptimal choice
    Preference,     // User preference or style choice
    Technique,      // Specific technical approach
    Constraint,     // Environmental or project constraint
    Irrelevant,     // Not useful for skill extraction
}

struct TagResult {
    entry_id: Uuid,
    tag: EntryTag,
    confidence: f64,
    reasoning: String, // LLM's explanation (for debugging)
}
```

The classification prompt is compiled into the binary. It cannot be modified by the self-modification engine (constitutional constraint). This prevents the system from gaming its own skill extraction.

### Stage 2: CLUSTER

Group tagged entries by semantic similarity.

```rust
struct ClusterStage {
    /// Only entries tagged as Pattern, Technique, or Preference
    tagged_entries: Vec<TagResult>,
    /// Cosine similarity threshold for cluster membership
    similarity_threshold: f64, // 0.85
    /// Minimum entries to form a valid cluster
    min_cluster_size: usize,   // 2
}

struct Cluster {
    id: Uuid,
    centroid: Vec<f32>,          // Average embedding
    members: Vec<JournalEntryRef>,
    dominant_tag: EntryTag,
    cohesion: f64,               // Average intra-cluster similarity
}

impl ClusterStage {
    fn execute(&self, embeddings: &EmbeddingIndex) -> Vec<Cluster> {
        // 1. Get embeddings for all tagged entries
        let vectors: Vec<(Uuid, Vec<f32>)> = self.tagged_entries
            .iter()
            .filter(|t| t.tag != EntryTag::Irrelevant)
            .map(|t| (t.entry_id, embeddings.get(t.entry_id)))
            .collect();

        // 2. Agglomerative clustering with cosine threshold
        let mut clusters: Vec<Cluster> = vec![];
        for (id, vec) in &vectors {
            let mut best_cluster: Option<usize> = None;
            let mut best_sim: f64 = 0.0;

            for (i, cluster) in clusters.iter().enumerate() {
                let sim = cosine_similarity(vec, &cluster.centroid);
                if sim > self.similarity_threshold && sim > best_sim {
                    best_cluster = Some(i);
                    best_sim = sim;
                }
            }

            match best_cluster {
                Some(i) => clusters[i].add_member(*id, vec),
                None => clusters.push(Cluster::new(*id, vec.clone())),
            }
        }

        // 3. Filter: minimum cluster size
        clusters.retain(|c| c.members.len() >= self.min_cluster_size);
        clusters
    }
}
```

### Stage 3: SUGGEST

Generate candidate skills from clusters via LLM.

```rust
struct SuggestStage {
    clusters: Vec<Cluster>,
}

struct SkillCandidate {
    id: Uuid,
    pattern: String,           // Natural language description
    domain: String,            // e.g., "backend", "frontend", "devops"
    tech_versions: Vec<String>, // e.g., ["rust@1.78", "tokio@1.37"]
    confidence: f64,           // 0.0-1.0, from LLM assessment
    source_entries: Vec<Uuid>, // Journal entries that formed this skill
    source_cluster: Uuid,
    suggested_context: SkillContext,
}

struct SkillContext {
    project_types: Vec<String>,
    risk_tolerance: RiskTolerance,
    tech_stack: Vec<String>,
}
```

### Stage 4: REVIEW

Candidates are stored on disk and presented to the user.

```rust
/// Storage: ~/.kc/skills/candidates/{slug}.toml
/// User reviews via `/skills review` command in TUI

enum ReviewDecision {
    Approve,                    // Move to ~/.kc/skills/approved/
    Edit { new_pattern: String }, // Edit and approve
    Reject,                     // Move to ~/.kc/skills/rejected/
    Defer,                      // Keep in candidates, ask again next cycle
}
```

### Skill Schema (TOML)

```toml
[skill]
id = "550e8400-e29b-41d4-a716-446655440000"
pattern = "Always validate cache hit rate before deploying"
domain = "backend"
tech_versions = ["rust@1.78", "redis@7.2"]
confidence = 0.8
state = "active"  # suggested | candidate | active | archived
created_at = "2026-05-30T12:00:00Z"
expires_at = "2027-05-30T12:00:00Z"
half_life_days = 365
source_projects = ["project-uuid-1", "project-uuid-2"]
version = 1
superseded_by = ""  # UUID of newer version, empty if current

[skill.context]
project_types = ["web_app", "api"]
risk_tolerance = "medium"  # low | medium | high
tech_stack = ["rust", "tokio", "redis"]

[skill.conflicts]
conflicts_with = []  # UUIDs of skills that contradict this one

[skill.metrics]
times_applied = 0
times_helpful = 0
last_applied = ""
```

### Directory Layout

```
~/.kc/skills/
├── candidates/          # Stage 4: awaiting user review
│   ├── validate-cache-hit-rate.toml
│   └── prefer-streaming-responses.toml
├── approved/            # Active skills (user-approved)
│   └── always-pin-dependencies.toml
├── archived/            # Expired or superseded
│   └── use-webpack-4-config.toml
└── rejected/            # User rejected (system learns what NOT to suggest)
    └── always-use-orm.toml
```

### Versioning

Skills are immutable once approved. Edits create a new version:

```rust
fn edit_skill(skill: &Skill, new_pattern: String) -> Skill {
    let mut new_skill = Skill {
        id: Uuid::new_v4(),
        pattern: new_pattern,
        version: skill.version + 1,
        created_at: Utc::now(),
        ..skill.clone()
    };

    // Archive old version
    let mut old = skill.clone();
    old.state = SkillState::Archived;
    old.superseded_by = Some(new_skill.id);
    move_to_dir(&old, "archived");

    new_skill
}
```

### Edge Cases

1. **Duplicate detection**: Before Stage 3 generates a candidate, check embedding similarity against existing approved skills. If > 0.9 similarity, skip (already known).
2. **Conflicting skills**: If a new candidate contradicts an existing skill, flag both for user review. Don't auto-resolve.
3. **Empty clusters**: If Stage 2 produces no clusters (all entries are unique), skip Stages 3-4. Log "no patterns detected" to telemetry.
4. **LLM unavailable during mining**: Queue the mining run. Retry when LLM recovers. Stage 1 (TAG) and Stage 3 (SUGGEST) require LLM. Stage 2 (CLUSTER) uses only embeddings.
5. **Skill expiration**: Skills have `expires_at` based on `half_life_days`. Expired skills move to `archived/` automatically. User can renew via `/skills renew {slug}`.

### Conflict Detection

```rust
fn detect_conflicts(candidate: &SkillCandidate, existing: &[Skill]) -> Vec<SkillConflict> {
    existing.iter()
        .filter(|s| s.state == SkillState::Active)
        .filter(|s| domain_overlap(&s.domain, &candidate.domain) > 0.5)
        .filter(|s| context_overlap(&s.context, &candidate.suggested_context) > 0.6)
        .filter_map(|s| {
            let pattern_similarity = embedding_cosine(&s.pattern_embedding, &candidate.pattern_embedding);
            
            if pattern_similarity > 0.85 {
                // Very similar pattern — likely duplicate, not conflict
                Some(SkillConflict::Duplicate { existing: s.id, similarity: pattern_similarity })
            } else if pattern_similarity > 0.5 && action_direction_opposed(s, candidate) {
                // Same domain, overlapping context, but opposite recommendation
                Some(SkillConflict::Contradiction { 
                    existing: s.id, 
                    overlap: pattern_similarity,
                    reason: format!("'{}' contradicts '{}'", candidate.pattern, s.pattern),
                })
            } else {
                None
            }
        })
        .collect()
}

fn action_direction_opposed(a: &Skill, b: &SkillCandidate) -> bool {
    // Heuristic: check for negation patterns
    let negation_pairs = [
        ("always", "never"),
        ("use", "avoid"),
        ("prefer", "avoid"),
        ("enable", "disable"),
        ("add", "remove"),
    ];
    
    for (pos, neg) in &negation_pairs {
        let a_has_pos = a.pattern.to_lowercase().contains(pos);
        let b_has_neg = b.pattern.to_lowercase().contains(neg);
        let a_has_neg = a.pattern.to_lowercase().contains(neg);
        let b_has_pos = b.pattern.to_lowercase().contains(pos);
        
        if (a_has_pos && b_has_neg) || (a_has_neg && b_has_pos) {
            return true;
        }
    }
    
    false
}
```

When conflicts are detected:
- **Duplicates (>0.85 similarity)**: Auto-skip candidate, log "already known" to telemetry. No user interaction needed.
- **Contradictions**: Present BOTH skills to user in review with full context (source entries, domain, tech versions). User decides which to keep, archive, or contextualize differently (e.g., "skill A applies to backend, skill B applies to frontend").

---

## 4. Journal Schema & Parser Contract

### Two Journals — Disambiguation

The system has two distinct journal-like structures that serve completely different purposes:

- The **Project Journal** (`.kc/journal.md`) is the human-readable episodic memory. Markdown + YAML frontmatter. Git-diffable. Used for skill mining and project continuity. This is what users see and edit. Memory can be rebuilt from it.

- The **State Checkpoint Log** (`~/.kc/projects/{id}/state.log`) is the binary crash-recovery log. Append-only binary format (see `docs/expanding_on/cognitive-homeostasis.md` for format). Used by the supervisor for panic recovery and session replay. NOT human-readable. NOT the same as the project journal.

Memory can be rebuilt from the Project Journal. Runtime state can be rebuilt from the State Checkpoint Log. They serve different purposes and never reference each other.

---

The journal is a single Markdown file with YAML frontmatter entries. Human-readable, git-diffable, append-only during normal operation. It is the durable source of truth — memory can be rebuilt from it.

---

### File Location & Format

- Path: `.kc/journal.md` (per-project)
- Format: Markdown with YAML frontmatter blocks separated by `---`
- Encoding: UTF-8
- Line endings: LF (normalized on write)
- Max file size: unbounded (but recommend splitting at 10MB via `kc journal rotate`)

### Entry Type Schemas

#### Decision Entry

```yaml
---
type: decision
date: 2026-05-30T14:30:00Z
author: user          # "user" | "system" | agent name
confidence: 0.85      # 0.0-1.0, how confident in this decision
reversible: true      # Can this be undone without significant cost?
context: "Choosing between SQLite and Postgres for telemetry storage"
alternatives:
  - option: "PostgreSQL"
    pros: ["Full SQL", "Concurrent writes"]
    cons: ["Requires server process", "Deployment complexity"]
  - option: "SQLite"
    pros: ["Zero deployment", "Single file", "Embedded"]
    cons: ["Single writer", "No network access"]
rationale: "SQLite wins because KC is single-process and local-first. WAL mode handles our read concurrency needs."
---

Decided to use SQLite for telemetry storage. The zero-deployment constraint
is non-negotiable for a single-binary TUI application.
```

#### Failure Entry

```yaml
---
type: failure
date: 2026-05-30T15:00:00Z
severity: medium      # low | medium | high | critical
status: open          # open | investigating | resolved
observed: "Memory consolidation crashes when episodic buffer exceeds 800 entries"
hypotheses:
  - "Ring buffer overflow not handled in edge case"
  - "Embedding batch size exceeds ONNX runtime limit"
root_cause: ""        # REQUIRED for status=resolved
fix_applied: ""       # REQUIRED for status=resolved
---

Consolidation panic observed at tick 45,230. Stack trace points to
`memory/consolidation.rs:142`. Investigating.
```

#### Insight Entry

```yaml
---
type: insight
date: 2026-05-30T16:00:00Z
pattern: "Users prefer explicit approval for memory writes even when low-risk"
evidence_count: 5     # How many observations support this
confidence: 0.7       # How confident in the generalization
related_entries: []   # UUIDs of supporting journal entries
---

After 5 sessions, users consistently approve memory writes manually rather
than enabling auto-approve. This suggests trust is earned slowly.
```

#### Milestone Entry

```yaml
---
type: milestone
date: 2026-05-30T17:00:00Z
description: "Memory Palace v1 complete"
deliverables:
  - "6-tier memory system operational"
  - "Consolidation pipeline running during idle"
  - "HNSW index with 384d embeddings"
phase: "Phase 2"
---

All memory tiers functional. Consolidation runs during idle periods.
Performance within budget on Standard tier hardware.
```

#### BugFix Entry

```yaml
---
type: bugfix
date: 2026-05-30T18:00:00Z
symptom: "TUI freezes for 2s when switching to Paranoia mode"
root_cause: "Ring buffer iteration was O(n²) due to nested clone"
fix_applied: "Replaced Vec clone with iterator reference, added render budget check"
files_changed:
  - "src/tui/paranoia.rs"
  - "src/tui/ring_buffer.rs"
---

Fixed quadratic rendering in Paranoia mode. Render time dropped from
2100ms to 8ms for 1000-entry buffer.
```

### Parser Contract

```rust
struct JournalParser {
    path: PathBuf,
    last_hash: Option<[u8; 32]>,  // BLAKE3 hash of file at last full parse
    last_size: u64,                // File size at last parse (for append detection)
    entries: Vec<JournalEntry>,
}

impl JournalParser {
    /// Full parse on startup
    fn parse_full(&mut self) -> Result<Vec<JournalEntry>> {
        let content = fs::read_to_string(&self.path)?;
        self.last_hash = Some(blake3::hash(content.as_bytes()).into());
        self.last_size = content.len() as u64;

        let mut entries = vec![];
        for block in split_frontmatter_blocks(&content) {
            match parse_entry(block) {
                Ok(entry) => entries.push(entry),
                Err(e) => {
                    tracing::warn!("Skipping invalid journal entry: {}", e);
                    // NEVER crash on bad journal data
                }
            }
        }
        self.entries = entries.clone();
        Ok(entries)
    }

    /// Incremental parse on file change notification
    fn parse_incremental(&mut self) -> Result<Vec<JournalEntry>> {
        let metadata = fs::metadata(&self.path)?;
        let current_size = metadata.len();

        if current_size > self.last_size {
            // Append detected — only parse new content
            let content = fs::read_to_string(&self.path)?;
            let new_content = &content[self.last_size as usize..];
            let new_entries = self.parse_block(new_content);
            self.last_size = current_size;
            self.last_hash = Some(blake3::hash(content.as_bytes()).into());
            self.entries.extend(new_entries.clone());
            Ok(new_entries)
        } else {
            // File was modified (not appended) — full re-parse
            let content = fs::read_to_string(&self.path)?;
            let current_hash = blake3::hash(content.as_bytes());
            if Some(current_hash.into()) != self.last_hash {
                // Hash mismatch: manual edit detected
                tracing::info!("Journal manually edited — full re-parse");
                self.parse_full()
            } else {
                Ok(vec![]) // No changes
            }
        }
    }
}
```

### File Watching

- **Linux**: `inotify` via `notify` crate (IN_MODIFY event)
- **macOS**: `kqueue` via `notify` crate (NOTE_WRITE event)
- **Debounce**: 100ms (coalesce rapid writes from editors that write-then-rename)

### File Event Coalescing

Raw file system events are noisy (editors write temp files, build tools generate thousands of events). The coalescer merges and filters events before they reach perception:

```rust
struct FileEventCoalescer {
    /// Pending events within the current coalescing window
    pending: HashMap<PathBuf, FileEventType>,
    /// Coalescing window (events within this window are merged)
    window: Duration, // 200ms
    /// Patterns to suppress entirely (build output, node_modules, .git)
    suppress_patterns: Vec<glob::Pattern>,
}

impl FileEventCoalescer {
    fn process(&mut self, event: FileEvent) -> Option<CoalescedFileEvent> {
        // 1. Check suppress patterns
        if self.suppress_patterns.iter().any(|p| p.matches_path(&event.path)) {
            return None; // Silently drop
        }

        // 2. Merge into pending (latest event type wins for same path)
        self.pending.insert(event.path.clone(), event.event_type);

        // 3. If window elapsed, flush all pending as single batch
        if self.window_elapsed() {
            let batch = CoalescedFileEvent {
                paths: self.pending.drain().collect(),
                tick: current_tick(),
            };
            Some(batch)
        } else {
            None
        }
    }
}

// Default suppress patterns:
// **/target/**
// **/node_modules/**
// **/.git/objects/**
// **/*.swp
// **/*~
```

This reduces perception noise significantly. A `cargo build` that touches 200 files in `target/` produces zero perception events. An editor save-and-rename produces one event (the final path).

### Relationship to Memory Palace

```
Journal Entry Type    →    Memory Tier           →    Mechanism
─────────────────────────────────────────────────────────────────
Decision             →    Semantic (tier 3)      →    Creates concept node with
                                                      edges to alternatives
Failure (resolved)   →    Procedural (tier 4)    →    Feeds skill mining as
                                                      anti-pattern evidence
Insight              →    Semantic (tier 3)      →    Creates pattern node,
                                                      strengthens existing edges
Milestone            →    Episodic (tier 2)      →    Time-indexed project event
BugFix               →    Procedural (tier 4)    →    Action-outcome pair for
                                                      similar future bugs
All types            →    Episodic (tier 2)      →    Indexed with embeddings
                                                      for temporal retrieval
```

**Critical invariant**: Journal deletion does NOT delete corresponding memory nodes. Memory is independent — it was derived from the journal but is not referentially dependent on it. Deleting a journal entry is like forgetting you learned something, but the knowledge remains.

### Edge Cases

1. **Corrupted YAML frontmatter**: Parser logs warning, skips entry, continues. Never panics.
2. **Missing required fields**: Entry is parsed but flagged as `incomplete`. Still indexed in episodic memory but not processed by skill mining.
3. **Concurrent writes**: Journal is append-only during normal operation. If both user and system write simultaneously, the file watcher detects the change and re-parses. Last-write-wins at the file level (OS handles this).
4. **Very large journal**: At 10MB+, recommend rotation via `kc journal rotate`. Old entries archived to `.kc/journal.archive/journal-{date}.md`. Memory references remain valid (they use entry UUIDs, not file offsets).
5. **Binary content in markdown body**: Ignored. Parser only cares about YAML frontmatter for structured data. Markdown body is free-form text indexed as-is.

---

## 5. Project Initialization & Directory Boundaries

The `.kc/` directory defines a project boundary. No parent traversal, no symlink following, no ambiguity. Innermost `.kc/` wins.

---

### `kc init .`

Creates the following structure in the current directory:

```
.kc/
├── steering/
│   └── .gitkeep
├── specs/
│   └── .gitkeep
├── journal.md          # Empty with header template
├── memory/
│   └── .gitkeep
└── config.toml         # Project-local config (overrides ~/.kc/config.toml)
```

#### Initial `journal.md` Template

```markdown
# Project Journal

> Structured episodic memory. Entries are append-only during normal operation.
> Each entry has YAML frontmatter followed by free-form markdown.

```

#### Initial `config.toml`

```toml
# Project-local configuration
# Values here override ~/.kc/config.toml for this project only.

[project]
name = ""           # Auto-detected from directory name if empty
id = "auto"        # Generated UUID on first run

# [llm]
# Override LLM preferences for this project
# prefer_local = true

# [approval]
# Override approval thresholds
# external = "require"    # "auto" | "require"
# persistent = "require"  # "auto" | "require"

# [budget]
# Per-project cost tracking
# max_daily_usd = 10.0
# spent_total_usd = 0.0
```

### Project Boundary Resolution

```rust
fn find_project_root(start: &Path) -> Option<PathBuf> {
    let mut current = start.canonicalize().ok()?;

    loop {
        let kc_dir = current.join(".kc");
        if kc_dir.is_dir() {
            return Some(current);
        }

        if !current.pop() {
            return None; // Reached filesystem root
        }
    }
}
```

**Rules**:
1. Walk UP from CWD until `.kc/` directory found.
2. If none found → "uninitialized" mode (no memory, no journal, limited capabilities).
3. Never follow symlinks when resolving `.kc/`. The directory must physically exist.
4. Never traverse above filesystem root.

### Nested Projects

```
~/projects/
├── .kc/                    ← Project A (monorepo root)
├── web/
│   ├── .kc/                ← Project B (nested, independent)
│   └── src/
└── api/
    └── src/                ← Part of Project A (no .kc/ here)
```

When CWD is `~/projects/web/src/`:
- Project root = `~/projects/web/` (innermost `.kc/` wins)
- `~/projects/.kc/` is completely ignored

When CWD is `~/projects/api/src/`:
- Project root = `~/projects/` (walks up to find `.kc/`)

### Monorepo Support

Single `.kc/` at repository root. Specs can reference subdirectories:

```
monorepo/
├── .kc/
│   ├── specs/
│   │   ├── auth-service/       # Spec scoped to packages/auth/
│   │   └── shared-utils/       # Spec scoped to packages/shared/
│   └── journal.md              # Single journal for entire monorepo
├── packages/
│   ├── auth/
│   └── shared/
└── apps/
```

### Project Registry

```toml
# ~/.kc/projects.toml — tracks all known projects

[[projects]]
id = "550e8400-e29b-41d4-a716-446655440000"
path = "/home/user/projects/kognisant-desktop"
name = "kognisant-desktop"
last_opened = "2026-05-30T14:00:00Z"
storage_bytes = 4_200_000
created_at = "2026-01-15T10:00:00Z"

[[projects]]
id = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
path = "/home/user/projects/web-app"
name = "web-app"
last_opened = "2026-05-29T09:00:00Z"
storage_bytes = 1_800_000
created_at = "2026-03-01T08:00:00Z"
```

Updated on every `kc` invocation (touch `last_opened`, recalculate `storage_bytes` if stale).

### Uninitialized Mode

When no `.kc/` is found:

```rust
struct UninitializedMode {
    capabilities: Capabilities {
        memory: false,
        journal: false,
        skills: true,          // User-level skills still available
        llm: true,             // LLM pool still works
        approval: true,        // Safety gates still active
        self_modification: false,
        telemetry: true,       // Logs to ~/.kc/ level
    },
    prompt: "No project detected. Run `kc init .` to initialize.",
}
```

### Edge Cases

1. **`.kc/` is a file, not a directory**: Ignored. Only directories count as project markers.
2. **Permissions**: If `.kc/` exists but is not readable, treat as uninitialized with error message.
3. **Deleted mid-session**: If `.kc/` is deleted while KC is running, detect via file watcher. Gracefully transition to uninitialized mode. No crash.
4. **Multiple KC instances same project**: File-level locking via `.kc/.lock` (advisory lock). Second instance warns "Another KC instance is active for this project" and operates read-only.
5. **Path with spaces/unicode**: Fully supported. All path operations use `PathBuf`, never string concatenation.

---

## 6. LLM Pool Routing & Fallback Strategy

The LLM Pool selects the best available model for each query using a weighted scoring algorithm, with automatic fallback through a provider chain. Cost tracking and budget enforcement are built-in.

---

### Routing Algorithm

```rust
fn score_model(model: &ModelInfo, request: &LlmRequest, config: &RoutingConfig) -> f64 {
    // Hard gate: if model lacks required capability, score is 0
    if !model.supports_required_capabilities(request) {
        return 0.0;
    }

    let capability_match = 1.0; // Passed gate above

    let speed_preference = match config.speed_priority {
        SpeedPriority::Fast => estimate_speed(model),
        SpeedPriority::Normal => 0.5,
        SpeedPriority::DontCare => 1.0,
    };

    let cost_preference = if model.cost_per_token == 0.0 {
        1.0 // Free (local) models get max cost score
    } else {
        1.0 - (model.cost_per_token / max_known_cost).min(1.0)
    };

    let quality_tier = model.quality_tier as f64 / 5.0;

    let user_preference = if config.preferred_models.contains(&model.id) {
        1.0
    } else {
        0.0
    };

    // Weighted combination
    let score = capability_match * (
        speed_preference * 0.25 +
        cost_preference * 0.25 +
        quality_tier * 0.15 +
        user_preference * 0.05 +
        model.reliability_score * 0.10 +
        if model.is_local { 0.20 } else { 0.0 } // Locality bonus
    );

    score
}
```

### Locality Bonus Configuration

```rust
/// Locality bonus is context-dependent, not fixed
fn locality_bonus(request: &LlmRequest, model: &ModelInfo) -> f64 {
    if !model.is_local { return 0.0; }
    
    match request.complexity {
        Complexity::Low => 0.30,    // Simple queries: strongly prefer local
        Complexity::Medium => 0.15, // Moderate: slight local preference
        Complexity::High => 0.05,   // Complex: capability matters more than locality
    }
}
```

This replaces the fixed `0.20` bonus in `score_model`. Complex reasoning tasks (long context, multi-step planning) should prefer capable remote models over fast-but-limited local ones.

Configuration in `config.toml`:

```toml
[llm.routing]
# Locality bonus multiplier (0.0 = no preference, 1.0 = always prefer local)
locality_preference = 0.5
# Minimum quality tier for complex requests (1-5)
min_quality_for_complex = 3
```

### Fallback Chain

```rust
const FALLBACK_ORDER: &[ProviderClass] = &[
    ProviderClass::Local,       // Ollama (always available offline)
    ProviderClass::Managed,     // Kognisant API (reliable, managed)
    ProviderClass::ThirdParty,  // OpenAI, Anthropic, etc.
];

async fn query_with_fallback(
    request: &LlmRequest,
    pool: &LlmPool,
) -> Result<LlmResponse, LlmError> {
    // Score all available models
    let mut candidates: Vec<(f64, &ModelInfo, &dyn Provider)> = pool
        .available_models()
        .map(|(model, provider)| {
            let score = score_model(model, request, &pool.config);
            (score, model, provider)
        })
        .filter(|(score, _, _)| *score > 0.0)
        .collect();

    // Sort by score descending
    candidates.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap());

    // Try each candidate in order
    for (_, model, provider) in &candidates {
        match provider.complete(request, model).await {
            Ok(response) => {
                pool.reliability.record_success(provider.name());
                return Ok(response);
            }
            Err(e) => {
                pool.reliability.record_failure(provider.name(), &e);
                handle_provider_error(pool, provider, &e);
                continue;
            }
        }
    }

    Err(LlmError::AllProvidersUnavailable)
}
```

### Failure Handling

```rust
fn handle_provider_error(pool: &LlmPool, provider: &dyn Provider, error: &LlmError) {
    match error {
        LlmError::Timeout => {
            // 30s timeout hit. Mark degraded for 5 minutes.
            pool.status.mark_degraded(provider.name(), Duration::from_secs(300));
        }
        LlmError::RateLimit { retry_after } => {
            pool.status.mark_rate_limited(provider.name(), *retry_after);
        }
        LlmError::AuthFailure => {
            pool.status.mark_unavailable(provider.name());
            // Notify user: "Provider X auth failed — check API key"
        }
        LlmError::ServerError(_) => {
            // Immediate fallback, mark degraded briefly
            pool.status.mark_degraded(provider.name(), Duration::from_secs(60));
        }
        _ => {
            pool.status.mark_degraded(provider.name(), Duration::from_secs(30));
        }
    }
}
```

### Degraded Cognition Mode

When ALL providers are unavailable:

```rust
struct DegradedCognitionState {
    /// Actions that need LLM are queued here (not dropped)
    pending_actions: VecDeque<PendingLlmAction>, // capacity: 32
    /// Subsystems that continue without LLM
    active_subsystems: ActiveSubsystems {
        perception: true,       // File watching, event detection
        memory_activation: true, // Embedding-based retrieval (local model)
        affect_dynamics: true,   // Mathematical, no LLM needed
        goal_market: true,       // Priority math, no LLM needed
        prediction_l1_l2: true,  // Statistical prediction layers
        prediction_l3_l4_l5: false, // Semantic prediction needs LLM
        agent_society: false,    // Agents need LLM for reasoning
        self_modification: false, // Patch generation needs LLM
        skill_mining: false,     // TAG and SUGGEST stages need LLM
    },
}
```

The kernel continues ticking. Perception, memory activation, affect dynamics, and goal priority math all work without LLM. When a provider recovers, queued actions are processed in FIFO order.

### Cost Tracking

```rust
struct CostTracker {
    /// Per-session (resets on KC restart)
    session_tokens_in: u64,
    session_tokens_out: u64,
    session_cost_usd: f64,

    /// Per-project (persisted in .kc/config.toml)
    project_total_cost_usd: f64,

    /// Budget (from config)
    budget_daily_usd: Option<f64>,  // None = unlimited
    budget_monthly_usd: Option<f64>,
    spent_today_usd: f64,
    spent_this_month_usd: f64,
}

impl CostTracker {
    fn check_budget(&self, estimated_cost: f64) -> BudgetDecision {
        if let Some(daily) = self.budget_daily_usd {
            if self.spent_today_usd + estimated_cost > daily {
                return BudgetDecision::RequireApproval {
                    reason: format!(
                        "Daily budget ${:.2} would be exceeded (spent: ${:.2})",
                        daily, self.spent_today_usd
                    ),
                };
            }
        }
        BudgetDecision::Allowed
    }
}
```

TUI display:
- **Trace mode**: Status bar shows `LLM: ✓ 3 providers | $0.42 today`
- **Paranoia mode**: Full breakdown per provider, per model, with token counts

### Health Check

```rust
/// Runs every 60 seconds in background
async fn health_check_loop(pool: Arc<LlmPool>) {
    loop {
        tokio::time::sleep(Duration::from_secs(60)).await;

        for provider in pool.providers() {
            let healthy = match provider.health_check().await {
                Ok(_) => true,
                Err(_) => false,
            };

            if healthy && pool.status.is_unavailable(provider.name()) {
                // Provider recovered
                pool.status.mark_available(provider.name());
                tracing::info!("Provider {} recovered", provider.name());
            } else if !healthy && pool.status.is_available(provider.name()) {
                // Provider went down
                pool.status.mark_unavailable(provider.name());
                tracing::warn!("Provider {} unreachable", provider.name());
            }
        }
    }
}
```

### Edge Cases

1. **Local Ollama not running**: Detected at boot. Not an error — just fewer options. User notified in settings.
2. **API key rotation**: If a key becomes invalid mid-session, provider is marked unavailable. User must update config and KC detects the change via file watcher.
3. **Network partition**: All remote providers fail simultaneously. Local Ollama (if available) becomes sole provider. If no local model, enter degraded cognition.
4. **Cost spike from long context**: Pre-estimate cost before sending. If estimated cost > per-query budget, require approval before sending.
5. **Provider returns garbage**: Validate response structure. If response fails schema validation, treat as provider error and fallback.

---

## 7. Telemetry & Replay System

Telemetry logs significant events (not every tick) to a per-project SQLite database. Replay reconstructs sessions from the event log for observation — it is NOT deterministic re-execution.

---

### Storage Architecture Decision

Decision: **Single database per project** (not a single global database).

Rationale:
- Project deletion cleanly removes all associated telemetry (no orphans)
- Projects can be archived independently (zip the project's telemetry.db)
- No cross-project query contamination (one project's events don't pollute another's)
- SQLite performs well up to ~10GB per file — a single project will never hit this
- Cross-project analysis (rare) can be done via `ATTACH DATABASE` in SQLite or a separate analysis tool

Trade-off accepted: 50 projects = 50 files. This is fine — each is independent and self-contained.

Orphan detection: On startup, scan `~/.kc/projects/` and compare against `projects.toml`. Any project_id not in the registry is flagged as orphaned. User can clean up via `kc projects prune`.

### Storage

```
~/.kc/projects/{project-id}/telemetry.db
```

One SQLite database per project. WAL mode for concurrent read/write.

### What Gets Logged

```rust
enum TelemetryEvent {
    // User interactions
    UserInput { content: String, tick: u64 },
    ApprovalDecision { request_id: Uuid, decision: ApprovalDecision, latency_ms: u64 },
    ModeSwitch { from: VisibilityMode, to: VisibilityMode },
    CommandExecuted { command: String },

    // Agent actions
    ToolCall { agent: AgentId, tool: String, args: serde_json::Value, result: ToolResult },
    FileWrite { path: PathBuf, bytes: u64, agent: AgentId },
    LlmQuery { provider: String, model: String, tokens_in: u32, tokens_out: u32, cost: f64, latency_ms: u64 },

    // State transitions
    GoalCreated { id: GoalId, source: GoalSource, priority: f64 },
    GoalCompleted { id: GoalId, outcome: GoalOutcome, ticks_elapsed: u64 },
    MemoryWrite { tier: MemoryTier, key: String, size_bytes: u64 },
    AffectChange { dimension: AffectDimension, old: f64, new: f64 }, // Only if |delta| > 0.1
    SkillStateChange { skill_id: Uuid, from: SkillState, to: SkillState },

    // Errors and pathologies
    Error { subsystem: String, message: String, severity: Severity },
    PathologyDetected { kind: PathologyKind, intervention: String },
    PanicRecovery { subsystem: String, tick: u64, recovered: bool },

    // Approval lifecycle
    ApprovalRequested { id: Uuid, category: ApprovalCategory, action_summary: String },
    ApprovalTimedOut { id: Uuid },
}
```

### What Is NOT Logged

- Individual tick phases (too much data — ~100 events/second at 10Hz)
- Memory activation scores (transient, changes every tick)
- Prediction error values (continuous stream, not discrete events)
- Working memory contents (changes every tick)

Tick-level data exists only in the Paranoia mode ring buffer (in-memory, 1000 events, not persisted).

### SQLite Schema

```sql
CREATE TABLE events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    tick INTEGER NOT NULL,
    timestamp TEXT NOT NULL,        -- ISO 8601
    event_type TEXT NOT NULL,       -- Discriminant of TelemetryEvent
    payload TEXT NOT NULL,          -- JSON serialization of event data
    severity TEXT DEFAULT 'info'    -- debug | info | warn | error
);

CREATE INDEX idx_events_session ON events(session_id);
CREATE INDEX idx_events_tick ON events(tick);
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_timestamp ON events(timestamp);

CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    started_at TEXT NOT NULL,
    ended_at TEXT,
    tick_count INTEGER DEFAULT 0,
    event_count INTEGER DEFAULT 0
);

CREATE TABLE retention_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
-- retention_meta stores: last_cleanup, retention_days, archive_path
```

### Retention Policy

```rust
struct RetentionConfig {
    /// Days to keep in active database
    active_days: u32,        // Default: 30
    /// Days to keep in compressed archive
    archive_days: u32,       // Default: 365
    /// Maximum database size before forced cleanup
    max_db_size_mb: u64,     // Default: 500
}

/// Runs daily (or on startup if last run > 24h ago)
async fn cleanup_telemetry(db: &Database, config: &RetentionConfig) {
    let cutoff = Utc::now() - Duration::days(config.active_days as i64);

    // 1. Export old events to compressed archive
    let old_events = db.query("SELECT * FROM events WHERE timestamp < ?", &[cutoff]);
    if !old_events.is_empty() {
        let archive_path = format!("telemetry-archive-{}.zst", cutoff.format("%Y%m%d"));
        compress_and_write(old_events, &archive_path); // zstd compression
    }

    // 2. Delete from active database
    db.execute("DELETE FROM events WHERE timestamp < ?", &[cutoff]);

    // 3. VACUUM if significant space freed
    db.execute("VACUUM", &[]);
}
```

### Replay Mechanism

Replay reconstructs a session timeline from the event log. It is observation, not simulation.

```rust
struct ReplaySession {
    session_id: String,
    events: Vec<TelemetryEvent>,
    current_index: usize,
    playback_speed: f64,     // 1.0 = real-time, 2.0 = 2x speed
    state: ReplayState,      // Playing | Paused | Scrubbing
}

enum ReplayState {
    Playing,
    Paused,
    Scrubbing { target_tick: u64 },
}

impl ReplaySession {
    /// Load session from telemetry database
    fn load(db: &Database, session_id: &str) -> Result<Self> {
        let events = db.query(
            "SELECT * FROM events WHERE session_id = ? ORDER BY tick, id",
            &[session_id],
        )?;

        Ok(Self {
            session_id: session_id.to_string(),
            events: events.into_iter().map(deserialize_event).collect(),
            current_index: 0,
            playback_speed: 1.0,
            state: ReplayState::Paused,
        })
    }

    /// Advance replay by one frame (called by TUI render loop)
    fn advance(&mut self, dt: Duration) -> Vec<&TelemetryEvent> {
        let mut emitted = vec![];
        let effective_dt = dt.mul_f64(self.playback_speed);

        while self.current_index < self.events.len() {
            let event = &self.events[self.current_index];
            // Emit events whose timestamp falls within this frame
            if event.within_frame(effective_dt) {
                emitted.push(event);
                self.current_index += 1;
            } else {
                break;
            }
        }
        emitted
    }

    /// Scrub to specific tick
    fn scrub_to(&mut self, tick: u64) {
        self.current_index = self.events
            .binary_search_by_key(&tick, |e| e.tick())
            .unwrap_or_else(|i| i);
    }
}
```

### TUI Replay Rendering

- `/replay session {id}` enters replay mode
- Events render in the TUI as if happening live (same widgets, same layout)
- Status bar shows: `▶ REPLAY | Tick 4,230/12,500 | 1.0x | [Space] pause [←→] scrub`
- User CANNOT interact with the system during replay (read-only)
- `[Esc]` exits replay mode

### Replay vs Simulation

| Aspect | Replay | Simulation (World Simulator) |
|--------|--------|------------------------------|
| Purpose | Observe what happened | Explore what could happen |
| Data source | Telemetry event log | Current state + hypothetical inputs |
| Determinism | Exact reproduction of events | Non-deterministic (LLM involved) |
| User interaction | Read-only observation | Can modify inputs |
| Approval gates | None (already resolved) | Active (simulated actions need approval) |
| Cost | Zero (no LLM queries) | Expensive (LLM generates predictions) |

### Edge Cases

1. **Corrupted telemetry database**: Detected via `PRAGMA integrity_check` on startup. If corrupted, rename to `.corrupted`, start fresh. Old data is lost but system continues.
2. **Replay of very long session**: Events are loaded lazily (paginated from SQLite). Only events within ±1000 ticks of current position are in memory.
3. **Session without end marker**: If KC crashed, session has no `ended_at`. Replay still works — just plays until last recorded event.
4. **Disk full during logging**: Telemetry writes are best-effort. If write fails, log to stderr and continue. Never crash the kernel because telemetry can't write.
5. **Clock skew**: Events use monotonic tick numbers as primary ordering. Wall-clock timestamps are secondary (for human display only).

---

## 8. Self-Modification Boundaries

The system can modify most of itself — but constitutional modules are cryptographically protected and cannot be weakened. Trust levels let users choose their comfort zone.

---

### Modification Scope

#### CAN Self-Modify (with appropriate approval)

| Target | Approval Required | Auto-Revert Window |
|--------|------------------|--------------------|
| Prompt templates (agent system prompts) | Single approval | 60s |
| Tool configurations (add/remove/adjust) | Single approval | 60s |
| Hyperparameters (decay rates, thresholds) | Depends on trust level | 60s |
| Strategy weights (bid strategies, routing) | Depends on trust level | 60s |
| Source code (any non-constitutional module) | `/approve-self-mod` command | 60s |

#### CANNOT Self-Modify (constitutional, cryptographically enforced)

```rust
/// These modules are outside the source_mirror filesystem.
/// The kernel has read-only access. The supervisor owns them.
/// Signatures verified on boot and every 60s.
const CONSTITUTIONAL_MODULES: &[&str] = &[
    "safety_gate",              // Validates all patches
    "approval_system",          // User approval logic
    "telemetry_recorder",       // Audit trail (cannot be silenced)
    "constitutional_verifier",  // This verification system itself
    "cognitive_immune_system",  // Pathology detection
    "mutation_budget_enforcer", // Rate limiting on modifications
];
```

Why these specifically:
- **Safety gate**: If the system could weaken its own safety checks, all other protections become meaningless.
- **Approval system**: If the system could bypass approval, human-in-the-loop is theater.
- **Telemetry**: If the system could silence logging, it could hide misbehavior.
- **Constitutional verifier**: Self-referential protection — the thing that checks integrity cannot itself be modified.
- **Immune system**: The pathology detector must be independent of the system it monitors.
- **Mutation budget**: The rate limiter cannot be modified to allow unlimited modifications.

### Trust Levels

```rust
#[derive(Clone, Copy, Deserialize)]
enum TrustLevel {
    /// ALL changes require explicit approval (including hyperparameters)
    Paranoid,

    /// Structural + source changes require approval.
    /// Hyperparameters auto-approved if within configured bounds.
    Cautious, // DEFAULT

    /// Only source code and constitutional changes require approval.
    /// Everything else is auto-approved.
    Autonomous,
}

impl TrustLevel {
    fn requires_approval(&self, modification: &Modification) -> bool {
        match (self, &modification.target) {
            // Constitutional: ALWAYS requires approval (all trust levels)
            (_, ModTarget::Constitutional) => true,

            // Source code: always requires approval
            (_, ModTarget::SourceCode) => true,

            // Paranoid: everything requires approval
            (Self::Paranoid, _) => true,

            // Cautious: structural changes require approval
            (Self::Cautious, ModTarget::ToolConfig) => true,
            (Self::Cautious, ModTarget::PromptTemplate) => true,
            (Self::Cautious, ModTarget::Hyperparameter) => {
                // Auto-approve if within bounds
                !modification.within_configured_bounds()
            }
            (Self::Cautious, ModTarget::StrategyWeight) => {
                !modification.within_configured_bounds()
            }

            // Autonomous: only source code requires approval (handled above)
            (Self::Autonomous, _) => false,
        }
    }
}
```

### Hyperparameter Bounds (for auto-approval in Cautious mode)

```toml
# ~/.kc/config.toml
[self_modification.bounds]
# Each hyperparameter has a valid range for auto-approval
# Changes outside these ranges require explicit approval

[self_modification.bounds.memory]
decay_rate_min = 0.0001
decay_rate_max = 0.01
activation_threshold_min = 0.2
activation_threshold_max = 0.8

[self_modification.bounds.affect]
decay_rate_min = 0.005
decay_rate_max = 0.05
extreme_threshold_min = 0.8
extreme_threshold_max = 0.95

[self_modification.bounds.goals]
priority_decay_min = 0.0005
priority_decay_max = 0.005
generation_threshold_min = 0.4
generation_threshold_max = 0.7
```

### Rate-of-Change Limit

Beyond absolute bounds, no single modification can change a parameter by more than 25% of its current value. This prevents catastrophic jumps even within valid ranges:

```rust
/// No single modification can change a parameter by more than 25% of its current value
const MAX_PARAMETER_CHANGE_RATIO: f64 = 0.25;

fn validate_change_magnitude(current: f64, proposed: f64) -> Result<(), ModificationError> {
    let change_ratio = (proposed - current).abs() / current.abs().max(f64::EPSILON);
    if change_ratio > MAX_PARAMETER_CHANGE_RATIO {
        return Err(ModificationError::ChangeTooDrastic {
            current,
            proposed,
            max_allowed: current * (1.0 + MAX_PARAMETER_CHANGE_RATIO),
            min_allowed: current * (1.0 - MAX_PARAMETER_CHANGE_RATIO),
        });
    }
    Ok(())
}
```

This means a decay rate of 0.005 can only be changed to the range [0.00375, 0.00625] in a single modification. Multiple modifications over time can still reach any value within bounds, but gradual change prevents destabilization.

### Source Code Modification Approval

Source code changes require a special command — not just pressing [a] in the approval dialog:

```rust
/// Source code modification requires explicit `/approve-self-mod` command.
/// This is deliberately more friction than normal approval.
fn approve_source_modification(entry: &ApprovalEntry) -> bool {
    // Normal [a]pprove key does NOT work for source modifications
    // User must type `/approve-self-mod {id}` in the command palette
    // This prevents accidental approval of code changes
    matches!(entry.approval_method, ApprovalMethod::ExplicitCommand)
}
```

### Security Gate for Self-Modification Patches

Beyond the safety gate (which checks immutable markers and complexity), a dedicated security gate validates that patches don't introduce dangerous capabilities:

```rust
/// Security-specific validation for self-modification patches
fn security_gate(patch: &CodePatch) -> Result<(), SecurityViolation> {
    // New network calls (reqwest::Client::new, TcpStream, UdpSocket)
    if patch.introduces_pattern(&["reqwest::Client", "TcpStream", "UdpSocket", "hyper::"]) {
        return Err(SecurityViolation::NewNetworkAccess);
    }

    // New file reads outside project boundary
    if patch.introduces_pattern(&["std::fs::read", "tokio::fs::read"]) {
        // Check if paths are within project root
        if !patch.all_paths_within_boundary() {
            return Err(SecurityViolation::FileAccessOutsideBoundary);
        }
    }

    // New environment variable reads
    if patch.introduces_pattern(&["std::env::var", "std::env::vars"]) {
        return Err(SecurityViolation::NewEnvAccess);
    }

    // New process spawning
    if patch.introduces_pattern(&["Command::new", "tokio::process"]) {
        return Err(SecurityViolation::NewProcessSpawn);
    }

    Ok(())
}

enum SecurityViolation {
    NewNetworkAccess,
    FileAccessOutsideBoundary,
    NewEnvAccess,
    NewProcessSpawn,
}
```

The security gate runs AFTER the safety gate and BEFORE shadow runtime evaluation. A patch that fails the security gate is immediately rejected — no shadow evaluation, no approval escalation. This is a hard block because these capabilities could be used for data exfiltration.

### Auto-Revert Mechanism

All modifications (regardless of type) have a 60-second health monitoring window:

```rust
struct ModificationMonitor {
    modification_id: Uuid,
    applied_at: Instant,
    baseline_metrics: HealthMetrics,
    revert_threshold: f64, // 0.1 = 10% degradation triggers revert
}

impl ModificationMonitor {
    async fn monitor(&self, kernel: &CognitiveKernel) -> MonitorOutcome {
        tokio::time::sleep(Duration::from_secs(60)).await;

        let current_metrics = kernel.health_metrics();
        let degradation = self.baseline_metrics.compare(&current_metrics);

        if degradation > self.revert_threshold {
            MonitorOutcome::Revert {
                reason: format!("Metrics degraded by {:.1}% within 60s", degradation * 100.0),
            }
        } else {
            MonitorOutcome::Accept
        }
    }
}
```

### Health Metric Basket

```rust
struct HealthMetrics {
    /// Average tick duration over last 100 ticks (microseconds)
    avg_tick_duration_us: u64,
    /// Prediction error rate (Layer 2+) — rolling average
    prediction_error_rate: f64,
    /// Memory retrieval precision (correct activations / total activations)
    memory_precision: f64,
    /// Goal completion rate (completed / attempted in window)
    goal_completion_rate: f64,
    /// Agent bid success rate (winning bids that led to successful outcomes)
    agent_success_rate: f64,
    /// Subsystem panic count in monitoring window
    panic_count: u32,
}

impl HealthMetrics {
    fn degradation_from(&self, baseline: &HealthMetrics) -> f64 {
        let mut score = 0.0;
        
        // Performance regression (weight: 0.3)
        if self.avg_tick_duration_us > baseline.avg_tick_duration_us * 2 {
            score += 0.3;
        }
        
        // Prediction accuracy drop (weight: 0.25)
        let pred_delta = baseline.prediction_error_rate - self.prediction_error_rate;
        if pred_delta < -0.1 { // Error rate increased by >10%
            score += 0.25;
        }
        
        // Memory precision drop (weight: 0.2)
        let mem_delta = self.memory_precision - baseline.memory_precision;
        if mem_delta < -0.15 {
            score += 0.2;
        }
        
        // Any panics (weight: 0.25)
        if self.panic_count > 0 {
            score += 0.25;
        }
        
        score // 0.0 = healthy, 1.0 = catastrophic
    }
}
```

**Staged monitoring** after any modification:

| Stage | Timing | Action on threshold breach |
|-------|--------|---------------------------|
| Initial check | 60 seconds after modification | Immediate auto-revert |
| Follow-up 1 | 5 minutes after modification | Auto-revert + log delayed degradation |
| Follow-up 2 | 30 minutes after modification | Auto-revert + flag for user review |

If any stage exceeds the configured `revert_threshold` (default 0.1), the modification is reverted and the system returns to baseline. The staged approach catches both immediate regressions (memory leaks, panics) and slow-burn degradation (gradually worsening prediction accuracy).

### Edge Cases

1. **User changes trust level mid-session**: Takes effect immediately. Pending approvals are re-evaluated against new trust level.
2. **Modification within bounds but harmful**: The 60s auto-revert catches behavioral degradation even for auto-approved changes.
3. **Rapid sequential modifications**: Mutation budget limits daily count. Each modification must pass the 60s window before the next can be applied.
4. **Revert of a revert**: If a revert itself causes issues (unlikely but possible), the immune system detects the pathology and freezes modifications for 24h.
5. **Constitutional module file corruption**: Supervisor detects via signature verification. Kernel is killed and restarted from known-good binary.

---

## 9. Error Handling & Graceful Degradation

Every subsystem degrades gracefully. The kernel never stops ticking. Errors are contained, logged, and recovered from — automatically where possible, with user notification where not.

---

### Design Principle

```
Crash → Contain → Log → Recover → Notify
```

No single subsystem failure should bring down the kernel. Each subsystem runs within a catch boundary. Failures are isolated, logged to telemetry, and the system continues with reduced capability.

### LLM Pool Unavailable

```rust
impl CognitiveKernel {
    fn handle_llm_unavailable(&mut self) {
        // 1. Queue LLM-dependent actions (don't drop them)
        self.pending_llm_actions.extend(
            self.action_queue.drain_llm_dependent()
        );

        // 2. Cap the queue
        while self.pending_llm_actions.len() > 32 {
            let dropped = self.pending_llm_actions.pop_front();
            self.telemetry.log(TelemetryEvent::ActionDropped {
                action: dropped,
                reason: "llm_queue_full",
            });
        }

        // 3. Continue ticking with available subsystems
        // Perception: ✓ (file watching, event detection)
        // Memory activation: ✓ (embedding similarity, no LLM needed)
        // Affect dynamics: ✓ (mathematical computation)
        // Goal market: ✓ (priority math)
        // Prediction L1-L2: ✓ (statistical)
        // Prediction L3-L5: ✗ (needs LLM)
        // Agent society: ✗ (agents need LLM for reasoning)
        // Self-modification: ✗ (patch generation needs LLM)

        // 4. Notify TUI
        self.kernel_tx.send(KernelEvent::HealthEvent(HealthEvent::LlmUnavailable {
            queued_actions: self.pending_llm_actions.len(),
            active_subsystems: self.active_subsystem_list(),
        })).ok();
    }

    fn handle_llm_recovered(&mut self) {
        // Process queued actions in FIFO order
        while let Some(action) = self.pending_llm_actions.pop_front() {
            self.action_queue.inject(action);
        }

        self.kernel_tx.send(KernelEvent::HealthEvent(HealthEvent::LlmRecovered)).ok();
    }
}
```

TUI status bar: `⚠ LLM unavailable — queued actions: 7 | Active: perception, memory, affect, goals`

### Memory Corruption

```rust
impl MemoryPalace {
    fn startup_integrity_check(&mut self) -> IntegrityResult {
        let mut result = IntegrityResult::Healthy;

        for db_path in &self.database_paths() {
            match self.check_sqlite_integrity(db_path) {
                Ok(_) => {}
                Err(CorruptionError::WalCorruption) => {
                    // WAL corruption: try checkpoint recovery
                    if self.recover_wal(db_path).is_err() {
                        result = IntegrityResult::Degraded;
                        self.rebuild_from_journal(db_path);
                    }
                }
                Err(CorruptionError::PageCorruption) => {
                    // Severe: rebuild from journal
                    result = IntegrityResult::Rebuilt;
                    self.rebuild_from_journal(db_path);
                }
            }
        }

        result
    }

    fn rebuild_from_journal(&mut self, db_path: &Path) {
        // Journal is append-only and more durable than SQLite
        let journal = JournalParser::parse_full(&self.journal_path);

        match journal {
            Ok(entries) => {
                // Recreate database from journal entries
                let new_db = Database::create(db_path);
                for entry in entries {
                    self.index_entry(&new_db, &entry);
                }
                self.telemetry.log(TelemetryEvent::MemoryRebuilt {
                    source: "journal",
                    entries_recovered: entries.len(),
                });
            }
            Err(_) => {
                // Journal also corrupted: start fresh
                let new_db = Database::create(db_path);
                self.telemetry.log(TelemetryEvent::Error {
                    subsystem: "memory".into(),
                    message: "Memory loss event: both database and journal corrupted".into(),
                    severity: Severity::Critical,
                });
            }
        }
    }
}
```

### Skill File Corruption

Individual skill files are independent. One corrupted file doesn't affect others.

```rust
fn load_skills(dir: &Path) -> Vec<Skill> {
    let mut skills = vec![];

    for entry in fs::read_dir(dir).unwrap_or_default() {
        let path = entry.path();
        match toml::from_str::<Skill>(&fs::read_to_string(&path).unwrap_or_default()) {
            Ok(skill) => skills.push(skill),
            Err(e) => {
                // Archive corrupted file, don't delete
                let corrupted_path = path.with_extension("toml.corrupted");
                fs::rename(&path, &corrupted_path).ok();
                tracing::warn!("Corrupted skill file archived: {:?} — {}", path, e);
            }
        }
    }

    skills
}
```

### Agent Pathology Detection

The cognitive immune system monitors for behavioral pathologies:

```rust
struct CognitiveImmuneSystem {
    bid_history: HashMap<AgentId, VecDeque<BidRecord>>,
    affect_history: VecDeque<AffectSnapshot>,
    goal_generation_rate: RateTracker,
}

impl CognitiveImmuneSystem {
    fn check_pathologies(&mut self, state: &SystemState) -> Vec<Intervention> {
        let mut interventions = vec![];

        // 1. Infinite bid loop: same agent, same goal, >10 consecutive ticks
        for (agent_id, history) in &self.bid_history {
            if history.len() >= 10 {
                let last_10: Vec<_> = history.iter().rev().take(10).collect();
                let same_goal = last_10.windows(2).all(|w| w[0].goal_id == w[1].goal_id);
                let same_agent = true; // By definition (keyed by agent_id)

                if same_goal && same_agent {
                    interventions.push(Intervention::SuspendAgent {
                        agent: *agent_id,
                        duration_ticks: 100,
                        reason: "Infinite bid loop detected",
                    });
                }
            }
        }

        // 2. Affective stuck: extreme value for >3000 ticks
        if let Some(stuck_dim) = self.detect_affective_stuck(3000) {
            interventions.push(Intervention::AffectPull {
                dimension: stuck_dim,
                target: 0.5,          // Pull toward neutral
                rate: 0.02,           // 2% per tick
                reason: "Affective stuck state detected",
            });
        }

        // 3. Goal flood: generation rate > 5× resolution rate
        let gen_rate = self.goal_generation_rate.per_minute();
        let res_rate = state.goal_resolution_rate.per_minute();
        if gen_rate > res_rate * 5.0 && res_rate > 0.0 {
            interventions.push(Intervention::RaiseGenerationThreshold {
                multiplier: 1.5,
                reason: "Goal flood: generation outpacing resolution 5:1",
            });
            interventions.push(Intervention::DecayAllGoalPriorities {
                factor: 0.9, // Reduce all priorities by 10%
            });
        }

        // Log all interventions
        for intervention in &interventions {
            self.telemetry.log(TelemetryEvent::PathologyDetected {
                kind: intervention.kind(),
                intervention: format!("{:?}", intervention),
            });
        }

        interventions
    }
}
```

### Panic Recovery

```rust
/// Installed as the global panic hook
fn panic_hook(info: &PanicInfo) {
    // 1. Capture state snapshot
    let snapshot = SystemState::capture_emergency();
    let timestamp = Utc::now().format("%Y%m%d_%H%M%S");
    let crash_path = dirs::home_dir()
        .unwrap()
        .join(format!(".kc/crash/{}.bin", timestamp));

    // 2. Write crash dump (best-effort)
    if let Ok(bytes) = bincode::serialize(&snapshot) {
        fs::write(&crash_path, bytes).ok();
    }

    // 3. Log to stderr (TUI may be broken)
    eprintln!("KC PANIC: {}", info);
    eprintln!("Crash dump: {:?}", crash_path);

    // 4. The supervisor process detects the exit and restarts
    // On restart, KC replays from journal to restore state
}

/// On startup after crash
fn recover_from_crash() -> RecoveryResult {
    let crash_files: Vec<_> = fs::read_dir(crash_dir())
        .unwrap_or_default()
        .filter_map(|e| e.ok())
        .collect();

    if crash_files.is_empty() {
        return RecoveryResult::CleanStart;
    }

    // Find most recent crash dump
    let latest = crash_files.iter().max_by_key(|f| f.metadata().unwrap().modified().unwrap());

    if let Some(crash_file) = latest {
        let snapshot: SystemState = bincode::deserialize(&fs::read(crash_file.path()).unwrap())
            .unwrap_or_default();

        // Restore from journal (more reliable than crash dump)
        let journal_state = JournalParser::parse_full(&project_journal_path());

        // Clean up crash files
        for file in crash_files {
            fs::remove_file(file.path()).ok();
        }

        RecoveryResult::Recovered {
            from_tick: snapshot.tick_number,
            message: format!(
                "KC recovered from crash. Session restored from checkpoint tick {}.",
                snapshot.tick_number
            ),
        }
    } else {
        RecoveryResult::CleanStart
    }
}
```

### Subsystem Isolation Pattern

Every subsystem tick phase is wrapped in a catch boundary:

```rust
impl CognitiveKernel {
    async fn tick(&mut self) {
        self.tick_number += 1;

        // Each phase is isolated — one failure doesn't stop others
        if let Err(e) = std::panic::catch_unwind(|| self.perception_phase()) {
            self.handle_subsystem_panic("perception", e);
        }

        if let Err(e) = std::panic::catch_unwind(|| self.prediction_phase()) {
            self.handle_subsystem_panic("prediction", e);
        }

        if let Err(e) = std::panic::catch_unwind(|| self.memory_phase()) {
            self.handle_subsystem_panic("memory", e);
        }

        // ... remaining phases ...

        // Always runs (even if other phases panicked)
        self.affect_phase(); // Pure math, cannot panic
        self.telemetry_phase(); // Best-effort logging
    }

    fn handle_subsystem_panic(&mut self, subsystem: &str, error: Box<dyn Any>) {
        self.telemetry.log(TelemetryEvent::Error {
            subsystem: subsystem.into(),
            message: format!("Panic in {}: {:?}", subsystem, error),
            severity: Severity::High,
        });

        // Notify TUI
        self.kernel_tx.send(KernelEvent::HealthEvent(HealthEvent::SubsystemPanic {
            subsystem: subsystem.into(),
            tick: self.tick_number,
        })).ok();
    }
}
```

### Edge Cases

1. **Cascading failures**: If 3+ subsystems panic in the same tick, trigger full restart via supervisor rather than limping along.
2. **Telemetry itself fails**: If the telemetry database is corrupted, fall back to stderr logging. Never let telemetry failure cascade.
3. **Disk full**: Detected by write failures. Enter minimal mode: stop all writes except crash dumps. Notify user.
4. **OOM**: Rust doesn't have a global OOM handler. Mitigation: monitor RSS via `/proc/self/status` (Linux) every 60s. If approaching limit, trigger memory consolidation (free episodic buffer).
5. **Supervisor crash**: If the supervisor dies, the kernel continues running but loses constitutional verification. On next boot, full integrity check runs.

---

## 10. Configuration, Deployment & Updates

KC ships as a single Rust binary. No runtime dependencies, no auto-update, no telemetry phone-home. Configuration is layered with clear precedence.

---

### Installation

```bash
# From crates.io (requires Rust toolchain)
cargo install kognisant-desktop

# From GitHub releases (pre-built binary)
curl -sSL https://github.com/kognisant/desktop/releases/latest/download/kc-$(uname -s)-$(uname -m) -o kc
chmod +x kc
sudo mv kc /usr/local/bin/

# Verify
kc --version
```

### Updates

Manual only. No auto-update mechanism. No self-update via self-modification (constitutional constraint — the binary on disk is outside the source_mirror scope).

```bash
# Update from crates.io
cargo install kognisant-desktop --force

# Update from GitHub releases
# Same curl command as install (overwrites binary)
```

Rationale: Auto-update in a system that can self-modify its own source code creates a confusing trust boundary. The user must explicitly choose to update the base binary.

### Configuration Hierarchy

Precedence (highest wins):

```
5. CLI flags              kc --trust-level=paranoid
4. Environment variables  KC_TRUST_LEVEL=paranoid
3. Project config         .kc/config.toml
2. User config            ~/.kc/config.toml
1. Built-in defaults      (compiled into binary)
```

Resolution at startup:

```rust
fn resolve_config() -> Config {
    let mut config = Config::builtin_defaults();

    // Layer 2: user config
    if let Ok(user_config) = load_toml("~/.kc/config.toml") {
        config.merge(user_config);
    }

    // Layer 3: project config
    if let Some(project_root) = find_project_root(&std::env::current_dir().unwrap()) {
        if let Ok(project_config) = load_toml(project_root.join(".kc/config.toml")) {
            config.merge(project_config);
        }
    }

    // Layer 4: environment variables
    config.merge_env("KC_");

    // Layer 5: CLI flags
    config.merge_cli(std::env::args());

    config
}
```

### Full `config.toml` Schema

```toml
# ~/.kc/config.toml — User-level configuration
# All values shown are built-in defaults.
# Uncomment and modify to override.

# ─────────────────────────────────────────────
# General
# ─────────────────────────────────────────────

[general]
# Trust level for self-modification approval
# Values: "paranoid" | "cautious" | "autonomous"
trust_level = "cautious"

# Default TUI visibility mode on startup
# Values: "focus" | "trace" | "paranoia"
default_mode = "focus"

# Tick rate (Hz) when user is active
active_tick_rate = 10

# Tick rate (Hz) when user is idle (>60s no input)
idle_tick_rate = 1

# ─────────────────────────────────────────────
# LLM Pool
# ─────────────────────────────────────────────

[llm]
# Prefer local models (Ollama) over remote
prefer_local = true

# Provider timeout (seconds)
provider_timeout_secs = 30

# Health check interval (seconds)
health_check_interval_secs = 60

# Response cache TTL (seconds)
cache_ttl_secs = 3600

# Cache max size (MB)
cache_max_size_mb = 100

[llm.budget]
# Cost limits (USD). Set to 0 for unlimited.
max_per_query = 0.05
max_per_hour = 1.0
max_per_day = 10.0
max_per_month = 100.0

# Action when budget exceeded
# Values: "require_approval" | "block" | "warn"
over_budget_action = "require_approval"

[llm.providers.ollama]
enabled = true
host = "http://localhost:11434"
# Models are auto-detected

[llm.providers.openai]
enabled = false
# API key read from OPENAI_API_KEY env var
# base_url = "https://api.openai.com/v1"  # Override for compatible APIs

[llm.providers.anthropic]
enabled = false
# API key read from ANTHROPIC_API_KEY env var

[llm.providers.kognisant]
enabled = true
# Managed API — token stored in ~/.kc/auth/

# ─────────────────────────────────────────────
# Approval System
# ─────────────────────────────────────────────

[approval]
# Default timeout for approval dialogs (seconds)
# Set to 0 for no timeout (wait indefinitely)
default_timeout_secs = 300

# Queue capacity
queue_capacity = 8

# Category-specific overrides
[approval.categories]
# Values: "always" | "configurable" | "never"
# "configurable" respects the sub-settings below
destructive = "always"
structural = "always"
external = "configurable"
persistent = "configurable"
autonomous = "always"

[approval.external]
# When external = "configurable":
# Auto-approve local network requests (localhost, 127.0.0.1, LAN)
auto_approve_local = true
# Require approval for remote/internet requests
require_remote = true

[approval.persistent]
# When persistent = "configurable":
# Auto-approve project-local memory writes
auto_approve_project_local = true
# Require approval for user-level memory/skill writes
require_user_level = true

# ─────────────────────────────────────────────
# Memory
# ─────────────────────────────────────────────

[memory]
# Embedding model (auto-selected based on hardware if "auto")
# Values: "auto" | "minilm" | "nomic" | "api"
embedding_model = "auto"

# Working memory capacity (slots)
wm_capacity = 7

# Consolidation idle threshold (seconds of no user input)
consolidation_idle_threshold_secs = 60

# HNSW parameters
[memory.hnsw]
m = 16
ef_construction = 200
ef_search = 50

# ─────────────────────────────────────────────
# Telemetry
# ─────────────────────────────────────────────

[telemetry]
# Retention period for active database (days)
retention_days = 30

# Retention period for compressed archives (days)
archive_days = 365

# Maximum database size before forced cleanup (MB)
max_db_size_mb = 500

# Enable/disable telemetry (disabling removes replay capability)
enabled = true

# ─────────────────────────────────────────────
# Skills
# ─────────────────────────────────────────────

[skills]
# Mining trigger threshold (unprocessed journal entries)
mining_threshold = 20

# Cluster similarity threshold
cluster_similarity = 0.85

# Minimum cluster size for skill suggestion
min_cluster_size = 2

# Default skill half-life (days)
default_half_life_days = 365

# Weekly review: max suggestions per cycle
max_suggestions_per_week = 5

# ─────────────────────────────────────────────
# Self-Modification
# ─────────────────────────────────────────────

[self_modification]
# Enable/disable self-modification entirely
enabled = true

# Initial daily budget (modifications per 24h)
daily_budget = 5

# Minimum stability window between modifications (seconds)
stability_window_secs = 1800

# Rollback cooldown after a failed modification (seconds)
rollback_cooldown_secs = 7200

# Health monitoring window after modification (seconds)
health_monitor_secs = 60

# Degradation threshold for auto-revert (0.0-1.0)
revert_threshold = 0.1

[self_modification.bounds]
# Hyperparameter bounds for auto-approval in "cautious" mode
# Format: [min, max] — changes within bounds are auto-approved

[self_modification.bounds.memory]
decay_rate = [0.0001, 0.01]
activation_threshold = [0.2, 0.8]

[self_modification.bounds.affect]
decay_rate = [0.005, 0.05]
extreme_threshold = [0.8, 0.95]

[self_modification.bounds.goals]
priority_decay = [0.0005, 0.005]
generation_threshold = [0.4, 0.7]

# ─────────────────────────────────────────────
# Journal
# ─────────────────────────────────────────────

[journal]
# Auto-rotate at this file size (bytes). 0 = never auto-rotate.
auto_rotate_bytes = 10_485_760  # 10MB

# File watch debounce (milliseconds)
watch_debounce_ms = 100
```

### Environment Variable Mapping

All config values can be overridden via environment variables with `KC_` prefix. Nested keys use `__` (double underscore) as separator:

```
KC_GENERAL__TRUST_LEVEL=paranoid
KC_LLM__PREFER_LOCAL=false
KC_LLM__BUDGET__MAX_PER_DAY=50.0
KC_APPROVAL__DEFAULT_TIMEOUT_SECS=600
KC_TELEMETRY__ENABLED=false
KC_SELF_MODIFICATION__ENABLED=false
```

### Live Reload

Config file changes are detected via file watcher (same mechanism as journal watching).

**Immediately applied** (no restart needed):
- Trust level
- Approval thresholds and timeouts
- LLM budget limits
- Telemetry retention settings
- Skill mining parameters
- Self-modification bounds
- Visibility mode default

**Requires restart** (noted in config comments):
- Tick rate changes
- Embedding model change (requires re-indexing)
- HNSW parameters (requires index rebuild)
- Provider enable/disable (requires re-discovery)

```rust
impl ConfigWatcher {
    async fn handle_config_change(&self, path: &Path) {
        let new_config = match load_toml(path) {
            Ok(c) => c,
            Err(e) => {
                tracing::warn!("Invalid config change ignored: {}", e);
                return; // Don't apply broken config
            }
        };

        let diff = self.current_config.diff(&new_config);

        for change in &diff.changes {
            if change.requires_restart() {
                self.kernel_tx.send(KernelEvent::HealthEvent(
                    HealthEvent::ConfigChangeRequiresRestart {
                        key: change.key.clone(),
                    }
                )).ok();
            } else {
                // Apply immediately
                self.current_config.apply_change(change);
            }
        }

        tracing::info!("Config reloaded: {} changes applied", diff.applied_count());
    }
}
```

### Headless Mode

```bash
kc --headless
```

- No TUI rendering (stdout is silent)
- No approval dialogs — actions approved based on allowlist (not blanket auto-approve)
- Requires explicit opt-in: `KC_HEADLESS_CONFIRM=yes-i-understand-the-risks` env var must also be set
- Useful for CI pipelines where KC manages build/test orchestration
- Telemetry still records everything (audit trail preserved)
- Exits with non-zero status on unrecoverable error

```rust
struct HeadlessConfig {
    /// Explicit allowlist of action categories permitted without approval
    allowed_categories: Vec<ApprovalCategory>,
    /// Explicit denylist (overrides allowlist)
    denied_actions: Vec<String>,
    /// Maximum cost per action in headless mode (USD)
    max_action_cost: f64,
}

// Default headless config (conservative)
impl Default for HeadlessConfig {
    fn default() -> Self {
        Self {
            allowed_categories: vec![
                ApprovalCategory::External,   // API calls OK in CI
                ApprovalCategory::Persistent, // Memory writes OK
            ],
            denied_actions: vec![
                "file_delete".into(),
                "git_force_push".into(),
                "self_modify".into(),
            ],
            max_action_cost: 1.0, // $1 max per action
        }
    }
}
```

Config in TOML:

```toml
[headless]
allowed_categories = ["external", "persistent"]
denied_actions = ["file_delete", "git_force_push", "self_modify"]
max_action_cost = 1.0
```

Actions not in allowlist AND not in denylist → denied with log entry. The denylist always takes precedence over the allowlist (a denied action is never executed regardless of category).

Output format:

```rust
struct HeadlessMode {
    /// Allowlist-based approval (replaces blanket auto-approve)
    config: HeadlessConfig,
    /// Output goes to structured JSON on stdout (for CI parsing)
    output_format: OutputFormat::JsonLines,
    /// Exit conditions
    exit_on: ExitCondition::GoalComplete | ExitCondition::Error,
}
```

### Daemon Mode

```bash
kc --daemon
```

- Runs in background (daemonizes)
- No TUI — communicates via Unix socket at `~/.kc/kc.sock`
- PID file at `~/.kc/kc.pid`
- Useful for IDE integrations (VS Code extension, Neovim plugin)
- Approval requests sent via socket, responses received via socket
- Supports multiple simultaneous clients (one per project)

```rust
struct DaemonMode {
    socket_path: PathBuf,     // ~/.kc/kc.sock
    pid_file: PathBuf,        // ~/.kc/kc.pid
    /// Protocol: newline-delimited JSON over Unix socket
    protocol: Protocol::NdJson,
}

// Client connects and sends:
// {"type": "attach", "project": "/path/to/project"}
// Server responds with event stream (same KernelEvent types, JSON-serialized)
// Client sends commands (same UserCommand types, JSON-serialized)
```

#### Daemon Authentication

```rust
struct DaemonAuth {
    /// Token generated on daemon start, written to ~/.kc/daemon.token
    /// Client must send this token in the first message to authenticate
    session_token: String,
    /// Only allow connections from same UID (Unix) or same user (Windows)
    same_user_only: bool,
}

// On daemon start:
fn start_daemon() {
    let token = generate_random_token(32); // 32 bytes, hex-encoded
    fs::write("~/.kc/daemon.token", &token)?;
    fs::set_permissions("~/.kc/daemon.token", Permissions::from_mode(0o600))?;
    
    // Socket permissions: owner-only
    let socket = UnixListener::bind("~/.kc/kc.sock")?;
    fs::set_permissions("~/.kc/kc.sock", Permissions::from_mode(0o600))?;
}

// Client authentication:
// First message MUST be: {"type": "auth", "token": "<contents of daemon.token>"}
// If token doesn't match → connection dropped immediately
```

Authentication is mandatory. There is no `--no-auth` flag. The token file and socket are both restricted to owner-only permissions. On Windows, equivalent ACL restrictions apply (see Platform Compatibility below).

### First-Run Experience

On first invocation (no `~/.kc/` exists):

1. Create `~/.kc/` directory structure
2. Generate default `config.toml` with all defaults commented out
3. Detect available LLM providers (Ollama, env vars)
4. Display welcome message in TUI:
   ```
   Welcome to KC. No project detected.
   Run `kc init .` in a project directory to get started.
   
   Detected providers: Ollama (3 models), OpenAI (API key found)
   Trust level: cautious (default)
   ```

### Edge Cases

1. **Config syntax error**: Invalid TOML is rejected. Previous valid config remains active. Warning shown in TUI.
2. **Conflicting project/user config**: Project config wins for project-scoped settings. User config wins for user-scoped settings (skills, preferences). Explicit precedence rules prevent ambiguity.
3. **Binary version mismatch**: If `~/.kc/` was created by a newer version, older binary detects via version field in `~/.kc/meta.toml`. Warns user but attempts to continue (forward-compatible where possible).
4. **Headless mode without confirmation env var**: Exits immediately with error: "Headless mode requires KC_HEADLESS_CONFIRM=yes-i-understand-the-risks"
5. **Daemon mode port conflict**: If socket already exists, check if PID is alive. If alive, error "KC daemon already running (PID {})". If stale, remove socket and start.
6. **Read-only filesystem**: Detected on first write attempt. Enter read-only mode: no journal, no memory writes, no telemetry. Notify user.

### Platform Compatibility

```rust
#[cfg(unix)]
mod platform {
    pub fn daemon_socket_path() -> PathBuf {
        dirs::home_dir().unwrap().join(".kc/kc.sock")
    }
    pub type Listener = tokio::net::UnixListener;
}

#[cfg(windows)]
mod platform {
    pub fn daemon_pipe_name() -> String {
        r"\\.\pipe\kc-daemon".to_string()
    }
    pub type Listener = tokio::net::windows::named_pipe::ServerOptions;
}
```

Platform differences:

| Feature | Unix/macOS | Windows |
|---------|-----------|---------|
| Daemon IPC | Unix socket (`~/.kc/kc.sock`) | Named pipe (`\\.\pipe\kc-daemon`) |
| File permissions | `chmod 0600` for sensitive files | ACL-based (owner-only) |
| Process supervision | `fork()` + PID file | Windows Service or background process |
| File watching | inotify (Linux) / kqueue (macOS) | ReadDirectoryChangesW |
| Terminal | crossterm handles all platforms | crossterm handles all platforms |

The TUI itself (ratatui + crossterm) is fully cross-platform. Platform-specific code is isolated to the `platform` module. All path handling uses `PathBuf` (never string concatenation with `/`). The `dirs` crate resolves home directory correctly on all platforms.

---

## Summary of Key Invariants

These invariants hold across all 10 specifications:

1. **The tick never stops.** No subsystem failure, approval wait, or LLM outage pauses the cognitive loop.
2. **User input is never dropped.** The TUI→kernel channel has sufficient capacity and blocks rather than drops.
3. **Constitutional modules are immutable.** Cryptographic enforcement, not policy enforcement.
4. **Journal is the durable source of truth.** Memory can be rebuilt from it. It is append-only during normal operation.
5. **Errors are contained.** One subsystem panic does not cascade. The kernel continues with reduced capability.
6. **Configuration is layered and live-reloaded.** No restart needed for most changes.
7. **Cost is tracked and bounded.** No surprise bills. Budget enforcement is built into the routing layer.
8. **Telemetry is always on.** The system cannot silence its own audit trail (constitutional constraint).
9. **Self-modification is bounded.** Mutation budget, trust levels, auto-revert, and constitutional protection create nested safety boundaries.
10. **Local-first, single binary.** No runtime dependencies, no network requirements for core operation, no auto-update.
11. **No locks on the hot path.** The tick loop uses `tokio::sync::watch` for state broadcast and owned data flow between phases — no `Mutex` or `RwLock` contention.
12. **Headless mode is allowlist-gated.** No blanket auto-approve. Actions must be explicitly permitted by category, and the denylist always wins.
13. **Daemon connections are authenticated.** Token-based auth on first message, owner-only file permissions, no anonymous access.
14. **Telemetry is per-project.** One SQLite database per project. No cross-project contamination. Orphan detection on startup.
15. **Health monitoring is staged.** Modifications are monitored at 60s, 5min, and 30min. Any stage can trigger auto-revert.
