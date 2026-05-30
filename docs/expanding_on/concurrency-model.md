# Concurrency Model — Integration Specification

The concurrency model resolves how the cognitive kernel, tokio runtime, agent society, and LLM pool interact at the execution level. It specifies what is sequential, what is async, and why.

---

## Summary

The cognitive tick loop is single-threaded and sequential. Agents do not run concurrently — they bid and execute in order within a tick. Tokio provides async I/O for file watching, LLM streaming, tool execution, and the TUI event loop, but cognition itself is a deterministic sequential pipeline. LLM queries are fire-and-forget within a tick; responses arrive as perception in future ticks. The system achieves "pseudo-continuous" operation through 10Hz discrete sampling, not true continuous computation.

---

## The Tick Loop Is Single-Threaded

The cognitive tick loop runs on a SINGLE tokio task. Agents are synchronous functions called sequentially within the Deliberation phase. There is NO concurrent agent execution. The "society of mind" is a sequential simulation, not a parallel system.

```rust
// The tick loop is NOT concurrent. It's sequential:
async fn tick(&mut self) {
    // Phase 1: Perception (sync — polls file watcher, reads channels)
    let sensations = self.perception.gather();
    
    // Phase 2: Prediction (sync — runs PP layers sequentially)
    let predictions = self.predictive_stack.generate(&sensations);
    
    // Phase 3: Comparison (sync — compute surprise)
    let surprises = self.compare(&predictions, &sensations);
    
    // Phase 4: Update (sync — update beliefs, activate memories)
    self.update(&surprises);
    
    // Phase 5: Deliberation (sync — agents bid SEQUENTIALLY)
    let bids: Vec<GoalBid> = self.agents.iter_mut()
        .filter(|a| self.schedule.should_run(a.id(), self.tick_number))
        .map(|agent| agent.bid(&self.state))
        .flatten()
        .collect();
    let actions = self.goal_market.resolve(bids, &self.affect);
    
    // Phase 6: Action (ASYNC — tool execution, LLM queries fire here)
    for action in actions {
        self.execute_action(action).await;
    }
    
    // Phase 7: Broadcast state (sync — write to watch channel)
    self.state_tx.send(self.snapshot());
}
```

### Why Sequential Cognition?

1. **Determinism**: Given the same inputs, the same tick produces the same outputs. Essential for replay (see `state-consistency.md`).
2. **No synchronization overhead**: No mutexes, no lock contention, no deadlocks. The kernel owns all cognitive state exclusively.
3. **Predictable timing**: Each phase has a bounded cost. The 100ms budget is achievable because we know exactly what runs.
4. **Debuggability**: A sequential trace is trivially inspectable in Paranoia mode. Concurrent traces require causal ordering.

---

## Why Tokio Then?

Tokio is used for async I/O substrate, not parallelism for cognition:

| Use Case | Why Async | Runs Where |
|----------|-----------|-----------|
| File watcher events | `notify` crate delivers via async channel | Separate tokio task |
| LLM streaming | HTTP connections, SSE parsing, backpressure | Spawned tasks (fire-and-forget) |
| Tool execution | Shell commands with timeout, stdout capture | Spawned tasks (fire-and-forget) |
| TUI event loop | Terminal input polling, render scheduling | Separate tokio task |
| Timer scheduling | Tick interval, health checks, periodic re-discovery | tokio::time |
| Supervisor heartbeat | Periodic ping to supervisor process | Separate tokio task |

The cognitive loop itself is one `async fn` that awaits the tick interval timer, then runs synchronous computation. The `async` keyword is present only because it needs to `.await` the timer and fire off spawned tasks in the Action phase.

---

## LLM Queries Are Fire-and-Forget Within a Tick

When an agent's action requires an LLM query:

1. The Action phase fires the HTTP request (non-blocking spawn)
2. The tick completes WITHOUT waiting for the response
3. The LLM response arrives as a `SensoryChannel::LlmResponse` in a FUTURE tick's Perception phase
4. The agent that requested it sees the response as new sensory input and continues

This means LLM queries span multiple ticks. An agent bids, wins, fires a query, then waits (potentially 5-50 ticks at 10Hz, i.e., 500ms-5s) for the response to arrive as perception. During that time, other agents can bid and execute.

```rust
// LLM queries are async but don't block the tick
async fn execute_action(&mut self, action: Action) {
    match action {
        Action::LlmQuery(query) => {
            // Fire and forget — response arrives via perception channel
            let perception_tx = self.perception_tx.clone();
            tokio::spawn(async move {
                let response = llm_pool.query(query).await;
                perception_tx.send(SensoryEvent::LlmResponse(response)).ok();
            });
        }
        Action::ToolExec(tool) => {
            // Also async — result arrives via perception
            let perception_tx = self.perception_tx.clone();
            tokio::spawn(async move {
                let result = tool.execute().await;
                perception_tx.send(SensoryEvent::ToolOutput(result)).ok();
            });
        }
        Action::SendMessage(msg) => {
            // Sync — immediate (writes to TUI event channel)
            self.event_tx.send(KernelEvent::Message(msg)).ok();
        }
    }
}
```

### Implications for Agent Design

Agents must be designed for multi-tick workflows:

1. Agent bids on a goal requiring LLM output
2. Agent wins, fires LLM query, records `pending_query_id` in its internal state
3. Agent does NOT bid on the same goal next tick (it's waiting)
4. When `LlmResponse` arrives in perception, the agent recognizes its `query_id`
5. Agent bids again with the response data, now ready to produce final output

This is analogous to async/await but at the cognitive level — the "await point" is the tick boundary.

---

## Cold-Start Protocol

The first 100 ticks use bootstrap goals that bypass the market:

```rust
const BOOTSTRAP_TICKS: u64 = 100;

fn bootstrap_goals() -> Vec<Goal> {
    vec![
        Goal {
            id: Uuid::nil(),
            origin: GoalOrigin::Bootstrap,
            description: "Load project context from .kc/".into(),
            priority: 1.0,
            assigned_agent: Some(AgentId::Planner),
        },
        Goal {
            id: Uuid::nil(),
            origin: GoalOrigin::Bootstrap,
            description: "Parse steering documents".into(),
            priority: 0.9,
            assigned_agent: Some(AgentId::Planner),
        },
        Goal {
            id: Uuid::nil(),
            origin: GoalOrigin::Bootstrap,
            description: "Index project files for perception".into(),
            priority: 0.8,
            assigned_agent: Some(AgentId::Coder),
        },
    ]
}

impl GoalMarket {
    fn tick(&mut self, tick: u64, surprises: &[Surprise], affect: &AffectState) {
        if tick <= BOOTSTRAP_TICKS {
            // Direct assignment, no bidding
            self.active_goals = bootstrap_goals();
            return;
        }
        // Normal market operation after bootstrap
        self.generate_from_surprise(surprises, affect);
        // ...
    }
}
```

### Bootstrap Sequence

| Tick Range | Activity | Purpose |
|-----------|----------|---------|
| 1-10 | Load `.kc/` directory, parse config | Establish project identity |
| 11-30 | Parse steering documents, load skills | Establish constraints and capabilities |
| 31-60 | Index project files, build initial embeddings | Seed perception and memory |
| 61-80 | Run initial PP calibration (high learning rate) | Establish baseline predictions |
| 81-100 | Transition to market operation (gradual) | Smooth handoff to emergent behavior |

During bootstrap:
- PP layers run with `α = 0.1` (fast adaptation) instead of normal rates
- Affect is clamped to neutral (no curiosity-driven exploration yet)
- Self-modification is disabled
- The immune system is in observation-only mode

### Post-Bootstrap Transition

The transition from bootstrap to market is gradual, not abrupt:

```rust
fn bootstrap_weight(tick: u64) -> f64 {
    if tick <= 80 { return 1.0; }
    if tick > 100 { return 0.0; }
    // Linear ramp-down from tick 80-100
    1.0 - ((tick - 80) as f64 / 20.0)
}

// During ticks 80-100, both bootstrap goals and market goals coexist
// Bootstrap goals have their priority multiplied by bootstrap_weight
// Market goals compete normally
// By tick 101, bootstrap goals have zero weight and are removed
```

---

## Why 10Hz Is "Pseudo-Continuous" (Tension 1 Resolution)

### The Tension

The architecture claims "continuous cognition" but implements discrete 10Hz ticks. This is an honest design tradeoff, not a contradiction.

### Resolution

The system is NOT truly continuous. It's discrete sampling at 10Hz. The "continuous" claim means:

- The system is ALWAYS running (not turn-based, not event-driven, not request-response)
- It processes time in small enough quanta (100ms) that it appears continuous to humans
- Predictions are generated BEFORE observations arrive (proactive, not reactive)
- The system has internal state that evolves even without external input

### Why 10Hz?

The 10Hz rate was chosen because:

| Constraint | Requirement | How 10Hz Satisfies |
|-----------|-------------|-------------------|
| UX responsiveness | < 200ms perceived latency | 100ms tick + render = ~150ms worst case |
| Tick budget | All phases must complete | Sequential phases fit in 100ms on Standard tier |
| Hardware sustainability | Must not saturate CPU | 10Hz leaves 90%+ CPU idle for spawned tasks |
| Event timescale | Match observed events | File saves, typing bursts occur at 1-10Hz |
| Prediction utility | Predictions must arrive before observations | 100ms lookahead is meaningful for human-speed events |

### Why Not Event-Driven?

Event-driven was explicitly rejected because:

1. **Can't generate predictions without a clock** — when do you predict if nothing happened? The PP stack needs regular ticks to generate predictions that can then be surprised.
2. **Non-deterministic execution order** — burst of events = unpredictable processing order, making replay impossible.
3. **Resource usage is unpredictable** — burst of events = burst of computation = thermal spikes, latency spikes.
4. **No idle-time cognition** — consolidation, self-reflection, and curiosity-driven exploration require the system to "think" even when nothing external is happening.

### Adaptive Tick Rate

The 10Hz rate is the ACTIVE rate. The system drops to 1Hz when idle (user inactive > 60s, no pending goals) and 5Hz during recovery (inflammation > 0.5). The MCC controls this adaptation based on system load and affect state.

---

## Agent State Access

Agents don't access shared mutable state. They receive an immutable snapshot:

```rust
trait CognitiveAgent {
    /// Agents receive a READ-ONLY view of system state
    fn bid(&self, state: &StateView) -> Vec<GoalBid>;
    
    /// Agents receive their allocated resources and execute
    fn execute(&mut self, allocation: &ResourceAllocation, tools: &ToolRegistry) -> Vec<Action>;
    
    /// Agents learn from outcomes (mutates only their own internal state)
    fn learn(&mut self, outcome: &ActionOutcome);
}

/// Immutable snapshot passed to agents — no shared mutable state
struct StateView {
    tick: u64,
    active_goals: &[Goal],
    surprises: &[Surprise],
    affect: &AffectVector,
    wm_contents: &[MemoryChunk],
    pending_approvals: usize,
    llm_status: LlmPoolStatus,
}
```

Each agent owns its internal state (confidence, strategy weights, pattern buffers). The kernel owns the global state. No sharing, no locks, no races.

### What Agents Can Mutate

| Mutable By Agent | Mutable By Kernel Only |
|-----------------|----------------------|
| Own confidence scores | Affect vector |
| Own strategy weights | Working memory contents |
| Own pattern buffers | Active goals list |
| Own pending query IDs | PP layer weights |
| Own coalition history | Tick counter |

---

## Coalition Execution Is Sequential

When a coalition forms (e.g., Research → Code → Test), the members execute in dependency order within the SAME tick's Action phase:

```rust
fn execute_coalition(&mut self, coalition: &Coalition) -> Vec<Action> {
    let mut all_actions = vec![];
    
    // Members are pre-sorted by dependency order
    for member in &coalition.members {
        let agent = self.agents.get_mut(member.agent_id);
        let actions = agent.execute(&member.allocation, &self.tools);
        
        // Each member's output is available to the next member
        // via the perception channel (arrives next tick)
        all_actions.extend(actions);
    }
    
    all_actions
}
```

However, if a coalition member's action depends on another member's OUTPUT (not just execution), it must wait until a future tick:

1. Tick N: Research agent fires LLM query for documentation
2. Tick N+1 to N+30: Response arrives via perception
3. Tick N+31: Coder agent sees research results in perception, bids to implement
4. Tick N+31: Coalition re-forms with Coder ready to execute

Coalitions are NOT persistent across ticks. They dissolve after each execution and re-form if conditions still warrant it (see `agent-society.md`).

---

## Inter-Agent Dependencies Across Ticks

When an agent's action depends on another agent's output:

### The Pattern

```
Tick N:   Agent A bids → wins → fires action (e.g., LLM query)
Tick N+1: Agent A does NOT bid (waiting for response)
          Agent B bids on unrelated goal → wins → executes
Tick N+K: LLM response arrives in perception
          Agent A recognizes its response → bids with result → wins → produces output
Tick N+K+1: Agent C sees Agent A's output in perception → bids to continue
```

### Why This Works

- No blocking: the system never waits. Other agents fill the gap.
- No coordination protocol: agents independently recognize relevant perception.
- Deterministic: given the same perception sequence, the same agent wins.
- Natural prioritization: urgent goals get served while slow queries complete.

### What If the Response Never Arrives?

Each agent tracks pending queries with a timeout (default: 300 ticks / 30 seconds). If a response doesn't arrive within the timeout, the agent bids to either retry the query or abandon the goal. The immune system's `InfiniteBidLoopDetector` catches agents stuck in perpetual retry cycles.

---

## Interaction with Tick Scheduling

Not all agents run every tick. The tick scheduler (defined in `architecture-decisions.md` §1) determines which subsystems are active:

```
Agent bidding runs at 2Hz (every 5 ticks).
Goal market runs at 5Hz (every 2 ticks).
```

This means:
- Agents can only bid on ticks divisible by 5
- Between bidding ticks, previously-won actions continue executing (spawned tasks)
- The goal market updates priorities more frequently than agents bid
- This creates a natural "think before acting" rhythm

---

## Edge Cases

1. **Tick overrun**: If a tick takes > 100ms (expensive perception, many agents), the next tick is delayed but NOT skipped. The system falls behind real-time temporarily. The MCC detects this and may reduce tick rate or shed agents.

2. **Spawned task panic**: If a `tokio::spawn`ed LLM query or tool execution panics, the perception channel never receives the response. The agent's timeout mechanism handles this (see above).

3. **Channel backpressure on perception**: If spawned tasks produce results faster than the tick loop consumes them, the perception channel buffers them. Channel capacity is 256 events. If full, spawned tasks block (acceptable — they're background work).

4. **Multiple LLM responses in one tick**: If several queries complete between ticks, all responses arrive in the same Perception phase. Multiple agents may recognize their responses simultaneously and all bid in the same Deliberation phase. The market resolves normally.

5. **Agent execution exceeds budget**: If an agent's `execute()` call takes too long (e.g., expensive local computation), it delays subsequent agents in the same tick. Mitigation: agents have a per-execution time budget enforced by the MCC. Exceeding it triggers a warning and potential shedding.

6. **Bootstrap interrupted**: If the system is shut down during bootstrap (ticks 1-100), the next boot starts bootstrap from scratch. Bootstrap state is NOT checkpointed — it's fast enough to redo (~10 seconds).

---

## Interaction with Other Subsystems

- **TUI**: Runs on a separate tokio task. Reads kernel state via `watch` channel (never blocks the tick loop). See `architecture-decisions.md` §1 for channel architecture.
- **LLM Pool**: Queries are spawned as independent tokio tasks. The pool handles provider selection, fallback, and streaming internally. Results flow back via the perception channel. See `llm-pool.md` for routing details.
- **Cognitive Homeostasis**: The supervisor monitors tick duration via heartbeat. If ticks consistently overrun, the supervisor sends `ReduceLoad` command. See `cognitive-homeostasis.md` for escalation.
- **Self-Modification**: Compilation and shadow runtime evaluation run as background tokio tasks, completely outside the tick loop. Only the final hot-reload requires supervisor coordination. See `self-modification.md` for the full pipeline.
- **Memory Palace**: Memory activation runs synchronously within the Update phase. Consolidation runs as a background task during idle periods (triggered by MCC, not by the tick loop). See `memory-palace.md` for consolidation scheduling.
- **Telemetry**: Tick snapshots are written to the telemetry database via a background task that reads the `watch` channel. Never blocks the tick loop.
- **Replay System**: Deterministic replay requires that all non-determinism (LLM responses, tool outputs, file events) is recorded. The perception channel is the recording point — everything that enters perception is logged. See `state-consistency.md` for replay guarantees.

---

## Research References

- **Tokio documentation** — Task model, cooperative scheduling, spawn semantics
- **Anderson, J.R. (2007)**. "How Can the Human Mind Occur in the Physical Universe?" — ACT-R's serial bottleneck model
- **Baars, B.J. (1988)**. "A Cognitive Theory of Consciousness" — Global Workspace Theory (sequential broadcast)
- **Relevant crates**: `tokio` (async runtime), `notify` (file watcher), `crossterm` (terminal I/O), `reqwest` (HTTP for LLM)
