# Kognisant Desktop (KC)

A continuous, self-modifying, predictive processing engine that runs in your terminal. KC treats cognition as an emergent property of interacting subsystems — not a sequential pipeline. All data stays on-device, encrypted at rest, with optional E2E encrypted cloud sync.

> **Design philosophy**: The user should always understand what the system is doing, why, what could happen next, and how to intervene.

---

## What Is This?

KC is a TUI-based cognitive runtime built entirely in Rust. It implements predictive processing and active inference as a practical engineering system — a local proto-AGI that observes your project, predicts what you need, and acts with your approval.

It is **not** a chatbot. It is a continuous cognitive loop (10Hz when active, 1Hz when idle) that perceives your workspace, maintains beliefs about your project, generates goals from prediction errors, and selects actions through a competitive multi-agent society.

### Core Properties

- **Continuous**: Always running, always predicting. Not turn-based.
- **Self-modifying**: Can read, patch, recompile, and hot-reload its own source — bounded by constitutional safety constraints.
- **Predictive**: Every subsystem generates predictions and updates beliefs from surprise (prediction error).
- **Human-in-the-loop**: Never automates judgment. Skill extraction, action approval, and self-modification all require human consent at appropriate gates.
- **Local-first**: All cognition runs on your machine. LLM inference is one modality among many, routed through a multi-provider pool.

---

## TUI Visibility Modes

KC runs in the terminal with three visibility modes. Switch between them based on how much you want to see:

| Mode | Purpose | What You See |
|------|---------|-------------|
| **Focus** | Daily driver | Conversation + workspace status. Minimal cognitive noise. |
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
│   │   ├── kernel.rs           # 10Hz tick loop
│   │   ├── tick.rs             # Tick phases
│   │   └── state.rs            # SystemState
│   ├── perception/             # Sensory cortex
│   ├── prediction/             # Predictive processing stack
│   ├── memory/                 # Memory palace (6-tier)
│   ├── self_model/             # Homunculus
│   ├── affect/                 # Affective economy
│   ├── world/                  # World simulator
│   ├── goals/                  # Goal market
│   ├── society/                # Multi-agent society
│   ├── meta/                   # Meta-cognitive controller
│   ├── action/                 # Motor cortex + effectors
│   ├── self_modify/            # Self-modification engine
│   ├── llm/                    # LLM pool (multi-provider)
│   ├── skills/                 # Skill extraction + lifecycle
│   │   ├── mining.rs           # SkillMiningAgent pipeline
│   │   ├── lifecycle.rs        # TTL, expiration, renewal
│   │   ├── context.rs          # Contextual skill matching
│   │   └── ecosystem.rs        # Version tracking, half-lives
│   ├── journal/                # Structured journal system
│   │   ├── entries.rs          # Decision, Failure, Insight, Milestone types
│   │   ├── parser.rs           # YAML frontmatter + markdown parsing
│   │   └── extraction.rs       # Tag, cluster, suggest pipeline
│   ├── tools/                  # Tool system
│   ├── telemetry/              # Full cognitive tracing
│   ├── replay/                 # Deterministic replay system
│   └── config/                 # Settings, auth
├── docs/                       # Architecture documentation
│   ├── proto-agi.md            # Full architecture (source of truth)
│   └── expanding_on/           # Deep-dive documents per subsystem
├── Cargo.toml                  # Rust dependencies
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
│   ├── journal.md              # Project episodic memory (structured)
│   └── memory/                 # Project-local persistent context
```

### User-Level Storage (`~/.kc/`)

Cross-project skills, preferences, and memory persist at the user level:

```
~/.kc/
├── skills/                     # Persistent cross-project skills
│   ├── approved/               # Active skills (user-approved)
│   ├── candidates/             # Pending user review
│   ├── archived/               # Expired/archived skills
│   └── rejected/               # Rejected (system learns what not to suggest)
├── preferences/                # User preferences, communication style
├── memory/                     # Cross-project semantic memory
└── config.toml                 # Global settings, LLM providers
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

Key subsystems:
- **Predictive Processing Stack** — 5-layer hierarchy generating predictions and propagating errors
- **Memory Palace** — 6-tier reconstructive memory with competitive activation
- **Homunculus** — Self-model that predicts the system's own behavior
- **Affective Economy** — 6D dynamical system driving resource allocation
- **Agent Society** — 13 specialist agents competing via bidding market
- **Goal Market** — Goals emerge from surprise, resolved through competitive bidding
- **World Simulator** — Causal reasoning, counterfactuals, social modeling
- **Self-Modification Engine** — Bounded recursive evolution with constitutional safety

For the full architecture, see [docs/proto-agi.md](docs/proto-agi.md).

---

## Safety

Every operation supports **pause / cancel / rollback / replay / resume**. Approval gates fire for:
- Destructive operations (file deletion, data modification)
- Structural changes (architecture-level refactoring)
- External operations (network requests, API calls)
- Persistent changes (memory writes, skill promotion)
- Autonomous operations (self-modification, goal pursuit without explicit user request)

The system cannot weaken its own safety constraints. Constitutional modules are cryptographically signed and verified by an external supervisor process.

---

## License

Proprietary. All rights reserved.
