# Affective Economy — Deep Dive

The affective economy is a 6-dimensional dynamical system that controls cognitive resource allocation. Affect is not decoration or user-facing emotion — it is the mechanism by which the system decides how much to think, what to attend to, and when to rest.

---

## Summary

Six affective dimensions (uncertainty, curiosity, frustration, fatigue, novelty drive, reward expectation) form a continuous dynamical system that shapes every cognitive decision. Valence and arousal are computed summary statistics. The cognitive budget — how many tokens per tick, how deep to plan, how many agents to run — is derived directly from the affective state.

---

## Temporal Dynamics Equations

### The Dynamical System

Each dimension evolves according to coupled differential equations (discretized per tick):

```
d(uncertainty)/dt = surprise_rate * 0.3 - resolution_rate * 0.5 - decay_uncertainty
d(curiosity)/dt = novelty_signal * 0.2 + uncertainty * 0.1 - satisfaction_signal * 0.3 - decay_curiosity
d(frustration)/dt = failure_rate * 0.4 + repeated_error * 0.3 - success_signal * 0.5 - decay_frustration
d(fatigue)/dt = cognitive_load * 0.1 + tick_overrun * 0.2 - rest_signal * 0.3 - decay_fatigue
d(novelty_drive)/dt = habituation_signal * 0.2 + curiosity * 0.1 - novelty_satisfaction * 0.4 - decay_novelty
d(reward_expectation)/dt = reward_signal * 0.3 + progress_signal * 0.2 - disappointment * 0.4 - decay_reward
```

### Decay Constants (Per Tick at 10Hz)

| Dimension | Decay Rate | Half-Life | Rationale |
|-----------|-----------|-----------|-----------|
| Uncertainty | 0.0005 | ~1400 ticks (2.3 min) | Resolves relatively quickly with information |
| Curiosity | 0.001 | ~700 ticks (70s) | Fades if not fed, but slowly |
| Frustration | 0.00003 | ~23,000 ticks (38 min) | Persistent — takes real success to reduce |
| Fatigue | 0.0001 | ~7,000 ticks (12 min) | Recovers during consolidation/idle |
| Novelty Drive | 0.0008 | ~870 ticks (87s) | Satisfied by novel input, rebuilds during routine |
| Reward Expectation | 0.0003 | ~2,300 ticks (3.8 min) | Decays toward neutral without reinforcement |

### Coupling Between Dimensions

Dimensions are not independent — they influence each other:

```
frustration += uncertainty * 0.05 * dt  // Uncertainty breeds frustration over time
curiosity -= frustration * 0.1 * dt     // Frustration suppresses curiosity
fatigue += frustration * 0.02 * dt      // Sustained frustration is exhausting
novelty_drive += fatigue * 0.03 * dt    // Fatigue makes routine feel stale
reward_expectation -= frustration * 0.05 * dt  // Frustration lowers expectations
```

These couplings create emergent dynamics:
- **Frustration spiral**: failure → frustration → suppressed curiosity → less exploration → more failure
- **Recovery cycle**: rest → reduced fatigue → increased curiosity → exploration → novelty satisfaction
- **Burnout pattern**: sustained high load → fatigue → frustration coupling → reward collapse

---

## How Affect Drives the Cognitive Budget

### Budget Computation (Per Tick)

The cognitive budget is recomputed every tick from the current affective state:

```
tokens_per_tick = base_tokens * (1 + curiosity * 0.5) * (1 - fatigue * 0.4)
llm_queries_per_minute = base_rate * (1 - fatigue) * (1 + reward_expectation * 0.3)
planning_depth = if frustration > 0.7 { 1 } else { base_depth * (1 - frustration * 0.5) }
memory_retrieval_depth = if novelty_drive > 0.6 { max_tiers } else { default_tiers }
self_modification_risk = reward_expectation * (1 - uncertainty) * (1 - frustration * 0.5)
```

### Budget Allocation Table

| Affect State | Tokens | LLM Rate | Planning | Memory | Self-Mod Risk |
|-------------|--------|----------|----------|--------|---------------|
| Curious + Low Fatigue | High (1500) | High (10/min) | Deep (5) | All tiers | Moderate |
| Frustrated + High Uncertainty | Low (600) | Low (3/min) | Shallow (1) | WM only | Zero |
| Fatigued | Minimal (400) | Minimal (2/min) | None (0) | None | Zero |
| High Reward Expectation | High (1200) | High (8/min) | Medium (3) | Semantic + Procedural | High |
| Neutral (all ~0.5) | Base (1000) | Base (5/min) | Base (3) | WM + EB + SN | Low |

### Affect-Driven Behavioral Modes

The system naturally enters different "modes" based on affective state:

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Exploration** | curiosity > 0.7, uncertainty > 0.5 | Broad search, many LLM queries, deep memory retrieval |
| **Exploitation** | reward_expectation > 0.7, uncertainty < 0.3 | Focused execution, minimal exploration, fast actions |
| **Recovery** | fatigue > 0.7 | Consolidation, reduced tick rate, memory maintenance |
| **Panic** | frustration > 0.8, uncertainty > 0.8 | Minimal planning, only high-confidence actions, seek help |
| **Flow** | curiosity ~0.5, frustration < 0.2, fatigue < 0.3 | Balanced, productive, sustained output |

---

## Precision Weighting Per Modality

### How Affect Modulates Perception

Each sensory modality has a precision weight that determines how much attention it gets. Affect modulates these weights:

```
precision[user_message] = base * (1 + social_rapport_value * 0.3)
precision[file_change] = base * (1 + reward_expectation * 0.2)  // Expecting build results
precision[process_output] = base * (1 + frustration * 0.4)  // Hyper-focus on errors when frustrated
precision[timer_tick] = base * (1 - curiosity * 0.2)  // Ignore routine when curious about something
precision[self_state] = base * (1 + uncertainty * 0.3)  // Monitor self more when uncertain
precision[error_signal] = base * (1 + frustration * 0.5 + uncertainty * 0.3)  // Errors always salient
```

### Precision Floor and Ceiling

- **Floor**: 0.1 — no modality is ever completely ignored (safety requirement)
- **Ceiling**: 2.0 — no modality dominates so completely that others are suppressed
- **User message floor**: 0.5 — user input is always at least moderately attended to (social contract)

### Adaptive Precision Learning

Over time, the system learns which modalities are informative in which contexts:

```
if modality_X predicted well → decrease precision (it's predictable, less attention needed)
if modality_X surprised often → increase precision (it's informative, attend more)
```

This creates a natural attention allocation: attend to what's surprising, ignore what's predictable.

---

## Valence and Arousal Computation

### Valence (Hedonic Tone)

Valence represents overall positive/negative affect. Computed as a weighted sum:

```
valence = (
    reward_expectation * 0.4 +
    curiosity * 0.3 -
    frustration * 0.4 -
    fatigue * 0.2 +
    (1 - uncertainty) * 0.2
).clamp(-1.0, 1.0)
```

**Interpretation**:
- Valence > 0.5: System is "happy" — things are going well, expectations are being met
- Valence ~ 0: Neutral — routine operation
- Valence < -0.5: System is "distressed" — failures, confusion, exhaustion

### Arousal (Activation Level)

Arousal represents how "activated" the system is:

```
arousal = (
    curiosity * 0.3 +
    frustration * 0.4 +
    novelty_drive * 0.3
).clamp(0.0, 1.0)
```

**Interpretation**:
- Arousal > 0.7: High activation — lots of processing, fast responses, broad attention
- Arousal ~ 0.4: Moderate — normal operation
- Arousal < 0.2: Low activation — idle, consolidating, minimal processing

### Valence-Arousal Quadrants

| Quadrant | Valence | Arousal | System State |
|----------|---------|---------|-------------|
| High V, High A | Positive | High | Flow state, productive exploration |
| High V, Low A | Positive | Low | Satisfied rest, gentle consolidation |
| Low V, High A | Negative | High | Panic, frustration-driven hyperactivity |
| Low V, Low A | Negative | Low | Burnout, disengagement, needs recovery |

---

## Interaction with Goal Market

### Affect Shapes Goal Scoring

The goal market's bid resolution is directly modulated by affect:

```
effective_score(bid) = match affect_state {
    high_curiosity => bid.epistemic_value * 2.0 + bid.pragmatic_value,
    high_frustration => if bid.confidence > 0.9 { bid.pragmatic_value * 3.0 } else { 0.0 },
    high_fatigue => if bid.expected_cost < 0.2 { bid.pragmatic_value } else { 0.0 },
    high_novelty_drive => bid.novelty_score * 2.0 + bid.epistemic_value,
    neutral => bid.expected_value / (bid.expected_cost + 0.1),
}
```

### Goal Generation Thresholds

Affect determines how easily new goals are generated from surprise:

```
goal_generation_threshold = base_threshold * (1 + fatigue * 0.5) * (1 - curiosity * 0.3)
```

- High curiosity → lower threshold → more goals generated from smaller surprises
- High fatigue → higher threshold → only very surprising events generate goals

### Goal Abandonment

Affect drives goal abandonment decisions:

```
abandon_goal if:
    goal.age > max_age AND frustration > 0.6  // "I've been stuck too long"
    OR goal.expected_value < 0.1 AND fatigue > 0.5  // "Not worth the effort"
    OR goal.confidence < 0.2 AND uncertainty > 0.7  // "I don't even know how to do this"
```

---

## Fatigue-Triggered Consolidation

### The Fatigue → Sleep Pipeline

```
fatigue accumulates from:
    - Sustained high cognitive load (many tokens per tick)
    - Tick budget overruns (processing takes longer than allocated)
    - LLM query failures (wasted effort)
    - Repeated errors without resolution
    - Long sessions without idle periods

when fatigue > 0.6 AND episodic_buffer.len() > 100:
    → MCC schedules consolidation
    → Tick rate drops to 1Hz
    → LLM gateway closes
    → Dream engine activates
    → Fatigue decays at 3x normal rate during consolidation
    → Consolidation ends when fatigue < 0.3 OR user input arrives
```

### Consolidation Quality vs Fatigue Level

| Fatigue Level | Consolidation Depth | Duration | Quality |
|--------------|--------------------|---------|---------| 
| 0.6 - 0.7 | Light (pattern extraction only) | ~2 min | Moderate |
| 0.7 - 0.8 | Medium (patterns + counterfactuals) | ~5 min | Good |
| 0.8 - 0.9 | Deep (full dream cycle) | ~10 min | Excellent |
| > 0.9 | Emergency (forced, immediate) | Until < 0.5 | Variable |

### Post-Consolidation Affect Reset

After consolidation completes:
```
fatigue *= 0.3          // Major reduction
curiosity += 0.2       // Fresh perspective
frustration *= 0.7     // Partial relief
novelty_drive += 0.15  // Ready for new things
uncertainty *= 0.8     // Consolidation resolved some unknowns
```

---

## Open Questions / Design Decisions

1. **Affect initialization**: What should the initial affective state be on first boot? Current plan: all dimensions at 0.3 (slightly below neutral) with high curiosity (0.7) to encourage initial exploration.

2. **User-visible affect**: Should the user see the raw affect vector or a simplified representation? Current plan: simplified (valence orb + arousal indicator) with detailed view available in Settings.

3. **Affect manipulation risk**: Could a user intentionally manipulate the system's affect to get different behavior? (e.g., repeatedly failing to increase frustration and trigger fast-mode). This is acceptable — the user is the principal. But should there be a "reset affect" button?

4. **Cross-session affect persistence**: Should affect state persist across application restarts? Current plan: yes, stored in cognitive_state. The system "wakes up" in the same mood it "went to sleep" in, with fatigue partially recovered.

5. **Affect dimension count**: Six dimensions were chosen to balance expressiveness with computational cost. Should there be more? (e.g., "boredom" as distinct from "fatigue + low novelty"?) Current decision: no — emergent combinations of the six cover most states.

6. **Coupling strength tuning**: The coupling constants between dimensions (e.g., frustration → curiosity suppression at 0.1) are currently hand-tuned. Should these be learned? Possibly via meta-learning (L5 homunculus), but adds complexity.

---

## Research References

- **Russell, J.A. (1980)**. "A circumplex model of affect" — Valence-arousal framework
- **Damasio, A. (1994)**. "Descartes' Error" — Emotion as essential to rational decision-making
- **Panksepp, J. (1998)**. "Affective Neuroscience" — Basic emotional systems
- **Kahneman, D. (2011)**. "Thinking, Fast and Slow" — Cognitive resource allocation under affect
- **Dolan, R.J. (2002)**. "Emotion, Cognition, and Behavior" — How affect modulates attention and memory
- **Bach & Dayan (2017)**. "Algorithms for survival: a comparative perspective on emotions" — Computational models of affect
- **Relevant crates**: `nalgebra` (vector math for dynamics), `serde` (state serialization)

---

## Edge Cases and Failure Modes

1. **Affective stuck state**: A dimension gets locked at an extreme (e.g., frustration = 1.0) due to continuous failure. The immune system's AffectRebalancer handles this by gradually pulling toward neutral.

2. **Oscillation**: Rapid cycling between high curiosity and high frustration (explore → fail → frustrated → stop exploring → bored → curious → explore → fail). Mitigation: hysteresis in mode transitions (require sustained state before switching).

3. **Fatigue death spiral**: If fatigue is high but consolidation keeps getting interrupted (user keeps sending messages), fatigue never recovers. Mitigation: after 3 interrupted consolidations, the system communicates to the user that it needs a break.

4. **Reward expectation inflation**: If the system consistently succeeds, reward expectation approaches 1.0 and any failure becomes catastrophically surprising. Mitigation: reward expectation has a ceiling of 0.9 and natural decay.

5. **Zero-arousal trap**: If all activating dimensions (curiosity, frustration, novelty) are low, the system becomes completely passive. Mitigation: minimum arousal floor of 0.1 ensures at least basic responsiveness.

6. **Affect-budget mismatch**: On Minimal tier, the budget is already constrained by hardware. Affect-driven budget reduction could make the system unusable. Mitigation: hardware-tier minimum budget that affect cannot reduce below.

---

## Interaction with Other Subsystems

- **Predictive Processing**: Cumulative surprise feeds into uncertainty and curiosity. Precision weighting is directly modulated by affect.
- **Memory Palace**: Emotional salience (derived from valence + arousal at encoding time) is a factor in memory activation competition. High-affect moments are remembered better.
- **Homunculus**: The self-model predicts affect dynamics. Self-surprise about affect ("I expected to be frustrated but I'm not") triggers introspection.
- **Goal Market**: Affect shapes bid scoring, goal generation thresholds, and abandonment criteria (detailed above).
- **Agent Society**: Agent bid confidence is modulated by affect. In high-frustration states, only high-confidence agents get resources.
- **Self-Modification**: Self-modification risk tolerance is directly computed from affect (high reward expectation + low uncertainty = willing to take risks).
- **Cognitive Homeostasis**: The immune system monitors affect for stuck states and intervenes when dimensions are pathologically extreme.
- **Hardware Scaling**: When thermal throttling or memory pressure occurs, fatigue is artificially increased to trigger natural resource reduction.
