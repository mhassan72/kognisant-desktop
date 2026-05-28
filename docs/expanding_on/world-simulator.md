# World Simulator — Deep Dive

The World Simulator is a mental sandbox that maintains beliefs about the external world, runs causal chains forward, generates counterfactuals, and models the user as a social agent. It enables the system to "think before acting" by simulating consequences.

---

## Summary

The world simulator maintains a belief graph (what the system thinks is true), a causal engine (how things relate causally), a social model (what the user wants and knows), and a mental sandbox (fork-and-simulate). It answers questions like "what would happen if I did X?" and "why did Y happen?" without actually doing anything.

---

## Mental Sandbox Forking Mechanism

### Fork Architecture

When the system needs to simulate a hypothetical action:

```
1. Clone the current belief graph (shallow copy with copy-on-write)
2. Apply the hypothetical action to the clone
3. Run causal propagation forward N steps
4. Evaluate the resulting state
5. Discard the clone (no side effects on real beliefs)
```

### Copy-on-Write Implementation

Full deep copies of the belief graph are expensive. Instead, use structural sharing:

```
struct MentalSandbox {
    base_beliefs: Arc<BeliefGraph>,  // Shared reference to real beliefs
    overrides: HashMap<NodeId, BeliefNode>,  // Only modified nodes are copied
    added_edges: Vec<CausalEdge>,
    removed_edges: HashSet<EdgeId>,
}

impl MentalSandbox {
    fn get_belief(&self, id: &NodeId) -> &BeliefNode {
        // Check overrides first, fall back to base
        self.overrides.get(id).unwrap_or_else(|| self.base_beliefs.get(id))
    }

    fn set_belief(&mut self, id: NodeId, node: BeliefNode) {
        // Copy-on-write: only modified nodes are cloned
        self.overrides.insert(id, node);
    }
}
```

### Simulation Budget

Each simulation has a compute budget:

```
max_steps = DynamicBounds::simulation_steps()  // 2-20 depending on device tier
max_duration_ms = tick_budget * 0.3  // Max 30% of tick budget for simulation
max_nodes_explored = 100  // Prevent runaway graph traversal
```

If any limit is hit, simulation terminates early and returns partial results with a confidence penalty.

### Parallel Simulations

The system can run multiple simulations concurrently (comparing alternatives):

```
let futures: Vec<_> = candidate_actions.iter()
    .map(|action| {
        let sandbox = MentalSandbox::fork(&self.beliefs);
        tokio::spawn(async move { sandbox.simulate(action, steps) })
    })
    .collect();

let results = join_all(futures).await;
let best = results.iter().max_by_key(|r| r.expected_value);
```

On Standard tier: up to 3 parallel simulations. On Performance tier: up to 8.

---

## Causal Chain Propagation Algorithm

### The Causal Graph

Causal relationships are stored as directed edges with metadata:

```
struct CausalEdge {
    cause: NodeId,
    effect: NodeId,
    mechanism: String,        // Human-readable explanation
    strength: f64,            // 0-1: how reliably cause produces effect
    delay: u32,               // Ticks between cause and effect
    confounders: Vec<NodeId>, // Known confounding variables
    evidence_count: u32,      // How many times observed
    last_observed: u64,       // Tick of last confirmation
}
```

### Propagation Algorithm

Forward propagation through the causal graph:

```
fn propagate(sandbox: &mut MentalSandbox, steps: u8) {
    for step in 0..steps {
        let mut activations: Vec<(NodeId, f64)> = vec![];

        for edge in sandbox.active_edges() {
            let cause_activation = sandbox.get_activation(edge.cause);

            if cause_activation > 0.1 {  // Cause is active
                // Compute effect activation
                let effect_strength = cause_activation * edge.strength;

                // Apply delay (only propagate if enough steps have passed)
                if step >= edge.delay as u8 {
                    activations.push((edge.effect, effect_strength));
                }
            }
        }

        // Apply all activations (parallel update, not sequential)
        for (node, strength) in activations {
            let current = sandbox.get_activation(node);
            // Sigmoid combination (prevents unbounded growth)
            let new_activation = sigmoid(current + strength);
            sandbox.set_activation(node, new_activation);
        }

        // Decay: all activations decay slightly per step
        sandbox.decay_all(0.9);
    }
}
```

### Causal Chain Learning

New causal relationships are learned from observation:

```
1. Observe: Event A occurred at tick T
2. Observe: Event B occurred at tick T + Δ
3. Check: Has A→B been observed before?
   - Yes: increment evidence_count, update strength
   - No: Create tentative edge (strength = 0.3, evidence = 1)
4. Confounder check: Was there a C that also preceded B?
   - Yes: reduce A→B strength, add C as confounder
5. Intervention check: Did we CAUSE A (active inference)?
   - Yes: stronger evidence for causation (not just correlation)
   - No: weaker evidence (could be confounded)
```

---

## Do-Calculus Implementation

### The Problem

Correlation ≠ causation. Observing that A and B co-occur doesn't mean A causes B. The do-calculus provides a formal framework for computing causal effects from observational data.

### P(Y | do(X)) Computation

The interventional probability — "what would happen to Y if we forced X to occur":

```
fn compute_intervention(x: &NodeId, y: &NodeId) -> f64 {
    // 1. Find all paths from X to Y
    let paths = find_all_paths(x, y, max_depth: 5);

    // 2. For each path, compute the causal effect
    let mut total_effect = 0.0;
    for path in paths {
        let path_strength = path.edges.iter()
            .map(|e| e.strength)
            .product::<f64>();

        // 3. Check for confounders on this path
        let confounded = path.edges.iter()
            .any(|e| !e.confounders.is_empty());

        if confounded {
            // Apply backdoor adjustment
            let adjusted = backdoor_adjust(path, &self.beliefs);
            total_effect += adjusted;
        } else {
            total_effect += path_strength;
        }
    }

    // 4. Clamp to [0, 1]
    total_effect.clamp(0.0, 1.0)
}
```

### Backdoor Adjustment

When confounders exist, adjust by conditioning on them:

```
fn backdoor_adjust(path: &CausalPath, beliefs: &BeliefGraph) -> f64 {
    let confounders = path.all_confounders();

    // P(Y | do(X)) = Σ_z P(Y | X, Z=z) * P(Z=z)
    let mut adjusted_effect = 0.0;
    for confounder_state in confounder_states(&confounders, beliefs) {
        let conditional = compute_conditional(path, &confounder_state);
        let prior = compute_prior(&confounder_state, beliefs);
        adjusted_effect += conditional * prior;
    }
    adjusted_effect
}
```

### Practical Limitations

Full do-calculus is computationally expensive. Simplifications used:
- Maximum path depth: 5 edges
- Maximum confounders considered: 3 per path
- Binary confounder states (present/absent) rather than continuous
- Cache intervention results (invalidate when beliefs change)

---

## Counterfactual Generation

### "What If I Had Done X Instead?"

```
fn counterfactual(past_action: &Action, alternative: &Action, context_tick: u64) -> Comparison {
    // 1. Restore belief state at context_tick (from journal)
    let historical_beliefs = journal.beliefs_at(context_tick);

    // 2. Simulate actual path (what did happen)
    let actual_sandbox = MentalSandbox::fork(&historical_beliefs);
    actual_sandbox.apply(past_action);
    actual_sandbox.propagate(5);
    let actual_outcome = actual_sandbox.evaluate();

    // 3. Simulate counterfactual path (what would have happened)
    let counter_sandbox = MentalSandbox::fork(&historical_beliefs);
    counter_sandbox.apply(alternative);
    counter_sandbox.propagate(5);
    let counter_outcome = counter_sandbox.evaluate();

    // 4. Compute regret/relief
    Comparison {
        actual_outcome,
        counterfactual_outcome: counter_outcome,
        regret: (counter_outcome.value - actual_outcome.value).max(0.0),
        relief: (actual_outcome.value - counter_outcome.value).max(0.0),
    }
}
```

### Counterfactual Uses

| Use Case | Trigger | Outcome |
|----------|---------|---------|
| Learning from mistakes | Task failed | "If I had researched first, success probability was 0.7 vs 0.2" |
| Strategy evaluation | Multiple approaches available | Compare simulated outcomes before choosing |
| Regret computation | Post-action evaluation | Feeds into value function update |
| User explanation | User asks "why did you do X?" | "Because simulating Y showed worse outcome" |

### Counterfactual Budget

Counterfactuals are expensive (require historical state restoration + simulation). Budget:
- Maximum 3 counterfactuals per consolidation window
- Only for high-surprise outcomes (free energy > 0.7)
- Only for actions where alternatives existed (not forced actions)

---

## Social Model — Bayesian Updates

### User Model Structure

```
struct SocialModel {
    // Skill assessment
    skill_level: HashMap<String, Beta>,  // Beta distribution per domain
    // e.g., "rust": Beta(α=8, β=2) → "probably skilled"

    // Preference model
    preferences: HashMap<String, f64>,  // Learned preferences
    // e.g., "verbose_explanations": 0.3, "code_first": 0.8

    // Engagement model
    response_time_dist: NormalDist,     // Expected response time
    session_length_dist: NormalDist,    // Expected session duration
    active_hours: [f64; 24],           // Activity probability per hour

    // Mood estimation
    estimated_mood: AffectVector,       // Inferred user affect
    mood_confidence: f64,

    // Communication style
    formality: f64,                     // 0 = casual, 1 = formal
    detail_preference: f64,            // 0 = terse, 1 = verbose
    proactivity_tolerance: f64,        // 0 = only when asked, 1 = proactive
}
```

### Bayesian Skill Assessment

User skill level is modeled as a Beta distribution (conjugate prior for binary outcomes):

```
// Prior: Beta(1, 1) = uniform (no knowledge)
// After observing user succeed at task: α += 1
// After observing user struggle with task: β += 1

fn update_skill(domain: &str, observation: SkillObservation) {
    let beta = self.skill_level.entry(domain).or_insert(Beta::new(1.0, 1.0));

    match observation {
        SkillObservation::Succeeded => beta.α += 1.0,
        SkillObservation::Struggled => beta.β += 1.0,
        SkillObservation::AskedBasicQuestion => beta.β += 0.5,
        SkillObservation::UsedAdvancedFeature => beta.α += 0.5,
    }

    // Decay: slowly forget old observations (user skill changes over time)
    beta.α = 1.0 + (beta.α - 1.0) * 0.999;
    beta.β = 1.0 + (beta.β - 1.0) * 0.999;
}

fn estimated_skill(domain: &str) -> f64 {
    let beta = self.skill_level.get(domain).unwrap_or(&Beta::new(1.0, 1.0));
    beta.α / (beta.α + beta.β)  // Mean of Beta distribution
}
```

### Mood Inference

User mood is inferred from behavioral signals:

```
fn update_mood(signals: &[UserSignal]) {
    for signal in signals {
        match signal {
            UserSignal::ShortResponse => self.estimated_mood.frustration += 0.1,
            UserSignal::LongResponse => self.estimated_mood.engagement += 0.1,
            UserSignal::QuickReply => self.estimated_mood.arousal += 0.05,
            UserSignal::SlowReply => self.estimated_mood.fatigue += 0.05,
            UserSignal::Emoji(positive) => self.estimated_mood.valence += 0.2,
            UserSignal::Emoji(negative) => self.estimated_mood.valence -= 0.2,
            UserSignal::ExplicitFrustration => self.estimated_mood.frustration += 0.3,
            UserSignal::Praise => self.estimated_mood.reward += 0.3,
        }
    }
    // Decay toward neutral
    self.estimated_mood.decay(0.995);
}
```

---

## Simulation Validation

### How to Know if Simulations Are Accurate

The system tracks simulation accuracy by comparing predicted outcomes to actual outcomes:

```
struct SimulationAccuracy {
    predictions: VecDeque<(SimulationResult, Option<ActualOutcome>)>,
}

impl SimulationAccuracy {
    fn record_prediction(&mut self, sim: SimulationResult) {
        self.predictions.push_back((sim, None));
    }

    fn record_actual(&mut self, outcome: ActualOutcome) {
        // Match to most recent unresolved prediction
        if let Some(entry) = self.predictions.iter_mut().rev().find(|(_, actual)| actual.is_none()) {
            entry.1 = Some(outcome);
        }
    }

    fn accuracy(&self) -> f64 {
        let resolved: Vec<_> = self.predictions.iter()
            .filter_map(|(pred, actual)| actual.as_ref().map(|a| (pred, a)))
            .collect();

        if resolved.is_empty() { return 0.5; }  // No data = uncertain

        let correct = resolved.iter()
            .filter(|(pred, actual)| pred.outcome_matches(actual, tolerance: 0.3))
            .count();

        correct as f64 / resolved.len() as f64
    }
}
```

### Calibration

If simulation accuracy drops below 0.5 (worse than random):
1. Increase causal edge decay (forget unreliable causal beliefs)
2. Reduce simulation confidence in bid scoring
3. Trigger causal model relearning during next consolidation
4. Log warning to telemetry

---

## Open Questions / Design Decisions

1. **Belief persistence**: How long should beliefs persist without re-confirmation? Current plan: exponential decay with half-life of 50,000 ticks (~83 min). But some beliefs (e.g., "this project uses React") should be near-permanent. Solution: stability score that slows decay for well-established beliefs.

2. **Simulation depth vs accuracy**: Deeper simulations (more steps) explore more consequences but accumulate error. Is there an optimal depth? Likely domain-dependent — code builds have short causal chains, social interactions have long ones.

3. **Social model privacy**: The system models the user's mood and skill level. Should this be transparent? Current plan: yes, visible in Settings. User can reset or correct the model.

4. **Causal discovery method**: Currently using simple temporal precedence + intervention. Should we use more sophisticated methods (PC algorithm, FCI)? Probably overkill for our domain — most causal relationships are obvious (edit file → build fails).

5. **Multi-user support**: If multiple users interact with the system, should there be separate social models? Current plan: single-user system (desktop app). Multi-user deferred.

6. **World model scope**: How much of the "world" should the system model? Currently: project files, build system, user, and immediate tools. Should it model the broader development ecosystem? (CI/CD, team members, deployment?) Deferred to post-v1.

---

## Research References

- **Pearl, J. (2009)**. "Causality: Models, Reasoning, and Inference" — Do-calculus, causal graphs
- **Spirtes et al. (2000)**. "Causation, Prediction, and Search" — Causal discovery algorithms
- **Gopnik et al. (2004)**. "A theory of causal learning in children" — Bayesian causal learning
- **Sloman, S. (2005)**. "Causal Models" — Mental models and simulation
- **Baker et al. (2017)**. "Rational quantitative attribution of beliefs, desires, and percepts" — Bayesian Theory of Mind
- **Relevant crates**: `petgraph` (graph algorithms), `statrs` (Beta distribution), `rand` (sampling for Monte Carlo simulation)

---

## Edge Cases and Failure Modes

1. **Causal graph explosion**: Too many nodes/edges make propagation expensive. Mitigation: prune edges with strength < 0.1 and evidence_count < 3.

2. **Simulation divergence**: Simulated outcomes wildly differ from reality. Mitigation: track accuracy, reduce confidence when accuracy is low, trigger relearning.

3. **Social model bias**: Early observations disproportionately shape the user model (anchoring). Mitigation: Beta distribution decay ensures old observations lose weight over time.

4. **Counterfactual regret spiral**: System discovers it made many suboptimal choices, generating excessive regret. Mitigation: cap regret accumulation; regret is informative but shouldn't paralyze.

5. **Circular causation**: A→B→C→A creates infinite propagation. Mitigation: visited-node tracking during propagation; stop if a node is visited twice in one propagation pass.

6. **Stale beliefs about dynamic systems**: The project's build system changes but beliefs haven't updated. Mitigation: beliefs about tool behavior have shorter half-lives than beliefs about code structure.

---

## Interaction with Other Subsystems

- **Goal Market**: Simulation results inform bid confidence. Before pursuing a goal, agents can simulate outcomes to estimate success probability.
- **Predictive Processing**: The world model IS the generative model for layers 3-4 (pragmatic and strategic predictions).
- **Memory Palace**: Beliefs are backed by semantic network nodes. Causal chains are stored in the semantic graph. Social model observations are episodic memories.
- **Agent Society**: Agents query the world simulator before bidding ("if I do X, what happens?"). The social model informs the SocialAgent's behavior.
- **Affective Economy**: Simulation outcomes affect reward expectation. Counterfactual regret increases frustration.
- **Self-Modification**: Before self-modifying, the system simulates the modification's effects on its own behavior.
- **Cognitive Homeostasis**: The contradiction resolver operates on the belief graph. Stale beliefs are pruned during epistemic healing.
