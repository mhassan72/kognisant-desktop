# Predictive Processing — Deep Dive

The predictive processing (PP) stack is the computational backbone of Kognisant's cognition. Every observation, every action, every internal state change flows through this hierarchy. It implements the Free Energy Principle as a practical engineering system.

---

## Summary

The PP stack generates top-down predictions at every layer, compares them to bottom-up observations, computes precision-weighted prediction errors, and propagates those errors to update beliefs or trigger actions. It is the mechanism by which the system "thinks."

---

## Free Energy Principle — Implementation Details

### Variational Free Energy in Practice

The formal definition:

```
F = E_q[log q(φ) - log p(o, φ)]
```

In implementation, this decomposes into two computable terms:

1. **Accuracy term**: How well do predictions match observations? (negative log-likelihood)
2. **Complexity term**: How far has the posterior drifted from the prior? (KL divergence)

Each layer maintains its own generative model `p_l(o_l | s_l)` where:
- `o_l` = observations at layer l (which are predictions from layer l-1)
- `s_l` = hidden states (beliefs) at layer l

### Practical Computation Per Tick

For each layer, per tick:

1. **Generate prediction**: `pred_l = f_l(s_l, context_l)` — a forward pass through the layer's generative model
2. **Receive observation**: `obs_l` — either raw sensory data (layer 0) or prediction error from layer below
3. **Compute error**: `e_l = obs_l - pred_l` (element-wise in embedding space)
4. **Weight by precision**: `weighted_e_l = π_l * e_l` where `π_l` is the precision (inverse variance)
5. **Decide propagation**: If `||weighted_e_l|| > threshold_l`, propagate upward; else, suppress (explain away)
6. **Update beliefs**: `s_l += learning_rate_l * weighted_e_l`

### Precision Weighting Math

Precision is not a scalar — it's a diagonal matrix (or vector) representing confidence per dimension of the prediction space.

```
π_l[i] = 1 / (σ²_l[i] + ε)
```

Where `σ²_l[i]` is the estimated variance of prediction errors on dimension `i` at layer `l`, computed as an exponential moving average:

```
σ²_l[i] ← (1 - α) * σ²_l[i] + α * e_l[i]²
```

With `α` typically 0.01 (slow adaptation) for stable layers and 0.1 (fast adaptation) for volatile layers.

**Precision modulation by affect**: The affective economy scales precision per modality:
- High curiosity → increases precision on novel channels (amplifies surprise from new things)
- High fatigue → decreases precision globally (reduces sensitivity, conserves resources)
- High frustration → increases precision on error channels (hyper-focus on what's failing)

---

## Layer-by-Layer PP Stack Design

### Layer 0: Raw Sensory

- **Input**: Raw bytes from sensory modalities (file events, IPC messages, timer ticks, process output)
- **Prediction**: "What bytes/tokens will arrive next on each channel?"
- **Model type**: Simple statistical model (n-gram for text, frequency for events)
- **Update speed**: Fast (α = 0.1) — adapts quickly to new input patterns
- **Typical surprise**: Unexpected file change, user message when idle predicted
- **Embedding dimension**: 64 (compact, fast)

### Layer 1: Syntactic

- **Input**: Prediction errors from Layer 0
- **Prediction**: "What structural patterns will these raw inputs form?"
- **Model type**: Pattern recognizer (regex-like for code, template matching for messages)
- **Update speed**: Medium (α = 0.05)
- **Typical surprise**: Unusual code structure, unexpected message format
- **Embedding dimension**: 128

### Layer 2: Semantic

- **Input**: Prediction errors from Layer 1
- **Prediction**: "What does this mean? What concepts are being referenced?"
- **Model type**: Embedding-based similarity (uses ONNX model or LLM embeddings)
- **Update speed**: Slow (α = 0.02) — semantic understanding changes gradually
- **Typical surprise**: Topic shift, new concept introduced, contradiction with known beliefs
- **Embedding dimension**: 384 (MiniLM) or 768 (Nomic)

### Layer 3: Pragmatic

- **Input**: Prediction errors from Layer 2
- **Prediction**: "What is the user trying to accomplish? What's the intent?"
- **Model type**: Goal inference model (maps semantic content to likely user goals)
- **Update speed**: Slow (α = 0.01)
- **Typical surprise**: User changes strategy, abandons current task, introduces new requirement
- **Embedding dimension**: 256

### Layer 4: Strategic

- **Input**: Prediction errors from Layer 3
- **Prediction**: "What is the long-term trajectory? What will happen over the next N interactions?"
- **Model type**: Sequence model (predicts goal sequences, project evolution)
- **Update speed**: Very slow (α = 0.005) — strategic understanding is stable
- **Typical surprise**: Project pivot, fundamental requirement change, user skill level reassessment
- **Embedding dimension**: 256

### Concrete Prediction Formats

Each layer produces predictions in a specific format, enabling precise error computation:

**Layer 0 (Raw)**: Predicts which sensory channels will fire next tick.
- Output: `Vec<(SensoryChannel, f64)>` — probability per channel
- Observation: which channels actually fired (binary vector)
- Error: channels that fired unexpectedly (false negatives) or didn't fire when expected (false positives)
- Metric: binary cross-entropy

**Layer 1 (Syntactic)**: Predicts structural patterns in active streams.
- For user input: next token probabilities (simple bigram/trigram model)
- For file events: expected file paths based on recent activity
- Output: `Vec<f32>` embedding of predicted pattern (128d)
- Observation: embedding of actual pattern (128d)
- Error: cosine distance between predicted and observed embeddings
- Metric: `1.0 - cosine_similarity(predicted, observed)`

**Layer 2 (Semantic)**: Predicts meaning/intent of incoming data.
- Uses embedding model (MiniLM 384d or Nomic 768d depending on tier)
- Output: 384d embedding of predicted semantic content
- Observation: 384d embedding of actual content
- Error: cosine distance in embedding space
- Metric: `1.0 - cosine_similarity(predicted, observed)` in 384d space

**Layer 3 (Pragmatic)**: Predicts user goal/intent.
- Output: probability distribution over active goals + "new goal" category
- Observation: which goal the user's action actually serves (determined post-hoc)
- Error: cross-entropy between predicted distribution and one-hot observed
- Metric: `H(observed, predicted) = -Σ observed_i * log(predicted_i)`

**Layer 4 (Strategic)**: Predicts project trajectory.
- Output: predicted next milestone/phase + confidence
- Observation: actual progress (milestone reached, phase transition, or no change)
- Error: deviation from predicted timeline
- Metric: `|predicted_milestone_tick - actual_milestone_tick| / horizon`

---

## Prediction Generation Algorithms

### Per-Layer Generative Model

Each layer uses a lightweight generative model (not an LLM — that would be too expensive at 10Hz):

**Layer 0-1**: Markov models with context
- Maintain transition probabilities for common patterns
- Context window: last 10 observations at that layer
- Prediction: weighted average of likely next states

**Layer 2-3**: Embedding-space linear predictors
- Maintain a linear projection `W_l` that maps current state to predicted next state
- `pred = W_l @ current_state + bias_l`
- Updated via online gradient descent on prediction errors
- Periodically re-trained during consolidation using episodic replay

**Layer 4**: Trajectory model
- Maintains a set of "trajectory templates" (common project evolution patterns)
- Prediction: weighted mixture of active trajectories
- Weights updated by how well each trajectory explains recent observations

### When to Invoke the LLM

The PP stack does NOT call the LLM every tick. LLM queries are expensive and reserved for:
- Layer 2+ surprise exceeding a high threshold (> 0.8 free energy)
- Explicit semantic disambiguation needed
- Goal inference failure (Layer 3 cannot resolve intent)
- Strategic prediction collapse (Layer 4 accuracy drops below 0.3)

The MCC gates LLM access. The PP stack can *request* an LLM query by emitting a high-priority surprise signal, but the MCC decides whether to grant it based on budget and timing.

---

## Error Propagation Algorithms

### Bottom-Up Propagation (Belief Update)

When prediction error is too large to explain away:

```
for layer in 0..num_layers {
    error = compute_error(layer)
    weighted_error = precision[layer] * error

    if norm(weighted_error) > propagation_threshold[layer] {
        // Error is significant — propagate up
        send_to_layer(layer + 1, weighted_error)
        // Also update this layer's beliefs
        beliefs[layer] += learning_rate[layer] * weighted_error
    } else {
        // Error is small — explain away (perceptual inference)
        // Adjust perception rather than beliefs
        perception[layer] += attenuation_rate * weighted_error
        // Stop propagation here
        break
    }
}
```

### Top-Down Propagation (Prediction Refinement)

Higher layers send predictions downward to constrain lower-layer interpretations:

```
for layer in (0..num_layers).rev() {
    context = get_context_from_above(layer + 1)
    prediction[layer] = generate_prediction(beliefs[layer], context)
    // Lower layers use this prediction as their "expected input"
}
```

### Lateral Propagation (Same-Layer Interaction)

Predictions at the same layer can influence each other:
- Semantic layer: spreading activation in the semantic network
- Pragmatic layer: goal compatibility checking
- Strategic layer: trajectory coherence enforcement

---

## Open Questions / Design Decisions

1. **Embedding model selection**: MiniLM-L6 (384d, fast, small) vs Nomic-embed (768d, better quality, larger). Should this be device-tier dependent? Likely yes — Minimal tier uses API-only embeddings, Standard uses MiniLM, Performance uses Nomic.

2. **Precision initialization**: How to set initial precision weights before the system has seen any data? Current plan: uniform precision (1.0) with fast adaptation (α = 0.1) for the first 1000 ticks, then switch to slow adaptation.

3. **Layer count on Minimal tier**: Only 2 layers (raw + semantic) on low-end devices. How to gracefully degrade? The semantic layer must absorb pragmatic and strategic functions — essentially a "compressed" stack.

4. **Prediction horizon**: How far ahead should each layer predict? Layer 0 predicts next tick, Layer 4 predicts next ~100 interactions. The intermediate layers need calibrated horizons.

5. **Catastrophic forgetting**: Online updates to layer weights can overwrite useful patterns. Should we use elastic weight consolidation (EWC) or simply rely on the consolidation/dream cycle to re-stabilize?

6. **Cross-modal binding**: When multiple sensory channels fire simultaneously, how are their predictions bound into a unified percept? Current plan: binding pool with temporal coincidence detection.

---

## Research References

- **Friston, K. (2010)**. "The free-energy principle: a unified brain theory?" — Foundational paper on FEP
- **Clark, A. (2013)**. "Whatever next? Predictive brains, situated agents, and the future of cognitive science" — PP as cognitive architecture
- **Rao & Ballard (1999)**. "Predictive coding in the visual cortex" — Original hierarchical predictive coding
- **Bogacz, R. (2017)**. "A tutorial on the free-energy framework for modelling perception and learning" — Practical implementation guide
- **Parr, T. & Friston, K. (2019)**. "Generalised free energy and active inference" — Expected free energy for action selection
- **Millidge, B. et al. (2021)**. "Predictive Coding Approximates Backprop Along Arbitrary Computation Graphs" — PP as learning algorithm
- **Relevant crates**: `ndarray` (tensor ops), `ort` (ONNX inference), `burn` (ML framework), `nalgebra` (linear algebra), `ratatui` (TUI rendering of prediction state in Paranoia mode)

---

## Edge Cases and Failure Modes

1. **Precision collapse**: If all precisions go to zero (everything is uncertain), the system becomes unresponsive. Mitigation: minimum precision floor of 0.01 on all dimensions.

2. **Prediction lock-in**: If a high layer becomes too confident (precision → ∞), it suppresses all bottom-up errors and the system ignores reality. Mitigation: maximum precision ceiling, plus the immune system's PredictionCollapseDetector.

3. **Oscillation**: Rapid alternation between two incompatible predictions. Mitigation: hysteresis in belief updates (require sustained error before switching).

4. **Cold start**: No prediction history means no meaningful predictions. First ~100 ticks operate in "learning mode" with high learning rates and suppressed action selection.

5. **Embedding model failure**: If the ONNX model fails to load (missing file, incompatible hardware), layers 2+ cannot generate embeddings. Fallback: use LLM API for embeddings (slower, costs tokens) or degrade to 1-layer stack.

6. **Tick budget overrun**: If prediction computation takes longer than the tick budget allows, the system must skip layers. Priority order: Layer 0 (always), Layer 2 (semantic), Layer 4 (strategic). Layers 1 and 3 are skippable.

---

## Interaction with Other Subsystems

- **Memory Palace**: Surprise signals trigger memory activation (competitive retrieval). High surprise at Layer 2+ causes semantic network spread activation.
- **Affective Economy**: Precision weights are modulated by affect. Cumulative surprise increases arousal and curiosity dimensions.
- **Goal Market**: Layer 3-4 surprises generate goals (prediction errors become things to investigate/resolve).
- **Homunculus**: The self-model runs its own mini PP stack predicting the system's behavior. Self-surprise = the homunculus's PP stack detecting errors.
- **Agent Society**: Agents receive surprise signals as part of their perception. High surprise in their domain triggers higher bids.
- **Meta-Cognitive Controller**: The MCC monitors PP stack health (accuracy per layer) and decides which layers to activate based on cognitive budget.
- **TUI**: In Paranoia mode, per-layer prediction accuracy, surprise magnitudes, and precision weights are rendered in real-time. The tick inspector shows which PP phase is currently executing.
- **Skill Extraction**: Repeated prediction patterns at Layer 3-4 (user intent patterns) feed into the SkillMiningAgent's pattern detection.
- **Project Context**: `.kc/steering/` documents create strong priors at Layer 3-4 (the system predicts behavior consistent with steering constraints).
