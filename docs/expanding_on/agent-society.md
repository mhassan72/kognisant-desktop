# Agent Society — Deep Dive

The Agent Society is a collection of 13 specialist cognitive agents that compete and cooperate via a bidding market. There is no central planner — task allocation emerges from the interaction of agent bids, affect-weighted scoring, and coalition formation.

---

## Summary

Instead of a monolithic agent with a planning module, Kognisant implements a "society of mind" where specialized agents perceive the system state, generate bids for cognitive resources, form coalitions for complex tasks, and learn from outcomes. Orchestration is emergent, not engineered.

---

## Individual Agent Specifications

### 1. PlannerAgent

**Role**: Long-horizon task decomposition and sequencing.

- **Perceives**: Active goals, goal hierarchy, task dependencies, user intent signals
- **Bids on**: Complex multi-step goals that require decomposition
- **Bid strength**: Proportional to goal complexity × confidence in decomposition
- **Actions**: Generates sub-goal trees, sequences actions, identifies dependencies
- **Learning signal**: Sub-goal completion rate, plan revision frequency
- **Essential on**: All tiers (core functionality)

**Unique behavior**: The PlannerAgent maintains a "plan cache" — previously successful decomposition patterns indexed by goal type. On familiar goals, it bids with high confidence and low cost.

### 2. CoderAgent

**Role**: Code generation, modification, and completion.

- **Perceives**: Active coding goals, file context, language/framework detection, recent errors
- **Bids on**: Any goal involving code output (write, modify, refactor, fix)
- **Bid strength**: Proportional to domain familiarity × code complexity assessment
- **Actions**: Generates code via LLM, applies patches, runs formatters
- **Learning signal**: Code acceptance rate, test pass rate, user edit distance post-generation
- **Essential on**: All tiers (primary value delivery)

**Unique behavior**: Tracks per-project "code style" preferences learned from user edits. If the user consistently reformats generated code in a specific way, the CoderAgent adapts.

### 3. DebuggerAgent

**Role**: Error diagnosis, root cause analysis, fix generation.

- **Perceives**: Error signals, build failures, test failures, stack traces, recent changes
- **Bids on**: Error-related goals, especially repeated failures
- **Bid strength**: Increases with frustration level and error recurrence count
- **Actions**: Analyzes error context, generates hypotheses, proposes fixes, runs diagnostic commands
- **Learning signal**: Fix success rate, time-to-resolution
- **Folds into**: PlannerAgent on Minimal tier (simpler heuristic debugging)

**Unique behavior**: Maintains a "failure pattern database" — maps error signatures to successful fixes. On repeated errors, skips diagnosis and applies known fix directly.

### 4. ResearchAgent

**Role**: Information gathering, documentation lookup, web search.

- **Perceives**: Knowledge gaps (high uncertainty in semantic network), unfamiliar APIs, new libraries
- **Bids on**: Goals requiring external information, curiosity-driven exploration
- **Bid strength**: Proportional to epistemic value (uncertainty reduction potential)
- **Actions**: Searches documentation, reads files, queries web, synthesizes findings
- **Learning signal**: Information utility (did the gathered info resolve the goal?)
- **Folds into**: Disabled on Minimal tier (user must provide information)

**Unique behavior**: Caches research results in semantic memory with source attribution. Before searching externally, checks if the answer already exists in memory.

### 5. RefactorAgent

**Role**: Code quality improvement, architecture optimization, technical debt reduction.

- **Perceives**: Code complexity metrics, duplication detection, architectural violations, style inconsistencies
- **Bids on**: Quality-improvement goals, especially during low-urgency periods
- **Bid strength**: Low urgency but high expected long-term value; bids higher when system is idle
- **Actions**: Identifies refactoring opportunities, proposes structural changes, applies transformations
- **Learning signal**: Post-refactor test stability, code complexity reduction
- **Folds into**: CoderAgent on Minimal tier (inline refactoring only)

**Unique behavior**: Only bids when no urgent goals are active (opportunistic improvement). Tracks "refactoring debt" score per file.

### 6. TestAgent

**Role**: Test generation, test execution, coverage analysis.

- **Perceives**: Code changes without tests, coverage gaps, recent failures, untested paths
- **Bids on**: Goals related to verification, especially after code generation
- **Bid strength**: Increases after CoderAgent actions (complementary bidding)
- **Actions**: Generates test cases, runs test suites, reports coverage, identifies edge cases
- **Learning signal**: Bug detection rate, false positive rate
- **Folds into**: Disabled on Minimal tier (user runs tests manually)

**Unique behavior**: Forms natural coalition with CoderAgent — when CoderAgent generates code, TestAgent automatically bids to verify it. This creates an emergent "write then test" pattern without explicit orchestration.

### 7. ExplainAgent

**Role**: Documentation generation, concept explanation, user education.

- **Perceives**: User confusion signals, complex code without comments, undocumented APIs
- **Bids on**: Explanation requests, documentation goals, "why" questions
- **Bid strength**: Proportional to detected user confusion × explanation complexity
- **Actions**: Generates explanations, writes documentation, creates examples
- **Learning signal**: User comprehension signals (follow-up questions, acceptance)
- **Folds into**: SocialAgent on Minimal tier (shorter explanations)

**Unique behavior**: Adapts explanation depth to user skill level (tracked in social model). Expert users get terse technical explanations; beginners get step-by-step walkthroughs.

### 8. MetaAgent

**Role**: Monitors other agents, suggests improvements, detects inefficiencies.

- **Perceives**: Agent performance metrics, bid patterns, coalition success rates, resource waste
- **Bids on**: Meta-improvement goals (improve agent strategies, adjust parameters)
- **Bid strength**: Low but persistent; increases when agent performance degrades
- **Actions**: Adjusts agent parameters, suggests strategy changes, reports to homunculus
- **Learning signal**: System-wide performance improvement after interventions
- **Folds into**: Disabled on Minimal tier

**Unique behavior**: The only agent that can modify other agents' parameters. Acts as an "internal consultant" — observes patterns across all agents and suggests optimizations.

### 9. CuriosityAgent

**Role**: Generates exploratory goals, seeks novel information, prevents epistemic closure.

- **Perceives**: Novelty signals, unexplored areas of the codebase, knowledge gaps, routine patterns
- **Bids on**: Exploration goals, information-seeking actions, novel approaches
- **Bid strength**: Proportional to novelty_drive affect dimension × information gap size
- **Actions**: Explores unfamiliar code, tries alternative approaches, investigates anomalies
- **Learning signal**: Discovery value (did exploration lead to useful knowledge?)
- **Folds into**: Disabled on Minimal tier (no autonomous exploration)

**Unique behavior**: Deliberately bids against the "safe" option. When all other agents converge on a solution, CuriosityAgent bids for the alternative — ensuring the system doesn't get stuck in local optima.

### 10. SafetyAgent

**Role**: Veto dangerous actions, enforce constraints, prevent harm.

- **Perceives**: Proposed actions, self-modification requests, destructive operations, security-sensitive changes
- **Bids on**: Nothing (does not generate goals) — only vetoes
- **Bid strength**: N/A — operates as a filter, not a bidder
- **Actions**: Blocks dangerous actions, requests human approval for critical changes, logs safety events
- **Learning signal**: False positive rate (vetoes that were overridden by user)
- **Essential on**: All tiers (non-negotiable)

**Unique behavior**: Has veto power — can block any action regardless of bid score. The only agent that can override the goal market's decisions. Cannot be disabled or shed.

### 11. SocialAgent

**Role**: Manages user relationship, tone, rapport, communication style.

- **Perceives**: User sentiment, conversation history, response patterns, engagement level
- **Bids on**: Communication goals, check-in actions, rapport maintenance
- **Bid strength**: Increases when user seems frustrated, confused, or disengaged
- **Actions**: Adjusts communication tone, initiates check-ins, asks clarifying questions
- **Learning signal**: User engagement metrics, explicit feedback, conversation continuation
- **Essential on**: All tiers (user relationship is core)

**Unique behavior**: Maintains a "user model" in the world simulator's social model. Tracks preferences (verbose vs terse, formal vs casual, proactive vs reactive). Adapts all system output through this lens.

### 12. MemoryAgent

**Role**: Memory organization, retrieval optimization, consolidation management.

- **Perceives**: Memory utilization, retrieval failures, stale memories, fragmentation
- **Bids on**: Memory maintenance goals, consolidation requests, reorganization
- **Bid strength**: Increases with memory pressure and retrieval failure rate
- **Actions**: Triggers consolidation, reorganizes semantic network, prunes stale entries
- **Learning signal**: Retrieval precision improvement, memory efficiency
- **Folds into**: Disabled on Minimal tier (automatic maintenance only)

**Unique behavior**: The only agent that can trigger consolidation outside of the fatigue-driven schedule. If retrieval quality degrades, MemoryAgent bids for immediate maintenance regardless of fatigue level.

### 13. SkillMiningAgent

**Role**: Pattern extraction from user interactions, skill candidate generation, lifecycle management.

- **Perceives**: Repeated user patterns, correction signals, explicit teaching moments, interaction history
- **Bids on**: Skill extraction opportunities, candidate review scheduling, lifecycle maintenance
- **Bid strength**: Proportional to pattern confidence × repetition count × generalizability score
- **Actions**: Generates skill candidates, schedules weekly reviews, manages TTL expiration, archives stale skills
- **Learning signal**: Skill approval rate, skill usage frequency post-approval, rejection patterns
- **Essential on**: All tiers (skill continuity is core value)

**Unique behavior**: Operates on a longer timescale than other agents. While most agents bid per-tick, SkillMiningAgent accumulates evidence across sessions before generating candidates. It maintains a "pattern buffer" that persists in `.kc/memory/` and only surfaces candidates when confidence exceeds threshold (default 0.7).

**Detection signals**:
- **Repetition**: Same approach used 3+ times across different contexts
- **Explicit teaching**: User says "always do X when Y" or "remember that Z"
- **Correction patterns**: User consistently modifies system output in the same way
- **Preference signals**: User repeatedly chooses one approach over alternatives

**Skill candidate generation**:
```
1. Pattern detected (repetition/teaching/correction)
2. Extract: conditions, actions, expected outcomes
3. Assess generalizability (project-specific vs cross-project)
4. Compute confidence score
5. If confidence > 0.7: generate candidate → ~/.kc/skills/candidates/
6. Queue for weekly review (max 3-5 per week)
```

**Lifecycle management**:
- Monitors skill usage frequency
- Applies domain-specific half-lives (language syntax: 6mo, API patterns: 2wk)
- Triggers quarterly renewal reviews for active skills
- Archives skills that haven't been used within 2× their half-life
- Learns from rejections (adjusts detection thresholds for similar patterns)

---

## Bid Scoring Algorithms

### Base Score Computation

```
base_score = (expected_value * confidence) / (expected_cost + ε)
```

Where:
- `expected_value` = predicted outcome quality (0-1)
- `confidence` = agent's belief it can succeed (0-1)
- `expected_cost` = resources needed (0-1, fraction of tick budget)
- `ε` = 0.1 (prevents division by zero, biases toward low-cost actions)

### Affect-Modulated Scoring

The base score is then modulated by the current affective state:

```
final_score = base_score * affect_multiplier(bid, affect_state)

affect_multiplier = match affect_state.dominant_mode() {
    Exploration => bid.epistemic_value * 2.0 + 1.0,
    Exploitation => bid.pragmatic_value * 2.0 + 1.0,
    Recovery => if bid.cost < 0.2 { 1.5 } else { 0.1 },
    Panic => if bid.confidence > 0.9 { 3.0 } else { 0.0 },
    Flow => 1.0,  // No modulation in flow state
}
```

### Urgency Decay

Bids that have been waiting in the queue lose urgency over time:

```
effective_urgency = bid.urgency * e^(-age_ticks / 500)
```

This prevents old, stale bids from blocking fresh, relevant ones.

---

## Coalition Formation Rules

### When Coalitions Form

Two or more bids form a coalition when:

1. **Complementary goals**: Bid A's output is Bid B's input (e.g., Research → Code)
2. **Shared context**: Both bids reference the same goal or file
3. **Sequential dependency**: One bid explicitly requires another's completion first
4. **Synergy bonus**: Combined expected value > sum of individual values

### Coalition Scoring

```
coalition_score = Σ(member_scores) * synergy_bonus - coordination_cost

synergy_bonus = 1.0 + 0.2 * complementarity_count
coordination_cost = 0.05 * member_count  // More members = more overhead
```

### Coalition Lifecycle

```
1. Formation: Complementary bids detected during resolution
2. Resource allocation: Total budget split among members (proportional to cost)
3. Execution: Members execute in dependency order
4. Outcome: All members receive shared outcome signal
5. Dissolution: Coalition dissolves after execution (no persistent teams)
```

### Coalition Examples

| Coalition | Members | Trigger | Synergy |
|-----------|---------|---------|---------|
| "Implement Feature" | Planner + Coder + Test | Complex user request | Plan → Code → Verify |
| "Debug & Fix" | Debugger + Coder | Repeated build failure | Diagnose → Patch |
| "Research & Implement" | Research + Coder | Unknown API/library | Learn → Apply |
| "Explain & Document" | Explain + Coder | User asks "how does X work?" | Analyze → Explain |
| "Quality Pass" | Refactor + Test | Idle period, code debt high | Improve → Verify |

---

## Emergent Behavior Patterns

### Observed Emergent Dynamics

These behaviors are not programmed — they emerge from the interaction rules:

1. **Specialization deepening**: Agents that win bids frequently in a domain develop higher confidence in that domain, making them win more often (positive feedback loop, bounded by confidence ceiling).

2. **Natural turn-taking**: After one agent dominates for several ticks, its cost increases (resource depletion) and other agents' bids become relatively more attractive.

3. **Crisis response**: When multiple error signals fire simultaneously, DebuggerAgent and SafetyAgent naturally dominate (their bid strength scales with error severity), pushing other agents aside.

4. **Idle creativity**: When no user goals are active, CuriosityAgent and RefactorAgent naturally win (their bids don't require external triggers), creating autonomous improvement behavior.

5. **Adaptive team composition**: Over time, the system learns which agent combinations work well together. Successful coalitions are more likely to form again (coalition history in procedural memory).

---

## Agent Lifecycle

### Birth (Initialization)

```
1. Agent struct created with default parameters
2. Initial confidence: 0.5 (neutral)
3. Initial strategy: hardcoded baseline
4. No learned preferences (tabula rasa per project)
```

### Active Operation

```
1. Perceive: Read relevant system state (filtered by agent's domain)
2. Evaluate: Assess whether any active goals match agent's capabilities
3. Bid: Generate GoalBid with estimated value, cost, confidence
4. Execute (if won): Perform actions, consume resources
5. Learn: Update confidence and strategy based on outcome
```

### Shedding (Resource Pressure)

When the system needs to reduce agent count:

```
Priority order for shedding (first shed = lowest priority):
1. CuriosityAgent (exploration is luxury)
2. RefactorAgent (quality improvement can wait)
3. ExplainAgent (user can ask if needed)
4. MemoryAgent (automatic maintenance continues)
5. MetaAgent (optimization is luxury)
6. TestAgent (user can test manually)
7. ResearchAgent (user can provide info)
8. DebuggerAgent (Planner absorbs basic debugging)
9. --- NEVER SHED BELOW THIS LINE ---
10. CoderAgent (primary value delivery)
11. PlannerAgent (core task decomposition)
12. SkillMiningAgent (skill continuity)
13. SocialAgent (user relationship)
14. SafetyAgent (non-negotiable)
```

### Death (Permanent Removal)

Agents are never permanently removed. They can be:
- **Shed** (temporarily disabled, reactivated when resources allow)
- **Dormant** (no bids generated, but still perceives — reactivates on relevant signal)

---

## How Agents Learn from Outcomes

### Confidence Update Rule

After each action:

```
if outcome.succeeded:
    confidence = confidence + α * (1 - confidence)  // Asymptotic approach to 1.0
else:
    confidence = confidence - β * confidence  // Asymptotic approach to 0.0

where α = 0.1 (slow confidence gain)
      β = 0.15 (slightly faster confidence loss — negativity bias)
```

### Strategy Learning

Each agent maintains a strategy vector (weights on different approaches):

```
strategy_weights = {
    "approach_A": 0.6,
    "approach_B": 0.3,
    "approach_C": 0.1,
}

// After outcome:
if used_approach == "approach_A" && succeeded:
    strategy_weights["approach_A"] += 0.05
    normalize(strategy_weights)
```

### Cross-Agent Learning

When a coalition succeeds, all members learn:
- "Working with Agent X on goal type Y is effective"
- This increases future coalition formation probability for similar goals

---

## Minimal-Tier Agent Folding

On Minimal tier (4 agents only), the 8 disabled agents' responsibilities fold into the 4 active ones:

| Disabled Agent | Folds Into | Quality Loss |
|---------------|-----------|-------------|
| DebuggerAgent | PlannerAgent | Simpler heuristics, no pattern database |
| ResearchAgent | (disabled) | User must provide information |
| RefactorAgent | CoderAgent | Inline only, no separate pass |
| TestAgent | (disabled) | User runs tests manually |
| ExplainAgent | SocialAgent | Shorter, less detailed explanations |
| MetaAgent | (disabled) | No self-optimization |
| CuriosityAgent | (disabled) | No autonomous exploration |
| MemoryAgent | (disabled) | Automatic maintenance only |

---

## Open Questions / Design Decisions

1. **Agent count**: 13 was chosen to cover major cognitive functions without excessive overhead. The addition of SkillMiningAgent (13th) was driven by the need for persistent skill extraction as a first-class cognitive function. Should there be more specialized agents (e.g., SecurityAgent, PerformanceAgent)? Current decision: no — keep it at 13 and let agents develop sub-specializations through learning.

2. **Bid frequency**: Should agents bid every tick or only when they detect relevant goals? Current plan: agents perceive every tick but only generate bids when they have something to bid on (saves computation).

3. **Coalition persistence**: Should successful coalitions persist across ticks (becoming "teams")? Current decision: no — coalitions dissolve after each execution. Persistent teams would reduce flexibility.

4. **Agent communication**: Should agents communicate directly with each other (peer-to-peer) or only through the market? Current plan: market only. Direct communication adds complexity and makes behavior harder to predict.

5. **User-created agents**: Should users be able to define custom agents? Interesting but complex. Deferred to post-v1.

6. **Agent personality**: Should agents have distinct "personalities" (risk-tolerant vs conservative)? Currently implicit in their bid strategies, but could be made explicit.

---

## Research References

- **Minsky, M. (1986)**. "The Society of Mind" — Original society of mind concept
- **Maes, P. (1989)**. "How to do the right thing" — Behavior-based agent architectures
- **Brooks, R. (1991)**. "Intelligence without representation" — Emergent behavior from simple agents
- **Shoham & Leyton-Brown (2008)**. "Multiagent Systems" — Mechanism design, auction theory
- **Woolley et al. (2010)**. "Evidence for a collective intelligence factor" — Group intelligence emergence
- **Relevant crates**: `tokio` (async agent execution), `crossbeam` (lock-free communication)

---

## Edge Cases and Failure Modes

1. **Bid starvation**: One agent consistently outbids all others, monopolizing resources. Mitigation: diminishing returns — consecutive wins increase an agent's effective cost.

2. **Coalition deadlock**: Two agents each waiting for the other's output. Mitigation: timeout on coalition execution; if no progress in 50 ticks, dissolve and re-bid.

3. **Confidence collapse**: An agent's confidence drops to near-zero after repeated failures. Mitigation: minimum confidence floor of 0.1 (agent can always bid, just weakly).

4. **Safety veto storm**: SafetyAgent vetoes everything during a period of high uncertainty. Mitigation: veto requires specific safety justification; generic "uncertain" is not sufficient grounds.

5. **Emergent collusion**: Two agents learn to always bid together, effectively becoming one agent. This isn't necessarily bad (it's specialization), but monitor for resource waste.

---

## Interaction with Other Subsystems

- **Goal Market**: Agents are the bidders in the goal market. The market resolves bids; agents generate them.
- **Affective Economy**: Affect modulates bid scoring (detailed in affective-economy.md). Agent confidence is also affected by system-wide affect.
- **Memory Palace**: Agents access memory for context. The MemoryAgent specifically manages memory health.
- **Homunculus**: The MetaAgent uses homunculus-like self-prediction to monitor other agents. The homunculus monitors the society as a whole.
- **Predictive Processing**: Surprise signals are distributed to all agents as part of their perception. Each agent filters for domain-relevant surprises.
- **Hardware Scaling**: Agent count is bounded by device tier. The MCC sheds agents when under resource pressure.
- **Self-Modification**: Agents can propose self-modifications (via the goal market), but only the SelfModificationEngine can execute them.
- **TUI**: In Trace mode, agent activity is rendered showing current bids, executions, and coalition state. In Paranoia mode, full bid history and confidence trajectories are visible.
- **Skill Extraction**: The SkillMiningAgent operates on a longer timescale, accumulating evidence across sessions. It interacts with `~/.kc/skills/` for persistence and the journal for attribution.
- **Project Context**: Agents read `.kc/steering/` documents as hard constraints. Violations of steering docs generate high-priority prediction errors that agents must address.
