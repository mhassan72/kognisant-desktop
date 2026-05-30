# Kognisant Desktop (KC)

```
██╗  ██╗
██║ ██╔╝
█████╔╝
██╔██╗
██║ ╚██╗
╚═╝  ╚═╝

K O G N I S A N T
Cognitive Runtime
```

A continuous, self-modifying, predictive processing engine that runs in your terminal. KC treats cognition as an emergent property of interacting subsystems — not a sequential pipeline. All data stays on-device, encrypted at rest, with optional E2E encrypted cloud sync.

> **Design philosophy**: The user should always understand what the system is doing, why, what could happen next, and how to intervene.

---

## What Is This?

KC is a TUI-based cognitive runtime built entirely in Rust. It implements predictive processing and active inference as a practical engineering system — a local proto-AGI that observes your project, predicts what you need, and acts with your approval.

It is **not** a chatbot. It is a continuous cognitive loop (10Hz when active, 1Hz when idle) that perceives your workspace, maintains beliefs about your project, generates goals from prediction errors, and selects actions through a competitive multi-agent society.

### Core Properties

- **Continuous**: Always running, always predicting. Not turn-based. The tick loop is single-threaded and sequential — agents bid in order within each tick, no shared mutable state, no locks on the hot path.
- **Self-modifying**: Can read, patch, recompile, and hot-reload its own source — bounded by constitutional safety constraints, cryptographic verification, and an immutable supervisor process.
- **Predictive**: Every subsystem generates predictions and updates beliefs from surprise (prediction error). Five PP layers from raw sensory to strategic intent.
- **Human-in-the-loop**: Never automates judgment. Skill extraction, action approval, and self-modification all require human consent at appropriate gates.
- **Local-first**: All state is local. LLM inference is one modality among many, routed through a multi-provider pool (Ollama local-first, remote fallback). Standard+ tiers are fully local-capable.

---

## TUI Visibility Modes

KC runs in the terminal with three visibility modes. Switch between them based on how much you want to see:

| Mode | Purpose | What You See |
|------|---------|-------------|
| **Focus** | Daily driver | Conversation + activity indicator + workspace status. Minimal cognitive noise. |
| **Trace** | Operational visibility | Active goals, agent bids, prediction errors, action pipeline. |
| **Paranoia** | Full observability | Every tick phase, memory activations, affect vector, DAG execution, replay controls. |

The system behaves identically in all modes — visibility doesn't change cognition, only what's rendered.

---

## Project Structure

```
kognisant-desktop/
├── src/                        # Rust source (the entire application)
│   ├── main.rs                 # Entry point — TUI + cognitive kernel
│   ├── tui/                    # Terminal UI (ratatui)
│   │   ├── mod.rs
│   │   ├── focus.rs            # Focus mode (minimal, daily driver)
│   │   ├── trace.rs            # Trace mode (operational visibility)
│   │   ├── paranoia.rs         # Paranoia mode (full observability)
│   │   ├── approval.rs         # Action approval dialogs
│   │   ├── dag.rs              # Execution DAG viewer
│   │   └── memory_view.rs      # Memory visibility layer
│   ├── cognitive/              # Continuous cognitive loop
│   │   ├── kernel.rs           # 10Hz tick loop (single-threaded, sequential)
│   │   ├── tick.rs             # Tick phases + per-subsystem scheduling
│   │   └── state.rs            # SystemState (owned, not shared)
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
│   │   ├── mining.rs           # SkillMiningAgent pipeline (TAG → CLUSTER → SUGGEST → REVIEW)
│   │   ├── lifecycle.rs        # TTL, expiration, renewal
│   │   ├── context.rs          # Contextual skill matching
│   │   └── ecosystem.rs        # Version tracking, domain half-lives
│   ├── journal/                # Structured journal system
│   │   ├── entries.rs          # Decision, Failure, BugFix, Insight, Milestone types
│   │   ├── parser.rs           # YAML frontmatter + markdown parsing
│   │   └── extraction.rs       # Tag, cluster, suggest pipeline
│   ├── tools/                  # Tool system (13 tools, sandboxed)
│   ├── telemetry/              # Full cognitive tracing (SQLite, per-project)
│   ├── replay/                 # Session replay (observation, not re-execution)
│   └── config/                 # Settings, auth, provider config
├── docs/                       # Architecture documentation
│   ├── proto-agi.md            # Full architecture (source of truth)
│   ├── architecture-decisions.md # Implementation specs (authoritative for details)
│   └── expanding_on/           # 17 deep-dive documents per subsystem
├── Cargo.toml
├── Cargo.lock
└── README.md
```

---

## Project Cognition Context (`.kc/`)

KC stores per-project cognition in a `.kc/` directory at the project root. This is where steering docs, specs, journal entries, and project-local memory live.

```
any-project/
├── .kc/
│   ├── steering/               # Project rules — agents MUST follow
│   │   ├── architecture.md
│   │   ├── conventions.md
│   │   └── constraints.md
│   ├── specs/                  # Multi-tenant spec system
│   │   ├── feature-name/
│   │   │   ├── requirements.md
│   │   │   ├── design.md
│   │   │   └── tasks.md
│   │   └── ...
│   ├── journal.md              # Project episodic memory (structured entries)
│   └── memory/                 # Project-local persistent context
```

### User-Level Storage (`~/.kc/`)

Cross-project skills, preferences, and memory persist at the user level:

```
~/.kc/
├── skills/                     # Persistent cross-project skills
│   ├── approved/               # Active skills (user-approved, TOML format)
│   ├── candidates/             # Pending user review
│   ├── archived/               # Expired/archived skills
│   └── rejected/               # Rejected (system learns what not to suggest)
├── preferences/                # User preferences, communication style
├── memory/                     # Cross-project semantic memory
├── projects/                   # Per-project runtime data
│   └── {project-id}/
│       ├── telemetry.db        # SQLite event log (per-project, 30-day retention)
│       └── state.log           # Binary state checkpoint log (crash recovery)
├── state/                      # Global runtime state
│   ├── memory_palace/          # SQLite databases for memory tiers
│   └── snapshots/              # rkyv state snapshots (crash recovery)
├── config.toml                 # Global settings, LLM providers
└── projects.toml               # Registry of all known projects
```

Skills are never auto-promoted. The system mines patterns from your work, proposes candidates, and waits for your approval. Weekly review surfaces 3-5 suggestions. Quarterly renewal ensures stale skills expire gracefully.

---

## Getting Started

### Prerequisites

- Rust toolchain (stable, 1.75+)
- A terminal emulator with 256-color support

### Build

```bash
cargo build --release
```

### Run

```bash
cargo run --release
```

KC will start in Focus mode. Use `Ctrl+1/2/3` to switch visibility modes.

### Initialize a Project

```bash
cd your-project/
kc init .
```

This creates the `.kc/` directory with steering templates, an empty journal, and project-local config.

### Configuration

On first run, KC creates `~/.kc/config.toml` with defaults. Configure LLM providers there:

```toml
[llm]
prefer_local = true

[llm.providers.ollama]
enabled = true
host = "http://localhost:11434"

[llm.providers.openai]
enabled = false
# api_key read from OPENAI_API_KEY env var
```

---

## Architecture

KC implements the Free Energy Principle as a practical engineering system. The core thesis: all behavior emerges from minimizing prediction error (surprise).

### Key Subsystems

- **Predictive Processing Stack** — 5-layer hierarchy (raw → syntactic → semantic → pragmatic → strategic) generating predictions and propagating errors
- **Memory Palace** — 6-tier reconstructive memory with competitive activation and O(80) optimized inhibition
- **Homunculus** — Self-model that predicts the system's own behavior (L0-L5 self-awareness)
- **Affective Economy** — 6D coupled dynamical system driving resource allocation
- **Agent Society** — 13 specialist agents competing via bidding market (sequential within tick, emergent orchestration)
- **Goal Market** — Goals emerge from surprise, resolved through competitive bidding (with cold-start bootstrap)
- **World Simulator** — Causal reasoning, counterfactuals, social modeling
- **Self-Modification Engine** — Bounded recursive evolution with constitutional safety, security gate, and staged health monitoring
- **Tool System** — 13 sandboxed tools (file ops, shell, git, LLM, memory) with approval routing
- **Cognitive Homeostasis** — 8 pathology detectors, 5 intervention severity levels, supervisor process

### Concurrency Model

The cognitive tick loop is **single-threaded and sequential**. Agents are synchronous functions called in order within the Deliberation phase. Tokio provides async I/O for file watching, LLM streaming, and the TUI — but cognition itself is a deterministic sequential pipeline. LLM queries are fire-and-forget; responses arrive as perception in future ticks.

### Communication

- `tokio::sync::watch` — Tick state broadcast (kernel → TUI, latest-value semantics)
- `tokio::sync::mpsc` — Discrete events (kernel → TUI, capacity 16, never lost)
- `tokio::sync::mpsc` — User commands (TUI → kernel, capacity 32, never dropped)

No locks on the hot path. No shared mutable state between kernel and TUI.

For the full architecture, see [docs/proto-agi.md](docs/proto-agi.md).
For implementation specifications, see [docs/architecture-decisions.md](docs/architecture-decisions.md).

---

## Safety

Every operation supports **pause / cancel / rollback / replay / resume**. Approval gates fire for:
- Destructive operations (file deletion, data modification)
- Structural changes (architecture-level refactoring)
- External operations (network requests, API calls)
- Persistent changes (memory writes, skill promotion)
- Autonomous operations (self-modification, goal pursuit without explicit user request)

The system cannot weaken its own safety constraints. Constitutional modules are cryptographically signed and verified by an external supervisor process (PID 1 of the application). The supervisor is the parent process — the kernel cannot restart without it.

Self-modification patches pass through both a safety gate (immutable markers, complexity limits) and a security gate (no new network access, no env reads, no process spawning outside tools). Hyperparameter bounds prevent self-lobotomy even within "approved" ranges.

---

## Documentation

| Document | Purpose |
|----------|---------|
| [docs/proto-agi.md](docs/proto-agi.md) | Full architecture — source of truth |
| [docs/architecture-decisions.md](docs/architecture-decisions.md) | Implementation specs — authoritative for details |
| [docs/expanding_on/](docs/expanding_on/) | 17 deep-dive documents per subsystem |

### Expansion Documents

| File | Topic |
|------|-------|
| `concurrency-model.md` | Tick loop threading, agent execution, async I/O boundary |
| `state-consistency.md` | rkyv snapshots, SQLite, recovery reconciliation |
| `safety-architecture.md` | Supervisor as PID 1, immutable launcher, boot verification |
| `predictive-processing.md` | PP stack, concrete prediction formats per layer |
| `memory-palace.md` | 6-tier memory, embedding migration, optimized inhibition |
| `agent-society.md` | 13 agents, shedding priority, coalition formation |
| `goal-market.md` | Cold-start bootstrap, bidding, temporal discounting |
| `affective-economy.md` | 6D dynamics, coupling, behavioral modes |
| `tool-system.md` | 13 tools, sandboxing, approval routing |
| `tui-design.md` | 3 modes, rendering pipeline, approval flow |
| `llm-pool.md` | Routing, fallback, cost tracking, degraded mode |
| `self-modification.md` | Pipeline, safety/security gates, shadow runtimes |
| `cognitive-homeostasis.md` | Pathology detectors, state checkpoint log, supervisor |
| `hardware-scaling.md` | Device profiling, dynamic bounds, thermal throttling |
| `world-simulator.md` | Causal engine, counterfactuals, social model |
| `homunculus-self-model.md` | Self-prediction, L0-L5, meta-learning |
| `cloud-sync.md` | E2E encryption, HKDF, conflict resolution |

---

## License

Proprietary. All rights reserved.
