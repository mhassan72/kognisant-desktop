# 🧠 Kognisant Desktop

A continuous, self-modifying, predictive processing system running locally as a desktop application. Cognition emerges from interacting subsystems — not a sequential pipeline.

---

## What This Is

Kognisant Desktop is a **Proto-AGI v2** cognitive architecture. It replaces the traditional agent model (reactive, turn-based, externally prompted) with a continuous cognitive system that is always running, self-directed, and intrinsically motivated.

The system continuously predicts what will happen next — user messages, file changes, build outcomes, its own internal states. Prediction error (surprise) is the fundamental currency of cognition. Minimizing long-term surprise drives all behavior.

For the full architecture document, see [`docs/proto-agi.md`](docs/proto-agi.md).

---

## Architecture at a Glance

```
┌─────────────────────────────────────────────────────────────────┐
│              CONTINUOUS COGNITIVE KERNEL (Rust + N-API)           │
│                                                                   │
│  Perception-Action Loop (10Hz tick)                              │
│    → Predictive Stack (5 layers)                                 │
│    → Surprise Detection → Belief Update → Action Selection       │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Memory Palace │  │  Homunculus  │  │   Affective  │          │
│  │ (6-tier)      │  │ (Self-Model) │  │   Economy    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │    World     │  │  Goal Market │  │    Agent     │          │
│  │  Simulator   │  │  (Bidding)   │  │   Society    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                   │
│  Meta-Cognitive Controller • Self-Modification Engine             │
│  Cognitive Homeostasis • LLM Pool (multi-provider)               │
└─────────────────────────────────────────────────────────────────┘
                              │ IPC (N-API)
┌─────────────────────────────────────────────────────────────────┐
│              VUE 3 FRONTEND (Vite + Tailwind)                    │
│  Views: Chat | Cognitive Graph | Memory Palace | Goal Market     │
│         Agent Society | World Simulator | Self-Model | Telemetry │
└─────────────────────────────────────────────────────────────────┘
                              │ HTTPS (outbound)
              ┌───────────────┴───────────────┐
              │         LLM PROVIDERS          │
              │  Kognisant API • Ollama (local) │
              │  OpenAI • Any compatible endpoint│
              └────────────────────────────────┘
```

Key subsystems:
- **Predictive Processing Stack** — 5-layer hierarchy generating predictions, computing surprise, propagating errors
- **Neuro-Symbolic Memory Palace** — 6-tier competitive activation memory (working → episodic → semantic → procedural → LTM → dream)
- **Homunculus** — Self-model that predicts the system's own behavior and detects self-surprise
- **Affective Economy** — 6D affect state that drives cognitive resource allocation
- **Agent Society** — 12 specialist agents competing via a bidding market (emergent orchestration, no central planner)
- **Goal Market** — Goals generated from prediction errors, resolved via value-weighted bidding
- **World Simulator** — Mental sandbox with counterfactual reasoning and causal chains
- **Self-Modification Engine** — Reads/modifies own source, recompiles, hot-reloads (safety-gated)
- **Cognitive Homeostasis** — Immune system detecting and correcting pathological cognition patterns
- **LLM Pool** — Local multi-provider router (Kognisant API, Ollama, OpenAI-compat, custom endpoints)

---

## Technical Stack

| Layer | Technology | Role |
|-------|-----------|------|
| Cognitive Kernel | **Rust** (compiled via NAPI-RS) | 10Hz tick loop, all cognitive subsystems, native performance |
| Desktop Shell | **Electron** (`main.js` + `preload.js`) | Window management, secure IPC bridge |
| Frontend | **Vue 3** + **Tailwind CSS** (Vite) | Real-time cognitive visualization, reactive UI |
| Storage | **SQLite** (rusqlite, bundled) | Memory palace, telemetry, world model, cognitive state |
| Vector Search | **HNSW** / sqlite-vss | Semantic network approximate nearest neighbor |
| Embeddings | **ONNX Runtime** (ort) | Local embedding generation (CPU/GPU) |
| LLM Routing | Multi-provider pool | Kognisant API, Ollama, OpenAI-compat, env-var discovery |
| Version Control | **git2** (libgit2) | Self-modification lineage tracking |
| Sync | **AES-256-GCM** + HKDF | E2E encrypted cloud backup & multi-device |

Zero-server architecture: no local HTTP server, no WebSockets. The Rust kernel is loaded directly into Electron's main process via N-API. Communication flows through `contextBridge` — direct memory-mapped bindings.

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
│       ├── continuous/               # Continuous cognitive loop
│       │   ├── kernel.rs             # Main 10Hz loop
│       │   ├── tick.rs               # Tick phases, scheduling
│       │   └── state.rs              # SystemState (shared, lock-free)
│       ├── perception/               # Sensory cortex
│       │   ├── cortex.rs             # Multi-modal perception
│       │   └── modalities/           # user_message, file_system, process, timer, self_state
│       ├── prediction/               # Predictive processing stack
│       │   ├── stack.rs              # 5-layer hierarchy
│       │   ├── layer.rs              # Individual PP layer
│       │   ├── surprise.rs           # Surprise computation
│       │   └── precision.rs          # Precision weighting
│       ├── memory/                   # Memory palace (6-tier)
│       │   ├── palace.rs             # Orchestrator
│       │   ├── working.rs            # Working memory
│       │   ├── episodic.rs           # Episodic buffer (ring buffer)
│       │   ├── semantic.rs           # Semantic network (graph + vectors)
│       │   ├── procedural.rs         # Procedural memory (RL + rules)
│       │   ├── consolidated.rs       # Long-term memory (compressed)
│       │   └── dream.rs              # Dream engine (consolidation)
│       ├── self_model/               # Homunculus
│       │   ├── homunculus.rs         # Self-simulation
│       │   ├── introspection.rs      # Self-awareness injection
│       │   └── levels.rs             # L0-L5 self-awareness
│       ├── affect/                   # Affective economy
│       │   ├── economy.rs            # 6D affect + budget
│       │   ├── dynamics.rs           # Temporal dynamics, decay
│       │   └── budget.rs             # Cognitive resource allocation
│       ├── world/                    # World simulator
│       │   ├── simulator.rs          # Mental sandbox
│       │   ├── causal.rs             # Causal engine
│       │   ├── beliefs.rs            # Belief graph
│       │   └── social.rs             # User model
│       ├── goals/                    # Goal market
│       │   ├── market.rs             # Bid resolution
│       │   ├── generation.rs         # Goal generation from surprise
│       │   ├── value_function.rs     # Learned values
│       │   └── hierarchy.rs          # Goal/subgoal trees
│       ├── society/                  # Multi-agent society
│       │   ├── society.rs            # Agent container + market
│       │   ├── bidding.rs            # Coalition formation
│       │   └── agents/               # 12 specialist agents
│       ├── meta/                     # Meta-cognitive controller
│       │   ├── controller.rs         # MCC orchestration
│       │   ├── attention.rs          # Attention allocation
│       │   └── sleep.rs              # Consolidation scheduling
│       ├── action/                   # Motor cortex
│       │   ├── cortex.rs             # Action selection
│       │   └── effectors/            # message, tool, llm, file, self_modify, sleep
│       ├── self_modify/              # Self-modification engine
│       │   ├── engine.rs             # Orchestrator
│       │   ├── safety_gate.rs        # Immutable markers, critical path
│       │   └── rollback.rs           # Restore on failure
│       ├── llm/                      # LLM pool (multi-provider)
│       │   ├── pool.rs               # Routes to best available provider
│       │   ├── kognisant.rs          # Kognisant API (default)
│       │   ├── ollama.rs             # Local Ollama
│       │   ├── openai_compat.rs      # Any OpenAI-compatible endpoint
│       │   └── selector.rs           # Model selection logic
│       ├── tools/                    # Tool system
│       │   ├── registry.rs
│       │   └── sandbox.rs
│       ├── telemetry/                # Full cognitive tracing
│       └── config/                   # Settings, auth
├── frontend/                         # Vue 3 + Tailwind
│   └── src/
│       ├── views/                    # Chat, CognitiveGraph, MemoryPalace, GoalMarket, etc.
│       ├── stores/                   # Pinia stores per subsystem
│       ├── components/               # cognitive/, memory/, affect/, common/
│       └── composables/              # useCognitiveStream (10Hz), useKernel
├── main.js                           # Electron main process
├── preload.js                        # Secure context bridge
└── package.json                      # Root orchestration
```

---

## Documentation

All architecture and design documentation lives in `docs/`:

| File | Contents |
|------|----------|
| [`docs/proto-agi.md`](docs/proto-agi.md) | Full Proto-AGI v2.0 architecture — the source of truth |
| [`docs/database_schema/`](docs/database_schema/) | SQLite schema designs for all subsystems |
| [`docs/database_schema/overview.md`](docs/database_schema/overview.md) | Schema design principles and database layout |
| [`docs/database_schema/memory_palace.sql`](docs/database_schema/memory_palace.sql) | 6-tier memory system schema |
| [`docs/database_schema/cognitive_state.sql`](docs/database_schema/cognitive_state.sql) | Predictive stack, affect, homunculus, goals, agents |
| [`docs/database_schema/telemetry.sql`](docs/database_schema/telemetry.sql) | Full traceability (tick traces, LLM log, self-mod audit) |
| [`docs/database_schema/world_model.sql`](docs/database_schema/world_model.sql) | Beliefs, causal chains, social model, simulations |
| [`docs/database_schema/sync_schema.sql`](docs/database_schema/sync_schema.sql) | E2E encrypted cloud sync metadata |
| [`docs/database_schema/global_db.sql`](docs/database_schema/global_db.sql) | Global settings, auth, skills, device profile |
| [`docs/expanding_on/`](docs/expanding_on/) | Deep-dive expansion documents per subsystem |

### Expansion Documents (`docs/expanding_on/`)

Each file goes deeper than proto-agi.md — implementation details, edge cases, research references, and open design questions:

| File | Topic |
|------|-------|
| [`predictive-processing.md`](docs/expanding_on/predictive-processing.md) | Free Energy Principle implementation, precision weighting, layer-by-layer PP stack |
| [`memory-palace.md`](docs/expanding_on/memory-palace.md) | Tier interactions, activation decay, consolidation algorithms, HNSW config |
| [`homunculus-self-model.md`](docs/expanding_on/homunculus-self-model.md) | Self-prediction, generative self-model training, L0-L5 details |
| [`affective-economy.md`](docs/expanding_on/affective-economy.md) | Temporal dynamics equations, precision weighting per modality, budget computation |
| [`agent-society.md`](docs/expanding_on/agent-society.md) | All 12 agent specs, bid scoring, coalition formation, agent lifecycle |
| [`goal-market.md`](docs/expanding_on/goal-market.md) | Goal generation algorithm, value function RL, temporal discounting, hierarchy |
| [`world-simulator.md`](docs/expanding_on/world-simulator.md) | Mental sandbox forking, causal propagation, do-calculus, social model |
| [`self-modification.md`](docs/expanding_on/self-modification.md) | Full pipeline, safety gates, constitutional kernel, shadow runtimes, git2 |
| [`cognitive-homeostasis.md`](docs/expanding_on/cognitive-homeostasis.md) | Supervisor architecture, journal format, pathology detectors, inflammation model |
| [`llm-pool.md`](docs/expanding_on/llm-pool.md) | Provider discovery, model scoring, cache strategy, fallback chains, cost tracking |
| [`hardware-scaling.md`](docs/expanding_on/hardware-scaling.md) | Device profiling, dynamic bounds formulas, thermal throttling, agent shedding |
| [`cloud-sync.md`](docs/expanding_on/cloud-sync.md) | HKDF key derivation, CRDT merge, sync queue, bandwidth estimation, device revocation |

---

## Getting Started

### Prerequisites

- **Rust**: `1.85.0` (Stable)
- **Node.js**: `18.x` or higher
- **C/C++ Compiler**: `Clang` or `MSVC` (required by NAPI-RS for linking)

### Installation

Install all dependencies across the workspace (Root, Frontend, and Kernel):

```bash
npm run install:all
```

### Development

Start the full-stack development environment:

```bash
npm run dev
```

This concurrently builds the Rust binary, starts the Vite HMR server, and launches Electron.

---

## Available Scripts

| Script | Description |
|:---|:---|
| `npm run dev` | Full development boot (Kernel + Vite + Electron) |
| `npm run build` | Production build of the Kernel and Frontend |
| `npm run build:kernel` | Compiles Rust into a production `.node` addon |
| `npm run install:all` | Recursive npm install across all directories |
| `npm run clean` | Purge all `node_modules` and build artifacts |

---

## Current Phase

**Pre-Implementation** — Architecture and database schemas are complete. Next: Phase 0 implementation (continuous cognitive kernel with 10Hz tick loop, multi-provider LLM pool, basic predictive stack).

See [`docs/proto-agi.md` → Implementation Phases](docs/proto-agi.md#implementation-phases) for the full roadmap.
