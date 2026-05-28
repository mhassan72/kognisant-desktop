# Homunculus (Self-Model) — Deep Dive

The Homunculus is a running generative model of the system itself. It predicts what the system will do, compares predictions to actual behavior, and uses self-surprise to drive meta-learning. It is the mechanism by which the system "knows itself."

---

## Summary

The Homunculus maintains three parallel generative models: a self-model (what am I?), an action model (what will I do?), and a perception model (what do I perceive?). Self-surprise — the gap between predicted and actual self-behavior — drives introspection, self-modification decisions, and meta-cognitive adjustments.

---

## Self-Prediction Mechanisms

### The Three Internal Models

Each model is a lightweight predictor (not an LLM) that runs every tick:

**1. Self-Model** (`what am I?`)
- Predicts: next-tick cognitive state (WM contents, affect vector, active goals count, tick duration)
- Input: current state + last 10 state deltas
- Architecture: Linear projection with residual connection
- Output dimension: 64 (compressed state representation)

**2. Action Model** (`what will I do?`)
- Predicts: which action type the system will select this tick
- Input: current surprise vector + affect state + goal priorities
- Architecture: Small MLP (64 → 32 → num_action_types)
- Output: probability distribution over action types (SendMessage, ExecuteTool, LlmQuery, SelfModify, Sleep, Explore, Null)

**3. Perception Model** (`what will I perceive?`)
- Predicts: which sensory channels will fire next tick and approximate content
- Input: recent sensory history (last 20 ticks) + current context
- Architecture: Autoregressive model over sensory channels
- Output: per-channel probability of activation + predicted embedding

### Prediction Cycle (Per Tick)

```
1. Generate predictions from all three models (using tick N state)
2. Store predictions tagged with tick N+1
3. At tick N+1: compare stored predictions to actual observations
4. Compute self-surprise for each model
5. Update models via online gradient descent
6. If self-surprise exceeds threshold → trigger introspection
```

---

## Generative Self-Model Training

### Online Learning

The self-model trains continuously via prediction error minimization:

```
loss = MSE(predicted_state[t+1], actual_state[t+1])
gradient = ∂loss/∂weights
weights -= learning_rate * gradient
```

Learning rate schedule:
- First 1000 ticks: `lr = 0.01` (fast adaptation, building initial self-model)
- Ticks 1000-10000: `lr = 0.001` (stabilizing)
- After 10000: `lr = 0.0001` (fine-tuning, slow drift tracking)

### Consolidation-Phase Retraining

During dream/consolidation windows, the self-model is retrained on buffered state history:

1. Sample 500 state transitions from recent history
2. Batch train for 10 epochs (offline, no tick pressure)
3. Validate on held-out 100 transitions
4. If validation loss improved → accept new weights
5. If validation loss worsened → reject, keep old weights (prevents catastrophic forgetting)

### What the Self-Model Learns

Over time, the self-model captures:
- Typical tick duration patterns (faster when idle, slower under load)
- Affect dynamics (how curiosity responds to novelty, how frustration builds)
- Goal generation patterns (what kinds of surprise trigger what kinds of goals)
- Action preferences (tendency to use certain tools, LLM query frequency)
- Capacity limits (when WM overflows, when consolidation is needed)

---

## Introspection Injection into Working Memory

### When Introspection Fires

Introspection is not free — it consumes WM slots. The MCC controls introspection depth (0.0 to 1.0):

| Introspection Depth | Trigger | WM Slots Used | Content |
|---------------------|---------|---------------|---------|
| 0.0 - 0.2 | Normal operation | 0 | No self-awareness in WM |
| 0.2 - 0.5 | Moderate self-surprise | 1 | Brief self-status summary |
| 0.5 - 0.8 | High self-surprise or user asks "why" | 2-3 | Detailed self-report |
| 0.8 - 1.0 | Critical self-surprise or pathology detected | 3-5 | Full diagnostic dump |

### Introspection Report Structure

When introspection fires, it generates a `SelfAwarenessReport` that competes for WM slots:

```
SelfAwarenessReport {
    current_goals: top 3 active goals with priorities
    affect_snapshot: current 6D affect + valence + arousal
    confidence_summary: per-domain confidence scores
    known_limitations: top 5 unresolved unknowns
    recent_surprises: last 3 salient surprises
    prediction_accuracy_1min: rolling accuracy over 600 ticks
    action_model_accuracy: how well it predicted its own actions
    resource_utilization: tick budget usage, LLM queries remaining
}
```

### How Introspection Affects Behavior

When self-awareness is in WM, it influences:
- **LLM prompts**: Self-knowledge is included in system prompts ("I am currently uncertain about X, my confidence in Y is low")
- **Action selection**: The system can reason about its own state ("I'm fatigued, I should consolidate rather than take on new work")
- **User communication**: Can explain its own reasoning ("I chose this approach because my confidence in alternative A was only 0.3")
- **Goal generation**: Self-limitations become goals ("I keep failing at X, I should learn a better strategy")

---

## Self-Surprise Computation

### Formula

```
self_surprise = Σ_model (precision_model * ||predicted - actual||²)
```

Where the sum is over the three internal models, weighted by their respective precisions.

### Precision Per Model

Each model has its own precision (confidence in its predictions):

```
precision_self_model = 1 / (running_variance_of_self_prediction_errors + ε)
precision_action_model = 1 / (running_variance_of_action_prediction_errors + ε)
precision_perception_model = 1 / (running_variance_of_perception_prediction_errors + ε)
```

High precision + high error = very surprising (something is really wrong with self-understanding).
Low precision + high error = expected uncertainty (the system knows it doesn't know itself well yet).

### Self-Surprise Thresholds

| Self-Surprise Level | Interpretation | Response |
|--------------------|---------------|----------|
| < 0.2 | Normal self-prediction | No action |
| 0.2 - 0.5 | Mild self-surprise | Log to known_unknowns, increase introspection slightly |
| 0.5 - 0.8 | Significant self-surprise | Trigger introspection injection, update self-model aggressively |
| > 0.8 | Critical self-surprise | Pause autonomous actions, maximum introspection, consider self-modification |

---

## L0-L5 Implementation Details

### L0: Proprioception

**What it senses**: Raw system metrics
- Process RSS (memory usage)
- Tick duration (ms)
- Queue depths (goal queue, LLM queue, action queue)
- CPU temperature
- Active agent count
- SQLite page cache hit rate

**Implementation**: Direct system calls via `sys-info` crate + internal counters. No model needed — these are direct observations.

**Update frequency**: Every tick (cheap to compute).

### L1: Introspection

**What it knows**: Current cognitive contents
- Working memory slot contents (what's currently "in mind")
- Active goals and their priorities
- Current affect vector
- Which agents are active and what they're bidding on
- Recent prediction errors (what surprised the system)

**Implementation**: Read-only access to shared state. The homunculus reads but does not modify these structures.

**Update frequency**: Every tick (just pointer reads, no computation).

### L2: Self-Prediction

**What it predicts**: Own future behavior
- "I will query the LLM next tick" (action model)
- "My frustration will increase if this build fails again" (affect model)
- "I will generate a debugging goal" (goal model)

**Implementation**: The three generative models described above. This is where the computational cost lives.

**Update frequency**: Every tick (forward pass through models).

### L3: Self-Evaluation

**What it judges**: Own performance quality
- Prediction accuracy over rolling windows (1min, 5min, 30min)
- Task completion rate (goals resolved / goals generated)
- User satisfaction signals (explicit feedback, implicit engagement)
- Resource efficiency (tokens per successful task)

**Implementation**: Statistical accumulators with exponential moving averages. Compared against historical baselines.

**Update frequency**: Every 100 ticks (aggregation is expensive).

### L4: Self-Modification

**What it can do**: Change own source code
- Identify performance bottlenecks from L3 data
- Generate improvement hypotheses
- Propose code patches via the SelfModificationEngine
- Evaluate patches in shadow runtime

**Implementation**: Interface to the self-modification subsystem. The homunculus doesn't modify directly — it proposes modifications that go through the safety gate.

**Update frequency**: On-demand (triggered by sustained L3 degradation).

### L5: Meta-Learning

**What it learns**: How to learn better
- Which learning rates work best for which subsystems
- When to consolidate vs when to keep accumulating
- Which agent strategies produce better outcomes
- How to allocate cognitive budget more effectively

**Implementation**: Second-order optimization — the homunculus tracks the *rate of improvement* of its own models and adjusts hyperparameters accordingly.

**Update frequency**: Every 10,000 ticks (~17 minutes). Meta-learning is slow and deliberate.

---

## Meta-Learning Loops

### Learning Rate Adaptation

The homunculus monitors prediction accuracy trends:

```
if accuracy_trend > 0 (improving):
    # Current learning rate is working, keep it
    pass
elif accuracy_trend < -0.01 (degrading):
    # Learning rate may be too high (oscillating) or too low (not adapting)
    if recent_variance > historical_variance:
        learning_rate *= 0.5  # Too high, reduce
    else:
        learning_rate *= 1.5  # Too low, increase
```

### Strategy Selection Meta-Learning

The homunculus tracks which cognitive strategies work in which contexts:

```
strategy_outcomes = {
    "deep_planning": { "complex_tasks": 0.8, "simple_tasks": 0.3 },
    "fast_execution": { "complex_tasks": 0.2, "simple_tasks": 0.9 },
    "research_first": { "novel_domains": 0.7, "familiar_domains": 0.4 },
}
```

Over time, this becomes a meta-policy: "In context X, prefer strategy Y." This meta-policy is itself updated by outcomes.

### Consolidation Timing Meta-Learning

The homunculus learns when consolidation is most effective:

```
consolidation_value = improvement_after_consolidation / time_spent_consolidating
```

If consolidation consistently produces high value after long idle periods but low value after short ones, the system learns to wait longer before consolidating.

---

## Open Questions / Design Decisions

1. **Self-model architecture**: Linear projection vs small MLP vs transformer? Linear is fastest but may miss nonlinear self-dynamics. Current plan: start linear, upgrade to MLP if self-prediction accuracy plateaus below 0.6.

2. **Introspection cost**: Each WM slot used for introspection is one less slot for task-relevant information. How to balance? Current plan: introspection never exceeds 20% of WM capacity.

3. **Self-deception risk**: The self-model could learn to predict its own failures and then *avoid situations where it would fail* rather than *improving*. This is a form of self-deception. Mitigation: the curiosity agent forces exploration regardless of self-model predictions.

4. **Recursive self-modeling**: Should the homunculus model its own modeling process? (L6: meta-meta-cognition?) Current decision: No. Two levels of recursion (L5 meta-learning) is sufficient. Deeper recursion has diminishing returns and risks infinite regress.

5. **Self-model persistence**: Should the trained self-model weights persist across sessions? Yes — they're stored in `cognitive_state/` and synced. A fresh self-model would need to re-learn everything about the system's behavior.

6. **Multi-project self-model**: Is the self-model project-specific or global? The system behaves differently in different project contexts. Current plan: one global self-model with project-specific context vectors.

---

## Research References

- **Friston, K. (2011)**. "What is optimal about motor control?" — Active inference and self-prediction
- **Seth, A.K. (2013)**. "Interoceptive inference, emotion, and the embodied self" — Predictive self-models
- **Metzinger, T. (2003)**. "Being No One" — Phenomenal self-model theory
- **Schmidhuber, J. (2010)**. "Formal Theory of Creativity, Fun, and Intrinsic Motivation" — Compression progress as curiosity
- **Cleeremans, A. (2011)**. "The Radical Plasticity Thesis" — Self-models as learned representations
- **Relevant crates**: `burn` or `candle` (small neural nets), `ndarray` (tensor ops), `serde` (state serialization)

---

## Edge Cases and Failure Modes

1. **Self-model divergence**: If the system changes rapidly (e.g., after a self-modification), the self-model becomes stale. Mitigation: spike learning rate after any self-modification event.

2. **Introspection flooding**: If self-surprise stays high for extended periods, introspection consumes all WM. Mitigation: hard cap at 5 WM slots for introspection, regardless of self-surprise level.

3. **Action model gaming**: If the action model becomes too accurate, the system might become predictable (always doing what it predicts). This isn't necessarily bad, but it reduces exploration. Mitigation: curiosity agent adds noise to action selection.

4. **Cold start self-model**: On first boot, the self-model has no training data. It predicts random states. Mitigation: first 1000 ticks run with introspection disabled (no point introspecting on random predictions).

5. **Self-model as attack surface**: If an adversary could manipulate the self-model (e.g., by crafting inputs that cause specific self-predictions), they could influence the system's behavior. Mitigation: self-model inputs are internal state only, not directly controllable by external input.

---

## Interaction with Other Subsystems

- **Predictive Processing**: The homunculus IS a predictive processing system — just pointed inward. It uses the same precision-weighted prediction error framework.
- **Memory Palace**: Self-knowledge is stored in semantic memory (concepts about self). Known unknowns are episodic (time-stamped discoveries about self-limitations).
- **Affective Economy**: Self-surprise modulates affect — high self-surprise increases uncertainty and arousal. The homunculus reads affect state as input to its predictions.
- **Goal Market**: Self-improvement goals originate from L3 (self-evaluation) and L5 (meta-learning). These compete in the goal market like any other goal.
- **Self-Modification**: L4 capability. The homunculus identifies what to modify; the SelfModificationEngine handles how.
- **Cognitive Homeostasis**: The immune system monitors the homunculus itself — if self-prediction accuracy collapses, the PredictionCalibrator intervenes.
- **Agent Society**: The MetaAgent monitors other agents using homunculus-like self-prediction. The homunculus monitors the whole system including the MetaAgent.
