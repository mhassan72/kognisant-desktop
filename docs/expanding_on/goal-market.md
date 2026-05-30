# Goal Market — Deep Dive

The Goal Market is where cognitive intentions become actions. Goals are generated from prediction errors, scored by a learned value function, resolved through competitive bidding, and organized into hierarchies with temporal discounting. There is no central planner assigning tasks — allocation emerges from market dynamics.

---

## Summary

Goals in Kognisant are not user-assigned tasks (though user requests become goals). They emerge from the system's attempt to minimize surprise. The goal market resolves competing goals through a bidding mechanism where agents compete for the right to pursue goals, weighted by affect state, expected value, and resource constraints.

---

## Cold-Start Bootstrap

At system startup (or after crash recovery), there are no active goals, no prediction history, and no surprise signals. Without intervention, the system would tick indefinitely with empty phases. The bootstrap protocol solves this.

### Bootstrap Goals (First 100 Ticks)

During the first 100 ticks after startup, the goal market injects hardcoded bootstrap goals that are NOT subject to normal market bidding:

```rust
fn inject_bootstrap_goals(market: &mut GoalMarket, tick: u64) {
    if tick > 100 { return; } // Bootstrap only for first 100 ticks

    if tick == 1 {
        // Goal 1: Perceive environment (assigned to perception, always runs)
        market.inject(Goal {
            id: Uuid::nil(), // Sentinel: bootstrap goal
            origin: GoalOrigin::Bootstrap,
            description: "Initialize perception — scan project files, detect context".into(),
            priority: 1.0, // Maximum priority
            assigned_agent: Some(AgentId::Planner),
            bypass_bidding: true, // Not subject to market
        });

        // Goal 2: Load project context
        market.inject(Goal {
            id: Uuid::nil(),
            origin: GoalOrigin::Bootstrap,
            description: "Load .kc/ steering docs, journal, specs, memory".into(),
            priority: 0.9,
            assigned_agent: Some(AgentId::Planner),
            bypass_bidding: true,
        });
    }

    if tick == 10 {
        // Goal 3: Greet user (if interactive mode)
        market.inject(Goal {
            id: Uuid::nil(),
            origin: GoalOrigin::Bootstrap,
            description: "Signal readiness to user".into(),
            priority: 0.7,
            assigned_agent: Some(AgentId::Social),
            bypass_bidding: true,
        });
    }
}
```

### Transition to Normal Operation

After tick 100:
- Bootstrap goals are removed (if not already completed)
- The PP stack has accumulated enough observations to generate predictions
- Surprise signals begin firing naturally (predictions vs observations)
- Normal goal generation from surprise takes over
- The market operates normally from this point

### Agent Default Bids

Even without explicit goals, agents maintain a "situational awareness" bid:

```rust
impl CognitiveAgent for PlannerAgent {
    fn bid(&self, perception: &AgentPerception, budget: &CognitiveBudget) -> Option<GoalBid> {
        // Normal bidding on active goals
        if let Some(goal) = self.find_matching_goal(perception) {
            return Some(self.bid_on_goal(goal, budget));
        }

        // Default bid: maintain awareness (very low priority, near-zero cost)
        // This prevents agents from going completely dormant
        Some(GoalBid {
            agent: self.id(),
            goal: Goal::implicit("maintain situational awareness"),
            urgency: 0.01,
            expected_value: 0.1,
            expected_cost: 0.01, // Almost free
            confidence: 1.0,
            ..Default::default()
        })
    }
}
```

This ensures agents always have something to bid on, preventing the chicken-and-egg problem where agents need goals to bid but goals need agents to exist.

### Post-Crash Recovery

After crash recovery, the system doesn't need the full 100-tick bootstrap because:
- The rkyv snapshot restores active goals (they persist across crashes)
- The journal provides project context immediately
- Only if ALL state is lost (both snapshot and journal corrupted) does the full bootstrap run

---

## Goal Generation from Surprise — Detailed Algorithm

### The Surprise-to-Goal Pipeline

```
1. Surprise detected at PP layer L with free energy F
2. Filter: F > generation_threshold (affect-modulated)
3. Classify surprise by layer:
   - Layer 0-1: Immediate perceptual mismatch → PredictionError goal
   - Layer 2: Semantic gap → CuriosityGap goal
   - Layer 3: Intent mismatch → ValueGradient goal
   - Layer 4: Strategic deviation → Opportunity or SelfImprovement goal
4. Compute initial priority: F * (1 + arousal) * layer_weight
5. Check for duplicate/subsumption against active goals
6. If novel: submit to goal market
7. If subsumed: boost priority of existing parent goal
```

### Generation Threshold Dynamics

The threshold adapts to prevent goal flooding:

```
base_threshold = 0.5

// Affect modulation
threshold = base_threshold * (1 + fatigue * 0.5) * (1 - curiosity * 0.3)

// Flood protection (from immune system)
if goals_generated_last_100_ticks > goals_resolved_last_100_ticks * 3:
    threshold *= 1.5  // Raise bar during flood

// Minimum floor
threshold = threshold.max(0.2)  // Always generate goals for very high surprise
```

### Duplicate Detection

Before submitting a new goal, check for semantic overlap with active goals:

```
for existing in active_goals:
    similarity = cosine(new_goal.embedding, existing.embedding)
    if similarity > 0.85:
        // Subsumption: boost existing goal instead of creating new one
        existing.priority += new_goal.priority * 0.5
        return  // Don't create duplicate
    elif similarity > 0.6:
        // Related: create as sub-goal of existing
        existing.add_subgoal(new_goal)
        return
// Novel: submit as independent goal
```

### Goal Origin Classification

| Origin Type | Trigger | Example | Typical Priority |
|------------|---------|---------|-----------------|
| UserRequest | User sends message with intent | "Fix the auth bug" | High (0.8-1.0) |
| PredictionError | Layer 0-1 surprise | Unexpected file change | Medium (0.4-0.7) |
| CuriosityGap | Layer 2 surprise, repeated pattern | New API seen 3 times without concept | Low-Medium (0.3-0.5) |
| ValueGradient | Layer 3-4, positive expected outcome | "Refactoring X would improve Y" | Low (0.2-0.4) |
| Contradiction | Conflicting beliefs detected | Two beliefs about same entity disagree | Medium (0.5-0.7) |
| Opportunity | Pattern match to known improvement | "This code matches a pattern I can optimize" | Low (0.2-0.3) |
| SelfImprovement | L3 self-evaluation detects degradation | Task success rate declining | Medium (0.4-0.6) |
| SocialMaintenance | User engagement dropping | No user input for 5 minutes, last interaction was frustrating | Low-Medium (0.3-0.5) |

---

## Value Function RL Updates

### The Learned Value Function

The value function maps (state, action, outcome) triples to scalar values. It learns what the system should care about.

### Intrinsic Values (Hardcoded Anchors)

These provide the initial value landscape before learning:

```
curiosity_satisfaction = 0.6    // Reducing uncertainty is inherently valuable
competence_increase = 0.7      // Getting better at tasks is valuable
social_rapport = 0.5           // Positive user interaction is valuable
autonomy = 0.4                 // Self-directed action is valuable
coherence = 0.8                // Consistent world model is highly valuable
```

### Learned Values (Updated by Experience)

```
domain_values: HashMap<String, f64>    // "rust": 0.7, "python": 0.5
tool_values: HashMap<String, f64>      // "shell_exec": 0.6, "file_write": 0.8
strategy_values: HashMap<String, f64>  // "plan_first": 0.7, "iterate_fast": 0.5
```

### TD(λ) Update Rule

After each goal resolution:

```
// Temporal difference error
δ = reward + γ * V(next_state) - V(current_state)

// Update value estimates
V(state) += α * δ

// Eligibility traces for multi-step goals
for each state in goal_trajectory:
    eligibility[state] *= γ * λ
    V(state) += α * δ * eligibility[state]
```

Parameters:
- `α = 0.05` (learning rate — slow, stable learning)
- `γ = 0.95` (discount factor — values future rewards)
- `λ = 0.8` (trace decay — credit assignment over multiple steps)

### Reward Signal Sources

| Source | Signal | Weight |
|--------|--------|--------|
| User explicit feedback | "good", "bad", thumbs up/down | 1.0 |
| User implicit feedback | Accepted output without edits | 0.5 |
| Task completion | Goal marked resolved | 0.3 |
| Prediction accuracy improvement | Post-action surprise reduction | 0.2 |
| Coherence maintenance | No contradictions introduced | 0.1 |
| Resource efficiency | Low token cost for successful outcome | 0.1 |

---

## Temporal Discounting

### Hyperbolic Discounting Model

Goals further in the future are worth less (matching human decision-making):

```
discounted_value = value / (1 + k * delay)
```

Where:
- `value` = undiscounted expected value
- `k` = discounting rate (default 0.1, affect-modulated)
- `delay` = estimated ticks until goal completion

### Affect Modulation of Discounting

```
effective_k = base_k * (1 + frustration * 0.5) * (1 - reward_expectation * 0.3)
```

- High frustration → steeper discounting → prefer immediate results
- High reward expectation → shallower discounting → willing to invest in future

### Discounting in Practice

| Goal | Estimated Delay | Raw Value | Discounted Value (k=0.1) |
|------|----------------|-----------|--------------------------|
| "Reply to user" | 1 tick | 0.8 | 0.73 |
| "Fix current bug" | 50 ticks | 0.9 | 0.15 |
| "Refactor module" | 500 ticks | 0.7 | 0.014 |
| "Learn new framework" | 5000 ticks | 0.6 | 0.001 |

This naturally prioritizes immediate user needs over long-term improvements — unless curiosity or reward expectation override the discounting.

---

## Goal Hierarchy Decomposition

### Automatic Decomposition

When a goal is too complex for a single agent action:

```
1. PlannerAgent wins bid for complex goal
2. PlannerAgent decomposes into sub-goals:
   - Identifies required steps
   - Estimates dependencies
   - Creates sub-goal tree
3. Sub-goals are submitted to the market as independent goals
4. Parent goal tracks sub-goal completion
5. Parent resolves when all required sub-goals complete
```

### Hierarchy Structure

```
Goal: "Implement user authentication"
├── Sub-goal: "Research auth patterns for this framework"
│   └── Status: resolved (ResearchAgent)
├── Sub-goal: "Design auth schema"
│   └── Status: resolved (PlannerAgent + CoderAgent coalition)
├── Sub-goal: "Implement login endpoint"
│   ├── Sub-sub-goal: "Write handler"
│   ├── Sub-sub-goal: "Add validation"
│   └── Sub-sub-goal: "Write tests"
├── Sub-goal: "Implement session management"
│   └── Status: in_progress (CoderAgent)
└── Sub-goal: "Integration test"
    └── Status: blocked (depends on above)
```

### Dependency Resolution

Sub-goals can have dependencies:

```
pub enum GoalDependency {
    Requires(GoalId),           // Must complete before this can start
    Benefits(GoalId),           // Better if done first, but not required
    Conflicts(GoalId),          // Cannot run simultaneously
    Produces(ResourceId),       // This goal produces a resource others need
}
```

The market respects dependencies: a goal with unmet `Requires` dependencies cannot be bid on.

---

## Priority Market Dynamics

### Priority as Currency

Goal priority is not static — it changes over time based on:

```
priority(t) = initial_priority 
    * urgency_multiplier(t)
    * relevance_multiplier(context)
    * affect_multiplier(affect_state)
    * age_decay(t)
```

### Urgency Escalation

Goals that have been waiting too long escalate:

```
urgency_multiplier = 1.0 + log(1 + age_ticks / 100) * 0.2
```

This ensures old goals eventually get attention, even if they started with low priority.

### Context Relevance

Goals related to current user activity get boosted:

```
relevance_multiplier = 1.0 + cosine(goal.embedding, current_context.embedding) * 0.5
```

### Priority Redistribution

When a goal is resolved, its priority "energy" redistributes:
- 50% to parent goal (if exists)
- 30% to related goals (semantic similarity > 0.5)
- 20% dissipates (entropy)

---

## Goal Abandonment Criteria

### When Goals Die

A goal is abandoned (not just deprioritized) when:

```
abandon if ANY of:
    1. priority < 0.05 (decayed below relevance)
    2. age > 100,000 ticks (~2.8 hours) AND no progress
    3. confidence < 0.1 (no agent believes it can succeed)
    4. contradicted by newer information (world model update invalidates goal)
    5. user explicitly cancels
    6. parent goal abandoned (cascade)
    7. immune system intervention (goal flood response)
```

### Abandonment Consequences

When a goal is abandoned:
1. Record in telemetry (why abandoned, how long active)
2. Update value function (negative signal for similar goals)
3. If user-originated: notify user ("I've deprioritized X because Y")
4. Release any reserved resources
5. Dissolve any active coalitions pursuing this goal

### Graceful Degradation vs Hard Abandon

- **Graceful**: Priority decays naturally, goal becomes dormant, can reactivate if context changes
- **Hard**: Immediate removal (contradiction, user cancel, immune intervention)

---

## Open Questions / Design Decisions

1. **Goal capacity**: How many active goals can the system maintain? Currently bounded by `DynamicBounds::max_active_goals()` which derives from planning depth × available compute. Is this the right formula?

2. **User goal priority**: Should user-originated goals always outrank system-generated goals? Current plan: user goals start at 0.8-1.0 priority, system goals at 0.2-0.6. But a very old system goal with urgency escalation could theoretically outrank a new user goal. Is that acceptable?

3. **Goal persistence across sessions**: Should active goals persist when the application restarts? Current plan: yes, stored in cognitive_state. But stale goals from yesterday may not be relevant today. Solution: apply heavy age decay on restart.

4. **Collaborative goal setting**: Should the system propose goals to the user? ("I notice you haven't written tests for module X. Should I?") Current plan: yes, via SocialAgent, but only when confidence > 0.7 and user engagement is high.

5. **Goal market visualization**: How to show the user what the system is "thinking about"? In Trace mode, the goal panel shows active goals with priorities and agent assignments. In Paranoia mode, full bid history and resolution dynamics are visible. Focus mode shows only the current top-level goal in the status bar.

6. **Multi-project goals**: Can a goal span multiple projects? (e.g., "Learn React patterns" applies everywhere.) Current plan: no — goals are project-scoped. Cross-project learning happens through skill transfer, not shared goals.

---

## Research References

- **Sutton & Barto (2018)**. "Reinforcement Learning: An Introduction" — TD learning, value functions
- **Kahneman & Tversky (1979)**. "Prospect Theory" — Hyperbolic discounting, loss aversion
- **Deci & Ryan (2000)**. "Self-Determination Theory" — Intrinsic motivation, autonomy, competence
- **Bratman, M. (1987)**. "Intention, Plans, and Practical Reason" — BDI agent architecture
- **Gershman et al. (2015)**. "Computational rationality: A converging paradigm" — Resource-rational goal pursuit
- **Relevant crates**: `ordered-float` (priority comparison), `petgraph` (goal hierarchy as DAG), `serde` (goal serialization)

---

## Edge Cases and Failure Modes

1. **Goal explosion**: A single high-level goal decomposes into hundreds of sub-goals. Mitigation: maximum decomposition depth of 4 levels; maximum 20 sub-goals per parent.

2. **Circular dependencies**: Goal A requires B, B requires A. Mitigation: dependency cycle detection at submission time; reject circular dependencies.

3. **Value function drift**: If the user's preferences change, the learned value function becomes stale. Mitigation: value function has natural decay (unused values drift toward 0.5) and explicit reset on user request.

4. **Priority inflation**: All goals escalate over time, making priority meaningless. Mitigation: periodic normalization — rescale all priorities to [0, 1] range every 1000 ticks.

5. **Starvation of low-priority goals**: Important-but-not-urgent goals never get attention. Mitigation: urgency escalation ensures eventual attention; CuriosityAgent specifically bids on neglected goals.

6. **User goal conflict**: User requests two contradictory things. Mitigation: contradiction detection at submission; SocialAgent asks for clarification before both goals enter the market.

---

## Interaction with Other Subsystems

- **Predictive Processing**: Surprise is the primary goal generation signal. Layer-specific surprise maps to goal types.
- **Agent Society**: Agents are the bidders. The market resolves their bids. Agents learn from goal outcomes.
- **Affective Economy**: Affect modulates bid scoring, generation thresholds, discounting rates, and abandonment criteria.
- **Memory Palace**: Active goals bias memory retrieval. Completed goals are encoded as episodes. Goal patterns become procedural memory.
- **World Simulator**: Before pursuing a goal, the system can simulate outcomes. Simulation results inform bid confidence.
- **Homunculus**: Self-improvement goals originate from the homunculus's L3/L5 evaluations.
- **Self-Modification**: Self-modification is a goal type that goes through the market like any other, but with additional safety gating.
- **Cognitive Homeostasis**: The immune system can suppress goal generation (raise threshold) or force goal abandonment (flood response).
- **TUI**: Goal hierarchy is rendered in Trace mode (right panel). Paranoia mode shows bid scores, temporal discounting, and abandonment criteria in real-time.
- **Project Context**: `.kc/specs/` create explicit goals that persist across sessions. Spec-derived goals have higher initial priority (0.7-0.9) since they represent deliberate user intent.
- **Skill Extraction**: Completed goal patterns feed into the SkillMiningAgent. Repeated successful goal → execution patterns become skill candidates.
