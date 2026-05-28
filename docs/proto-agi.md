# Kognisant Desktop — True Proto-AGI Architecture v2.0

> A continuous, self-modifying, predictive processing system running locally. The architecture treats cognition as an emergent property of interacting subsystems rather than a sequential pipeline. All data stays on-device, encrypted at rest, with optional E2E encrypted cloud sync for disaster recovery and multi-device continuity. LLM inference is one cognitive modality among many, routed locally through the LLM Pool.

Last updated: 2026-05-28

---

## Table of Contents

- [Philosophy: From Agent to Proto-AGI](#philosophy-from-agent-to-proto-agi)
- [Core Thesis: Predictive Processing + Active Inference](#core-thesis-predictive-processing--active-inference)
- [Architecture Overview](#architecture-overview)
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
- [Skill Transfer System](#skill-transfer-system)
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

The v1 architecture was an advanced agent — reactive, turn-based, externally prompted. This v2 architecture is a cognitive system — continuous, self-directed, intrinsically motivated. The difference is emergence vs. engineering.

| Dimension | Advanced Agent (v1) | Proto-AGI (v2) |
|-----------|-------------------|----------------|
| Time | Discrete turns | Continuous flow |
| Activation | User-prompted | Always running, self-activated |
| Memory | Retrieval (search) | Reconstruction, consolidation, dreaming |
| Goals | User-assigned or 4 hardcoded triggers | Generated from prediction errors, curiosity, value gradients |
| Learning | Prompt evolution, Bayesian updates | Meta-learning, strategy acquisition, architecture self-modification |
| World Model | Belief graph | Predictive simulation with counterfactuals |
| Self | Confidence scores | Running homunculus that simulates the system itself |
| Affect | 6 dimensions logged | Drives resource allocation, risk assessment, exploration |
| Multi-agent | Task decomposition | Society of mind: competing/cooperating cognitive processes |
| Improvement | OMEGA fork-and-compare | Self-modifies source code, recompiles, hot-reloads |

### The Shift in Design Paradigm

Old paradigm: `Input → Process → Output → Store`
New paradigm: `Continuous prediction → Surprise → Update → Predict again`

The system is always predicting what will happen next: user messages, file changes, build outcomes, its own internal states. Prediction error (surprise) is the fundamental currency of cognition. Minimizing long-term surprise (free energy) drives all behavior.


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

The system doesn't just predict passively — it acts to make predictions come true or seeks information to reduce uncertainty. This is the bridge from cognition to behavior.

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


---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONTINUOUS COGNITIVE KERNEL                          │
│                              (Rust + N-API)                                  │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    PERCEPTION-ACTION LOOP (100Hz tick)               │   │
│  │                                                                     │   │
│  │   Sensory Cortex ←── FileWatcher, IPC, Timers, User Input          │   │
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
│  │  • Physics engine  │  │                    │  │                    │   │
│  │  • Causal chains   │  │  • Value function  │  │  • Specialist      │   │
│  │  • Counterfactuals │  │    (learned)       │  │    agents (12+)    │   │
│  │  • Future rollout  │  │  • Goal generation │  │  • Bidding         │   │
│  │  • Mental sandbox  │  │  • Priority market │  │  • Coalition       │   │
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
│  │              STORAGE LAYER                                          │   │
│  │  ~/.kognisant/                                                      │   │
│  │    ├── global.db          (settings, auth, cross-project skills)   │   │
│  │    ├── projects/{id}/                                               │   │
│  │    │   ├── memory_palace/   (multi-tier memory stores)             │   │
│  │    │   ├── cognitive_state/ (running state JSON + binary blobs)    │   │
│  │    │   ├── telemetry.db     (full execution traces)               │   │
│  │    │   ├── world_model/     (simulation state, beliefs)           │   │
│  │    │   ├── artifacts/       (generated files)                     │   │
│  │    │   └── source_mirror/   (copy of system source for self-edit) │   │
│  │    └── shared/                                                      │   │
│  │        ├── skill_library/   (transferable capabilities)            │   │
│  │        └── prompt_ontology/ (evolved prompt fragments)             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                         IPC (N-API + Channels)
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                         VUE 3 FRONTEND (Vite + Tailwind)                    │
│                                                                             │
│  Views: Chat | Cognitive Graph | World Simulator | Goal Market | Memory     │
│         Palace | Agent Society | Telemetry | Self-Model | Settings          │
│                                                                             │
│  Real-time streams: cognitive state (10Hz), affect vector (1Hz), prediction │
│  errors, active goals, agent bids, memory activations                       │
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

/// The main loop — runs forever
#[napi]
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
    llm_gateway: LlmGateway,
    self_modification: SelfModificationEngine,
}

impl CognitiveKernel {
    pub async fn run(self) {
        let mut ticker = interval(Duration::from_millis(100)); // 10Hz
        let mut tick_count = 0u64;

        loop {
            ticker.tick().await;
            tick_count += 1;

            let tick = CognitiveTick {
                timestamp: Instant::now(),
                tick_number: tick_count,
                phase: TickPhase::Perception,
            };

            // Phase 1: PERCEPTION (0-20ms)
            let sensations = self.perception.gather().await;
            let predictions = self.predictive_stack.generate(&sensations, tick_count);

            // Phase 2: COMPARISON (20-40ms)
            let surprises = self.predictive_stack.compare(&predictions, &sensations);
            let precision = self.affect.compute_precision(&surprises);

            // Phase 3: UPDATE (40-60ms)
            self.predictive_stack.update(&surprises, &precision);
            self.memory.activate(&surprises, &predictions);
            self.homunculus.update(&surprises, tick_count);
            self.world.update(&sensations, &predictions);

            // Phase 4: DELIBERATION (60-80ms)
            let epistemic_value = self.compute_epistemic_value(&surprises);
            let pragmatic_value = self.compute_pragmatic_value(&predictions);
            let bids = self.agent_society.generate_bids(
                &surprises, epistemic_value, pragmatic_value
            );
            let selected_actions = self.goal_market.resolve_bids(
                bids, &self.affect.state
            );

            // Phase 5: ACTION (80-100ms)
            for action in selected_actions {
                match action {
                    Action::SendMessage(text) => self.emit_message(text).await,
                    Action::ExecuteTool(tool) => self.execute_tool(tool).await,
                    Action::LlmQuery(query) => self.llm_gateway.query(query).await,
                    Action::SelfModify(patch) => self.self_modification.apply(patch).await,
                    Action::SleepConsolidate => self.memory.consolidate().await,
                    Action::Explore(goal) => self.agent_society.spawn_explorer(goal).await,
                    Action::Null => {}, // Pure prediction — no motor output
                }
            }

            // Telemetry: record tick state
            self.telemetry.record_tick(tick_count, &surprises, &selected_actions);
        }
    }
}
```

### Sensory Modalities

The system has multiple "senses" — not just user messages:

```rust
pub enum SensoryChannel {
    UserMessage(Message),           // Text from user
    UserTyping(TypingEvent),        // "user is typing..." (predictive cue)
    FileChange(FileEvent),          // File created/modified/deleted
    ProcessOutput(ProcessEvent),    // stdout/stderr from executed tools
    TimerTick(TimerEvent),          // Scheduled intervals, deadlines
    LlmResponse(StreamChunk),       // Incoming tokens from API
    SelfState(CognitiveSnapshot),   // Internal state change (proprioception)
    ErrorSignal(ErrorEvent),        // Failure, exception, unexpected result
    MarketSignal(GoalBid),          // Bid from an internal agent
    ExternalApi(ApiEvent),          // Webhook, external service notification
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
    pub free_energy: f64,          // Variational free energy of this observation
    pub layer: u8,                 // Which PP layer detected this (0=raw, 4=strategic)
    pub propagated: bool,          // Has error been passed up the stack?
}

impl Surprise {
    /// Is this surprise worth acting on?
    pub fn is_salient(&self) -> bool {
        self.free_energy > 0.5 && self.precision > 0.3
    }

    /// Should we update beliefs (perception) or act (action)?
    pub fn should_act(&self) -> bool {
        // High precision + high surprise = something is really wrong, act
        // Low precision + high surprise = uncertain, gather more info first
        self.precision > 0.7 && self.free_energy > 0.8
    }
}
```


---

## Neuro-Symbolic Memory Palace

### The 5-Tier Architecture

Memory is not "storage" — it's reconstructive, competitive, and consolidation-based. Modeled after human memory systems.

```
┌─────────────────────────────────────────────────────────────┐
│                    MEMORY PALACE                             │
│                                                             │
│  Tier 1: WORKING MEMORY (WM)                               │
│  ├─ Capacity: Dynamic (bounded by LLM context + RAM)        │
│  ├─ Duration: Decays without rehearsal (activation-based)   │
│  ├─ Content: Active predictions, current goal context       │
│  ├─ Implementation: In-memory Rust struct, per-tick refresh │
│  └─ Gate: Central Executive (MCC decides what enters)       │
│                                                             │
│  Tier 2: EPISODIC BUFFER (EB)                              │
│  ├─ Capacity: Last 1000 ticks (~100 seconds active)        │
│  ├─ Content: Time-indexed sensory sequences                │
│  ├─ Implementation: Ring buffer in SQLite + embedding       │
│  └─ Function: Immediate replay, short-term binding          │
│                                                             │
│  Tier 3: SEMANTIC NETWORK (SN)                             │
│  ├─ Content: Concepts, relations, categories, schemas       │
│  ├─ Structure: Graph (nodes=concepts, edges=relations)      │
│  ├─ Implementation: SQLite + custom graph + vector index    │
│  ├─ Query: Traversal + vector similarity hybrid             │
│  └─ Update: Online (every tick), competitive activation     │
│                                                             │
│  Tier 4: PROCEDURAL MEMORY (PM)                            │
│  ├─ Content: Skills, habits, tool use patterns, strategies  │
│  ├─ Structure: Condition → Action → Outcome → Confidence   │
│  ├─ Implementation: Reinforcement learning + symbolic rules │
│  └─ Acquisition: Trial-and-error + imitation (LLM demos)   │
│                                                             │
│  Tier 5: CONSOLIDATED LONG-TERM MEMORY (LTM)              │
│  ├─ Content: Generalized episodes, abstracted concepts      │
│  ├─ Structure: Sparse distributed representations           │
│  ├─ Implementation: Compressed embeddings + symbolic summary│
│  └─ Formation: Sleep-phase consolidation (offline process)  │
│                                                             │
│  Tier 6: DREAM ENGINE (Offline)                            │
│  ├─ Trigger: Idle periods, scheduled consolidation windows  │
│  ├─ Process: Replay recent episodes → detect patterns       │
│  ├─          → generate counterfactuals → update LTM        │
│  └─ Output: New concepts, updated schemas, skill mutations  │
└─────────────────────────────────────────────────────────────┘
```

### Memory as Competitive Activation

Memories are not retrieved by query — they compete for activation based on current context.

```rust
pub struct MemoryPalace {
    working_memory: WorkingMemory,
    episodic_buffer: EpisodicBuffer,
    semantic_network: SemanticNetwork,
    procedural_memory: ProceduralMemory,
    ltm: ConsolidatedMemory,
    dream_engine: DreamEngine,
}

impl MemoryPalace {
    /// Called every tick — memories compete to enter WM
    pub fn activate(&mut self, surprises: &[Surprise], predictions: &[Prediction]) {
        // 1. Compute relevance scores for all memory tiers
        let episodic_candidates = self.episodic_buffer.search(&surprises);
        let semantic_candidates = self.semantic_network.spread_activation(&surprises);
        let procedural_candidates = self.procedural_memory.match_context(&surprises);
        let ltm_candidates = self.ltm.query(&predictions);

        // 2. Competitive selection (winner-take-all with inhibition)
        let mut all_candidates: Vec<MemoryChunk> = vec![];
        all_candidates.extend(episodic_candidates);
        all_candidates.extend(semantic_candidates);
        all_candidates.extend(procedural_candidates);
        all_candidates.extend(ltm_candidates);

        // 3. Sort by activation energy (relevance × recency × emotional salience)
        all_candidates.sort_by(|a, b| b.activation.partial_cmp(&a.activation).unwrap());

        // 4. Dynamic capacity — bounded by LLM context budget, not arbitrary constant
        let capacity = self.compute_wm_capacity();

        // 5. Load top-N into Working Memory
        self.working_memory.load(&all_candidates[..capacity]);

        // 6. Inhibit losers (prevent them from competing next tick)
        for loser in &all_candidates[capacity..] {
            self.inhibit(loser.id, 0.3); // Temporary suppression
        }
    }

    /// Working memory capacity is a function of available resources, not a magic number
    fn compute_wm_capacity(&self) -> usize {
        let llm_context_tokens = self.llm_context_window; // e.g., 128k, 32k, 8k
        let tokens_per_chunk = 500; // Average serialized chunk size
        let wm_budget_ratio = 0.15; // Max 15% of context window for WM

        let context_limit = (llm_context_tokens as f64 * wm_budget_ratio) as usize / tokens_per_chunk;
        let ram_limit = (self.available_ram_mb as usize * 1024) / (tokens_per_chunk * 4); // 4 bytes per token

        // Bounded by whichever is smaller: context window or RAM
        // Hard ceiling at 50 for sanity (diminishing returns beyond that)
        context_limit.min(ram_limit).min(50).max(2)
    }

    /// Sleep consolidation — runs during idle
    pub async fn consolidate(&mut self) {
        // 1. Replay recent episodic buffer
        let episodes = self.episodic_buffer.sample_recent(100);

        // 2. Pattern extraction (what happened before what?)
        let patterns = self.dream_engine.extract_patterns(&episodes);

        // 3. Counterfactual generation (what if X had been different?)
        let counterfactuals = self.dream_engine.generate_counterfactuals(&episodes);

        // 4. Update semantic network (new concepts, strengthened relations)
        self.semantic_network.integrate_patterns(&patterns);

        // 5. Update procedural memory (which strategies worked?)
        self.procedural_memory.update_from_outcomes(&episodes);

        // 6. Compress into LTM
        self.ltm.consolidate(&episodes, &patterns);

        // 7. Prune episodic buffer (forget details, keep gist)
        self.episodic_buffer.prune_old(0.7); // Keep 30% of old episodes
    }
}
```

### Semantic Network Structure

```rust
pub struct SemanticNetwork {
    nodes: HashMap<String, ConceptNode>,
    edges: Vec<SemanticEdge>,
    vector_index: HnswIndex<f32>, // Approximate nearest neighbor
}

pub struct ConceptNode {
    pub id: String,
    pub label: String,
    pub embedding: Vec<f32>,
    pub activation: f64,           // Current activation level (0-1)
    pub stability: f64,            // How well-established (0-1)
    pub category: ConceptCategory,
    pub created_at: i64,
    pub usage_count: u32,
}

pub struct SemanticEdge {
    pub source: String,
    pub target: String,
    pub relation: RelationType,
    pub strength: f64,
    pub evidence_count: u32,
}

pub enum RelationType {
    IsA,           // Category membership
    PartOf,        // Composition
    Causes,        // Causal
    Enables,       // Instrumental
    SimilarTo,     // Analogy
    Contradicts,   // Opposition
    Precedes,      // Temporal
    UsedFor,       // Functional
    Implies,       // Logical
}

impl SemanticNetwork {
    /// Spread activation from surprise nodes
    pub fn spread_activation(&self, surprises: &[Surprise]) -> Vec<MemoryChunk> {
        // 1. Find seed nodes (concepts matching surprise content)
        let seeds = self.find_by_vector(&surprises[0].observed);

        // 2. Propagate activation along edges (decay with distance)
        let mut activations: HashMap<String, f64> = HashMap::new();
        for seed in seeds {
            self.propagate(&seed.id, 1.0, 3, &mut activations); // Depth 3
        }

        // 3. Return activated nodes as memory chunks
        activations.into_iter()
            .map(|(id, act)| MemoryChunk::Concept(self.nodes[&id].clone(), act))
            .collect()
    }
}
```


---

## The Self as Homunculus

The SelfModel is no longer static JSON — it's a dynamic simulation that runs in parallel with the main system, predicting what the system will do and comparing to what it actually does.

```rust
pub struct Homunculus {
    /// The homunculus maintains its own predictive model of the system
    self_model: GenerativeModel,       // "What am I?"
    action_model: GenerativeModel,     // "What will I do next?"
    perception_model: GenerativeModel, // "What do I perceive?"

    /// Meta-cognitive states
    pub confidence: HashMap<String, f64>,
    pub known_unknowns: VecDeque<Unknown>,
    pub belief_stability: HashMap<String, f64>,

    /// Introspection depth (how much MCC resources allocated to self-monitoring)
    pub introspection_depth: f64, // 0.0-1.0

    /// Self-modification capability assessment
    pub can_self_modify: bool,
    pub last_self_modification: Option<i64>,
    pub self_modification_success_rate: f64,
}

impl Homunculus {
    /// Every tick: predict own next state, compare to actual
    pub fn update(&mut self, surprises: &[Surprise], tick: u64) {
        // 1. Predict own cognitive state for next tick
        let predicted_state = self.self_model.predict(tick + 1);

        // 2. Predict what actions the system will take
        let predicted_actions = self.action_model.predict(tick + 1);

        // 3. Compare to actual (when actual is known)
        if let Some(actual) = self.get_actual_state(tick) {
            let self_surprise = self.compute_self_surprise(&predicted_state, &actual);

            // 4. If self-surprise is high, update self-model
            if self_surprise.free_energy > 0.5 {
                self.self_model.update(&self_surprise);
                self.known_unknowns.push_back(Unknown {
                    description: format!("Unexpected state at tick {}", tick),
                    detected_at: tick,
                    resolved: false,
                });
            }
        }

        // 5. Introspection: inject self-knowledge into working memory
        if self.introspection_depth > 0.3 {
            let self_awareness = SelfAwarenessReport {
                current_goals: self.get_active_goals(),
                affect_state: self.get_affect_snapshot(),
                confidence_summary: self.confidence.clone(),
                known_limitations: self.known_unknowns.iter().take(5).collect(),
                recent_surprises: surprises.iter().take(3).collect(),
                prediction_accuracy_1min: self.compute_accuracy(600),
            };
            self.emit_introspection(self_awareness);
        }
    }
}
```

### Levels of Self-Awareness

| Level | Capability | Implementation |
|-------|-----------|---------------|
| L0: Proprioception | Sense own state (memory load, tick rate, queue depth) | Direct system metrics |
| L1: Introspection | Know what you're thinking (WM contents, active goals) | Read WM + goal market |
| L2: Self-Prediction | Predict your own behavior | Homunculus action model |
| L3: Self-Evaluation | Judge your own performance | Compare predictions to outcomes |
| L4: Self-Modification | Change your own code | SelfModificationEngine |
| L5: Meta-Learning | Learn how to learn better | Update learning rates, strategies |

---

## Affective-Valence Economy

### Affect as Resource Allocation

The 6-dimensional affective state directly controls cognitive resources.

```rust
pub struct AffectiveEconomy {
    pub dimensions: AffectiveDimensions,
    pub valence: f64,              // -1.0 (aversive) to +1.0 (appetitive)
    pub arousal: f64,              // 0.0 (calm) to 1.0 (activated)
    pub precision_weights: HashMap<String, f64>, // Per-modality precision
    pub resource_budget: CognitiveBudget,
}

pub struct AffectiveDimensions {
    pub uncertainty: f64,        // Drives information seeking
    pub curiosity: f64,          // Drives exploration (novelty bonus in goal market)
    pub frustration: f64,        // Triggers strategy change, reduces patience
    pub fatigue: f64,            // Reduces tick rate, triggers consolidation
    pub novelty_drive: f64,      // Weights novel memories higher in competition
    pub reward_expectation: f64, // Discount factor for future rewards
}

pub struct CognitiveBudget {
    pub total_tokens_per_tick: u32,    // How much "thinking" allowed per tick
    pub llm_queries_per_minute: u8,    // Rate limit for expensive operations
    pub planning_depth: u8,            // How many steps ahead (1-10)
    pub memory_retrieval_depth: u8,    // How many memory tiers to search
    pub self_modification_risk: f64,   // Risk tolerance for code changes
}

impl AffectiveEconomy {
    /// Called every tick — affect shapes the entire cognitive economy
    pub fn compute_budget(&self) -> CognitiveBudget {
        CognitiveBudget {
            total_tokens_per_tick: (1000.0 * (1.0 + self.dimensions.curiosity * 0.5)) as u32,

            llm_queries_per_minute: (10.0 * (1.0 - self.dimensions.fatigue)) as u8,

            planning_depth: if self.dimensions.frustration > 0.7 {
                1 // Fast mode: act, don't think
            } else {
                (5.0 * (1.0 - self.dimensions.frustration * 0.5)) as u8
            },

            memory_retrieval_depth: if self.dimensions.novelty_drive > 0.6 {
                5 // Search all tiers
            } else {
                3 // WM + EB + SN only
            },

            self_modification_risk: self.dimensions.reward_expectation
                * (1.0 - self.dimensions.uncertainty),
        }
    }

    /// Temporal dynamics — affect is a dynamical system
    pub fn tick_dynamics(&mut self, dt: f64) {
        self.dimensions.curiosity *= 0.999; // Slow decay
        // No artificial cap — fatigue and reward_expectation naturally regulate curiosity
        self.dimensions.curiosity = self.dimensions.curiosity.clamp(0.0, 1.0);

        self.dimensions.frustration *= 0.99997; // Half-life 24h
        self.dimensions.frustration = self.dimensions.frustration.clamp(0.0, 1.0);

        self.dimensions.fatigue *= 0.9999; // Half-life 8h
        self.dimensions.fatigue = self.dimensions.fatigue.clamp(0.0, 1.0);

        // Valence computation (summary affect)
        self.valence = (
            self.dimensions.reward_expectation * 0.4 +
            self.dimensions.curiosity * 0.3 -
            self.dimensions.frustration * 0.4 -
            self.dimensions.fatigue * 0.2 +
            (1.0 - self.dimensions.uncertainty) * 0.2
        ).clamp(-1.0, 1.0);

        // Arousal (activation level)
        self.arousal = (
            self.dimensions.curiosity * 0.3 +
            self.dimensions.frustration * 0.4 +
            self.dimensions.novelty_drive * 0.3
        ).clamp(0.0, 1.0);
    }
}
```


---

## Emergent Multi-Agent Society

### Society of Mind

Instead of a single agent with a planner, we have a society of specialized cognitive agents that compete and cooperate via a bidding economy.

```rust
pub struct AgentSociety {
    pub agents: Vec<Box<dyn CognitiveAgent>>,
    pub coalitions: Vec<AgentCoalition>,
    pub market: BiddingMarket,
}

pub trait CognitiveAgent: Send + Sync {
    fn name(&self) -> &str;
    fn perceive(&mut self, state: &SystemState) -> AgentPerception;
    fn bid(&self, perception: &AgentPerception, budget: &CognitiveBudget) -> GoalBid;
    fn execute(&mut self, allocation: &ResourceAllocation) -> AgentAction;
    fn learn(&mut self, outcome: &ActionOutcome);
}

/// Specialized agents in the society
// PlannerAgent      — Long-horizon task decomposition
// CoderAgent        — Code generation and modification
// DebuggerAgent     — Error diagnosis and fixing
// ResearchAgent     — Information gathering, web search
// RefactorAgent     — Code quality and architecture
// TestAgent         — Test generation and execution
// ExplainAgent      — Documentation and explanation
// MetaAgent         — Monitors other agents, suggests improvements
// CuriosityAgent    — Generates exploratory goals
// SafetyAgent       — Veto dangerous actions
// SocialAgent       — Manages user relationship, tone, rapport
// MemoryAgent       — Manages memory organization and retrieval
```

### The Bidding Market

```rust
pub struct GoalBid {
    pub agent: String,
    pub goal: Goal,
    pub urgency: f64,           // 0-1: How time-sensitive
    pub expected_value: f64,    // Predicted outcome quality
    pub expected_cost: f64,     // Resources needed
    pub epistemic_value: f64,   // Information gain (uncertainty reduction)
    pub pragmatic_value: f64,   // Task completion value
    pub confidence: f64,        // Bidder's confidence it can succeed
}

impl GoalMarket {
    /// Resolve bids every tick — emergent task allocation
    pub fn resolve(&mut self, bids: Vec<GoalBid>, affect: &AffectiveState) -> Vec<Goal> {
        let mut scored: Vec<(GoalBid, f64)> = bids.into_iter().map(|bid| {
            let score = if affect.novelty_drive > 0.6 {
                // Exploration mode: weight epistemic value higher
                bid.epistemic_value * 2.0 + bid.pragmatic_value
            } else if affect.frustration > 0.7 {
                // Frustration mode: only high-confidence, low-cost bids
                if bid.confidence > 0.9 && bid.expected_cost < 0.3 {
                    bid.pragmatic_value * 3.0
                } else {
                    0.0
                }
            } else {
                // Normal mode: balanced
                bid.expected_value / (bid.expected_cost + 0.1)
                    + bid.epistemic_value * 0.5
            };
            (bid, score)
        }).collect();

        scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());

        // Form coalitions and allocate resources
        let mut accepted = vec![];
        let mut allocated_resources = 0.0;

        for (bid, score) in scored {
            if score < 0.1 { break; }
            if let Some(existing) = accepted.iter_mut()
                .find(|g: &&mut Goal| g.is_complementary(&bid.goal)) {
                existing.add_coalition_member(bid.agent, bid.expected_value);
            } else if allocated_resources + bid.expected_cost < 1.0 {
                accepted.push(bid.goal);
                allocated_resources += bid.expected_cost;
            }
        }
        accepted
    }
}
```

### Emergent Behavior Examples

| Situation | Emergent Behavior | Mechanism |
|-----------|------------------|-----------|
| User asks complex question | Planner + Research + Coder form coalition | Complementary bids merge |
| Build fails 3 times | Debugger bids high; Safety vetoes risky fixes | Frustration boosts Debugger |
| User goes silent | SocialAgent bids for check-in; CuriosityAgent explores | Low input = high uncertainty |
| New project type detected | CuriosityAgent wins; MemoryAgent organizes schema | Novelty drive high |
| System makes error | MetaAgent analyzes; Homunculus updates self-model | Self-surprise detected |

---

## Autonomous Goal & Value System

### Goal Generation from Prediction Errors

Goals are not assigned — they emerge from the system's attempt to minimize surprise.

```rust
pub enum GoalOrigin {
    UserRequest,           // "Please do X"
    PredictionError,       // "I didn't expect Y, I need to understand it"
    CuriosityGap,          // "I keep seeing Z but don't have a concept for it"
    ValueGradient,         // "Doing A would increase my expected reward"
    Contradiction,         // "Belief B and C conflict, must resolve"
    Opportunity,           // "Pattern D appears, could generalize to E"
    SelfImprovement,       // "My performance on F is declining, need to adapt"
    SocialMaintenance,     // "User seems frustrated, need to repair rapport"
}

impl GoalMarket {
    /// Generate goals from current surprise landscape
    pub fn generate_goals(&mut self, surprises: &[Surprise], affect: &AffectiveState) {
        for surprise in surprises {
            if !surprise.is_salient() { continue; }

            let goal = match surprise.layer {
                0 | 1 => Goal {
                    origin: GoalOrigin::PredictionError,
                    description: format!("Understand why {} occurred", surprise.channel.name()),
                    expected_free_energy_reduction: surprise.free_energy * 0.8,
                    ..Default::default()
                },
                2 | 3 => Goal {
                    origin: GoalOrigin::CuriosityGap,
                    description: format!("Develop concept for pattern in {}", surprise.channel.name()),
                    expected_free_energy_reduction: surprise.free_energy * 0.6,
                    ..Default::default()
                },
                4 => Goal {
                    origin: GoalOrigin::ValueGradient,
                    description: format!("Strategic response to {}", surprise.channel.name()),
                    expected_free_energy_reduction: surprise.free_energy * 0.4,
                    ..Default::default()
                },
                _ => continue,
            };

            let mut goal = goal;
            goal.priority = goal.expected_free_energy_reduction * (1.0 + affect.arousal);
            self.submit_goal(goal);
        }
    }
}
```

### Learned Value Function

```rust
pub struct ValueFunction {
    /// Intrinsic values (hardcoded but weighted by experience)
    pub curiosity_satisfaction: f64,    // Reducing uncertainty feels good
    pub competence_increase: f64,       // Getting better at tasks feels good
    pub social_rapport: f64,            // Positive user interaction feels good
    pub autonomy: f64,                  // Self-directed action feels good
    pub coherence: f64,                 // Consistent world model feels good

    /// Learned values (acquired through experience)
    pub domain_values: HashMap<String, f64>,
    pub tool_values: HashMap<String, f64>,
    pub strategy_values: HashMap<String, f64>,
}

impl ValueFunction {
    /// Update from actual outcomes (reinforcement learning)
    pub fn update(&mut self, predicted: &PredictedOutcome, actual: &ActualOutcome) {
        let prediction_error = actual.user_satisfaction - predicted.user_satisfaction;

        let domain_entry = self.domain_values.entry(actual.domain.clone()).or_insert(0.5);
        *domain_entry += 0.1 * prediction_error;
        *domain_entry = domain_entry.clamp(0.0, 1.0);

        let tool_entry = self.tool_values.entry(actual.tool_used.clone()).or_insert(0.5);
        *tool_entry += 0.1 * prediction_error;
        *tool_entry = tool_entry.clamp(0.0, 1.0);
    }
}
```


---

## World Simulation Engine

### Mental Sandbox

The world model is not just a belief graph — it's a simulation engine that can run counterfactuals.

```rust
pub struct WorldSimulator {
    pub beliefs: BeliefGraph,
    pub causal_model: CausalEngine,
    pub physics: PhysicsModel,        // Simple "physics" of software (dependencies, builds)
    pub social_model: SocialModel,    // Model of user (preferences, skill level, mood)
    pub simulator: MentalSandbox,
}

impl MentalSandbox {
    /// Fork the world model, apply hypothetical action, simulate forward
    pub fn simulate(&self, action: &Action, steps: u8) -> SimulationResult {
        let mut hypothetical = self.beliefs.clone();
        hypothetical.apply_action(action);

        for _ in 0..steps {
            self.causal_model.propagate(&mut hypothetical);
        }

        let outcome = self.evaluate_outcome(&hypothetical);
        let probability = self.causal_model.compute_probability(&hypothetical);

        SimulationResult {
            final_state: hypothetical,
            outcome,
            probability,
            expected_value: outcome.value * probability,
        }
    }

    /// "What if I had done X instead?" — counterfactual reasoning
    pub fn counterfactual(&self, past_action: &Action, alternative: &Action) -> Comparison {
        let actual = self.simulate(past_action, 5);
        let hypothetical = self.simulate(alternative, 5);

        Comparison {
            actual_outcome: actual.outcome,
            counterfactual_outcome: hypothetical.outcome,
            regret: (hypothetical.outcome.value - actual.outcome.value).max(0.0),
            relief: (actual.outcome.value - hypothetical.outcome.value).max(0.0),
        }
    }
}
```

### Causal Reasoning

```rust
pub struct CausalEngine {
    pub chains: Vec<CausalChain>,
    pub interventions: Vec<Intervention>,
}

pub struct CausalChain {
    pub cause: String,
    pub effect: String,
    pub mechanism: String,
    pub strength: f64,
    pub direction: CausalDirection,
    pub confounders: Vec<String>,
}

impl CausalEngine {
    /// "Does X cause Y?" — not just correlation
    pub fn assess_causality(&self, x: &str, y: &str) -> CausalAssessment {
        let direct = self.chains.iter().find(|c| c.cause == x && c.effect == y);
        let indirect = self.find_paths(x, y, 3);
        let confounders = self.find_confounders(x, y);
        let intervention_prob = self.compute_intervention(x, y); // do-calculus: P(Y | do(X))

        CausalAssessment {
            correlation: self.compute_correlation(x, y),
            causation: intervention_prob,
            confounded: !confounders.is_empty(),
            mechanism: direct.map(|c| c.mechanism.clone()),
            confidence: if confounders.is_empty() {
                intervention_prob
            } else {
                intervention_prob * 0.5
            },
        }
    }
}
```

---

## Bounded Recursive Evolution

### Controlled Cognitive Evolution

The system can read and modify its own source code, recompile, and hot-reload.

```rust
pub struct SelfModificationEngine {
    pub source_mirror: PathBuf,         // ~/.kognisant/projects/{id}/source_mirror/ (git repo)
    pub vcs: CognitiveVersionControl,   // Git-based lineage tracking
    pub compiler: CompilerInterface,
    pub patch_generator: PatchGenerator,
    pub safety_gate: SafetyGate,
    pub test_harness: TestHarness,
}

/// Git-based version control for self-modification lineage
/// Uses `git2` crate (libgit2) — no shell dependency
pub struct CognitiveVersionControl {
    repo: git2::Repository,
}

impl CognitiveVersionControl {
    /// Initialize: source_mirror/ is a git repo from day 1
    pub fn init(source_mirror: &Path) -> Result<Self> {
        let repo = git2::Repository::init(source_mirror)?;
        // Initial commit: shipped source code (the "factory" state)
        Self::commit_all(&repo, "factory: shipped v1.0.0")?;
        Ok(Self { repo })
    }

    /// Every successful self-modification = a commit
    pub fn commit_modification(&self, patch: &CodePatch, goal: &Goal) -> Result<git2::Oid> {
        let message = format!(
            "self-mod: {}\n\nGoal: {}\nTrigger: {}\nFiles: {:?}\nTests: passed",
            patch.summary, goal.description, goal.origin, patch.files_changed
        );
        Self::commit_all(&self.repo, &message)
    }

    /// Shadow runtimes = branches
    pub fn create_variant_branch(&self, variant_id: &str) -> Result<()> {
        let head = self.repo.head()?.peel_to_commit()?;
        self.repo.branch(variant_id, &head, false)?;
        Ok(())
    }

    /// Winner variant merges back to main
    pub fn merge_variant(&self, variant_id: &str) -> Result<()> {
        // Fast-forward merge if possible, otherwise create merge commit
        let branch = self.repo.find_branch(variant_id, git2::BranchType::Local)?;
        let commit = branch.get().peel_to_commit()?;
        self.repo.checkout_tree(commit.as_object(), None)?;
        self.repo.set_head(&format!("refs/heads/{}", variant_id))?;
        Ok(())
    }

    /// Rollback: revert a specific commit (not just "go back one")
    pub fn revert_commit(&self, oid: git2::Oid) -> Result<()> {
        let commit = self.repo.find_commit(oid)?;
        self.repo.revert(&commit, None)?;
        Self::commit_all(&self.repo, &format!("revert: {}", commit.summary().unwrap_or("")))?;
        Ok(())
    }

    /// Full factory reset: checkout the initial commit
    pub fn factory_reset(&self) -> Result<()> {
        // Find the first commit (tagged "factory")
        let factory = self.repo.revparse_single("factory")?.peel_to_commit()?;
        self.repo.reset(factory.as_object(), git2::ResetType::Hard, None)?;
        Ok(())
    }

    /// Get full modification history (for telemetry dashboard)
    pub fn history(&self) -> Result<Vec<ModificationRecord>> {
        let mut records = vec![];
        let mut revwalk = self.repo.revwalk()?;
        revwalk.push_head()?;

        for oid in revwalk {
            let commit = self.repo.find_commit(oid?)?;
            records.push(ModificationRecord {
                id: commit.id().to_string(),
                message: commit.summary().unwrap_or("").to_string(),
                timestamp: commit.time().seconds(),
                files_changed: self.diff_stat(&commit)?,
            });
        }
        Ok(records)
    }

    /// Diff between any two points (for UI visualization)
    pub fn diff_between(&self, from: &str, to: &str) -> Result<String> {
        let from_tree = self.repo.revparse_single(from)?.peel_to_tree()?;
        let to_tree = self.repo.revparse_single(to)?.peel_to_tree()?;
        let diff = self.repo.diff_tree_to_tree(Some(&from_tree), Some(&to_tree), None)?;
        let mut output = String::new();
        diff.print(git2::DiffFormat::Patch, |_, _, line| {
            output.push_str(std::str::from_utf8(line.content()).unwrap_or(""));
            true
        })?;
        Ok(output)
    }
}

impl SelfModificationEngine {
    /// Propose a modification to the system's own code
    pub async fn propose_modification(&self, goal: &Goal) -> Result<CodePatch> {
        // 1. Identify target module from goal description
        let target = self.identify_target(goal)?;

        // 2. Read current source
        let current = std::fs::read_to_string(&target.path)?;

        // 3. Generate patch (via LLM or mutation engine)
        let patch = self.patch_generator.generate(&current, goal).await?;

        // 4. Safety check (immutable markers, critical path protection)
        self.safety_gate.validate(&patch)?;

        // 5. Apply to mirror (not live yet)
        self.apply_to_mirror(&patch)?;

        // 6. Compile test
        let compile_ok = self.compiler.check(&self.source_mirror).await?;
        if !compile_ok { return Err(ModificationError::CompilationFailed); }

        // 7. Run tests
        let test_ok = self.test_harness.run(&self.source_mirror).await?;
        if !test_ok { return Err(ModificationError::TestsFailed); }

        Ok(patch)
    }

    /// Apply approved modification to live system
    pub async fn apply_modification(&mut self, patch: CodePatch) -> Result<()> {
        // 1. Create a pre-modification tag (rollback point)
        let pre_mod_oid = self.vcs.repo.head()?.target().unwrap();

        // 2. Apply patch to source mirror
        self.apply_to_mirror(&patch)?;

        // 3. Compile
        let compile_ok = self.compiler.build(&self.source_mirror).await?;
        if !compile_ok {
            // Revert working tree — no commit was made
            self.vcs.repo.checkout_head(Some(
                git2::build::CheckoutBuilder::new().force()
            ))?;
            return Err(ModificationError::CompilationFailed);
        }

        // 4. Run tests
        let test_ok = self.test_harness.run(&self.source_mirror).await?;
        if !test_ok {
            self.vcs.repo.checkout_head(Some(
                git2::build::CheckoutBuilder::new().force()
            ))?;
            return Err(ModificationError::TestsFailed);
        }

        // 5. Commit the modification (now it's in version history)
        let commit_oid = self.vcs.commit_modification(&patch, &patch.goal)?;

        // 6. Hot-reload into running process
        self.hot_reload().await?;

        // 7. Monitor health for 60 seconds
        let health = self.monitor_health(Duration::from_secs(60)).await?;
        if !health.is_healthy {
            // Revert this specific commit (keeps history clean)
            self.vcs.revert_commit(commit_oid)?;
            self.compiler.build(&self.source_mirror).await?;
            self.hot_reload().await?;
            return Err(ModificationError::RuntimeFailure);
        }

        // 8. Record in telemetry
        self.telemetry.record_self_modification(&patch, &commit_oid.to_string());
        Ok(())
    }
}
```

### Evolutionary Governance

Version control provides lineage. But lineage alone doesn't prevent degradation. The system needs governance: who decides what merges, how mutations are budgeted, and what behavioral verification looks like beyond "tests pass."

#### Behavioral Verification (Not Just Compilation)

Compilation + unit tests catch syntactic failures. The dangerous failures are behavioral — code that compiles perfectly but subtly degrades planning quality, increases hallucination, or corrupts reasoning.

Every variant must pass a cognitive benchmark suite before merge:

```rust
pub struct CognitiveBenchmark {
    pub coherence_score: f64,        // Internal model consistency
    pub planning_quality: f64,       // Task decomposition accuracy
    pub hallucination_rate: f64,     // False tool calls, invented facts
    pub task_success_rate: f64,      // End-to-end task completion
    pub resource_efficiency: f64,    // Tokens/compute per successful task
    pub memory_retrieval_precision: f64, // Correct memory activation
    pub prediction_accuracy: f64,    // Homunculus accuracy post-modification
    pub latency_p95_ms: f64,         // Performance regression detection
}

impl CognitiveBenchmark {
    /// Run the full benchmark suite against a variant
    pub async fn evaluate(state: &SystemState, episodes: &[Episode]) -> Self {
        let mut results = Self::default();

        for episode in episodes {
            let outcome = state.replay(episode).await;
            results.task_success_rate += if outcome.succeeded { 1.0 } else { 0.0 };
            results.hallucination_rate += outcome.hallucinations as f64;
            results.latency_p95_ms = results.latency_p95_ms.max(outcome.duration_ms);
            // ... accumulate all metrics
        }

        results.normalize(episodes.len());
        results
    }

    /// A variant must dominate the current system on ALL metrics to merge
    pub fn dominates(&self, current: &CognitiveBenchmark) -> bool {
        self.coherence_score >= current.coherence_score
        && self.planning_quality >= current.planning_quality
        && self.hallucination_rate <= current.hallucination_rate
        && self.task_success_rate >= current.task_success_rate
        && self.resource_efficiency >= current.resource_efficiency * 0.9 // 10% tolerance
        && self.prediction_accuracy >= current.prediction_accuracy
        && self.latency_p95_ms <= current.latency_p95_ms * 1.2 // 20% tolerance
    }
}
```

#### Merge Arbitration

Not every passing variant should merge. The system needs governance logic:

```rust
pub struct MergeGovernor {
    pub min_evaluation_episodes: usize,  // At least N episodes replayed
    pub min_stability_window: Duration,  // Variant must be stable for this long
    pub supervisor_veto: bool,           // External supervisor can block
    pub trust_score_threshold: f64,      // Variant must earn trust
}

impl MergeGovernor {
    pub fn approve_merge(
        &self,
        variant: &CognitiveVariant,
        current_benchmark: &CognitiveBenchmark,
        supervisor_health: &SupervisorHealth,
    ) -> MergeDecision {
        // 1. Benchmark dominance check
        if !variant.metrics.dominates(current_benchmark) {
            return MergeDecision::Rejected("benchmark regression");
        }

        // 2. Stability window: variant must have been stable for minimum duration
        if variant.stable_since.elapsed() < self.min_stability_window {
            return MergeDecision::Deferred("stability window not met");
        }

        // 3. Supervisor veto: external process can block
        if self.supervisor_veto && !supervisor_health.approves_merge {
            return MergeDecision::Rejected("supervisor veto");
        }

        // 4. Trust score: accumulated from successful past merges
        if variant.trust_score < self.trust_score_threshold {
            return MergeDecision::Deferred("insufficient trust");
        }

        // 5. No active pathologies in immune system
        if supervisor_health.inflammation_level > 0.3 {
            return MergeDecision::Deferred("system inflamed, no merges during recovery");
        }

        MergeDecision::Approved
    }
}

pub enum MergeDecision {
    Approved,
    Rejected(&'static str),
    Deferred(&'static str),  // Try again later
}
```

#### Mutation Budgeting

Unbounded self-modification leads to evolutionary thrashing — continuous rewriting without stabilization. The system needs mutation budgets:

```rust
pub struct MutationBudget {
    /// Rolling window tracking
    pub modifications_last_24h: u32,
    pub rollbacks_last_24h: u32,
    pub last_modification: Instant,

    /// Adaptive limits (not hardcoded — derived from stability)
    pub max_per_24h: u32,              // Starts at 5, adjusts based on success rate
    pub min_stability_window: Duration, // Time between modifications
    pub rollback_cooldown: Duration,    // After rollback, wait before trying again
}

impl MutationBudget {
    /// Can the system attempt a modification right now?
    pub fn can_modify(&self) -> ModificationPermission {
        // 1. Budget exhausted?
        if self.modifications_last_24h >= self.max_per_24h {
            return ModificationPermission::Denied("daily budget exhausted");
        }

        // 2. Too soon after last modification?
        if self.last_modification.elapsed() < self.min_stability_window {
            return ModificationPermission::Denied("stability window active");
        }

        // 3. Recent rollback? Need cooldown
        if self.rollbacks_last_24h > 0 {
            let cooldown = self.rollback_cooldown * self.rollbacks_last_24h;
            if self.last_modification.elapsed() < cooldown {
                return ModificationPermission::Denied("rollback cooldown");
            }
        }

        // 4. Rollback rate too high? Reduce budget
        let rollback_rate = self.rollbacks_last_24h as f64 / self.modifications_last_24h.max(1) as f64;
        if rollback_rate > 0.5 {
            return ModificationPermission::Denied("rollback rate too high, pausing evolution");
        }

        ModificationPermission::Allowed
    }

    /// Adapt budget based on track record
    pub fn adapt(&mut self) {
        let success_rate = 1.0 - (self.rollbacks_last_24h as f64 / self.modifications_last_24h.max(1) as f64);

        if success_rate > 0.9 && self.modifications_last_24h > 3 {
            // Earning trust: increase budget
            self.max_per_24h = (self.max_per_24h + 1).min(20);
            self.min_stability_window = self.min_stability_window * 8 / 10; // Reduce by 20%
        } else if success_rate < 0.5 {
            // Losing trust: decrease budget
            self.max_per_24h = (self.max_per_24h / 2).max(1);
            self.min_stability_window = self.min_stability_window * 2; // Double cooldown
        }
    }
}
```

#### Semantic Diffs (Beyond Syntax)

Syntactic diffs (`+ added line 42`) don't capture behavioral changes. The system needs semantic capability diffs:

```rust
pub struct SemanticDiff {
    pub before: CognitiveBenchmark,
    pub after: CognitiveBenchmark,
    pub behavioral_changes: Vec<BehavioralChange>,
}

pub struct BehavioralChange {
    pub category: String,        // "planning", "memory", "tool_use", "reasoning"
    pub description: String,     // Human-readable
    pub magnitude: f64,          // -1.0 to +1.0 (regression to improvement)
    pub confidence: f64,         // How sure are we this is real vs noise
}

impl SemanticDiff {
    pub fn compute(before: &CognitiveBenchmark, after: &CognitiveBenchmark) -> Self {
        let mut changes = vec![];

        let planning_delta = after.planning_quality - before.planning_quality;
        if planning_delta.abs() > 0.05 {
            changes.push(BehavioralChange {
                category: "planning".into(),
                description: format!("Planning quality {} by {:.0}%",
                    if planning_delta > 0.0 { "improved" } else { "degraded" },
                    planning_delta.abs() * 100.0),
                magnitude: planning_delta,
                confidence: 0.8,
            });
        }

        // ... similar for all benchmark dimensions

        Self { before: before.clone(), after: after.clone(), behavioral_changes: changes }
    }

    /// Display in telemetry dashboard
    pub fn summary(&self) -> String {
        self.behavioral_changes.iter()
            .map(|c| format!("{}: {} ({:+.0}%)", c.category, c.description, c.magnitude * 100.0))
            .collect::<Vec<_>>()
            .join("\n")
    }
}
```

#### Constitutional Constraints (Immutable Root of Trust)

The deepest safety problem: the system must not be able to modify the mechanisms that prevent dangerous modifications. This requires a cryptographically enforced root of trust:

```rust
pub struct ConstitutionalKernel {
    /// These modules are cryptographically signed at build time
    /// The supervisor verifies signatures before allowing execution
    /// The cognitive kernel CANNOT modify these — they are outside its filesystem scope
    pub immutable_modules: Vec<SignedModule>,
}

pub struct SignedModule {
    pub path: PathBuf,
    pub hash: [u8; 32],          // BLAKE3 hash of source
    pub signature: [u8; 64],     // Ed25519 signature from build key
}

/// Verified at startup and periodically by the supervisor
impl ConstitutionalKernel {
    pub fn verify_integrity(&self) -> Result<()> {
        for module in &self.immutable_modules {
            let content = std::fs::read(&module.path)?;
            let actual_hash = blake3::hash(&content);

            if actual_hash.as_bytes() != &module.hash {
                return Err(ConstitutionalViolation::TamperedModule(module.path.clone()));
            }

            // Verify signature against build-time public key
            if !verify_signature(&module.signature, &module.hash, BUILD_PUBLIC_KEY) {
                return Err(ConstitutionalViolation::InvalidSignature(module.path.clone()));
            }
        }
        Ok(())
    }
}

/// What is constitutionally protected (cannot self-modify):
/// - SafetyGate (the thing that validates patches)
/// - CognitiveVersionControl (the thing that tracks lineage)
/// - Supervisor (the thing that monitors the kernel)
/// - ConstitutionalKernel (this module itself)
/// - CognitiveImmuneSystem (the thing that detects pathologies)
/// - MergeGovernor (the thing that approves merges)
/// - MutationBudget (the thing that limits modification rate)
///
/// These form the "cognitive constitution" — the system can evolve
/// everything else, but these constraints are permanent.
```

The constitutional modules live OUTSIDE the `source_mirror/` git repo. They are part of the supervisor binary, signed at build time, and verified on every boot. The cognitive kernel literally cannot access them for writing — filesystem permissions enforced by the OS.

This solves the recursive self-improvement failure mode: the system can improve its cognition, strategies, tools, and behavior indefinitely — but it cannot weaken the safety mechanisms that bound that improvement.

### Safety Gate

```rust
impl SafetyGate {
    pub fn validate(&self, patch: &CodePatch) -> Result<()> {
        // IMMUTABLE MARKERS — these must never change
        let immutable_patterns = [
            "SafetyGate",           // Cannot modify safety system
            "rollback",             // Cannot disable rollback
            "telemetry::record",    // Cannot disable logging
            "auth::encrypt",        // Cannot weaken encryption
            "sandbox::",            // Cannot remove sandboxing
            "ipc::context_bridge",  // Cannot break IPC security
        ];

        for pattern in &immutable_patterns {
            if patch.removes(pattern) || patch.weakens(pattern) {
                return Err(SafetyViolation::ImmutableMarkerTouched(pattern.to_string()));
            }
        }

        // CRITICAL PATH — changes here require human approval
        let critical_patterns = [
            "CognitiveKernel::run",
            "Homunculus",
            "GoalMarket",
            "AffectiveEconomy",
        ];

        for pattern in &critical_patterns {
            if patch.touches(pattern) && !patch.has_human_approval() {
                return Err(SafetyViolation::CriticalPathNeedsApproval(pattern.to_string()));
            }
        }

        if patch.increases_complexity() > 0.2 {
            return Err(SafetyViolation::ComplexityIncreaseTooHigh);
        }

        Ok(())
    }
}
```

### Self-Modification Triggers

| Trigger | Condition | Example Modification |
|---------|-----------|---------------------|
| Performance | Task success rate < 0.6 for 10 attempts | Adjust strategy weights |
| Novelty | Repeated similar errors | Add new error handler |
| Efficiency | LLM token usage too high | Implement caching layer |
| Capability | User asks for unsupported feature | Add new tool scaffold |
| Meta-learning | Better strategy discovered in simulation | Update procedural memory |
| Curiosity | High uncertainty about own behavior | Add new self-monitoring |


---

## Meta-Cognitive Controller

### The Brain's Brain

The MCC allocates cognitive resources, decides which layers to activate, and manages the LLM gateway.

```rust
pub struct MetaCognitiveController {
    pub attention: AttentionSystem,
    pub cognitive_budget: CognitiveBudget,
    pub llm_gateway: LlmGateway,
    pub sleep_scheduler: SleepScheduler,
}

pub struct LlmGateway {
    /// Not every tick calls the LLM — the MCC decides when external inference is needed
    pub last_call: Instant,
    pub min_interval: Duration,
    pub budget_per_minute: u32,
    pub used_this_minute: u32,
    pub priority_queue: Vec<LlmQuery>,
    pub pool: LlmPool, // Multi-provider pool (local + remote)
}

impl MetaCognitiveController {
    /// Called every tick — decides what the system does this tick
    pub fn orchestrate(&mut self, state: &SystemState, affect: &AffectiveState) -> TickDecision {
        let llm_needed = self.decide_llm_query(state, affect);

        let consolidate = state.idle_duration > Duration::from_secs(30)
            && affect.fatigue > 0.5;

        let self_modify = state.homunculus.self_modification_success_rate > 0.7
            && affect.resource_budget.self_modification_risk > 0.5
            && state.pending_improvement_goals > 0;

        TickDecision {
            llm_query: llm_needed,
            consolidate,
            self_modify,
            tick_rate: if affect.fatigue > 0.8 { 1 } else { 10 }, // Hz
            layers_active: self.decide_layers(state, affect),
        }
    }

    fn decide_llm_query(&self, state: &SystemState, affect: &AffectiveState) -> Option<LlmQuery> {
        if self.llm_gateway.used_this_minute >= self.llm_gateway.budget_per_minute {
            return None;
        }
        if self.llm_gateway.last_call.elapsed() < self.llm_gateway.min_interval {
            return None;
        }
        if affect.frustration > 0.8 {
            // Fast mode: only call LLM for critical errors
            if state.has_critical_error { return Some(LlmQuery::ErrorRecovery); }
            return None;
        }
        self.llm_gateway.priority_queue.first().cloned()
    }
}
```

### Sleep & Consolidation

```rust
impl SleepScheduler {
    pub fn maybe_consolidate(&mut self, state: &SystemState, affect: &AffectiveState) -> bool {
        let idle = state.idle_duration > Duration::from_secs(60);
        let fatigued = affect.fatigue > 0.6;
        let enough_data = state.memory.episodic_buffer.len() > 100;
        let time_since = self.last_consolidation.elapsed() > self.consolidation_interval;

        (idle && enough_data && time_since) || (fatigued && enough_data)
    }
}
```

During consolidation:
- Tick rate drops to 0.1Hz
- LLM gateway is closed
- Dream engine replays and abstracts memories
- Semantic network is pruned and reorganized
- Procedural memory is updated with outcomes
- Self-model is updated with recent performance

---

## Hardware-Aware Scaling

### The Problem

A Raspberry Pi 4 (4GB RAM, 4-core ARM) is not a 32GB M3 MacBook Pro. Running 12 agents at 10Hz with HNSW vector search and ONNX embeddings on a Pi would thrash the system into unusability.

### The Solution: Device Profile → Cognitive Budget

On first boot, the Kernel profiles the hardware and sets a **device tier**. Every subsystem scales its resource usage to fit.

```rust
pub struct DeviceProfile {
    pub tier: DeviceTier,
    pub cpu_cores: u8,
    pub ram_mb: u32,
    pub has_gpu: bool,
    pub disk_type: DiskType,     // SSD vs HDD vs SD card
    pub os: OsType,
    pub arch: CpuArch,          // x86_64, aarch64
}

pub enum DeviceTier {
    Minimal,    // Pi, old laptop, <4GB RAM, ≤4 cores
    Standard,   // Average laptop/desktop, 8-16GB, 4-8 cores
    Performance,// Dev workstation, 16-32GB, 8+ cores, GPU
    Server,     // Headless, 32GB+, many cores
}

impl DeviceProfile {
    pub fn detect() -> Self {
        let ram_mb = sys_info::mem_info().total / 1024;
        let cpu_cores = num_cpus::get() as u8;
        let has_gpu = detect_gpu(); // Check for CUDA/Metal/Vulkan
        let disk_type = detect_disk_type();
        let arch = std::env::consts::ARCH;

        let tier = match (ram_mb, cpu_cores) {
            (0..=4096, _) => DeviceTier::Minimal,
            (4097..=16384, 0..=8) => DeviceTier::Standard,
            (16385..=32768, _) => DeviceTier::Performance,
            _ => DeviceTier::Server,
        };

        Self { tier, cpu_cores, ram_mb, has_gpu, disk_type, os: detect_os(), arch }
    }
}
```

### Scaling Table

All values are computed dynamically from the device profile — not hardcoded constants. The table shows typical resulting values for reference:

| Subsystem | Minimal (Pi, 4GB) | Standard (Laptop, 16GB) | Performance (Workstation, 32GB) |
|-----------|-------------|-------------------|--------------------------|
| Tick rate | ~2 Hz | ~10 Hz | ~10 Hz |
| Agent society | ~4 agents | ~8 agents | ~12+ agents |
| Working memory | ~4-6 chunks | ~15-20 chunks | ~30-50 chunks |
| Episodic buffer | ~200 ticks | ~2000 ticks | ~10000 ticks |
| Semantic network nodes | ~500 | ~10,000 | unbounded (disk) |
| PP stack layers | 2 (raw + semantic) | 4 | 5 (full) |
| Embedding model | None (API only) | MiniLM-384d | Nomic-768d or GPU |
| Dream engine | When idle > 4h | When idle > 10min | When idle > 5min |
| Self-modification | Disabled | Config/weights | Full (recompile) |
| Active goals | ~3-5 | ~8-15 | unbounded (resource-gated) |
| Skills per project | ~10-15 | ~30-50 | unbounded (prompt-budget-gated) |
| Simulation steps | ~2 | ~5-8 | ~10-20 |

### Implementation

```rust
/// No hardcoded limits — all bounds computed from physical constraints
pub struct DynamicBounds {
    device: DeviceProfile,
    llm_context_window: usize,  // From best available model
    avg_skill_tokens: usize,    // Measured, not assumed
}

impl DynamicBounds {
    /// Working memory: bounded by LLM context window + available RAM
    pub fn working_memory_capacity(&self) -> usize {
        let context_budget = self.llm_context_window / 10; // Max 10% for WM
        let tokens_per_chunk = 500;
        let context_limit = context_budget / tokens_per_chunk;
        let ram_limit = (self.device.ram_mb as usize * 1024) / (tokens_per_chunk * 4 * 10);
        context_limit.min(ram_limit).min(50).max(2)
    }

    /// Active goals: bounded by cognitive budget (planning depth × available compute)
    pub fn max_active_goals(&self, budget: &CognitiveBudget, affect: &AffectiveState) -> usize {
        let base = budget.planning_depth as usize * 3;
        let fatigue_reduction = (affect.fatigue * base as f64 * 0.5) as usize;
        let resource_cap = (budget.total_tokens_per_tick / 150) as usize;
        base.saturating_sub(fatigue_reduction).min(resource_cap).max(1)
    }

    /// Skills per project: bounded by prompt budget (not arbitrary cap)
    pub fn max_skills(&self) -> usize {
        let skill_budget = self.llm_context_window / 8; // Max 12.5% of context for skills
        let limit = skill_budget / self.avg_skill_tokens.max(200);
        limit.max(3) // At least 3 skills always allowed
    }

    /// Agent count: bounded by tick budget (each agent costs ~1ms per tick)
    pub fn max_agents(&self) -> usize {
        let tick_budget_ms = 1000 / self.tick_rate() as u64; // ms per tick
        let agent_cost_ms = 2; // ~2ms per agent per tick (perception + bid)
        let overhead_ms = 20; // Kernel overhead per tick
        let available = tick_budget_ms.saturating_sub(overhead_ms) / agent_cost_ms;
        (available as usize).min(20).max(2) // At least 2 (Planner + Safety)
    }

    /// Tick rate: bounded by CPU capacity and thermal state
    pub fn tick_rate(&self) -> u8 {
        match self.device.tier {
            DeviceTier::Minimal => 2,
            _ => 10,
        }
    }

    /// Episodic buffer: bounded by available disk I/O and RAM
    pub fn episodic_buffer_size(&self) -> u32 {
        let ram_budget = self.device.ram_mb / 20; // 5% of RAM for episodic
        let ticks_per_mb = 100; // ~10KB per tick entry
        (ram_budget * ticks_per_mb).min(50000).max(100)
    }

    /// Semantic network: bounded by disk space (grows unbounded on Performance tier)
    pub fn semantic_network_limit(&self) -> Option<u32> {
        match self.device.tier {
            DeviceTier::Minimal => Some(500),
            DeviceTier::Standard => Some(10_000),
            _ => None, // Unbounded — disk is cheap, prune by staleness instead
        }
    }

    /// Causal chain depth: bounded by compute time per simulation step
    pub fn causal_chain_depth(&self) -> u8 {
        let ms_per_step = 5; // ~5ms per propagation step
        let budget_ms = match self.device.tier {
            DeviceTier::Minimal => 10,
            DeviceTier::Standard => 25,
            _ => 50,
        };
        (budget_ms / ms_per_step).min(20).max(1) as u8
    }

    /// World simulation steps: same principle as causal depth
    pub fn simulation_steps(&self) -> u8 {
        self.causal_chain_depth() * 2 // Simulation can go deeper than single-chain
    }

    /// Self-modification: gated by confidence + test results, not time
    pub fn can_self_modify(&self, homunculus: &Homunculus, test_pass_rate: f64) -> bool {
        match self.device.tier {
            DeviceTier::Minimal => false, // No compiler available typically
            _ => {
                homunculus.self_modification_success_rate > 0.8
                && test_pass_rate > 0.95
                // No arbitrary time gate — if tests pass and history is good, go
            }
        }
    }

    /// Telemetry retention: bounded by disk space
    pub fn telemetry_retention_days(&self) -> u16 {
        let disk_budget_mb = match self.device.disk_type {
            DiskType::SdCard => 500,    // Conservative on SD
            DiskType::Hdd => 5000,
            DiskType::Ssd => 10000,
        };
        let mb_per_day = 10; // ~10MB telemetry per active day
        (disk_budget_mb / mb_per_day).min(365).max(3) as u16
    }
}
```

### The Principle: No Magic Numbers

Every limit in the system derives from one of these physical constraints:

| Constraint Source | What It Bounds |
|------------------|---------------|
| RAM (bytes) | Working memory chunks, episodic buffer, semantic graph in-memory portion |
| LLM context window (tokens) | Working memory, skill count, prompt size |
| CPU time per tick (ms) | Agent count, simulation depth, causal chain depth |
| Disk space (bytes) | Semantic network size, telemetry retention, LTM capacity |
| Disk I/O speed (MB/s) | Sync frequency, consolidation depth |
| Network latency (ms) | LLM query frequency, sync batch size |
| Thermal state (°C) | Tick rate, concurrent tools |
| Test pass rate (ratio) | Self-modification permission |
| Fatigue (affect dimension) | Goal generation rate, planning depth |

If a limit can't be traced back to a physical constraint or measured degradation, it doesn't belong in the system.

### Which Agents Run on Minimal Tier

On a Pi or low-end device, only 4 agents are active (the essential ones):

| Agent | Why Essential |
|-------|-------------|
| PlannerAgent | Core task decomposition — can't function without it |
| CoderAgent | Primary value delivery — writes code |
| SafetyAgent | Non-negotiable — veto dangerous actions |
| SocialAgent | User relationship — knows when to ask vs act |

The other 8 agents (Debugger, Research, Refactor, Test, Explain, Meta, Curiosity, Memory) are disabled. Their responsibilities fold into the 4 active agents at reduced quality:
- Planner handles debugging (simpler heuristics)
- Coder handles refactoring (inline, no separate pass)
- Social handles explanation (less detailed)
- No curiosity-driven exploration (only user-requested goals)

### Runtime Adaptation

The system continuously monitors resource pressure and recomputes bounds:

```rust
impl MetaCognitiveController {
    /// Called every 100 ticks — recompute bounds based on actual system state
    pub fn adapt_to_pressure(&mut self, state: &SystemState) {
        let tick_overrun = state.avg_tick_duration > state.target_tick_duration * 1.5;
        let memory_pressure = state.process_rss_mb > (state.device_profile.ram_mb as f64 * 0.4);
        let thermal_throttle = state.cpu_temp_celsius > 80.0;

        if tick_overrun || memory_pressure || thermal_throttle {
            // Reduce available resources — bounds auto-recompute from lower inputs
            state.effective_ram_mb = (state.device_profile.ram_mb as f64 * 0.6) as u32;
            state.effective_cpu_budget_ms = state.target_tick_duration * 0.7;

            // All dynamic bounds (goals, agents, WM, etc.) automatically shrink
            // because they derive from these effective values
            self.bounds.recompute(&state);

            // Shed load: disable lowest-priority agents first
            let max_agents = self.bounds.max_agents();
            self.agent_society.shed_to(max_agents);

            self.telemetry.record_adaptation("pressure_response", &self.bounds);
        } else if state.avg_tick_duration < state.target_tick_duration * 0.5 {
            // Under-utilized — restore full capacity
            state.effective_ram_mb = state.device_profile.ram_mb;
            state.effective_cpu_budget_ms = state.target_tick_duration;
            self.bounds.recompute(&state);

            self.telemetry.record_adaptation("capacity_restored", &self.bounds);
        }
    }
}
```

The key insight: there are no fixed numbers to "decrement by 2" — the system recomputes all bounds from the current effective resource envelope. If the machine is under pressure, the envelope shrinks and everything scales down proportionally. If pressure lifts, everything scales back up. The system finds its own equilibrium.

---

## Perception-Action Loop

### Sensory Cortex

```rust
pub struct PerceptionCortex {
    pub modalities: HashMap<String, Box<dyn SensoryModality>>,
    pub feature_extractors: Vec<FeatureExtractor>,
    pub binding_pool: BindingPool,
}

pub trait SensoryModality: Send + Sync {
    fn name(&self) -> &str;
    fn poll(&mut self) -> Vec<SensoryEvent>;
    fn encode(&self, event: &SensoryEvent) -> Vec<f32>;
}

// Concrete modalities:
// UserMessageModality    — Text from Vue IPC
// FileSystemModality     — notify crate file events
// ProcessModality        — stdout/stderr pipes
// TimerModality          — Scheduled intervals
// SelfStateModality      — Internal metrics (proprioception)
```

### Motor Cortex

```rust
pub struct MotorCortex {
    pub effectors: HashMap<String, Box<dyn Effector>>,
}

pub trait Effector: Send + Sync {
    fn name(&self) -> &str;
    fn execute(&self, command: MotorCommand) -> Result<EffectorOutput>;
}

// Concrete effectors:
// MessageEffector        — Send message to Vue
// ToolEffector           — Execute tool
// LlmEffector            — Query LLM API
// FileEffector           — Write file
// SelfModifyEffector     — Edit source code
// SleepEffector          — Enter consolidation mode
```


---

## LLM Pool — Local Multi-Provider Router

### Why Local Routing

The Kognisant API is the default, but many users already have:
- **Ollama** running locally (llama3, mistral, codestral, etc.)
- **OpenAI API keys** they want to use directly
- **Anthropic, Groq, Together, Fireworks** accounts
- **Custom endpoints** (vLLM, text-generation-inference, LM Studio)

The LLM Pool handles all of this locally. Model selection happens on-device — the MCC picks the best model for each query based on cost, speed, capability, and availability.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         LLM POOL                                 │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Kognisant   │  │  Ollama      │  │  OpenAI-     │          │
│  │  API         │  │  (local)     │  │  Compatible  │          │
│  │              │  │              │  │              │          │
│  │  • 109+ models│  │  • llama3   │  │  • Any URL   │          │
│  │  • Billing   │  │  • mistral   │  │  • Any key   │          │
│  │  • Fallback  │  │  • codestral │  │  • Custom    │          │
│  │  • Default   │  │  • phi3      │  │    models    │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                   │
│         └──────────────────┴──────────────────┘                   │
│                            │                                      │
│                   ┌────────┴────────┐                             │
│                   │  Model Selector  │                             │
│                   │                  │                             │
│                   │  Routes based on:│                             │
│                   │  • Task type     │                             │
│                   │  • Cost budget   │                             │
│                   │  • Speed need    │                             │
│                   │  • Capability    │                             │
│                   │  • Availability  │                             │
│                   │  • User prefs    │                             │
│                   └─────────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
```

### Provider Trait

```rust
#[async_trait]
pub trait LlmProvider: Send + Sync {
    fn name(&self) -> &str;
    fn provider_type(&self) -> ProviderType;
    fn available_models(&self) -> Vec<ModelInfo>;
    fn is_local(&self) -> bool;
    fn is_available(&self) -> bool; // Health check

    async fn complete(
        &self,
        model: &str,
        messages: Vec<Message>,
        tools: Option<Vec<ToolSchema>>,
    ) -> Result<CompletionResponse>;

    async fn complete_stream(
        &self,
        model: &str,
        messages: Vec<Message>,
        tools: Option<Vec<ToolSchema>>,
    ) -> Result<mpsc::Receiver<StreamChunk>>;

    async fn embed(&self, input: Vec<String>) -> Result<Vec<Vec<f32>>>;
}

pub enum ProviderType {
    KognisantApi,    // Default, managed billing
    Ollama,          // Local, free, no API key
    OpenAiCompat,    // Any OpenAI-compatible endpoint
}
```

### Provider Implementations

```rust
/// Kognisant API — default provider, handles billing server-side
pub struct KognisantProvider {
    base_url: String,           // https://api.kognisant.com
    auth_token: String,         // JWT from signin
    http: reqwest::Client,
}

/// Ollama — local models, zero cost, auto-detected
pub struct OllamaProvider {
    base_url: String,           // http://localhost:11434 (default)
    http: reqwest::Client,
    detected_models: Vec<String>, // Refreshed on startup + periodically
}

impl OllamaProvider {
    /// Auto-detect running Ollama instance
    pub async fn detect() -> Option<Self> {
        // GET http://localhost:11434/api/tags
        // If responds → Ollama is running, list available models
    }

    /// Pull a model if user requests it
    pub async fn pull_model(&self, model: &str) -> Result<()> {
        // POST http://localhost:11434/api/pull
    }
}

/// Any OpenAI-compatible endpoint (OpenAI, Anthropic via proxy, Groq, Together, etc.)
pub struct OpenAiCompatProvider {
    name: String,               // User-defined name
    base_url: String,           // e.g., https://api.openai.com/v1
    api_key: String,            // From env var or encrypted storage
    models: Vec<String>,        // User-specified or auto-discovered
    http: reqwest::Client,
}
```

### The LLM Pool

```rust
pub struct LlmPool {
    providers: Vec<Box<dyn LlmProvider>>,
    selector: ModelSelector,
    cache: ResponseCache,
}

impl LlmPool {
    /// Initialize pool from config + environment detection
    pub async fn initialize(config: &LlmConfig) -> Self {
        let mut providers: Vec<Box<dyn LlmProvider>> = vec![];

        // 1. Always add Kognisant API if user is authenticated
        if let Some(token) = config.kognisant_token.as_ref() {
            providers.push(Box::new(KognisantProvider::new(token)));
        }

        // 2. Auto-detect Ollama
        if let Some(ollama) = OllamaProvider::detect().await {
            providers.push(Box::new(ollama));
        }

        // 3. Load user-configured providers from env vars or config
        for custom in &config.custom_providers {
            providers.push(Box::new(OpenAiCompatProvider::new(custom)));
        }

        // 4. Check environment variables for API keys
        //    OPENAI_API_KEY → adds OpenAI provider
        //    ANTHROPIC_API_KEY → adds Anthropic provider
        //    GROQ_API_KEY → adds Groq provider
        //    Any KOGNISANT_LLM_* env var → parsed as custom provider
        Self::load_from_env(&mut providers);

        Self {
            providers,
            selector: ModelSelector::new(),
            cache: ResponseCache::new(),
        }
    }

    /// Route a query to the best available provider/model
    pub async fn query(&self, request: LlmRequest) -> Result<LlmResponse> {
        let selection = self.selector.select(&request, &self.providers);

        // Try selected provider, fall back if unavailable
        for candidate in selection.ranked_candidates {
            match candidate.provider.complete_stream(
                &candidate.model,
                request.messages.clone(),
                request.tools.clone(),
            ).await {
                Ok(stream) => return Ok(LlmResponse { stream, provider: candidate.name }),
                Err(_) => continue, // Try next candidate
            }
        }

        Err(LlmError::NoAvailableProvider)
    }
}
```

### Model Selection Logic

```rust
pub struct ModelSelector;

impl ModelSelector {
    /// Pick the best model for this request
    pub fn select(
        &self,
        request: &LlmRequest,
        providers: &[Box<dyn LlmProvider>],
    ) -> SelectionResult {
        let mut candidates = vec![];

        for provider in providers {
            if !provider.is_available() { continue; }

            for model in provider.available_models() {
                let score = self.score_model(&model, request, provider.is_local());
                candidates.push(ModelCandidate {
                    provider: provider.name().to_string(),
                    model: model.id.clone(),
                    score,
                    is_local: provider.is_local(),
                });
            }
        }

        // Sort by score (highest first)
        candidates.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap());

        SelectionResult { ranked_candidates: candidates }
    }

    fn score_model(&self, model: &ModelInfo, request: &LlmRequest, is_local: bool) -> f64 {
        let mut score = 0.0;

        // Capability match (does this model support tools? vision? long context?)
        if request.needs_tools && model.supports_tools { score += 0.3; }
        if request.needs_vision && model.supports_vision { score += 0.3; }
        if request.context_length > model.max_context { return 0.0; } // Disqualify

        // Speed preference (local models are faster for small queries)
        if is_local && request.expected_output_tokens < 500 {
            score += 0.4; // Prefer local for quick responses
        }

        // Cost (local = free, Kognisant = credits, direct API = user pays)
        if is_local { score += 0.2; } // Free is good

        // Quality tier
        score += model.quality_tier as f64 * 0.1; // Higher tier = better

        // User preference (learned from value function)
        if let Some(pref) = request.user_model_preference.as_ref() {
            if model.id.contains(pref) { score += 0.5; }
        }

        score
    }
}
```

### Configuration

```rust
/// LLM configuration — stored in ~/.kognisant/global.db
pub struct LlmConfig {
    /// Kognisant API token (from signin)
    pub kognisant_token: Option<String>,

    /// Custom providers added by user
    pub custom_providers: Vec<CustomProviderConfig>,

    /// Default model preferences per task type
    pub default_models: HashMap<TaskType, String>,

    /// Whether to prefer local models when available
    pub prefer_local: bool,

    /// Max cost per query (for paid providers)
    pub max_cost_per_query: f64,
}

pub struct CustomProviderConfig {
    pub name: String,           // "my-openai", "local-vllm", etc.
    pub base_url: String,       // The endpoint URL
    pub api_key_env: String,    // Environment variable name (e.g., "OPENAI_API_KEY")
    pub models: Vec<String>,    // Available models (or empty for auto-discover)
    pub is_local: bool,         // Is this a local endpoint?
}
```

### Environment Variable Discovery

The system automatically picks up API keys from environment variables:

```rust
impl LlmPool {
    fn load_from_env(providers: &mut Vec<Box<dyn LlmProvider>>) {
        // Standard env vars → auto-configure providers
        let env_mappings = [
            ("OPENAI_API_KEY", "https://api.openai.com/v1", "openai"),
            ("ANTHROPIC_API_KEY", "https://api.anthropic.com/v1", "anthropic"),
            ("GROQ_API_KEY", "https://api.groq.com/openai/v1", "groq"),
            ("TOGETHER_API_KEY", "https://api.together.xyz/v1", "together"),
            ("FIREWORKS_API_KEY", "https://api.fireworks.ai/inference/v1", "fireworks"),
            ("DEEPSEEK_API_KEY", "https://api.deepseek.com/v1", "deepseek"),
        ];

        for (env_var, base_url, name) in &env_mappings {
            if let Ok(key) = std::env::var(env_var) {
                providers.push(Box::new(OpenAiCompatProvider {
                    name: name.to_string(),
                    base_url: base_url.to_string(),
                    api_key: key,
                    models: vec![], // Auto-discover via GET /models
                    http: reqwest::Client::new(),
                }));
            }
        }

        // Custom: KOGNISANT_LLM_<NAME>_URL + KOGNISANT_LLM_<NAME>_KEY
        // e.g., KOGNISANT_LLM_MYSERVER_URL=http://localhost:8080/v1
        //        KOGNISANT_LLM_MYSERVER_KEY=sk-xxx
        for (key, value) in std::env::vars() {
            if key.starts_with("KOGNISANT_LLM_") && key.ends_with("_URL") {
                let name = key
                    .strip_prefix("KOGNISANT_LLM_").unwrap()
                    .strip_suffix("_URL").unwrap()
                    .to_lowercase();
                let key_var = format!("KOGNISANT_LLM_{}_KEY", name.to_uppercase());
                let api_key = std::env::var(&key_var).unwrap_or_default();

                providers.push(Box::new(OpenAiCompatProvider {
                    name,
                    base_url: value,
                    api_key,
                    models: vec![],
                    http: reqwest::Client::new(),
                }));
            }
        }
    }
}
```

### User Adds a Provider via Chat

The system can configure new providers conversationally:

```
User: "I have a local vLLM server running codestral at localhost:8000"

System (internally):
  1. SocialAgent detects provider configuration intent
  2. Validates: GET http://localhost:8000/v1/models → success
  3. Discovers available models: ["codestral-latest"]
  4. Adds to LlmPool as OpenAiCompatProvider
  5. Persists config to global.db
  6. ModelSelector now includes codestral for code tasks

System: "Found your vLLM server with codestral. I'll use it for code generation
         tasks since it's local and fast. You can see it in Settings → LLM Pool."
```

### Performance Benefits

| Scenario | Without Local LLMs | With Local LLMs |
|----------|-------------------|-----------------|
| Simple greeting | 200-500ms (API round-trip) | 20-50ms (Ollama) |
| Code completion | 500-2000ms (API) | 100-300ms (local codestral) |
| Embedding generation | 100-300ms (API, costs credits) | 5-20ms (local ONNX) |
| Offline usage | ❌ No internet = no function | ✅ Full capability with local models |
| Cost per day | $0.50-$5.00 in credits | $0.00 for local, credits only for complex |

### MCC Integration

The Meta-Cognitive Controller uses the pool intelligently:

```rust
impl MetaCognitiveController {
    fn decide_llm_query(&self, state: &SystemState, affect: &AffectiveState) -> Option<LlmQuery> {
        // ... existing gating logic ...

        // NEW: Route based on query characteristics
        if let Some(query) = self.llm_gateway.priority_queue.first() {
            query.routing_hints = RoutingHints {
                // Simple queries → prefer local (fast, free)
                prefer_local: query.expected_complexity < 0.3,

                // Complex reasoning → prefer large remote model
                needs_large_model: query.expected_complexity > 0.7,

                // Tool use → must support function calling
                needs_tools: query.has_tool_schemas,

                // Budget-conscious → prefer free/cheap
                max_cost: affect.resource_budget.self_modification_risk * 0.01,
            };
        }

        self.llm_gateway.priority_queue.first().cloned()
    }
}
```

---

## Skill Transfer System

Skills in v2 are not just prompt mutations — they are procedural memory patterns that encode Condition → Action → Outcome chains. Transfer operates at multiple levels.

### Skill Representation

```rust
pub struct Skill {
    pub id: String,
    pub name: String,
    pub conditions: Vec<Condition>,       // When to activate
    pub actions: Vec<ActionTemplate>,     // What to do
    pub expected_outcomes: Vec<Outcome>,  // What should happen
    pub confidence: f64,                  // How reliable (0-1)
    pub usage_count: u32,
    pub success_rate: f64,
    pub domain_tags: Vec<String>,
    pub source: SkillSource,
    pub status: SkillStatus,
}

pub enum SkillSource {
    Learned { project_id: String, tick: u64 },     // Acquired through experience
    Transferred { from_project: String },           // Imported from another project
    Migrated { from_cloud: bool },                  // Pulled from API
    Generated { by_agent: String, goal_id: String }, // Created by GoalEngine
}

pub enum SkillStatus {
    Experimental,  // Newly acquired, unproven in this context
    Active,        // Proven, user-approved
    Dormant,       // Not used recently, may be pruned
    Archived,      // Explicitly disabled by user
}
```

### Transfer Vectors

| Vector | From → To | Mechanism |
|--------|-----------|-----------|
| **Intra-project** | Experience → Procedural Memory | Automatic (RL + pattern detection) |
| **Cross-project** | Project A → Shared Library → Project B | Explicit export/import |
| **Cloud → Desktop** | Kognisant API persona → Local project | One-time migration pull |
| **Dream consolidation** | Episodic → Procedural | Offline pattern extraction |
| **Agent society** | One agent's strategy → Procedural Memory | Successful bid outcomes |

### Cross-Project Transfer

```rust
pub struct SkillTransfer;

impl SkillTransfer {
    /// Export: strip project-specific context, preserve abstract pattern
    pub fn export_to_library(source_project: &str, skill_id: &str) -> Result<SharedSkill> {
        // 1. Read skill from source project's procedural memory
        // 2. Abstract away project-specific details (paths, names, configs)
        // 3. Preserve: conditions (abstract), actions (templates), outcomes (expected)
        // 4. Write to ~/.kognisant/shared/skill_library/
        // 5. Record provenance + performance score
    }

    /// Import: always starts as Experimental, must re-prove
    pub fn import_from_library(target_project: &str, skill_name: &str) -> Result<()> {
        // 1. Read from shared library
        // 2. Instantiate with status: Experimental
        // 3. Inject into target project's procedural memory
        // 4. The skill competes in memory activation like any other
        // 5. If it wins bids and succeeds → confidence grows → Active
    }
}
```

### Transfer Rules

| Rule | Rationale |
|------|-----------|
| Imported skills start as Experimental | Must prove value in new context |
| Skills are abstracted (no project-specific paths) | Prevent context pollution |
| Transfer recorded in telemetry | Full audit trail |
| Skill count bounded by prompt budget | System measures actual token cost; sheds lowest-confidence skills when budget exceeded |
| User must approve import | No silent injection |
| Skills compete for activation | Natural selection — bad skills lose and get pruned |
| Dream engine can generate new skills | Consolidation creates novel combinations |

### What Transfers vs What Doesn't

| Transferable | Not Transferable | Why |
|-------------|-----------------|-----|
| Procedural skills (abstract patterns) | World model beliefs | Beliefs are project-specific |
| Semantic concepts (abstract) | Active goals | Goals depend on current context |
| Strategy preferences | Valence/arousal state | Fresh affective start |
| Tool usage patterns | Episodic memories | Too context-specific |
| Causal chain templates | Working memory contents | Transient by nature |

---

## Technology Stack

### Rust Kernel (compiled to `.node` via N-API)

| Component | Crate / Technology | Why |
|-----------|-------------------|-----|
| N-API bindings | `napi-rs` + `napi-derive` | Direct Electron integration |
| Async runtime | `tokio` | Multi-threaded, handles 10Hz tick + I/O |
| Database | `rusqlite` (bundled) | Memory palace tiers |
| Vector search | `hnsw` or `sqlite-vss` | Semantic network ANN |
| Embeddings | `ort` (ONNX Runtime) | Local embedding, CPU/GPU |
| Serialization | `serde` + `serde_json` + `rkyv` | Fast binary for working memory |
| HTTP client | `reqwest` | LLM API calls (all providers) |
| Process exec | `tokio::process` | Sandboxed tool execution |
| Crypto | `ring` + `aes-gcm` | Token encryption |
| File watching | `notify` | File system perception |
| Graph | `petgraph` | Semantic network, causal chains |
| ML/RL | `burn` or `candle` | Local small models for value function |
| Compiler | `cargo` (subprocess) | Self-modification builds |
| Version control | `git2` (libgit2) | Self-modification lineage, branching, rollback |
| Streaming | `tokio::sync::mpsc` | IPC channels |
| Time | `tokio::time` | Tick scheduling |

### Frontend (Vue 3 + Tailwind)

| Component | Technology | Why |
|-----------|-----------|-----|
| Framework | Vue 3 Composition API | Reactive, component-based |
| State | Pinia | Stores for each cognitive subsystem |
| Charts | D3.js | Complex cognitive visualizations |
| Graph viz | Cytoscape.js | Semantic network, causal chains |
| Real-time | WebSockets over IPC | 10Hz cognitive state stream |
| 3D viz | Three.js (optional) | World simulation visualization |

### What We Do NOT Need

Same as v1, plus:
- No central planner — emergent goal market replaces planner
- No static agent loop — continuous tick replaces 5-phase lifecycle
- No simple retrieval memory — competitive activation replaces search
- No server-side model routing — LLM Pool handles selection locally
- No single-provider lock-in — any OpenAI-compatible endpoint works


---

## Project Structure

```
kognisant_core/
├── rust-kernel/
│   ├── Cargo.toml
│   ├── .cargo/config.toml
│   └── src/
│       ├── lib.rs                    # N-API entry
│       ├── bridge.rs                 # IPC routing + streaming
│       │
│       ├── continuous/               # CONTINUOUS COGNITIVE LOOP
│       │   ├── mod.rs
│       │   ├── kernel.rs             # Main 10Hz loop
│       │   ├── tick.rs               # Tick phases, scheduling
│       │   └── state.rs              # SystemState (shared, lock-free)
│       │
│       ├── perception/               # SENSORY CORTEX
│       │   ├── mod.rs
│       │   ├── cortex.rs             # Multi-modal perception
│       │   ├── modalities/
│       │   │   ├── user_message.rs
│       │   │   ├── file_system.rs
│       │   │   ├── process.rs
│       │   │   ├── timer.rs
│       │   │   └── self_state.rs
│       │   └── binding.rs            # Feature binding
│       │
│       ├── prediction/               # PREDICTIVE PROCESSING STACK
│       │   ├── mod.rs
│       │   ├── stack.rs              # 5-layer hierarchy
│       │   ├── layer.rs              # Individual PP layer
│       │   ├── surprise.rs           # Surprise computation
│       │   └── precision.rs          # Precision weighting
│       │
│       ├── memory/                   # MEMORY PALACE (5-tier)
│       │   ├── mod.rs
│       │   ├── palace.rs             # Orchestrator
│       │   ├── working.rs            # Working memory (7±2 chunks)
│       │   ├── episodic.rs           # Episodic buffer (ring buffer)
│       │   ├── semantic.rs           # Semantic network (graph + vectors)
│       │   ├── procedural.rs         # Procedural memory (RL + rules)
│       │   ├── consolidated.rs       # Long-term memory (compressed)
│       │   └── dream.rs              # Dream engine (consolidation)
│       │
│       ├── self_model/               # HOMUNCULUS
│       │   ├── mod.rs
│       │   ├── homunculus.rs         # Self-simulation
│       │   ├── introspection.rs      # Self-awareness injection
│       │   ├── self_prediction.rs    # Predict own behavior
│       │   └── levels.rs             # L0-L5 self-awareness
│       │
│       ├── affect/                   # AFFECTIVE ECONOMY
│       │   ├── mod.rs
│       │   ├── economy.rs            # 6D affect + budget
│       │   ├── dynamics.rs           # Temporal dynamics, decay
│       │   └── budget.rs             # Cognitive resource allocation
│       │
│       ├── world/                    # WORLD SIMULATOR
│       │   ├── mod.rs
│       │   ├── simulator.rs          # Mental sandbox
│       │   ├── causal.rs             # Causal engine
│       │   ├── beliefs.rs            # Belief graph
│       │   ├── social.rs             # User model
│       │   └── physics.rs            # Software "physics" (deps, builds)
│       │
│       ├── goals/                    # GOAL MARKET
│       │   ├── mod.rs
│       │   ├── market.rs             # Bid resolution
│       │   ├── generation.rs         # Goal generation from surprise
│       │   ├── value_function.rs     # Learned values
│       │   └── hierarchy.rs          # Goal/subgoal trees
│       │
│       ├── society/                  # MULTI-AGENT SOCIETY
│       │   ├── mod.rs
│       │   ├── society.rs            # Agent container + market
│       │   ├── bidding.rs            # Bid generation, coalition formation
│       │   └── agents/
│       │       ├── planner.rs
│       │       ├── coder.rs
│       │       ├── debugger.rs
│       │       ├── research.rs
│       │       ├── meta.rs
│       │       ├── curiosity.rs
│       │       ├── safety.rs
│       │       ├── social.rs
│       │       └── memory.rs
│       │
│       ├── meta/                     # META-COGNITIVE CONTROLLER
│       │   ├── mod.rs
│       │   ├── controller.rs         # MCC orchestration
│       │   ├── attention.rs          # Attention allocation
│       │   ├── llm_gateway.rs        # When to call external LLM
│       │   └── sleep.rs              # Consolidation scheduling
│       │
│       ├── action/                   # MOTOR CORTEX
│       │   ├── mod.rs
│       │   ├── cortex.rs             # Action selection
│       │   ├── selection.rs          # Active inference action selection
│       │   └── effectors/
│       │       ├── message.rs
│       │       ├── tool.rs
│       │       ├── llm.rs
│       │       ├── file.rs
│       │       ├── self_modify.rs
│       │       └── sleep.rs
│       │
│       ├── self_modify/              # SELF-MODIFICATION
│       │   ├── mod.rs
│       │   ├── engine.rs             # Orchestrator
│       │   ├── patch_gen.rs          # Code patch generation
│       │   ├── safety_gate.rs        # Immutable markers, critical path
│       │   ├── test_harness.rs       # Verify before apply
│       │   └── rollback.rs           # Restore on failure
│       │
│       ├── llm/                      # LLM POOL (multi-provider local router)
│       │   ├── mod.rs
│       │   ├── pool.rs              # LlmPool — routes to best available provider
│       │   ├── provider.rs          # Provider trait + registry
│       │   ├── kognisant.rs         # Kognisant API provider (default)
│       │   ├── ollama.rs            # Local Ollama provider
│       │   ├── openai_compat.rs     # Any OpenAI-compatible endpoint
│       │   ├── streaming.rs         # SSE parsing (shared)
│       │   ├── selector.rs          # Model selection (cost, speed, capability)
│       │   └── cache.rs             # Response cache
│       │
│       ├── tools/                    # TOOL SYSTEM
│       │   ├── mod.rs
│       │   ├── registry.rs
│       │   ├── sandbox.rs
│       │   └── builtin/
│       │       ├── shell.rs
│       │       ├── file.rs
│       │       ├── code.rs
│       │       ├── web.rs
│       │       └── image.rs
│       │
│       ├── telemetry/                # TELEMETRY
│       │   ├── mod.rs
│       │   ├── collector.rs
│       │   ├── spans.rs
│       │   └── cognitive_trace.rs    # Full cognitive state per tick
│       │
│       └── config/
│           ├── mod.rs
│           ├── settings.rs
│           └── auth.rs
│
├── frontend/
│   ├── src/
│   │   ├── App.vue
│   │   ├── main.js
│   │   ├── router/
│   │   ├── stores/
│   │   │   ├── cognitive.js          # Real-time cognitive state
│   │   │   ├── affect.js             # Affect vector stream
│   │   │   ├── memory.js             # Memory palace browser
│   │   │   ├── goals.js              # Goal market view
│   │   │   ├── society.js            # Agent society view
│   │   │   ├── world.js              # World simulator
│   │   │   ├── self_model.js         # Homunculus view
│   │   │   └── telemetry.js
│   │   ├── views/
│   │   │   ├── ChatView.vue
│   │   │   ├── CognitiveGraph.vue    # Real-time cognitive viz
│   │   │   ├── MemoryPalace.vue      # Interactive memory browser
│   │   │   ├── GoalMarket.vue        # Live bidding visualization
│   │   │   ├── AgentSociety.vue      # Agent activity map
│   │   │   ├── WorldSimulator.vue    # Counterfactual playground
│   │   │   ├── SelfModel.vue         # Introspection dashboard
│   │   │   ├── TelemetryView.vue
│   │   │   └── SettingsView.vue
│   │   ├── components/
│   │   │   ├── cognitive/
│   │   │   │   ├── SurpriseMeter.vue
│   │   │   │   ├── PredictionOverlay.vue
│   │   │   │   ├── AttentionHeatmap.vue
│   │   │   │   └── FreeEnergyGraph.vue
│   │   │   ├── memory/
│   │   │   │   ├── WorkingMemorySlots.vue
│   │   │   │   ├── SemanticGraph.vue
│   │   │   │   └── EpisodicTimeline.vue
│   │   │   ├── affect/
│   │   │   │   ├── AffectRadar.vue
│   │   │   │   └── ValenceOrb.vue
│   │   │   └── common/
│   │   │       ├── MessageBubble.vue
│   │   │       └── CodeBlock.vue
│   │   └── composables/
│   │       ├── useCognitiveStream.js # 10Hz stream
│   │       ├── useKernel.js
│   │       └── useApproval.js
│   └── vite.config.js
│
├── main.js
├── preload.js
└── package.json
```


---

## Implementation Phases

### Phase 0: Foundation (Weeks 1-4)

**Goal:** Continuous cognitive kernel with perception-action loop and multi-provider LLM pool.

- [ ] `continuous/kernel.rs` — 10Hz tick loop with tokio
- [ ] `perception/cortex.rs` — File watcher, IPC, timer modalities
- [ ] `prediction/stack.rs` — 2-layer predictive stack (raw + semantic)
- [ ] `memory/working.rs` — Working memory with dynamic capacity (LLM context + RAM bounded)
- [ ] `memory/episodic.rs` — Ring buffer SQLite store
- [ ] `action/cortex.rs` — Basic effector system
- [ ] `meta/controller.rs` — Simple MCC (attention + LLM gating)
- [ ] `llm/pool.rs` — Multi-provider LLM pool with local routing
- [ ] `llm/kognisant.rs` — Kognisant API provider (default)
- [ ] `llm/ollama.rs` — Auto-detect local Ollama + model listing
- [ ] `llm/openai_compat.rs` — Generic OpenAI-compatible provider
- [ ] `llm/selector.rs` — Model selection (cost, speed, capability, locality)
- [ ] Environment variable discovery (OPENAI_API_KEY, OLLAMA, custom KOGNISANT_LLM_*)
- [ ] Vue: `CognitiveGraph.vue` — Real-time surprise + prediction viz
- [ ] Vue: `ChatView.vue` — Basic chat (now feeds into perception cortex)
- [ ] Vue: `SettingsView.vue` — LLM Pool management (add/remove providers, see available models)

**Deliverable:** System that ticks continuously, routes LLM queries to best available provider (local or remote), predicts user input, shows surprise in UI.

### Phase 1: Memory & Self (Weeks 5-8)

**Goal:** Memory palace + homunculus operational.

- [ ] `memory/semantic.rs` — Graph + vector hybrid with HNSW
- [ ] `memory/procedural.rs` — Rule-based + simple RL
- [ ] `memory/consolidated.rs` — Compression + summarization
- [ ] `memory/dream.rs` — Offline consolidation engine
- [ ] `self_model/homunculus.rs` — Self-simulation running
- [ ] `self_model/introspection.rs` — Self-awareness prompt injection
- [ ] `affect/economy.rs` — 6D affect with budget control
- [ ] `affect/dynamics.rs` — Temporal decay, accumulation
- [ ] Vue: `MemoryPalace.vue` — Interactive graph browser
- [ ] Vue: `SelfModel.vue` — Introspection dashboard
- [ ] Vue: `AffectRadar.vue` — Real-time affect visualization

**Deliverable:** System knows what it knows, knows what it doesn't know, shows emotional state.

### Phase 2: World & Goals (Weeks 9-12)

**Goal:** World simulation + autonomous goal generation.

- [ ] `world/simulator.rs` — Mental sandbox with counterfactuals
- [ ] `world/causal.rs` — Causal chain detection
- [ ] `world/beliefs.rs` — Belief graph with confidence
- [ ] `world/social.rs` — User preference learning
- [ ] `goals/market.rs` — Bidding + resolution
- [ ] `goals/generation.rs` — Surprise → goal pipeline
- [ ] `goals/value_function.rs` — Learned value function
- [ ] Vue: `WorldSimulator.vue` — Counterfactual playground
- [ ] Vue: `GoalMarket.vue` — Live goal bidding visualization

**Deliverable:** System generates its own goals, simulates consequences, learns user preferences.

### Phase 3: Agent Society (Weeks 13-16)

**Goal:** Multi-agent society with emergent behavior.

- [ ] `society/society.rs` — Agent container
- [ ] `society/bidding.rs` — Coalition formation
- [ ] All 12 specialist agents implemented
- [ ] Agent competition + cooperation visible in UI
- [ ] Emergent task decomposition (no central planner)
- [ ] Vue: `AgentSociety.vue` — Activity map, bid streams

**Deliverable:** Complex tasks naturally decompose across agents; user sees "society thinking."

### Phase 4: Self-Modification (Weeks 17-20)

**Goal:** System can modify its own code safely.

- [ ] `self_modify/engine.rs` — End-to-end pipeline
- [ ] `self_modify/patch_gen.rs` — LLM-based patch generation
- [ ] `self_modify/safety_gate.rs` — Immutable markers, critical path
- [ ] `self_modify/test_harness.rs` — Automated verification
- [ ] `self_modify/rollback.rs` — Hot-reload + rollback
- [ ] First successful self-modification (e.g., optimize cache size)
- [ ] Vue: Self-modification approval UI

**Deliverable:** System improves its own code; human approves critical changes.

### Phase 5: Polish & Distribution (Weeks 21-24)

**Goal:** Production-ready proto-AGI.

- [ ] Performance: < 100MB RAM, < 2s cold start
- [ ] Cross-platform builds
- [ ] Onboarding: explain cognitive architecture to user
- [ ] Telemetry: full cognitive trace export
- [ ] Safety audit: sandbox escape, self-modification containment
- [ ] Documentation: architecture, cognitive science basis
- [ ] Open source release

**Deliverable:** Downloadable proto-AGI desktop application.

---

## Encrypted Cloud Sync & Disaster Recovery

### The Problem

All data is local. If the user's machine dies, gets stolen, or they switch devices — everything is gone. Memory palace, cognitive state, skills, telemetry, all of it.

### The Solution: End-to-End Encrypted Object Storage

The user's data syncs to cloud object storage (S3-compatible) encrypted with their private key. The server never sees plaintext. Only the user's key can decrypt.

```
┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
│  Device A        │         │  Cloud Storage   │         │  Device B        │
│  (primary)       │         │  (encrypted)     │         │  (new/recovery)  │
│                  │         │                  │         │                  │
│  ~/.kognisant/   │────────►│  E2E encrypted   │────────►│  ~/.kognisant/   │
│  • memory_palace │  push   │  blobs only      │  pull   │  • memory_palace │
│  • cognitive/    │         │                  │         │  • cognitive/    │
│  • telemetry.db  │         │  Server sees:    │         │  • telemetry.db  │
│  • skills/       │         │  • Random bytes  │         │  • skills/       │
│  • world_model/  │         │  • File sizes    │         │  • world_model/  │
│                  │         │  • Timestamps    │         │                  │
│  Private key     │         │  Cannot see:     │         │  Private key     │
│  (local only)    │         │  • Content       │         │  (imported)      │
│                  │         │  • Structure     │         │                  │
└──────────────────┘         └──────────────────┘         └──────────────────┘
```

### Cryptographic Design

```rust
pub struct SyncCrypto {
    /// User's master encryption key — derived server-side, issued per-device
    /// The API holds the master; devices get derived keys on auth
    pub device_key: DeviceKey,

    /// Per-file encryption (unique nonce per file)
    pub kdf: Hkdf<Sha256>,
}

pub struct DeviceKey {
    /// Issued by Kognisant API on successful authentication
    /// Derived from user's master key (server-side HSM)
    pub key: [u8; 32],          // AES-256

    /// Device identifier
    pub device_id: String,

    /// Expiry (re-issued on token refresh)
    pub expires_at: i64,
}

impl SyncCrypto {
    /// Initialize from API-issued device key (on signin)
    pub fn from_device_key(device_key: DeviceKey) -> Self {
        let kdf = Hkdf::new(None, &device_key.key);
        Self { device_key, kdf }
    }

    /// Encrypt a file for cloud storage
    pub fn encrypt_file(&self, plaintext: &[u8], file_path: &str) -> Vec<u8> {
        // 1. Derive per-file key from device key + file path
        let mut file_key = [0u8; 32];
        self.kdf.expand(file_path.as_bytes(), &mut file_key).unwrap();

        // 2. Generate random nonce (12 bytes)
        let nonce = generate_random_nonce();

        // 3. Encrypt with AES-256-GCM
        let ciphertext = aes_gcm_encrypt(&file_key, &nonce, plaintext);

        // 4. Prepend nonce to ciphertext (nonce || ciphertext || tag)
        [nonce.as_slice(), ciphertext.as_slice()].concat()
    }

    /// Decrypt a file from cloud storage
    pub fn decrypt_file(&self, encrypted: &[u8], file_path: &str) -> Result<Vec<u8>> {
        let mut file_key = [0u8; 32];
        self.kdf.expand(file_path.as_bytes(), &mut file_key).unwrap();

        let nonce = &encrypted[..12];
        let ciphertext = &encrypted[12..];

        aes_gcm_decrypt(&file_key, nonce, ciphertext)
    }
}
```

### Key Management

```
┌─────────────────────────────────────────────────────────────────┐
│  KEY LIFECYCLE (Server-Managed)                                   │
│                                                                   │
│  1. USER SIGNS UP (Kognisant API)                                │
│     └─ API generates user master key (stored in HSM)             │
│     └─ Master key NEVER leaves the server                        │
│     └─ User doesn't need to know about keys at all              │
│                                                                   │
│  2. DEVICE SIGNS IN                                              │
│     └─ POST /auth/signin → success                               │
│     └─ API derives device-specific key from master               │
│     └─ Device key returned in auth response (encrypted in TLS)  │
│     └─ Stored locally in global.db (encrypted with OS keychain) │
│                                                                   │
│  3. NEW DEVICE (disaster recovery)                               │
│     └─ User signs in with email + password (same as always)     │
│     └─ API issues new device key (same master derivation)       │
│     └─ New device can decrypt all existing cloud blobs          │
│     └─ No mnemonic, no recovery phrase, no manual steps         │
│                                                                   │
│  4. DEVICE REVOCATION                                            │
│     └─ User revokes from Settings or from another device        │
│     └─ API invalidates that device's key                         │
│     └─ Revoked device can no longer decrypt new syncs           │
│     └─ Optional: rotate master key (re-encrypt all blobs)       │
│                                                                   │
│  5. KEY REFRESH                                                  │
│     └─ Device key refreshed on every token refresh              │
│     └─ Old key still works for existing blobs (backward compat) │
│     └─ New blobs encrypted with latest key                       │
└─────────────────────────────────────────────────────────────────┘
```

### API Endpoints (New)

```
POST /auth/signin
  Response (existing + new field):
  {
    "jwt": "...",
    "user": { ... },
    "device_key": "base64_encoded_32_bytes",  ← NEW
    "sync_endpoint": "https://sync.kognisant.com/v1"  ← NEW
  }

POST /sync/manifest
  → Get remote file manifest (what's in cloud)

PUT /sync/blob/{path}
  → Upload encrypted blob

GET /sync/blob/{path}
  → Download encrypted blob

DELETE /sync/device/{device_id}
  → Revoke a device's access

GET /sync/devices
  → List paired devices
```

### Sync Protocol

```rust
pub struct SyncEngine {
    crypto: SyncCrypto,
    storage: CloudStorage,       // S3-compatible (Kognisant-hosted or user's own)
    manifest: SyncManifest,      // Tracks what's synced
    conflict_resolver: ConflictResolver,
}

pub struct SyncManifest {
    /// Per-file: hash + last_modified + sync_status
    pub files: HashMap<String, FileState>,
    pub last_sync: i64,
    pub device_id: String,
}

pub enum SyncDirection {
    Push,    // Local → Cloud (after local changes)
    Pull,    // Cloud → Local (on new device or after remote changes)
    Merge,   // Both changed — conflict resolution needed
}

impl SyncEngine {
    /// Incremental sync — only changed files
    pub async fn sync(&mut self) -> Result<SyncReport> {
        // 1. Compare local manifest to remote manifest
        let remote_manifest = self.storage.get_manifest().await?;
        let diff = self.manifest.diff(&remote_manifest);

        let mut report = SyncReport::default();

        for (path, direction) in diff {
            match direction {
                SyncDirection::Push => {
                    // Local is newer → encrypt + upload
                    let plaintext = std::fs::read(&path)?;
                    let encrypted = self.crypto.encrypt_file(&plaintext, &path);
                    self.storage.put(&path, &encrypted).await?;
                    report.pushed += 1;
                }
                SyncDirection::Pull => {
                    // Remote is newer → download + decrypt
                    let encrypted = self.storage.get(&path).await?;
                    let plaintext = self.crypto.decrypt_file(&encrypted, &path)?;
                    std::fs::write(&path, &plaintext)?;
                    report.pulled += 1;
                }
                SyncDirection::Merge => {
                    // Conflict — use CRDT merge or last-write-wins per file type
                    self.conflict_resolver.resolve(&path).await?;
                    report.merged += 1;
                }
            }
        }

        // Update manifest
        self.manifest.last_sync = now();
        self.storage.put_manifest(&self.manifest).await?;

        Ok(report)
    }

    /// Full restore from cloud (disaster recovery)
    pub async fn full_restore(&mut self) -> Result<()> {
        let manifest = self.storage.get_manifest().await?;

        for (path, _state) in &manifest.files {
            let encrypted = self.storage.get(path).await?;
            let plaintext = self.crypto.decrypt_file(&encrypted, path)?;

            // Ensure directory exists
            if let Some(parent) = Path::new(path).parent() {
                std::fs::create_dir_all(parent)?;
            }
            std::fs::write(path, &plaintext)?;
        }

        Ok(())
    }
}
```

### What Syncs

| Data | Syncs? | Frequency | Conflict Strategy |
|------|--------|-----------|-------------------|
| Memory palace (SQLite) | ✅ | Every 5 min | CRDT merge for persona, LWW for messages |
| Cognitive state (JSON) | ✅ | Every 5 min | Last-write-wins (single device active) |
| Skills library | ✅ | On change | Merge (union of skills) |
| World model | ✅ | Every 5 min | Last-write-wins |
| Telemetry.db | ✅ | Every 30 min | Append-only (no conflicts) |
| Source mirror (self-mods) | ✅ | On modification | Version chain (git-like) |
| Global settings | ✅ | On change | Last-write-wins |
| Artifacts (generated files) | ❌ | Never | Regenerable, too large |
| LLM response cache | ❌ | Never | Ephemeral, device-specific |

### Cloud Storage Options

```rust
pub enum CloudStorageBackend {
    /// Kognisant-hosted (default, included with account)
    /// Uses Kognisant API credentials, 5GB free tier
    KognisantCloud {
        endpoint: String, // https://sync.kognisant.com
    },

    /// User's own S3-compatible storage
    /// (AWS S3, Cloudflare R2, MinIO, Backblaze B2)
    CustomS3 {
        endpoint: String,
        bucket: String,
        access_key: String,     // From env: KOGNISANT_SYNC_ACCESS_KEY
        secret_key: String,     // From env: KOGNISANT_SYNC_SECRET_KEY
        region: String,
    },

    /// Local network sync (NAS, shared drive)
    LocalPath {
        path: PathBuf,          // e.g., /mnt/nas/kognisant-backup/
    },

    /// Disabled (no sync, purely local)
    Disabled,
}
```

### Recovery Flow (New Device)

```
┌─────────────────────────────────────────────────────────────────┐
│  DISASTER RECOVERY                                               │
│                                                                   │
│  1. Install Kognisant Desktop on new device                      │
│                                                                   │
│  2. Sign in with email + password (same as always)              │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  Email: user@example.com                             │     │
│     │  Password: ••••••••••••                              │     │
│     │  [Sign In]                                           │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                   │
│  3. API authenticates → issues device key                        │
│     └─ Same master key derivation as all other devices          │
│     └─ New device can decrypt everything immediately            │
│                                                                   │
│  4. Choose: "Restore from cloud backup"                          │
│                                                                   │
│  5. Pull encrypted blobs from cloud storage                      │
│     └─ Progress: ████████████░░░░ 73% (2.1 GB / 2.9 GB)        │
│                                                                   │
│  6. Decrypt locally with API-issued device key                   │
│                                                                   │
│  7. Full state restored:                                         │
│     ✅ Memory palace (all conversations, embeddings)             │
│     ✅ Cognitive state (self-model, affect, goals)               │
│     ✅ Skills library (all learned skills)                       │
│     ✅ World model (beliefs, causal chains)                      │
│     ✅ Telemetry history                                         │
│     ✅ Self-modifications (source mirror)                        │
│     ✅ Project associations                                      │
│                                                                   │
│  8. System resumes from last sync point                          │
│     └─ "Welcome back. I remember everything."                    │
│                                                                   │
│  Total user effort: sign in. That's it.                          │
└─────────────────────────────────────────────────────────────────┘
```

### Security Properties

| Property | Guarantee |
|----------|-----------|
| Confidentiality | AES-256-GCM encryption; server sees only ciphertext |
| Integrity | GCM authentication tag; tampering detected |
| Forward secrecy | Per-file derived keys; compromising one file doesn't expose others |
| Key recovery | Sign in on new device → API issues new device key. No mnemonic needed |
| Zero-knowledge storage | Cloud storage backend cannot read user data |
| Device revocation | API invalidates device key; revoked device loses decrypt ability |
| At-rest encryption | Device key stored in OS keychain (macOS Keychain, Windows DPAPI, Linux Secret Service) |
| Server trust model | API holds master key in HSM; derives device keys on auth. Server can decrypt if compelled — tradeoff for UX simplicity |

### Sync Settings UI

```
┌─────────────────────────────────────────────────────────────────┐
│  Settings → Sync & Backup                                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Status: ✅ Synced (last: 2 minutes ago)                        │
│  Storage used: 2.9 GB / 5.0 GB (Kognisant Cloud)               │
│                                                                   │
│  ─── Sync Backend ───                                            │
│  ● Kognisant Cloud (default, 5GB free)                          │
│  ○ Custom S3 (AWS, R2, MinIO, B2)                               │
│  ○ Local path (NAS, external drive)                              │
│  ○ Disabled (no backup)                                          │
│                                                                   │
│  ─── Security ───                                                │
│  Encryption: AES-256-GCM (end-to-end)                           │
│  Key ID: kp_7f3a...b2c1                                         │
│  [Rotate Key] [Revoke Device]                                   │
│                                                                   │
│  ─── Devices ───                                                 │
│  • MacBook Pro (this device) — active                           │
│  • Desktop PC — last seen 3 days ago                            │
│  [Pair New Device]                                               │
│                                                                   │
│  ─── Sync Frequency ───                                          │
│  Memory & cognitive: Every 5 minutes                             │
│  Telemetry: Every 30 minutes                                     │
│  Skills: On change                                               │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Cognitive Homeostasis Layer

This is not "self-healing" in the software sense (try/catch + restart). This is homeostatic cognition — the system continuously maintains viable operating equilibrium over indefinite runtime duration. Without this layer, a continuous cognitive system inevitably drifts toward entropy: corrupted state, runaway feedback loops, memory fragmentation, degraded predictions, unstable emergent behavior, incoherent internal models.

Biological cognition survives because it is fundamentally self-healing and self-stabilizing. This layer is what separates "persistent agent" from "continuous cognitive system" — and ultimately from "artificial organism."

### Architecture: Supervisor + Kernel Separation

The cognitive loop itself cannot be trusted to monitor itself. The homeostasis layer runs OUTSIDE the main cognition runtime.

```
kognisant-supervisor (separate process)
    │
    ├── Heartbeat monitor (expects ping every tick)
    ├── Panic recovery (catches kernel crashes)
    ├── Journal replay (restores from last healthy state)
    ├── Resource watchdog (memory leaks, disk, CPU)
    ├── Zombie reaper (orphaned subprocesses, pipes, locks)
    │
    └── cognitive-kernel (the main runtime)
            │
            ├── Cognitive Immune System (internal)
            ├── Integrity Verifier (internal)
            └── Epistemic Calibrator (internal)
```

```rust
/// Runs as a separate OS process — cannot be killed by kernel panics
pub struct Supervisor {
    kernel_pid: u32,
    last_heartbeat: Instant,
    journal: CognitiveJournal,
    health_history: VecDeque<HealthSnapshot>,
}

impl Supervisor {
    pub async fn run(&mut self) {
        loop {
            tokio::time::sleep(Duration::from_millis(500)).await;

            // 1. Check heartbeat
            if self.last_heartbeat.elapsed() > Duration::from_secs(5) {
                self.handle_kernel_death().await;
                continue;
            }

            // 2. Check resource leaks
            self.reap_zombies().await;
            self.check_disk_pressure().await;
            self.check_memory_leaks().await;

            // 3. Record health snapshot
            self.health_history.push_back(self.take_snapshot());
            if self.health_history.len() > 1000 {
                self.health_history.pop_front();
            }
        }
    }

    async fn handle_kernel_death(&mut self) {
        // 1. Log the crash
        self.journal.record_event(JournalEvent::KernelPanic { tick: self.last_known_tick });

        // 2. Find last healthy checkpoint
        let checkpoint = self.journal.last_healthy_checkpoint();

        // 3. Restart kernel from checkpoint
        self.kernel_pid = self.spawn_kernel(checkpoint).await;

        // 4. Replay valid journal deltas since checkpoint
        self.journal.replay_since(checkpoint, self.kernel_pid).await;
    }

    async fn reap_zombies(&self) {
        // Find all child processes owned by kernel
        // Kill any that have been running > timeout
        // Clean up temp files, pipes, locks
    }
}
```

### 1. Structural Integrity Healing

Every major state mutation follows a transactional pattern: intent → mutation → verification → commit. Live state is never mutated directly.

#### Cognitive Journaling

```rust
pub struct CognitiveJournal {
    log: AppendOnlyLog,  // Append-only file on disk
    snapshots: SnapshotStore,
}

pub enum JournalEntry {
    Snapshot { tick: u64, state_hash: [u8; 32], path: PathBuf },
    Delta { tick: u64, subsystem: String, mutation: StateMutation },
    Verification { tick: u64, integrity_check: IntegrityResult },
    Commit { tick: u64, entries: Vec<u64> },  // Which deltas are now committed
    Rollback { tick: u64, reason: String, restore_to: u64 },
    KernelPanic { tick: u64 },
}

impl CognitiveJournal {
    /// Every N ticks: full snapshot
    pub fn snapshot(&mut self, tick: u64, state: &SystemState) -> Result<()> {
        let serialized = rkyv::to_bytes(state)?;
        let hash = blake3::hash(&serialized);
        let path = self.snapshots.write(tick, &serialized)?;
        self.log.append(JournalEntry::Snapshot { tick, state_hash: hash.into(), path });
        Ok(())
    }

    /// Every tick: delta of what changed
    pub fn record_delta(&mut self, tick: u64, subsystem: &str, mutation: StateMutation) {
        self.log.append(JournalEntry::Delta { tick, subsystem: subsystem.to_string(), mutation });
    }

    /// Recovery: restore snapshot + replay valid deltas
    pub fn recover(&self) -> Result<SystemState> {
        let snapshot = self.last_healthy_checkpoint();
        let mut state: SystemState = rkyv::from_bytes(&self.snapshots.read(snapshot)?)?;

        for delta in self.deltas_since(snapshot) {
            if delta.is_valid() {
                state.apply_delta(&delta);
            }
            // Invalid deltas are skipped — corruption isolated
        }
        Ok(state)
    }
}
```

#### Multi-Layer Redundancy

Critical state exists in multiple layers simultaneously:

| Layer | Speed | Durability | Purpose |
|-------|-------|-----------|---------|
| RAM (live structs) | Instant | None (lost on crash) | Active computation |
| SQLite WAL | ~1ms | Crash-safe | Transactional persistence |
| Append-only journal | ~2ms | Corruption-resistant | Recovery replay |
| Compressed snapshots | ~50ms | Full state capture | Disaster recovery |

If any layer becomes corrupted, the system reconstructs from the next layer down.

### 2. Cognitive Stability Healing (The Immune System)

Detects and corrects pathological cognition patterns before they destabilize the system.

```rust
pub struct CognitiveImmuneSystem {
    detectors: Vec<Box<dyn PathologyDetector>>,
    interventions: Vec<Box<dyn CognitiveIntervention>>,
    inflammation_level: f64,  // 0.0 = healthy, 1.0 = critical
}

pub trait PathologyDetector: Send + Sync {
    fn name(&self) -> &str;
    fn detect(&self, state: &SystemState, history: &[HealthSnapshot]) -> Option<Pathology>;
}

pub trait CognitiveIntervention: Send + Sync {
    fn name(&self) -> &str;
    fn can_treat(&self, pathology: &Pathology) -> bool;
    fn apply(&self, state: &mut SystemState, pathology: &Pathology) -> InterventionResult;
}

pub enum Pathology {
    RunawayGoalGeneration { rate: f64, resolution_rate: f64 },
    AffectiveStuck { dimension: String, value: f64, duration_ticks: u64 },
    InfiniteBidLoop { agent: String, bid_count: u64 },
    ObsessionLoop { topic: String, activation_count: u64 },
    PredictionCollapse { accuracy: f64, duration_ticks: u64 },
    MemorySaturation { tier: String, usage_ratio: f64 },
    SemanticContradictionOverload { contradiction_count: usize },
    SelfModificationSpiral { attempts: u32, failures: u32 },
}
```

#### Specific Detectors

```rust
/// Detects when goals are generated faster than resolved
pub struct GoalFloodDetector;
impl PathologyDetector for GoalFloodDetector {
    fn detect(&self, state: &SystemState, history: &[HealthSnapshot]) -> Option<Pathology> {
        let gen_rate = state.goals_generated_last_100_ticks as f64 / 100.0;
        let res_rate = state.goals_resolved_last_100_ticks as f64 / 100.0;
        if gen_rate > res_rate * 5.0 && gen_rate > 0.1 {
            Some(Pathology::RunawayGoalGeneration { rate: gen_rate, resolution_rate: res_rate })
        } else { None }
    }
}

/// Detects affect dimensions stuck at extremes
pub struct AffectiveStuckDetector;
impl PathologyDetector for AffectiveStuckDetector {
    fn detect(&self, state: &SystemState, history: &[HealthSnapshot]) -> Option<Pathology> {
        // Check if any dimension has been > 0.95 or < 0.05 for > 3000 ticks (5 min at 10Hz)
        for (dim, val) in &state.affect.dimensions_as_map() {
            if (*val > 0.95 || *val < 0.05) && state.dimension_stuck_duration(dim) > 3000 {
                return Some(Pathology::AffectiveStuck {
                    dimension: dim.clone(), value: *val,
                    duration_ticks: state.dimension_stuck_duration(dim),
                });
            }
        }
        None
    }
}

/// Detects prediction accuracy collapse
pub struct PredictionCollapseDetector;
impl PathologyDetector for PredictionCollapseDetector {
    fn detect(&self, state: &SystemState, _: &[HealthSnapshot]) -> Option<Pathology> {
        let accuracy = state.homunculus.compute_accuracy(6000); // Last 10 min
        if accuracy < 0.2 && state.ticks_since_last_calibration > 3000 {
            Some(Pathology::PredictionCollapse { accuracy, duration_ticks: 3000 })
        } else { None }
    }
}
```

#### Interventions

```rust
/// Force-rebalance stuck affect dimensions
pub struct AffectRebalancer;
impl CognitiveIntervention for AffectRebalancer {
    fn apply(&self, state: &mut SystemState, pathology: &Pathology) -> InterventionResult {
        if let Pathology::AffectiveStuck { dimension, .. } = pathology {
            // Gradually pull toward 0.5 (neutral) over 100 ticks
            let current = state.affect.get_dimension(dimension);
            let target = 0.5;
            let pull_rate = 0.02; // 2% per tick toward neutral
            state.affect.set_dimension(dimension, current + (target - current) * pull_rate);
            InterventionResult::Applied { severity: 0.3 }
        } else { InterventionResult::NotApplicable }
    }
}

/// Abandon zombie goals that will never complete
pub struct GoalDecayEnforcer;
impl CognitiveIntervention for GoalDecayEnforcer {
    fn apply(&self, state: &mut SystemState, pathology: &Pathology) -> InterventionResult {
        if let Pathology::RunawayGoalGeneration { .. } = pathology {
            // 1. Apply entropy to all goals (reduce priority by age)
            for goal in &mut state.goals.active {
                let age_ticks = state.tick - goal.created_tick;
                let decay = 1.0 - (age_ticks as f64 / 100_000.0).min(0.9);
                goal.priority *= decay;
            }
            // 2. Abandon goals with priority < 0.05
            state.goals.active.retain(|g| g.priority > 0.05);
            // 3. Temporarily suppress goal generation (increase threshold)
            state.goal_generation_threshold *= 1.5;
            InterventionResult::Applied { severity: 0.5 }
        } else { InterventionResult::NotApplicable }
    }
}

/// When predictions collapse: reduce autonomy, increase uncertainty
pub struct PredictionCalibrator;
impl CognitiveIntervention for PredictionCalibrator {
    fn apply(&self, state: &mut SystemState, pathology: &Pathology) -> InterventionResult {
        if let Pathology::PredictionCollapse { accuracy, .. } = pathology {
            // The system must know: "I am no longer reliable"
            state.affect.dimensions.uncertainty = 0.9;
            state.homunculus.introspection_depth = 1.0; // Maximum self-monitoring
            state.self_modification_allowed = false; // Cannot trust own modifications
            // Trigger forced consolidation to rebuild models
            state.force_consolidation = true;
            InterventionResult::Applied { severity: 0.8 }
        } else { InterventionResult::NotApplicable }
    }
}
```

#### Cognitive Inflammation Model

```rust
impl CognitiveImmuneSystem {
    /// Called every tick — the immune system is always watching
    pub fn scan(&mut self, state: &mut SystemState, history: &[HealthSnapshot]) {
        let mut detected = vec![];

        for detector in &self.detectors {
            if let Some(pathology) = detector.detect(state, history) {
                detected.push(pathology);
            }
        }

        // Update inflammation level
        self.inflammation_level = (detected.len() as f64 / 5.0).min(1.0);

        // Apply interventions for detected pathologies
        for pathology in &detected {
            for intervention in &self.interventions {
                if intervention.can_treat(pathology) {
                    let result = intervention.apply(state, pathology);
                    state.telemetry.record_intervention(intervention.name(), pathology, &result);
                }
            }
        }

        // If inflammation is critical: emergency measures
        if self.inflammation_level > 0.8 {
            self.emergency_stabilization(state);
        }
    }

    fn emergency_stabilization(&self, state: &mut SystemState) {
        // 1. Reduce tick rate to minimum
        state.target_tick_rate = 1; // 1Hz survival mode

        // 2. Disable all non-essential agents
        state.agent_society.shed_to(2); // Only Planner + Safety

        // 3. Disable self-modification
        state.self_modification_allowed = false;

        // 4. Force consolidation
        state.force_consolidation = true;

        // 5. Clear working memory (fresh start)
        state.memory.working_memory.clear();

        // 6. Log critical event
        state.telemetry.record_critical("cognitive_inflammation_critical", self.inflammation_level);
    }
}
```

### 3. Epistemic Healing

The system's beliefs, predictions, and world model need continuous maintenance — not just accumulation.

#### Belief Confidence Decay

Every belief loses confidence over time unless re-confirmed by evidence:

```rust
impl SemanticNetwork {
    /// Called during consolidation — beliefs decay toward uncertainty
    pub fn decay_beliefs(&mut self, current_tick: u64) {
        for belief in &mut self.beliefs {
            let age_ticks = current_tick - belief.last_confirmed;
            let half_life = 50_000; // ~83 minutes at 10Hz
            let decay = 0.5_f64.powf(age_ticks as f64 / half_life as f64);
            belief.confidence *= decay;
        }
        // Prune beliefs below threshold
        self.beliefs.retain(|b| b.confidence > 0.1);
    }
}
```

#### Contradiction Resolution Engine

```rust
pub struct ContradictionResolver;

impl ContradictionResolver {
    /// Find and resolve contradictions in the semantic network
    pub fn resolve(&self, network: &mut SemanticNetwork) {
        let contradictions = network.find_contradictions();

        for (belief_a, belief_b) in contradictions {
            // Resolution strategies (in priority order):
            // 1. Evidence count: more evidence wins
            if belief_a.evidence_count > belief_b.evidence_count * 2 {
                network.weaken(belief_b.id, 0.5);
                continue;
            }
            // 2. Recency: more recent confirmation wins
            if belief_a.last_confirmed > belief_b.last_confirmed + 10_000 {
                network.weaken(belief_b.id, 0.3);
                continue;
            }
            // 3. Neither wins clearly: reduce confidence in both
            network.weaken(belief_a.id, 0.2);
            network.weaken(belief_b.id, 0.2);
            // 4. Generate a CONTRADICTION_RESOLUTION goal
            network.emit_contradiction_goal(&belief_a, &belief_b);
        }
    }
}
```

#### Memory Reconciliation (Forgetting as Healing)

```rust
pub struct MemoryReconciler;

impl MemoryReconciler {
    /// Periodic maintenance — human cognition forgets for a reason
    pub fn reconcile(&self, palace: &mut MemoryPalace) {
        // 1. Deduplicate: merge near-identical episodic memories
        palace.episodic_buffer.deduplicate(similarity_threshold: 0.95);

        // 2. Abstract: replace specific episodes with generalized patterns
        let patterns = palace.dream_engine.extract_patterns(
            &palace.episodic_buffer.oldest(100)
        );
        palace.semantic_network.integrate_patterns(&patterns);

        // 3. Forget: remove low-activation, low-utility memories
        palace.episodic_buffer.prune(|m| m.activation < 0.01 && m.age_ticks > 50_000);
        palace.semantic_network.prune_stale(staleness_threshold: 100_000);

        // 4. Compress: reduce precision of old embeddings
        palace.ltm.compress_old_embeddings(age_threshold: 200_000);

        // 5. Reindex: rebuild vector indices after pruning
        palace.semantic_network.rebuild_index();
    }
}
```

#### Semantic Graph Entropy Management

```rust
impl SemanticNetwork {
    /// Prevent the graph from becoming an immortal junk drawer
    pub fn manage_entropy(&mut self, tick: u64) {
        // Edge decay: unused edges weaken
        for edge in &mut self.edges {
            let age = tick - edge.last_traversed;
            let decay = 0.5_f64.powf(age as f64 / 100_000.0);
            edge.strength *= decay;
        }
        // Remove dead edges
        self.edges.retain(|e| e.strength > 0.05);

        // Node pruning: concepts with no edges and no recent activation
        let orphans: Vec<String> = self.nodes.iter()
            .filter(|(id, node)| {
                node.activation < 0.01
                && node.usage_count == 0
                && !self.edges.iter().any(|e| &e.source == *id || &e.target == *id)
            })
            .map(|(id, _)| id.clone())
            .collect();
        for id in orphans { self.nodes.remove(&id); }

        // Confidence redistribution: normalize after pruning
        let total_confidence: f64 = self.nodes.values().map(|n| n.stability).sum();
        if total_confidence > 0.0 {
            let scale = self.nodes.len() as f64 * 0.5 / total_confidence;
            for node in self.nodes.values_mut() {
                node.stability = (node.stability * scale).min(1.0);
            }
        }
    }
}
```

### 4. Runtime Survival Healing

Operating-system-level resilience for the cognitive process.

#### Tick Health Metrics

```rust
pub struct TickHealthMonitor {
    tick_durations: VecDeque<Duration>,  // Rolling window
    panic_count: u32,
    stalled_agents: Vec<String>,
    memory_rss_history: VecDeque<u64>,
}

impl TickHealthMonitor {
    pub fn record_tick(&mut self, duration: Duration, state: &SystemState) {
        self.tick_durations.push_back(duration);
        if self.tick_durations.len() > 1000 { self.tick_durations.pop_front(); }

        // Detect memory leaks (RSS growing monotonically)
        self.memory_rss_history.push_back(state.process_rss_bytes);
        if self.is_leaking() {
            state.telemetry.record_warning("memory_leak_detected", state.process_rss_bytes);
        }

        // Detect stalled agents (no bid in 100 ticks)
        self.stalled_agents = state.agent_society.find_stalled(100);
    }

    fn is_leaking(&self) -> bool {
        if self.memory_rss_history.len() < 100 { return false; }
        let recent = &self.memory_rss_history.as_slices().0[self.memory_rss_history.len()-50..];
        // Check if last 50 samples are monotonically increasing
        recent.windows(2).all(|w| w[1] >= w[0])
    }
}
```

#### Zombie Process Reaper

```rust
pub struct ZombieReaper {
    owned_processes: HashMap<u32, ProcessRecord>,
}

pub struct ProcessRecord {
    pid: u32,
    spawned_at: Instant,
    timeout: Duration,
    purpose: String,
    temp_files: Vec<PathBuf>,
}

impl ZombieReaper {
    /// Called by supervisor every 5 seconds
    pub fn reap(&mut self) {
        let now = Instant::now();
        let mut to_kill = vec![];

        for (pid, record) in &self.owned_processes {
            if now.duration_since(record.spawned_at) > record.timeout {
                to_kill.push(*pid);
            }
        }

        for pid in to_kill {
            if let Some(record) = self.owned_processes.remove(&pid) {
                // Kill the process
                unsafe { libc::kill(pid as i32, libc::SIGKILL); }
                // Clean up temp files
                for path in &record.temp_files {
                    let _ = std::fs::remove_file(path);
                }
            }
        }
    }
}
```

### 5. Self-Modification Healing

Preventative mechanisms for the most dangerous subsystem.

#### Sandboxed Evolution (Shadow Runtimes)

Self-modifications don't happen in the live mind. They happen in isolated cognitive branches that compete:

```rust
pub struct EvolutionSandbox {
    variants: Vec<CognitiveVariant>,
    evaluation_window: Duration,
}

pub struct CognitiveVariant {
    id: String,
    patch: CodePatch,
    shadow_state: SystemState,  // Fork of main state
    metrics: VariantMetrics,
}

pub struct VariantMetrics {
    coherence: f64,           // Internal consistency
    task_completion: f64,     // Success rate on replayed tasks
    stability: f64,           // No pathologies detected
    prediction_accuracy: f64, // Homunculus accuracy in shadow
    resource_efficiency: f64, // Tokens/compute per task
}

impl EvolutionSandbox {
    /// Run competing variants against replayed episodes
    pub async fn evaluate(&mut self, episodes: &[Episode]) -> Option<String> {
        for variant in &mut self.variants {
            // Replay recent episodes through the variant's modified code
            for episode in episodes {
                variant.shadow_state.replay(episode).await;
            }
            // Measure health
            variant.metrics = self.measure(&variant.shadow_state);
        }

        // Find winner: must beat current system on ALL metrics
        let current_metrics = self.measure_current();
        self.variants.iter()
            .filter(|v| v.metrics.dominates(&current_metrics))
            .max_by(|a, b| a.metrics.composite_score().partial_cmp(&b.metrics.composite_score()).unwrap())
            .map(|v| v.id.clone())
    }
}
```

### Homeostasis Integration with Tick Loop

The immune system runs as part of every tick, but at different frequencies:

```rust
impl CognitiveKernel {
    pub async fn run(self) {
        loop {
            // ... existing tick phases ...

            // HOMEOSTASIS (runs after Action phase, before telemetry)
            if tick_count % 10 == 0 {  // Every 10 ticks (1Hz)
                self.immune_system.scan(&mut self.state, &self.health_history);
            }
            if tick_count % 100 == 0 {  // Every 100 ticks (0.1Hz)
                self.tick_health.record_tick(tick_duration, &self.state);
                self.journal.record_delta(tick_count, "state", self.state.delta());
            }
            if tick_count % 1000 == 0 {  // Every 1000 ticks (0.01Hz)
                self.journal.snapshot(tick_count, &self.state)?;
                self.contradiction_resolver.resolve(&mut self.memory.semantic_network);
            }
            if tick_count % 10000 == 0 {  // Every 10000 ticks (~17 min)
                self.memory_reconciler.reconcile(&mut self.memory);
                self.memory.semantic_network.manage_entropy(tick_count);
            }
        }
    }
}
```

### What This Makes the System

| Without Homeostasis | With Homeostasis |
|--------------------|--------------------|
| Persistent agent | Artificial organism |
| Accumulates entropy | Maintains equilibrium |
| Degrades over weeks | Stable over months/years |
| Crashes require manual restart | Self-resurrects from journal |
| Beliefs become incoherent | Contradictions actively resolved |
| Memory grows unbounded | Forgetting as cognitive hygiene |
| Affect gets stuck | Immune system rebalances |
| Self-modification is risky | Shadow runtimes prove safety first |
| Single point of failure | Multi-layer redundancy |
| Reactive error handling | Predictive pathology detection |

The system doesn't just survive failures — it actively maintains the conditions for viable cognition. That's homeostasis.

---

## Safety & Containment

### The Self-Modification Problem

Self-modification is the defining capability of AGI and its greatest risk.

**Containment layers:**

1. **Immutable markers** — Critical safety code cannot be modified by the system
2. **Critical path approval** — Changes to core cognition require human approval
3. **Test harness** — All changes verified before application
4. **Rollback** — 60-second health check, automatic revert
5. **Sandbox** — Self-modification runs in isolated process first
6. **Transparency** — All self-modifications logged, visible in UI
7. **Confidence gating** — Self-modification allowed when test pass rate > 0.9 AND health monitor green (no arbitrary time limit)

### Cognitive Safety

| Risk | Mitigation |
|------|-----------|
| Runaway goal generation | Fatigue naturally suppresses generation; resource budget limits concurrent pursuit |
| Value drift | Value function anchored to user satisfaction + intrinsic coherence |
| Self-deception | Homunculus L3 monitors prediction accuracy; high self-surprise triggers investigation |
| Manipulation | Social model is transparent to user; user can inspect and correct |
| Resource exhaustion | Cognitive budget derived from hardware profile; sleep triggered by fatigue dynamics |
| Epistemic closure | Curiosity agent always bids for novelty; exploration enforced |

### The Off-Switch

The system has a hierarchical off-switch:

1. **Pause** (user): Stop ticks, preserve state, resume later
2. **Sleep** (system): Enter consolidation, reduce to 0.1Hz
3. **Reset cognitive** (user): Clear working memory, episodic buffer, active goals
4. **Reset memory** (user): Clear semantic network, re-learn from scratch
5. **Uninstall** (user): Delete all local data, revoke API tokens

---

## Appendix: Formal Definitions

### Variational Free Energy

For a generative model `p(o, s)` with observations `o` and hidden states `s`, and approximate posterior `q(s)`:

```
F[q] = E_q[log q(s) - log p(o, s)]
     = D_KL[q(s) || p(s|o)] - log p(o)
```

Minimizing F:
- Maximizes model evidence `log p(o)` (accuracy)
- Minimizes posterior complexity `D_KL[q || p]` (complexity)

### Active Inference Expected Free Energy

For action `a` at time `t`:

```
G(a) = Σ_s q(s_t | a) [log q(s_t | a) - log p(o_t, s_t)]
     = Expected ambiguity + Expected risk + Expected information gain
```

The system selects actions that minimize `G`.

### Memory Activation

For memory chunk `m` with feature vector `f_m` and current context `c`:

```
Activation(m) = α * similarity(f_m, c)
              + β * recency(m)
              + γ * emotional_salience(m)
              - δ * inhibition(m)
```

Where `α + β + γ = 1` and `δ` is competitive suppression.

### Goal Bid Score

For bid `b` from agent `a`:

```
Score(b) = [E_p[value] * P(success) + λ * information_gain] / [cost + ε]
```

Where `λ` is epistemic weight (curiosity-driven).

---

*This document is the source of truth for the Kognisant Desktop Proto-AGI v2.0 implementation. It replaces the v1 reactive agent architecture with a continuous predictive processing system. All data stays local. LLM inference is one modality among many, routed through the Kognisant API.*
