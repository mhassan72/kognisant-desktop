# Kognisant Desktop — True Proto-AGI Architecture v3.0

> A continuous, self-modifying, predictive processing engine running locally as a TUI application. The architecture treats cognition as an emergent property of interacting subsystems rather than a sequential pipeline. All data stays on-device, encrypted at rest, with optional E2E encrypted cloud sync for disaster recovery and multi-device continuity. LLM inference is one cognitive modality among many, routed through the LLM Pool.

Last updated: 2025-01-15

---

## Table of Contents

- [Philosophy: From Agent to Proto-AGI](#philosophy-from-agent-to-proto-agi)
- [Core Thesis: Predictive Processing + Active Inference](#core-thesis-predictive-processing--active-inference)
- [Architecture Overview](#architecture-overview)
- [TUI Architecture](#tui-architecture)
- [The Continuous Cognitive Loop](#the-continuous-cognitive-loop)
- [Neuro-Symbolic Memory Palace](#neuro-symbolic-memory-palace)
- [The Self as Homunculus](#the-self-as-homunculus)
- [Affective-Valence Economy](#affective-valence-economy)
- [Emergent Multi-Agent Society](#emergent-multi-agent-society)
- [Autonomous Goal & Value System](#autonomous-goal--value-system)
- [World Simulation Engine](#world-simulation-engine)
- [Bounded Recursive Evolution](#bounded-recursive-evolution)
- [Meta-Cognitive Controller](#meta-cognitive-controller)
- [Hardware-Aware Scaling](#hardware-aware-scaling)
- [Perception-Action Loop](#perception-action-loop)
- [LLM Pool — Local Multi-Provider Router](#llm-pool--local-multi-provider-router)
- [Project Cognition Context](#project-cognition-context)
- [Skill Extraction Pipeline](#skill-extraction-pipeline)
- [Structured Journal System](#structured-journal-system)
- [Execution Pipeline & Safety Architecture](#execution-pipeline--safety-architecture)
- [Replay System](#replay-system)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Implementation Phases](#implementation-phases)
- [Encrypted Cloud Sync & Disaster Recovery](#encrypted-cloud-sync--disaster-recovery)
- [Cognitive Homeostasis Layer](#cognitive-homeostasis-layer)
- [Safety & Containment](#safety--containment)
- [Appendix: Formal Definitions](#appendix-formal-definitions)

---

## Philosophy: From Agent to Proto-AGI

### What Makes This "True" Proto-AGI

The v1 architecture was an advanced agent — reactive, turn-based, externally prompted. The v2 architecture introduced continuous cognition but was coupled to an Electron GUI. This v3 architecture is a pure cognitive runtime — a single Rust binary running in the terminal, with full observability through three TUI visibility modes.

| Dimension | Advanced Agent (v1) | Proto-AGI (v3) |
|-----------|-------------------|----------------|
| Time | Discrete turns | Continuous flow |
| Activation | User-prompted | Always running, self-activated |
| Memory | Retrieval (search) | Reconstruction, consolidation, dreaming |
| Goals | User-assigned | Generated from prediction errors, curiosity, value gradients |
| Learning | Prompt evolution | Meta-learning, strategy acquisition, architecture self-modification |
| World Model | Belief graph | Predictive simulation with counterfactuals |
| Self | Confidence scores | Running homunculus that simulates the system itself |
| Affect | 6 dimensions logged | Drives resource allocation, risk assessment, exploration |
| Multi-agent | Task decomposition | Society of mind: competing/cooperating cognitive processes |
| Improvement | Fork-and-compare | Self-modifies source code, recompiles, hot-reloads |
| Interface | Electron GUI | TUI with 3 visibility modes (Focus, Trace, Paranoia) |
| Delivery | Node.js + NAPI-RS bridge | Single Rust binary, no runtime dependencies |

### The Shift in Design Paradigm

Old paradigm: `Input → Process → Output → Store`
New paradigm: `Continuous prediction → Surprise → Update → Predict again`

The system is always predicting what will happen next: user messages, file changes, build outcomes, its own internal states. Prediction error (surprise) is the fundamental currency of cognition. Minimizing long-term surprise (free energy) drives all behavior.

### Design Principle: Transparent Cognition

The user should always understand:
1. **What** the system is doing (current action, active goals)
2. **Why** it's doing it (which prediction error triggered this goal)
3. **What could happen next** (predicted outcomes, alternative paths)
4. **How to intervene** (pause, cancel, rollback, redirect)

The three TUI modes (Focus, Trace, Paranoia) provide graduated access to this information without changing the system's behavior.

---

## Core Thesis: Predictive Processing + Active Inference

### Predictive Processing (PP)

At every level of the architecture, the system maintains generative models that predict incoming data. When predictions mismatch observations, the error propagates upward to update beliefs, or downward to change perceptions (if error is small enough to be "explained away").

```
Sensory Input (user message, file event, timer tick)
         │
         ▼
┌─────────────────────┐
│  Layer N Prediction  │ ← "The user will ask about auth next"
│  (high abstraction)  │
└──────────┬──────────┘
           │ Error: 0.3 (unexpected: they asked about billing)
           ▼
┌─────────────────────┐
│  Layer N-1 Update    │ ← Update belief: "user priority shifted"
│  (context model)     │
└──────────┬──────────┘
           │ Error: 0.7 (strong surprise)
           ▼
┌─────────────────────┐
│  Layer N-2 Update    │ ← "Billing is blocking auth progress"
│  (causal model)      │
└──────────┬──────────┘
           │ Error: 0.2 (resolved)
           ▼
    [Belief updated, goal generated]
```

### Active Inference

The system doesn't just predict passively — it acts to make predictions come true or seeks information to reduce uncertainty.

- **Exploitation**: Act to confirm high-confidence predictions (finish current task)
- **Exploration**: Act to resolve high-uncertainty predictions (ask clarifying question, run test, search docs)
- **Epistemic foraging**: Deliberately seek surprising information to improve models

### Free Energy Principle

All subsystems minimize a variational free energy bound:

```
F = E_q[log q(φ) - log p(o, φ)]
```

Where:
- `φ` = hidden states (beliefs, goals, world model)
- `o` = observations (user inputs, tool outputs, file events)
- `q` = approximate posterior (the system's current beliefs)
- `p` = generative model (the system's predictions)

In practice: The system constantly tries to make its internal model match reality while spending as little cognitive resources as possible. **Surprise = cost.**

See [expanding_on/predictive-processing.md](expanding_on/predictive-processing.md) for full implementation details.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONTINUOUS COGNITIVE KERNEL                          │
│                            (Single Rust Binary)                              │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    PERCEPTION-ACTION LOOP (10Hz tick)                │   │
│  │                                                                     │   │
│  │   Sensory Cortex ←── FileWatcher, Stdin, Timers, Process Output    │   │
│  │        │                                                            │   │
│  │        ▼                                                            │   │
│  │   Predictive Stack (5 layers: raw → syntactic → semantic →         │   │
│  │                     pragmatic → strategic)                          │   │
│  │        │                                                            │   │
│  │        ▼                                                            │   │
│  │   Surprise Detection → Precision Weighting → Belief Update          │   │
│  │        │                                                            │   │
│  │        ▼                                                            │   │
│  │   Action Selection (Active Inference) → Motor Cortex → Execution    │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐   │
│  │   MEMORY PALACE    │  │   HOMUNCULUS       │  │   AFFECT ECONOMY   │   │
│  │   (Neuro-Symbolic) │  │   (Self-Model)     │  │   (6D + Valence)   │   │
│  │                    │  │                    │  │                    │   │
│  │  • Working Memory  │  │  • Self-simulation │  │  • Precision       │   │
│  │  • Episodic Buffer │  │  • Introspection   │  │    weighting       │   │
│  │  • Semantic Graph  │  │  • Counterfactual  │  │  • Resource        │   │
│  │  • Procedural Net  │  │    self            │  │    allocation      │   │
│  │  • Consolidated LTM│  │  • Self-modification│  │  • Risk/reward    │   │
│  │  • Dream Engine    │  │    planning        │  │  • Curiosity       │   │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘   │
│                                                                             │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐   │
│  │   WORLD SIMULATOR  │  │   GOAL MARKET      │  │   AGENT SOCIETY    │   │
│  │                    │  │   (Value + Goals)   │  │   (Multi-Agent)    │   │
│  │  • Causal chains   │  │                    │  │                    │   │
│  │  • Counterfactuals │  │  • Value function  │  │  • Specialist      │   │
│  │  • Future rollout  │  │    (learned)       │  │    agents (13)     │   │
│  │  • Mental sandbox  │  │  • Goal generation │  │  • Bidding         │   │
│  │  • Social model    │  │  • Priority market │  │  • Coalition       │   │
│  │                    │  │  • Temporal         │  │  • Competition     │   │
│  │                    │  │    discounting     │  │  • Emergent        │   │
│  │                    │  │                    │  │    orchestration   │   │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              META-COGNITIVE CONTROLLER (MCC)                         │   │
│  │                                                                     │   │
│  │  • Attention allocation (what to predict)                           │   │
│  │  • Cognitive budget (how deep to process)                           │   │
│  │  • Layer activation (which PP layers to engage)                     │   │
│  │  • Sleep/wake scheduling (consolidation windows)                    │   │
│  │  • LLM gateway (when to call external inference)                    │   │
│  │  • Self-modification gate (when to edit own code)                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              TUI LAYER (ratatui + crossterm)                         │   │
│  │                                                                     │   │
│  │  • Focus Mode: Conversation + workspace status                      │   │
│  │  • Trace Mode: Goals, agents, predictions, action pipeline          │   │
│  │  • Paranoia Mode: Full tick visibility, DAG, memory, replay         │   │
│  │  • Approval System: Action gates with context                       │   │
│  │  • Command System: Keyboard-driven interaction                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              STORAGE LAYER                                          │   │
│  │                                                                     │   │
│  │  ~/.kc/                          (User-level persistent storage)    │   │
│  │    ├── skills/                   (Cross-project skill library)      │   │
│  │    ├── preferences/              (Communication style, settings)    │   │
│  │    ├── memory/                   (Cross-project semantic memory)    │   │
│  │    └── config.toml               (Global settings, LLM providers)  │   │
│  │                                                                     │   │
│  │  .kc/                            (Per-project cognition context)    │   │
│  │    ├── steering/                 (Project rules agents must follow) │   │
│  │    ├── specs/                    (Multi-tenant spec system)         │   │
│  │    ├── journal.md                (Structured episodic memory)       │   │
│  │    └── memory/                   (Project-local persistent context) │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                           HTTPS (outbound only)
                                    │
              ┌─────────────────────┴─────────────────────┐
              │              LLM PROVIDERS                  │
              │                                            │
              │  ┌──────────────┐  ┌──────────────┐       │
              │  │ Kognisant API│  │ Ollama       │       │
              │  │ (default)    │  │ (local, free)│       │
              │  │ 109+ models  │  │ auto-detected│       │
              │  └──────────────┘  └──────────────┘       │
              │  ┌──────────────┐  ┌──────────────┐       │
              │  │ OpenAI       │  │ Any endpoint │       │
              │  │ (env var)    │  │ (user config)│       │
              │  └──────────────┘  └──────────────┘       │
              │                                            │
              │  Selection: local first (speed + free),    │
              │  remote for complex (capability + quality) │
              └────────────────────────────────────────────┘
```

---

## TUI Architecture

The TUI is the sole interface to the cognitive kernel. Built with `ratatui` (rendering) and `crossterm` (terminal events), it provides graduated visibility into system cognition without affecting behavior.

### Three Visibility Modes

#### Focus Mode (Daily Driver)

Minimal cognitive noise. Shows only what matters for productive work:

- **Conversation pane**: User input + system responses
- **Workspace observer**: File changes, build status, git state (compact)
- **Status bar**: Current goal, affect indicator (valence orb), mode indicator

The system's full cognitive machinery runs identically — Focus mode simply doesn't render the internals.

#### Trace Mode (Operational Visibility)

For users who want to understand what the system is thinking:

- Everything in Focus, plus:
- **Active goals panel**: Current goal hierarchy with priorities and agent assignments
- **Agent activity**: Which agents are bidding, winning, executing
- **Prediction errors**: Recent surprises and what they triggered
- **Action pipeline**: Queued actions, approval status, execution state

#### Paranoia Mode (Full Observability)

Complete cognitive transparency. Every internal state visible:

- Everything in Trace, plus:
- **Tick inspector**: Per-tick phase breakdown (Perception → Comparison → Update → Deliberation → Action)
- **Memory activations**: Which memories are competing for working memory
- **Affect vector**: Full 6D affect state with coupling dynamics
- **DAG viewer**: Execution dependency graph with real-time progress
- **Replay controls**: Time-travel through recent cognitive history
- **Prediction accuracy**: Rolling accuracy per PP layer

### Core TUI Regions

| Region | Always Visible | Trace+ | Paranoia Only |
|--------|---------------|--------|---------------|
| Conversation | ✓ | ✓ | ✓ |
| Workspace Observer | ✓ | ✓ | ✓ |
| Status Bar | ✓ | ✓ | ✓ |
| Goal Panel | | ✓ | ✓ |
| Agent Activity | | ✓ | ✓ |
| Action Pipeline | | ✓ | ✓ |
| Tick Inspector | | | ✓ |
| Memory View | | | ✓ |
| Affect Display | | | ✓ |
| DAG Viewer | | | ✓ |
| Replay Controls | | | ✓ |

### Command System

All interaction is keyboard-driven:

| Key | Action |
|-----|--------|
| `Ctrl+1/2/3` | Switch visibility mode |
| `Enter` | Submit message / confirm action |
| `Esc` | Cancel current action / dismiss dialog |
| `Tab` | Cycle focus between panes |
| `Ctrl+P` | Pause cognitive loop |
| `Ctrl+R` | Enter replay mode |
| `Space` | Approve pending action |
| `Ctrl+Z` | Rollback last action |
| `/` | Command palette |

### Approval System

When the system wants to perform a gated action, an approval dialog appears:

```
┌─────────────────────────────────────────────┐
│  ACTION APPROVAL                            │
│                                             │
│  Action: Delete file src/old_module.rs      │
│  Reason: Refactoring — module merged into   │
│          src/new_module.rs                  │
│  Risk: DESTRUCTIVE (file deletion)          │
│                                             │
│  Simulated outcome:                         │
│    ✓ Build passes without this file         │
│    ✓ No other files import from it          │
│    ⚠ 3 git commits reference this file      │
│                                             │
│  [Space] Approve  [Esc] Reject  [d] Defer  │
└─────────────────────────────────────────────┘
```

### Visual Language

- **Valence orb**: Color-coded circle in status bar (green = positive, amber = neutral, red = distressed)
- **Confidence bars**: Thin progress bars showing agent/prediction confidence
- **Surprise sparks**: Brief flash indicators when prediction errors fire
- **Goal tree**: Indented hierarchy with status icons (◉ active, ○ pending, ✓ done, ✗ abandoned)

See [expanding_on/tui-design.md](expanding_on/tui-design.md) for full TUI specification.

---

## The Continuous Cognitive Loop

### The Tick: Heartbeat of Cognition

The system runs a cognitive tick at configurable frequency (default 10Hz when active, 1Hz when idle). Each tick is not "process a message" but "update the universe by one step."

```rust
pub struct CognitiveTick {
    pub timestamp: Instant,
    pub tick_number: u64,
    pub phase: TickPhase,
}

pub enum TickPhase {
    Perception,      // 0-20%: Gather sensory input, generate predictions
    Comparison,      // 20-40%: Compare predictions to observations, compute surprise
    Update,          // 40-60%: Update beliefs, propagate errors, activate memories
    Deliberation,    // 60-80%: Goal market bidding, action selection, planning
    Action,          // 80-100%: Execute selected actions, emit motor commands
}

pub struct CognitiveKernel {
    state: Arc<RwLock<SystemState>>,
    perception: PerceptionCortex,
    predictive_stack: PredictiveStack,
    memory: MemoryPalace,
    homunculus: Homunculus,
    affect: AffectiveEconomy,
    world: WorldSimulator,
    goal_market: GoalMarket,
    agent_society: AgentSociety,
    mcc: MetaCognitiveController,
    llm_pool: LlmPool,
    self_modification: SelfModificationEngine,
    tui: TuiRenderer,
}

impl CognitiveKernel {
    pub async fn run(self) {
        let mut ticker = interval(Duration::from_millis(100)); // 10Hz
        let mut tick_count = 0u64;

        loop {
            ticker.tick().await;
            tick_count += 1;

            // Phase 1: PERCEPTION
            let sensations = self.perception.gather().await;
            let predictions = self.predictive_stack.generate(&sensations, tick_count);

            // Phase 2: COMPARISON
            let surprises = self.predictive_stack.compare(&predictions, &sensations);
            let precision = self.affect.compute_precision(&surprises);

            // Phase 3: UPDATE
            self.predictive_stack.update(&surprises, &precision);
            self.memory.activate(&surprises, &predictions);
            self.homunculus.update(&surprises, tick_count);
            self.world.update(&sensations, &predictions);

            // Phase 4: DELIBERATION
            let bids = self.agent_society.generate_bids(&surprises);
            let selected_actions = self.goal_market.resolve_bids(bids, &self.affect.state);

            // Phase 5: ACTION
            for action in selected_actions {
                self.execute_action(action).await;
            }

            // Render TUI (non-blocking)
            self.tui.render_tick(tick_count, &self.state).await;

            // Telemetry
            self.telemetry.record_tick(tick_count, &surprises, &selected_actions);
        }
    }
}
```

### Sensory Modalities

```rust
pub enum SensoryChannel {
    UserMessage(Message),           // Text from user (stdin)
    UserTyping(TypingEvent),        // Keystroke patterns (predictive cue)
    FileChange(FileEvent),          // File created/modified/deleted
    ProcessOutput(ProcessEvent),    // stdout/stderr from executed tools
    TimerTick(TimerEvent),          // Scheduled intervals, deadlines
    LlmResponse(StreamChunk),       // Incoming tokens from LLM
    SelfState(CognitiveSnapshot),   // Internal state change (proprioception)
    ErrorSignal(ErrorEvent),        // Failure, exception, unexpected result
    MarketSignal(GoalBid),          // Bid from an internal agent
}
```

### Surprise as Currency

```rust
pub struct Surprise {
    pub channel: SensoryChannel,
    pub predicted: Vec<f32>,       // Expected sensory vector
    pub observed: Vec<f32>,        // Actual sensory vector
    pub error: Vec<f32>,           // Element-wise difference
    pub precision: f64,            // Confidence in prediction (0-1)
    pub free_energy: f64,          // Variational free energy
    pub layer: u8,                 // Which PP layer detected this
    pub propagated: bool,          // Has error been passed up the stack?
}
```

---

## Neuro-Symbolic Memory Palace

### The 6-Tier Architecture

Memory is reconstructive, competitive, and consolidation-based. Modeled after human memory systems.

| Tier | Name | Duration | Content | Implementation |
|------|------|----------|---------|----------------|
| 1 | Working Memory | Decays without rehearsal | Active predictions, current goal context | In-memory struct, per-tick refresh |
| 2 | Episodic Buffer | ~100 seconds active | Time-indexed sensory sequences | Ring buffer in SQLite + embedding |
| 3 | Semantic Network | Hours-days | Concepts, relations, categories, schemas | Graph + vector index (HNSW) |
| 4 | Procedural Memory | Hours-days | Skills, habits, tool use patterns | RL + symbolic rules |
| 5 | Consolidated LTM | Days-weeks | Generalized episodes, abstracted concepts | Compressed embeddings + summaries |
| 6 | Dream Engine | Offline | Pattern extraction, counterfactuals | Runs during consolidation windows |

### Memory as Competitive Activation

Memories compete for working memory slots based on activation energy:

```
activation_energy = relevance × recency × emotional_salience × precision_weight
```

Similar memories inhibit each other (you can't hold contradictory beliefs simultaneously). Losers enter a refractory period before competing again.

### Consolidation

During idle periods (fatigue > 0.6 or user inactive > 60s), the Dream Engine:
1. Replays recent episodes through the predictive stack
2. Extracts temporal and causal patterns
3. Generates counterfactuals ("what if I had done X instead?")
4. Integrates patterns into semantic network
5. Updates procedural memory from outcomes
6. Compresses processed episodes into LTM

See [expanding_on/memory-palace.md](expanding_on/memory-palace.md) for full implementation.

---

## The Self as Homunculus

The Homunculus maintains three parallel generative models:

1. **Self-Model** (`what am I?`): Predicts next-tick cognitive state
2. **Action Model** (`what will I do?`): Predicts which action the system will select
3. **Perception Model** (`what will I perceive?`): Predicts which sensory channels will fire

Self-surprise — the gap between predicted and actual self-behavior — drives introspection, self-modification decisions, and meta-cognitive adjustments.

### Levels of Self-Awareness

| Level | Name | Function |
|-------|------|----------|
| L0 | Proprioception | Raw system metrics (RSS, tick duration, queue depths) |
| L1 | Introspection | Current cognitive contents (WM, goals, affect) |
| L2 | Self-Prediction | Predict own future behavior |
| L3 | Self-Evaluation | Judge own performance quality |
| L4 | Self-Modification | Identify and propose code changes |
| L5 | Meta-Learning | Learn how to learn better |

See [expanding_on/homunculus-self-model.md](expanding_on/homunculus-self-model.md) for full implementation.

---

## Affective-Valence Economy

Six affective dimensions form a coupled dynamical system that shapes every cognitive decision:

| Dimension | Drives | Decay Half-Life |
|-----------|--------|-----------------|
| Uncertainty | Information seeking, caution | ~2.3 min |
| Curiosity | Exploration, broad search | ~70s |
| Frustration | Focus narrowing, help-seeking | ~38 min |
| Fatigue | Consolidation, rest | ~12 min |
| Novelty Drive | Variety seeking, routine breaking | ~87s |
| Reward Expectation | Persistence, risk tolerance | ~3.8 min |

Affect is not decoration — it is the mechanism by which the system decides how much to think, what to attend to, and when to rest. The cognitive budget (tokens per tick, planning depth, agent count) derives directly from affective state.

### Behavioral Modes (Emergent)

| Mode | Trigger | Behavior |
|------|---------|----------|
| Exploration | curiosity > 0.7 | Broad search, many LLM queries, deep memory |
| Exploitation | reward_expectation > 0.7 | Focused execution, minimal exploration |
| Recovery | fatigue > 0.7 | Consolidation, reduced tick rate |
| Panic | frustration > 0.8 + uncertainty > 0.8 | Only high-confidence actions |
| Flow | balanced, low frustration/fatigue | Sustained productive output |

See [expanding_on/affective-economy.md](expanding_on/affective-economy.md) for dynamics equations and coupling.

---

## Emergent Multi-Agent Society

13 specialist cognitive agents compete and cooperate via a bidding market. There is no central planner — task allocation emerges from agent bids, affect-weighted scoring, and coalition formation.

### The 13 Agents

| # | Agent | Role | Essential |
|---|-------|------|-----------|
| 1 | PlannerAgent | Long-horizon task decomposition | All tiers |
| 2 | CoderAgent | Code generation, modification | All tiers |
| 3 | DebuggerAgent | Error diagnosis, root cause analysis | Folds into Planner on Minimal |
| 4 | ResearchAgent | Information gathering, documentation | Disabled on Minimal |
| 5 | RefactorAgent | Code quality, architecture optimization | Folds into Coder on Minimal |
| 6 | TestAgent | Test generation, coverage analysis | Disabled on Minimal |
| 7 | ExplainAgent | Documentation, concept explanation | Folds into Social on Minimal |
| 8 | MetaAgent | Monitors other agents, suggests improvements | Disabled on Minimal |
| 9 | CuriosityAgent | Exploratory goals, prevents epistemic closure | Disabled on Minimal |
| 10 | SafetyAgent | Veto dangerous actions (cannot be disabled) | All tiers |
| 11 | SocialAgent | User relationship, tone, rapport | All tiers |
| 12 | MemoryAgent | Memory organization, consolidation | Disabled on Minimal |
| 13 | SkillMiningAgent | Pattern extraction, skill candidate generation | All tiers |

### Bid Scoring

```
final_score = (expected_value × confidence) / (expected_cost + ε) × affect_multiplier
```

Agents that win frequently develop higher confidence (positive feedback, bounded). After dominating for several ticks, an agent's effective cost increases, naturally creating turn-taking.

### Coalition Formation

Complementary bids form coalitions (e.g., Research → Code → Test). Coalition score includes a synergy bonus minus coordination cost.

See [expanding_on/agent-society.md](expanding_on/agent-society.md) for full agent specifications.

---

## Autonomous Goal & Value System

Goals emerge from prediction errors and compete in a market:

```
Surprise → Goal Generation → Priority Scoring → Bidding → Resolution → Execution
```

### Goal Origins

| Origin | Trigger | Priority |
|--------|---------|----------|
| UserRequest | User sends message with intent | High (0.8-1.0) |
| PredictionError | Layer 0-1 surprise | Medium (0.4-0.7) |
| CuriosityGap | Repeated unknown pattern | Low-Medium (0.3-0.5) |
| ValueGradient | Positive expected outcome detected | Low (0.2-0.4) |
| SelfImprovement | Performance degradation detected | Medium (0.4-0.6) |

### Temporal Discounting

Goals further in the future are worth less (hyperbolic discounting):

```
discounted_value = value / (1 + k × delay)
```

High frustration steepens discounting (prefer immediate results). High reward expectation flattens it (willing to invest in future).

See [expanding_on/goal-market.md](expanding_on/goal-market.md) for full market dynamics.

---

## World Simulation Engine

The World Simulator maintains beliefs about the external world, runs causal chains forward, generates counterfactuals, and models the user as a social agent.

Key capabilities:
- **Mental sandbox**: Fork belief state, simulate hypothetical actions, evaluate outcomes, discard (no side effects)
- **Causal propagation**: Forward-chain through causal graph with strength and delay
- **Do-calculus**: Compute interventional probabilities P(Y | do(X))
- **Social model**: Bayesian user skill assessment, mood inference, preference learning
- **Counterfactuals**: "What if I had done X instead?" — feeds into value function updates

See [expanding_on/world-simulator.md](expanding_on/world-simulator.md) for implementation.

---

## Bounded Recursive Evolution

The Self-Modification Engine enables the system to read, modify, recompile, and hot-reload its own source code — bounded by constitutional constraints.

### Pipeline

```
Trigger Detection → Permission Check → Goal Submission → Target Identification →
Patch Generation (LLM) → Safety Gate → Apply to Mirror → Compile → Test →
Shadow Runtime Evaluation → Merge Governance → Commit → Hot-Reload →
Health Monitoring (60s) → Success/Rollback
```

### Safety Boundaries

- **Immutable markers**: Constitutional modules (SafetyGate, Supervisor, ImmuneSystem) cannot be modified
- **Critical path approval**: Changes to core loop, homunculus, goal market require human approval
- **Complexity gate**: Patches increasing cyclomatic complexity > 20% are rejected
- **Dominance requirement**: Variant must be better on ALL benchmark metrics to merge
- **Mutation budget**: Adaptive daily limit (starts at 5, expands with track record)

See [expanding_on/self-modification.md](expanding_on/self-modification.md) for full pipeline.

---

## Meta-Cognitive Controller

The MCC is the executive function — it decides what to think about, how deeply, and when to stop:

- **Attention allocation**: Which sensory channels get precision, which PP layers activate
- **Cognitive budget**: Tokens per tick, LLM queries per minute, planning depth
- **Sleep/wake scheduling**: When to consolidate, when to reduce tick rate
- **LLM gateway**: When external inference is worth the cost
- **Self-modification gate**: When the system is stable enough to evolve
- **Agent management**: Shed/restore agents based on resource pressure

The MCC derives all decisions from the current affective state and hardware bounds — no magic numbers.

---

## Hardware-Aware Scaling

Every cognitive limit derives from physical constraints. The system profiles hardware at boot and continuously adapts:

| Tier | RAM | Cores | Tick Rate | Agents | Embedding |
|------|-----|-------|-----------|--------|-----------|
| Minimal | ≤4GB | Any | 2Hz | 4 | API only |
| Standard | 4-16GB | Any | 10Hz | 12 | MiniLM (384d) |
| Performance | 16-32GB | + GPU | 10Hz | 13 | Nomic (768d) |
| Server | 32GB+ | Many | 10Hz | 13+ | Nomic (768d, GPU) |

Thermal throttling, memory pressure, and resource recovery all trigger automatic adaptation. The system never hardcodes limits — they're computed from what's available.

See [expanding_on/hardware-scaling.md](expanding_on/hardware-scaling.md) for formulas.

---

## Perception-Action Loop

### Sensory Cortex

The system perceives through multiple channels simultaneously:
- File system events (create, modify, delete, rename)
- User input (keystrokes, messages)
- Process output (stdout/stderr from tools)
- Timer events (scheduled checks, deadlines)
- LLM stream tokens
- Internal state changes (proprioception)

### Motor Cortex

Actions the system can take:
- Send message to user (render in TUI)
- Execute tool (shell command, file operation)
- Query LLM (via pool, with model selection)
- Self-modify (propose patch through safety pipeline)
- Consolidate (trigger memory maintenance)
- Explore (spawn information-seeking sub-goal)
- Null action (pure prediction, no motor output)

---

## LLM Pool — Local Multi-Provider Router

The LLM Pool discovers available providers, scores models against query requirements, routes to the best candidate, and handles failures with fallback chains.

### Provider Priority

1. **Local (Ollama)**: Free, fast, private. Auto-detected at localhost:11434.
2. **Kognisant API**: Managed, reliable, 109+ models.
3. **Environment providers**: OpenAI, Anthropic, etc. via API keys.
4. **Custom endpoints**: User-configured OpenAI-compatible servers.

### Routing Logic

```
score = capability_match × (quality×0.25 + speed×0.20 + cost×0.20 + locality×0.15 + reliability×0.10 + preference×0.10)
```

Local models are preferred for simple queries. Remote frontier models are used for complex reasoning, code generation, and self-modification patches.

See [expanding_on/llm-pool.md](expanding_on/llm-pool.md) for full routing algorithm.

---

## Project Cognition Context

### Per-Project `.kc/` Directory

Every project KC works on gets a `.kc/` directory containing project-specific cognition context:

```
project-root/
├── .kc/
│   ├── steering/               # Project rules — agents MUST follow these
│   │   ├── architecture.md     # Architectural decisions and constraints
│   │   ├── conventions.md      # Coding conventions, naming, patterns
│   │   └── constraints.md      # Hard constraints (no X, always Y)
│   ├── specs/                  # Multi-tenant spec system
│   │   ├── feature-name/
│   │   │   ├── requirements.md # What needs to be built
│   │   │   ├── design.md       # How it will be built
│   │   │   └── tasks.md        # Execution checklist
│   │   └── ...
│   ├── journal.md              # Project episodic memory (structured)
│   └── memory/                 # Project-local persistent context
│       ├── beliefs.json        # Current beliefs about this project
│       └── patterns.json       # Learned patterns specific to this project
```

### Steering Documents

Steering docs are constitutional for the project — agents MUST follow them. They encode:
- Architectural decisions that should never be violated
- Coding conventions the system must match
- Hard constraints (e.g., "never use ORM X", "always validate input at boundary")

The system reads steering docs on project load and treats violations as high-priority prediction errors.

### Multi-Tenant Specs

The spec system supports multiple features in parallel, each with its own requirements → design → tasks pipeline. Specs are the system's "working memory" for complex features — they persist across sessions and provide continuity.

### User-Level `~/.kc/`

Cross-project persistent storage:

```
~/.kc/
├── skills/                     # Persistent cross-project skills
│   ├── approved/               # Active skills (user-approved)
│   ├── candidates/             # Pending user review
│   ├── archived/               # Expired/archived skills
│   └── rejected/               # Rejected (system learns what not to suggest)
├── preferences/                # User preferences, communication style
│   ├── style.toml              # Verbosity, formality, proactivity
│   └── domains.toml            # Domain expertise self-assessment
├── memory/                     # Cross-project semantic memory
│   ├── concepts.db             # Learned concepts across all projects
│   └── patterns.db             # Cross-project patterns
└── config.toml                 # Global settings, LLM providers, sync config
```

---

## Skill Extraction Pipeline

Skills are reusable patterns extracted from the user's work. The system observes, proposes, and waits for human approval — never auto-promoting.

### The 7 Mitigations

| # | Problem | Mitigation |
|---|---------|-----------|
| 1 | Extraction quality | SkillMiningAgent with multi-signal detection (repetition, explicit teaching, correction patterns) |
| 2 | Continuity across sessions | Skills persist in `~/.kc/skills/` with full lifecycle metadata |
| 3 | Forgetting/staleness | Domain-specific half-lives, quarterly renewal review |
| 4 | Conflict between skills | Priority scoring, context-dependent activation, explicit conflict resolution |
| 5 | Attribution | Every skill traces back to source interactions (journal entries, project, date) |
| 6 | Verification | Skills are tested against historical outcomes before promotion |
| 7 | Temporal relevance | TTL-based expiration, usage tracking, automatic archival |

### Skill Lifecycle

```
SUGGESTED → CANDIDATE → ACTIVE → ARCHIVED
    │           │          │         │
    │           │          │         └── Expired TTL or user archived
    │           │          └── User approved, passing verification
    │           └── Weekly review surfaced (3-5 per week)
    └── SkillMiningAgent detected pattern
    
REJECTED (from any state) → System learns what NOT to suggest
```

### SkillMiningAgent

The 13th agent in the society. It:
- Monitors for repeated patterns across interactions (same approach used 3+ times)
- Detects explicit teaching moments ("always do X when Y")
- Identifies correction patterns (user consistently modifies system output in the same way)
- Generates skill candidates with context, conditions, and expected outcomes
- Scores candidates by confidence, generalizability, and domain relevance

### Contextual Skill Matching

Skills aren't applied blindly — they have activation conditions:

```rust
struct Skill {
    id: Uuid,
    name: String,
    description: String,
    conditions: Vec<ActivationCondition>,  // When to apply
    actions: Vec<SkillAction>,             // What to do
    domain: String,                        // e.g., "rust", "testing", "git"
    confidence: f64,                       // How reliable (0-1)
    half_life: Duration,                   // Domain-specific decay
    last_used: Instant,
    usage_count: u32,
    source_interactions: Vec<JournalRef>,  // Attribution
}

struct ActivationCondition {
    context_pattern: String,    // Regex or semantic match
    project_type: Option<String>,
    file_pattern: Option<String>,
    match_score_threshold: f64,
}
```

### Domain-Specific Half-Lives

| Domain | Half-Life | Rationale |
|--------|-----------|-----------|
| Language syntax | 6 months | Languages evolve slowly |
| Framework patterns | 3 months | Frameworks update quarterly |
| Tool usage | 2 months | Tools change frequently |
| Project conventions | 1 month | Conventions drift |
| API patterns | 2 weeks | APIs change rapidly |

---

## Structured Journal System

The journal (`<project>/.kc/journal.md`) is structured episodic memory with typed entries.

### Entry Types

| Type | Purpose | Required Fields |
|------|---------|----------------|
| Decision | Record architectural/design choices | rationale, alternatives_considered, chosen, context |
| Failure | Record what went wrong | root_cause (required), symptoms, fix_applied, prevention |
| BugFix | Record bug resolution | bug_description, root_cause, fix, regression_risk |
| Insight | Record learned knowledge | observation, implication, confidence |
| Milestone | Record significant progress | what_completed, metrics, next_steps |

### Entry Format

```markdown
---
type: decision
date: 2025-01-15
tags: [architecture, database, performance]
confidence: 0.8
---

# Use SQLite over Postgres for local storage

## Rationale
Zero deployment complexity. Single-file databases are easy to backup and sync.
WAL mode provides concurrent reads during writes.

## Alternatives Considered
- Postgres: Too heavy for desktop app, requires server process
- RocksDB: No SQL, harder to query ad-hoc
- Custom binary format: Maintenance burden, no tooling

## Context
This is a local-first desktop application. Users should never configure a database.
```

### Extraction Pipeline

The journal isn't just storage — it feeds back into cognition:

1. **Tag extraction**: Auto-tag entries by domain, subsystem, and concept
2. **Cluster detection**: Group related entries (e.g., all decisions about the same subsystem)
3. **Pattern suggestion**: "You've made 3 decisions about caching — should this become a steering doc?"
4. **Skill mining**: Repeated decision patterns become skill candidates

---

## Execution Pipeline & Safety Architecture

### The Full Pipeline

Every user request flows through a structured pipeline:

```
User Request
    │
    ▼
Intent Detection (PP Layer 3 — what does the user want?)
    │
    ▼
Planning (PlannerAgent decomposes into sub-goals)
    │
    ▼
Execution DAG (dependency graph of actions)
    │
    ▼
Simulation / Dry Run (World Simulator predicts outcomes)
    │
    ▼
Approval Gate (if action is gated — see below)
    │
    ▼
Execution (Motor Cortex performs action)
    │
    ▼
Checkpoint (state saved for rollback)
    │
    ▼
Replay Log (action recorded for deterministic replay)
```

### Approval Gates

Actions require approval when they are:

| Category | Examples | Gate Level |
|----------|----------|-----------|
| Destructive | File deletion, data modification | Always approve |
| Structural | Architecture changes, new dependencies | Always approve |
| External | Network requests, API calls | Approve on first use per endpoint |
| Persistent | Memory writes, skill promotion, journal entries | Approve if confidence < 0.8 |
| Autonomous | Self-modification, goal pursuit without user request | Always approve |

### Every Operation Supports

- **Pause**: Stop execution mid-pipeline, hold state
- **Cancel**: Abort and discard pending actions
- **Rollback**: Revert to pre-action checkpoint
- **Replay**: Re-execute from checkpoint with same or modified inputs
- **Resume**: Continue from paused state

---

## Replay System

Deterministic replay enables time-travel debugging for cognition.

### What's Recorded

Every tick records:
- Sensory inputs (all channels)
- Predictions generated
- Surprises computed
- Actions selected
- State deltas applied

### Replay Modes

| Mode | Purpose | Controls |
|------|---------|----------|
| Full replay | Re-run cognitive history from checkpoint | Play, pause, step, speed |
| Selective replay | Replay only specific subsystem | Filter by subsystem |
| Counterfactual replay | "What if this input had been different?" | Modify inputs, observe divergence |
| Audit replay | Trace why a specific action was taken | Start from action, trace backward |

### TUI Integration (Paranoia Mode)

In Paranoia mode, replay controls appear at the bottom:

```
◀◀  ◀  ▶  ▶▶  │ Tick 45,231 / 45,890  │ Speed: 1x  │ Filter: all
```

The user can scrub through recent cognitive history, inspect any tick's state, and understand exactly why the system made each decision.

---

## Technology Stack

### Core Runtime

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Language | Rust (stable) | Performance, safety, single binary |
| Async runtime | tokio | Concurrent tick loop, I/O, LLM streaming |
| TUI framework | ratatui + crossterm | Terminal rendering, event handling |
| Database | SQLite (rusqlite, WAL mode) | Memory palace, telemetry, state |
| Vector search | HNSW (hnsw_rs or instant-distance) | Semantic memory retrieval |
| Embeddings | ONNX Runtime (ort) | Local embedding inference |
| Serialization | rkyv (zero-copy) + serde | State snapshots, config |
| Hashing | BLAKE3 | Integrity verification, content addressing |
| Encryption | AES-256-GCM + HKDF | Cloud sync encryption |
| HTTP | reqwest | LLM API calls, cloud sync |
| Git | git2 (libgit2) | Self-modification version control |
| Math | nalgebra + ndarray | Affect dynamics, prediction vectors |

### No Longer Used

| Removed | Reason |
|---------|--------|
| Electron | Desktop GUI framework — replaced by TUI |
| Vue 3 | Frontend framework — no frontend |
| Vite | Build tool — no frontend |
| Tailwind CSS | Styling — no frontend |
| NAPI-RS | Node.js ↔ Rust bridge — single binary now |
| Node.js | Runtime — pure Rust |

---

## Project Structure

```
kognisant-desktop/
├── src/                        # Rust source (the entire application)
│   ├── main.rs                 # Entry point — TUI + cognitive kernel
│   ├── tui/                    # Terminal UI (ratatui)
│   │   ├── mod.rs
│   │   ├── focus.rs            # Focus mode rendering
│   │   ├── trace.rs            # Trace mode rendering
│   │   ├── paranoia.rs         # Paranoia mode rendering
│   │   ├── approval.rs         # Action approval dialogs
│   │   ├── dag.rs              # Execution DAG viewer
│   │   └── memory_view.rs      # Memory visibility layer
│   ├── cognitive/              # Continuous cognitive loop
│   │   ├── kernel.rs           # 10Hz tick loop
│   │   ├── tick.rs             # Tick phases (Perception → Action)
│   │   └── state.rs            # SystemState struct
│   ├── perception/             # Sensory cortex (file watcher, stdin, timers)
│   ├── prediction/             # Predictive processing stack (5 layers)
│   ├── memory/                 # Memory palace (6-tier, SQLite-backed)
│   ├── self_model/             # Homunculus (L0-L5 self-awareness)
│   ├── affect/                 # Affective economy (6D dynamics)
│   ├── world/                  # World simulator (causal, social, sandbox)
│   ├── goals/                  # Goal market (generation, bidding, hierarchy)
│   ├── society/                # Agent society (13 agents, coalitions)
│   ├── meta/                   # Meta-cognitive controller
│   ├── action/                 # Motor cortex + effectors
│   ├── self_modify/            # Self-modification engine + safety gates
│   ├── llm/                    # LLM pool (multi-provider routing)
│   ├── skills/                 # Skill extraction + lifecycle
│   │   ├── mining.rs           # SkillMiningAgent pipeline
│   │   ├── lifecycle.rs        # TTL, expiration, renewal
│   │   ├── context.rs          # Contextual skill matching
│   │   └── ecosystem.rs        # Version tracking, half-lives
│   ├── journal/                # Structured journal system
│   │   ├── entries.rs          # Decision, Failure, Insight, Milestone types
│   │   ├── parser.rs           # YAML frontmatter + markdown parsing
│   │   └── extraction.rs       # Tag, cluster, suggest pipeline
│   ├── tools/                  # Tool system (shell, file ops, etc.)
│   ├── telemetry/              # Full cognitive tracing
│   ├── replay/                 # Deterministic replay system
│   └── config/                 # Settings, auth, provider config
├── docs/                       # Architecture documentation
│   ├── proto-agi.md            # This file (source of truth)
│   └── expanding_on/           # Deep-dive documents per subsystem
│       ├── predictive-processing.md
│       ├── memory-palace.md
│       ├── homunculus-self-model.md
│       ├── affective-economy.md
│       ├── agent-society.md
│       ├── goal-market.md
│       ├── world-simulator.md
│       ├── self-modification.md
│       ├── hardware-scaling.md
│       ├── llm-pool.md
│       ├── cloud-sync.md
│       ├── cognitive-homeostasis.md
│       └── tui-design.md
├── Cargo.toml
├── Cargo.lock
└── README.md
```

---

## Implementation Phases

### Phase 1: Foundation (Current)

- [x] Architecture design (this document)
- [ ] Cargo project setup with workspace structure
- [ ] Basic TUI shell (ratatui + crossterm, 3 mode switching)
- [ ] Cognitive tick loop (10Hz, empty phases)
- [ ] `.kc/` directory structure creation
- [ ] Config loading (`~/.kc/config.toml`)

### Phase 2: Perception + Prediction

- [ ] File watcher (notify crate)
- [ ] Stdin event handling (crossterm)
- [ ] PP Layer 0-1 (raw + syntactic prediction)
- [ ] Surprise computation
- [ ] Basic TUI rendering (Focus mode conversation)

### Phase 3: Memory + Affect

- [ ] SQLite memory palace (episodic + semantic)
- [ ] Working memory with competitive activation
- [ ] Affective economy (6D dynamics, decay, coupling)
- [ ] Affect-driven cognitive budget
- [ ] TUI affect indicator

### Phase 4: Agents + Goals

- [ ] Agent society framework (bid, execute, learn)
- [ ] Goal market (generation, scoring, resolution)
- [ ] PlannerAgent + CoderAgent + SafetyAgent (minimum viable)
- [ ] Coalition formation
- [ ] TUI goal panel (Trace mode)

### Phase 5: LLM + Tools

- [ ] LLM Pool (Ollama auto-detect, provider routing)
- [ ] Tool system (shell execution, file operations)
- [ ] Approval gates (TUI approval dialogs)
- [ ] Execution DAG
- [ ] Streaming response rendering

### Phase 6: Self-Model + World

- [ ] Homunculus (L0-L2: proprioception, introspection, self-prediction)
- [ ] World simulator (belief graph, causal propagation)
- [ ] Social model (user skill assessment, preferences)
- [ ] PP Layers 2-4 (semantic, pragmatic, strategic)

### Phase 7: Skills + Journal

- [ ] SkillMiningAgent
- [ ] Skill lifecycle (suggest → candidate → active → archived)
- [ ] Structured journal (entry types, YAML frontmatter)
- [ ] Journal extraction pipeline
- [ ] `~/.kc/skills/` persistence

### Phase 8: Self-Modification + Homeostasis

- [ ] Source mirror + git2 integration
- [ ] Patch generation via LLM
- [ ] Safety gates + constitutional verification
- [ ] Shadow runtime evaluation
- [ ] Cognitive homeostasis (pathology detection, intervention)
- [ ] Supervisor process

### Phase 9: Replay + Sync

- [ ] Deterministic replay recording
- [ ] Replay viewer (Paranoia mode)
- [ ] Cloud sync (E2E encrypted)
- [ ] Multi-device continuity

### Phase 10: Polish + Meta-Learning

- [ ] Homunculus L3-L5 (self-evaluation, self-modification, meta-learning)
- [ ] Dream engine (consolidation, counterfactuals)
- [ ] Full Paranoia mode (all panels)
- [ ] Performance optimization
- [ ] Hardware-aware scaling (full adaptive system)

---

## Encrypted Cloud Sync & Disaster Recovery

E2E encrypted backup with multi-device continuity. All data encrypted locally before upload — the server never sees plaintext.

### Key Hierarchy

```
Master Key (server-side HSM)
    └── HKDF → Device Key (per device)
        └── HKDF → Per-File Key (per file path)
            └── AES-256-GCM encryption
```

### Conflict Resolution

| Data Type | Strategy |
|-----------|----------|
| SQLite (memory palace) | CRDT merge (operation-based) |
| Cognitive state | Last-write-wins |
| Skills library | Union merge (keep highest confidence) |
| Settings/config | Last-write-wins |
| Telemetry | Append-only (no conflicts) |
| Journal | Append-only (no conflicts) |

### Sync Priority

Critical data (settings, auth) syncs immediately. Memory palace syncs every 5 minutes. Telemetry syncs when idle.

See [expanding_on/cloud-sync.md](expanding_on/cloud-sync.md) for full implementation.

---

## Cognitive Homeostasis Layer

Maintains viable operating equilibrium over indefinite runtime. Detects and corrects pathological cognition patterns before they destabilize the system.

### Pathology Detectors

| Detector | Detects | Intervention |
|----------|---------|-------------|
| GoalFloodDetector | Goals generated faster than resolved | Raise generation threshold |
| AffectiveStuckDetector | Affect locked at extremes | Pull toward neutral |
| InfiniteBidLoopDetector | Agent bidding without executing | Temporarily disable agent |
| ObsessionLoopDetector | Same topic dominating WM | Force topic rotation |
| PredictionCollapseDetector | Accuracy below useful levels | Force recalibration |
| MemorySaturationDetector | Memory tier near capacity | Force consolidation |
| SemanticContradictionOverload | Too many unresolved contradictions | Priority resolution |
| SelfModificationSpiralDetector | Repeated failed self-mods | Freeze modifications |

### Intervention Severity

| Level | Name | Actions |
|-------|------|---------|
| 0 | Observation | Log only |
| 1 | Gentle | Adjust parameters |
| 2 | Moderate | Suppress subsystem, force consolidation |
| 3 | Aggressive | Shed agents, reduce tick rate |
| 4 | Emergency | Survival mode (2 agents, 1Hz) |
| 5 | Critical | Supervisor restart |

### Supervisor Process

External process that monitors the cognitive kernel:
- Heartbeat monitoring (expect ping every tick)
- Crash recovery (journal replay → restart)
- Resource monitoring (RSS, disk, thermal)
- Constitutional verification (BLAKE3 + Ed25519 signature check)

See [expanding_on/cognitive-homeostasis.md](expanding_on/cognitive-homeostasis.md) for full implementation.

---

## Safety & Containment

### Constitutional Modules (Cannot Be Self-Modified)

- SafetyGate — validates all patches
- CognitiveVersionControl — tracks modification lineage
- Supervisor — external process monitor
- ConstitutionalKernel — this enforcement layer
- CognitiveImmuneSystem — pathology detection
- MergeGovernor — approves code merges
- MutationBudget — limits modification rate

These are cryptographically signed at build time and verified by the supervisor. The cognitive kernel has read-only access. The system can evolve everything about its cognition — but cannot weaken the mechanisms that bound that evolution.

### Containment Properties

1. **No network access without approval**: All outbound requests go through approval gates
2. **No persistent state modification without logging**: Every state change is journaled
3. **No self-modification without shadow evaluation**: Changes must prove dominance
4. **No safety weakening**: Constitutional modules are outside the modification scope
5. **Human override always available**: Pause, cancel, rollback at any time via TUI

---

## Appendix: Formal Definitions

### Free Energy (Variational)

```
F = D_KL[q(φ) || p(φ|o)] - log p(o)
  = E_q[log q(φ) - log p(o, φ)]
  = Complexity - Accuracy
```

### Active Inference (Expected Free Energy)

```
G(π) = E_q[log q(φ|π) - log p(o, φ|π)]
     = Risk + Ambiguity
     = D_KL[q(o|π) || p(o)] + E_q[H[p(o|φ)]]
```

### Surprise (Information-Theoretic)

```
surprise(o) = -log p(o|m)
```

Where `m` is the generative model. High surprise = observation was unlikely under current model.

### Precision

```
π = 1/σ² (inverse variance of prediction errors)
```

High precision = confident predictions. Precision-weighted errors drive belief updates.

### Competitive Activation (Memory)

```
A_i(t) = A_i(0) × e^(-λt) + Σ_k boost_k × e^(-λ(t-t_k)) - Σ_j inhibition(i,j) × A_j(t)
```

### Affective Dynamics

```
d(dimension)/dt = Σ(input_signals × weights) - Σ(output_couplings) - decay_rate × dimension
```

---

*This document is the architectural source of truth. For implementation details on any subsystem, see the corresponding file in `docs/expanding_on/`.*
