# TUI Design — Deep Dive

The TUI (Terminal User Interface) is the sole interface to the cognitive kernel. Built with `ratatui` for rendering and `crossterm` for terminal event handling, it provides graduated visibility into system cognition without affecting behavior.

---

## Summary

KC runs as a full-screen terminal application with three visibility modes (Focus, Trace, Paranoia). The TUI renders at the end of each cognitive tick, presenting a view into the system's internal state proportional to the user's chosen visibility level. The system behaves identically regardless of mode — visibility doesn't change cognition, only what's rendered.

---

## Rendering Pipeline

### Architecture

```
CognitiveKernel (tick loop)
    │
    ├── Tick completes → state snapshot
    │
    ▼
TuiRenderer
    ├── Event poll (crossterm — non-blocking)
    │   ├── Key events → command dispatch
    │   ├── Resize events → layout recompute
    │   └── No event → continue
    │
    ├── Layout computation (based on mode + terminal size)
    │
    ├── Widget rendering (ratatui)
    │   ├── Focus widgets (always rendered)
    │   ├── Trace widgets (if mode >= Trace)
    │   └── Paranoia widgets (if mode == Paranoia)
    │
    └── Frame flush (crossterm — write to stdout)
```

### Render Budget

The TUI must not block the cognitive tick. Rendering is budgeted:

```rust
const MAX_RENDER_MS: u64 = 16; // ~60fps cap, but we only render at tick rate (10Hz)

impl TuiRenderer {
    pub async fn render_tick(&mut self, tick: u64, state: &SystemState) {
        let start = Instant::now();
        
        // Poll events (non-blocking)
        while crossterm::event::poll(Duration::ZERO).unwrap_or(false) {
            if let Ok(event) = crossterm::event::read() {
                self.handle_event(event, state);
            }
        }
        
        // Render frame
        self.terminal.draw(|frame| {
            let layout = self.compute_layout(frame.size());
            self.render_mode(frame, &layout, state);
        }).ok();
        
        // Track render time for diagnostics
        let elapsed = start.elapsed();
        if elapsed > Duration::from_millis(MAX_RENDER_MS) {
            self.render_overruns += 1;
        }
    }
}
```

### Frame Rate

- Render rate matches tick rate (10Hz active, 1Hz idle)
- During user input (typing), render at 30Hz for responsive feedback
- During replay scrubbing, render at 30Hz for smooth playback
- Never exceed 60fps (terminal can't display faster anyway)

---

## Mode Specifications

### Focus Mode

The daily driver. Minimal cognitive noise, maximum productivity.

```
┌─────────────────────────────────────────────────────────────┐
│ KC │ Focus │ ◉ Implementing auth module │ ● │ 14:32 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  You: Can you add JWT validation to the auth middleware?    │
│                                                             │
│  KC: I'll add JWT validation. Here's my plan:              │
│                                                             │
│  1. Add `jsonwebtoken` crate to Cargo.toml                 │
│  2. Create validation middleware in src/auth/jwt.rs        │
│  3. Wire it into the router                                │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ACTION: Add dependency `jsonwebtoken = "9.3"`       │   │
│  │ [Space] Approve  [Esc] Skip  [d] Defer             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ src/auth/mod.rs modified │ build: ✓ │ git: 2 unstaged      │
└─────────────────────────────────────────────────────────────┘
```

**Layout regions:**
- **Title bar**: App name, mode indicator, current goal summary, valence orb, clock
- **Conversation pane**: Scrollable message history (user + system)
- **Approval overlay**: Appears when action needs approval (modal)
- **Status bar**: Workspace observer (file changes, build, git)

### Trace Mode

For users who want to understand the system's reasoning.

```
┌─────────────────────────────────────────────────────────────┐
│ KC │ Trace │ ◉ Implementing auth module │ ● │ 14:32 │
├───────────────────────────────────┬─────────────────────────┤
│                                   │ GOALS                   │
│  You: Add JWT validation          │ ◉ Implement auth [0.9]  │
│                                   │   ├─ ○ Add dep [0.8]    │
│  KC: Adding JWT validation...     │   ├─ ○ Write jwt.rs     │
│                                   │   └─ ○ Wire router      │
│  [streaming response]             │ ○ Fix lint warnings     │
│                                   │                         │
│                                   ├─────────────────────────┤
│                                   │ AGENTS                  │
│                                   │ ▶ Planner [0.9] decomp  │
│                                   │ ▷ Coder [0.7] waiting   │
│                                   │ ▷ Safety [✓] approved   │
│                                   │                         │
│                                   ├─────────────────────────┤
│                                   │ PIPELINE                │
│                                   │ ✓ Intent detected       │
│                                   │ ✓ Plan generated        │
│                                   │ ▶ Executing step 1/3    │
│                                   │ ○ Approval pending      │
├───────────────────────────────────┴─────────────────────────┤
│ src/auth/mod.rs modified │ build: ✓ │ git: 2 unstaged      │
└─────────────────────────────────────────────────────────────┘
```

**Additional regions:**
- **Goal panel** (right): Active goal hierarchy with priorities
- **Agent activity** (right): Which agents are active, their state
- **Action pipeline** (right): Current execution progress

### Paranoia Mode

Full cognitive transparency. Every internal state visible.

```
┌─────────────────────────────────────────────────────────────┐
│ KC │ Paranoia │ Tick 45231 │ 10Hz │ ● │ 14:32 │
├──────────────────────┬──────────────────────────────────────┤
│ CONVERSATION         │ TICK INSPECTOR                       │
│                      │ Phase: Deliberation [████░] 72%      │
│ You: Add JWT...      │ Surprises: 2 (L2: 0.4, L3: 0.6)    │
│                      │ WM slots: 8/12 used                  │
│ KC: Adding...        │ LLM queries: 3/10 budget             │
│                      ├──────────────────────────────────────┤
│                      │ AFFECT                               │
│                      │ Unc: ██░░░ 0.3  Cur: ████░ 0.7      │
│                      │ Fru: █░░░░ 0.1  Fat: ██░░░ 0.3      │
│                      │ Nov: ███░░ 0.5  Rew: ████░ 0.8      │
│                      │ Valence: +0.6  Arousal: 0.5          │
│                      │ Mode: FLOW                           │
│                      ├──────────────────────────────────────┤
│                      │ MEMORY                               │
│                      │ WM: [auth_patterns] [jwt_spec]       │
│                      │     [user_request] [cargo_toml]      │
│                      │ Competing: [old_auth] [session_mgmt] │
│                      ├──────────────────────────────────────┤
│                      │ DAG                                  │
│                      │ add_dep ──→ write_jwt ──→ wire_router│
│                      │   [▶]         [○]          [○]       │
├──────────────────────┴──────────────────────────────────────┤
│ ◀◀  ◀  ▶  ▶▶ │ Tick 45231/45231 │ 1x │ Filter: all       │
└─────────────────────────────────────────────────────────────┘
```

**Additional regions:**
- **Tick inspector**: Current phase, timing, resource usage
- **Affect display**: Full 6D vector with bars, valence/arousal, mode
- **Memory view**: WM contents, competing memories, activation scores
- **DAG viewer**: Execution graph with progress indicators
- **Replay bar**: Scrub through recent history

---

## Event Handling

### Input Processing

```rust
enum AppCommand {
    // Mode switching
    SwitchMode(VisibilityMode),
    
    // Conversation
    SubmitMessage(String),
    
    // Approval
    ApproveAction,
    RejectAction,
    DeferAction,
    
    // Navigation
    CycleFocus,
    ScrollUp,
    ScrollDown,
    
    // Cognitive control
    PauseCognition,
    ResumeCognition,
    RollbackLast,
    
    // Replay
    EnterReplay,
    ExitReplay,
    ReplayStep(i64),  // +1 forward, -1 backward
    ReplaySpeed(f32),
    
    // System
    CommandPalette,
    Quit,
}
```

### Key Binding Resolution

Keys are resolved in priority order:
1. Modal dialogs (approval, command palette) capture all input
2. Mode-specific bindings (replay controls only in Paranoia)
3. Global bindings (mode switch, quit, pause)
4. Text input (when conversation pane is focused)

### Terminal Event Loop Integration

The TUI event loop is integrated with the cognitive tick loop via tokio:

```rust
// Main loop structure
loop {
    tokio::select! {
        _ = tick_interval.tick() => {
            // Run cognitive tick
            kernel.tick().await;
            // Render at tick rate
            tui.render_tick(tick_count, &state).await;
        }
        event = event_stream.next() => {
            // Handle terminal event immediately (responsive input)
            if let Some(Ok(event)) = event {
                tui.handle_event(event, &mut state);
                // Re-render for immediate feedback
                tui.render_tick(tick_count, &state).await;
            }
        }
    }
}
```

---

## Approval Flow

### Approval Dialog Lifecycle

```
1. Action reaches approval gate
2. TUI renders approval dialog (modal overlay)
3. Cognitive loop continues (other actions can proceed)
4. User responds:
   - Approve → action executes, dialog dismissed
   - Reject → action cancelled, goal notified
   - Defer → action queued, dialog dismissed, re-surfaces later
5. If no response in 60s → auto-defer (never auto-approve)
```

### Approval Context

Each approval dialog shows:
- **What**: The specific action to be performed
- **Why**: Which goal triggered this, what prediction error led here
- **Risk**: Category (destructive, structural, external, persistent, autonomous)
- **Simulation**: What the world simulator predicts will happen
- **Alternatives**: Other actions the system considered (if available)

### Batch Approval

When multiple similar actions are pending (e.g., "add 5 dependencies"):

```
┌─────────────────────────────────────────────────┐
│  BATCH APPROVAL (5 actions)                     │
│                                                 │
│  Add dependencies to Cargo.toml:                │
│    • jsonwebtoken = "9.3"                       │
│    • axum = "0.7"                               │
│    • tower-http = "0.5"                         │
│    • serde_json = "1.0"                         │
│    • tokio = { version = "1", features = [...]} │
│                                                 │
│  [Space] Approve all  [Tab] Review each         │
│  [Esc] Reject all                               │
└─────────────────────────────────────────────────┘
```

---

## Replay Viewer

### Entering Replay Mode

From Paranoia mode, `Ctrl+R` enters replay mode:
- Cognitive loop pauses (or continues in background, replay is read-only)
- Replay bar becomes active
- User can scrub through tick history
- All panels show historical state at selected tick

### Replay Controls

| Key | Action |
|-----|--------|
| `←` / `→` | Step one tick backward/forward |
| `Shift+←` / `Shift+→` | Jump 10 ticks |
| `Home` / `End` | Jump to start/end of buffer |
| `+` / `-` | Increase/decrease playback speed |
| `Space` | Play/pause continuous playback |
| `f` | Filter by subsystem |
| `Ctrl+R` | Exit replay mode |

### Replay Rendering

During replay, all panels render from the historical state:
- Affect shows values at that tick
- Memory shows what was in WM at that tick
- Goals show the hierarchy at that tick
- Agents show who was bidding/executing at that tick

A "time cursor" indicator shows the current replay position relative to live.

---

## Visual Language

### Color Semantics

| Color | Meaning |
|-------|---------|
| Green | Positive (success, approval, healthy) |
| Amber/Yellow | Neutral or warning (pending, moderate) |
| Red | Negative (error, rejection, critical) |
| Blue | Informational (system messages, metadata) |
| Cyan | Active/highlighted (current focus, selected) |
| Dim/Gray | Inactive, historical, low priority |

### Status Icons

| Icon | Meaning |
|------|---------|
| ◉ | Active (goal in progress, agent executing) |
| ○ | Pending (queued, waiting) |
| ✓ | Complete (success) |
| ✗ | Failed/abandoned |
| ▶ | Currently executing |
| ▷ | Ready but waiting |
| ● | Valence orb (colored by affect) |
| ⚠ | Warning (needs attention) |

### Confidence Bars

Thin inline bars showing confidence/progress:
```
[████████░░] 0.8    (high confidence)
[███░░░░░░░] 0.3    (low confidence)
[██████████] 1.0    (certain)
```

### Surprise Indicators

When prediction errors fire, brief flash indicators appear in the relevant panel:
- Small spark character (`⚡`) next to the surprised subsystem
- Fades after 3 render frames
- Color intensity proportional to surprise magnitude

---

## Responsive Layout

### Terminal Size Adaptation

The TUI adapts to terminal dimensions:

| Width | Behavior |
|-------|----------|
| < 80 cols | Single column, panels stack vertically |
| 80-120 cols | Two columns (conversation + side panel) |
| > 120 cols | Full layout with all panels visible |

| Height | Behavior |
|--------|----------|
| < 24 rows | Compact mode (status bar only, no panels) |
| 24-40 rows | Standard layout |
| > 40 rows | Extended panels with more detail |

### Minimum Viable Display

At absolute minimum (80×24), Focus mode shows:
- 1 line: title bar
- 20 lines: conversation
- 1 line: approval (if active, overlays conversation)
- 1 line: status bar

---

## Open Questions / Design Decisions

1. **Mouse support**: Should the TUI support mouse clicks (for approval buttons, panel selection)? Current plan: yes via crossterm mouse capture, but keyboard-first design.

2. **Unicode vs ASCII**: Should we require Unicode support or provide ASCII fallback? Current plan: Unicode by default (modern terminals), ASCII fallback for minimal environments.

3. **Color depth**: 256-color vs true color? Current plan: 256-color for broad compatibility, with true-color enhancement if detected.

4. **Notification when backgrounded**: If the terminal is not focused, should KC notify via system notification for approval requests? Deferred — terminal apps can't easily detect focus state.

5. **Scrollback buffer**: How much conversation history to keep in the scrollback? Current plan: 1000 messages, with older messages available via search.

6. **Split pane resizing**: Should users be able to resize panels? Current plan: fixed proportions based on mode. Resizing adds complexity for minimal benefit.

---

## Research References

- **ratatui documentation** — TUI framework patterns and best practices
- **crossterm documentation** — Terminal event handling, raw mode
- **Vim/Neovim TUI patterns** — Modal interface design
- **htop/btop** — System monitoring TUI design
- **Relevant crates**: `ratatui` (rendering), `crossterm` (terminal), `tui-textarea` (text input), `unicode-width` (character width)

---

## Interaction with Other Subsystems

- **Cognitive Kernel**: TUI renders at the end of each tick. It reads state but never modifies cognitive state directly.
- **Approval System**: TUI is the approval interface. Approval dialogs are rendered as modal overlays.
- **Replay System**: Paranoia mode provides the replay viewer. Replay state is read-only.
- **Affective Economy**: Valence orb color and affect bars are derived from the affect vector.
- **Goal Market**: Goal panel renders the active goal hierarchy from the market's state.
- **Agent Society**: Agent activity panel shows current bids and executions.
- **Hardware Scaling**: On Minimal tier, render budget is reduced (skip expensive widgets, reduce refresh rate).
