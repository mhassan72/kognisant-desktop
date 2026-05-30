# Tool System — Deep Dive

The tool system provides the motor cortex with concrete capabilities. Tools are the mechanism by which the cognitive kernel affects the external world.

---

## Summary

Tools are typed, sandboxed, approval-gated functions that agents invoke to accomplish goals. Each tool has a schema (inputs/outputs), a risk category (for approval routing), and execution constraints (timeout, resource limits).

---

## Core Tools

| Tool | Category | Approval | Description |
|------|----------|----------|-------------|
| `file_read` | Read | Never | Read file contents within project boundary |
| `file_write` | Persistent | Configurable | Write/create file within project boundary |
| `file_delete` | Destructive | Always | Delete file within project boundary |
| `shell_exec` | External | Configurable | Execute shell command (sandboxed) |
| `search_text` | Read | Never | Ripgrep-style text search in project |
| `search_semantic` | Read | Never | Embedding-based semantic search in memory |
| `git_status` | Read | Never | Git status, log, diff |
| `git_commit` | Persistent | Configurable | Stage and commit changes |
| `git_push` | External | Always | Push to remote |
| `llm_query` | External | Budget-gated | Query LLM pool (cost tracked) |
| `memory_write` | Persistent | Configurable | Write to project-local memory |
| `skill_suggest` | Persistent | Always | Propose a new skill candidate |
| `journal_append` | Persistent | Never (system) | Append structured entry to journal |

---

## Sandboxing

Shell commands run in a restricted environment:
- Working directory: project root (cannot escape)
- Timeout: 30 seconds default (configurable per-tool)
- No network access unless tool is categorized as External
- stdout/stderr captured and fed back to perception as ProcessOutput
- Exit code determines success/failure

```rust
struct ShellSandbox {
    working_dir: PathBuf,       // Project root — enforced, cannot escape
    timeout: Duration,          // Default 30s
    env_allowlist: Vec<String>, // Only these env vars are visible
    network_allowed: bool,      // false unless tool is External category
    max_output_bytes: usize,    // 1MB default — prevents OOM from runaway output
}

impl ShellSandbox {
    fn execute(&self, command: &str, args: &[&str]) -> ToolResult {
        let child = Command::new(command)
            .args(args)
            .current_dir(&self.working_dir)
            .env_clear()
            .envs(self.filtered_env())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn();

        match child {
            Ok(mut process) => {
                let output = process.wait_with_output_timeout(self.timeout);
                match output {
                    Ok(out) => ToolResult::Success {
                        stdout: truncate(&out.stdout, self.max_output_bytes),
                        stderr: truncate(&out.stderr, self.max_output_bytes),
                        exit_code: out.status.code().unwrap_or(-1),
                    },
                    Err(_) => {
                        process.kill().ok();
                        ToolResult::Timeout { after: self.timeout }
                    }
                }
            }
            Err(e) => ToolResult::SpawnFailed { reason: e.to_string() },
        }
    }
}
```

---

## Tool Schema

```rust
struct ToolDefinition {
    name: String,
    description: String,
    category: ApprovalCategory,
    inputs: Vec<ToolParam>,
    outputs: ToolOutput,
    timeout: Duration,
    boundary: ExecutionBoundary, // ProjectOnly | UserLevel | System
}

struct ToolParam {
    name: String,
    param_type: ParamType, // String | Path | Json | Bool
    required: bool,
    validation: Option<ValidationRule>,
}

enum ParamType {
    String,
    Path,   // Validated against project boundary
    Json,
    Bool,
    Integer,
}

enum ValidationRule {
    PathWithinBoundary,         // Must be under project root
    MaxLength(usize),           // String length limit
    Pattern(String),            // Regex pattern match
    OneOf(Vec<String>),         // Enum-like constraint
}

enum ExecutionBoundary {
    ProjectOnly,  // Can only access files within .kc/ project root
    UserLevel,    // Can access ~/.kc/ (skills, preferences)
    System,       // Can access system resources (network, processes)
}

enum ToolOutput {
    Text,                       // Plain text result
    Json,                       // Structured JSON
    FileContent(PathBuf),       // File contents
    Stream,                     // Streaming output (for long-running commands)
}
```

---

## Execution Flow

```
Agent selects tool + params
    ↓
Tool schema validation (type check, boundary check)
    ↓
Approval gate (based on tool category + config)
    ↓
Execution (sandboxed, timeout-bounded)
    ↓
Result → Perception (ProcessOutput or FileChange)
    ↓
Telemetry log (tool call recorded)
```

### Detailed Execution Steps

```rust
async fn execute_tool(
    tool: &ToolDefinition,
    params: &ToolParams,
    agent: AgentId,
    approval_queue: &ApprovalQueue,
    config: &ApprovalConfig,
) -> Result<ToolResult, ToolError> {
    // 1. Schema validation
    tool.validate_params(params)?;

    // 2. Boundary check (path params must be within allowed boundary)
    for param in params.path_params() {
        if !param.is_within_boundary(tool.boundary) {
            return Err(ToolError::BoundaryViolation {
                path: param.clone(),
                boundary: tool.boundary,
            });
        }
    }

    // 3. Approval gate
    if tool.category.requires_approval(config) {
        let request = ApprovalRequest::from_tool_call(tool, params, agent);
        let decision = approval_queue.submit_and_wait(request).await;
        match decision {
            ApprovalDecision::Approve => {} // Continue
            ApprovalDecision::Deny { reason } => {
                return Err(ToolError::Denied { reason });
            }
            ApprovalDecision::Modify { modifications } => {
                // Apply modifications to params before execution
                params.apply_modifications(&modifications);
            }
            ApprovalDecision::Postpone => {
                return Err(ToolError::Postponed);
            }
        }
    }

    // 4. Execute
    let result = tool.execute(params).await?;

    // 5. Feed result back to perception
    perception_tx.send(SensoryEvent::ToolOutput {
        tool: tool.name.clone(),
        agent,
        result: result.clone(),
    }).ok();

    // 6. Telemetry
    telemetry.log(TelemetryEvent::ToolCall {
        agent,
        tool: tool.name.clone(),
        args: params.to_json(),
        result: result.summary(),
    });

    Ok(result)
}
```

---

## Tool Registry

Tools are registered at kernel startup. The registry is immutable during runtime (tools cannot be added/removed by self-modification — this is a constitutional constraint).

```rust
struct ToolRegistry {
    tools: HashMap<String, ToolDefinition>,
}

impl ToolRegistry {
    fn builtin() -> Self {
        let mut registry = Self { tools: HashMap::new() };

        registry.register(ToolDefinition {
            name: "file_read".into(),
            description: "Read file contents within project boundary".into(),
            category: ApprovalCategory::Read,
            inputs: vec![ToolParam::required("path", ParamType::Path)],
            outputs: ToolOutput::FileContent,
            timeout: Duration::from_secs(5),
            boundary: ExecutionBoundary::ProjectOnly,
        });

        registry.register(ToolDefinition {
            name: "file_write".into(),
            description: "Write or create file within project boundary".into(),
            category: ApprovalCategory::Persistent,
            inputs: vec![
                ToolParam::required("path", ParamType::Path),
                ToolParam::required("content", ParamType::String),
            ],
            outputs: ToolOutput::Json, // { "bytes_written": N }
            timeout: Duration::from_secs(10),
            boundary: ExecutionBoundary::ProjectOnly,
        });

        registry.register(ToolDefinition {
            name: "shell_exec".into(),
            description: "Execute shell command in sandboxed environment".into(),
            category: ApprovalCategory::External,
            inputs: vec![
                ToolParam::required("command", ParamType::String),
                ToolParam::optional("args", ParamType::Json),
                ToolParam::optional("timeout_secs", ParamType::Integer),
            ],
            outputs: ToolOutput::Json, // { "stdout", "stderr", "exit_code" }
            timeout: Duration::from_secs(30),
            boundary: ExecutionBoundary::ProjectOnly,
        });

        // ... remaining tools ...

        registry
    }
}
```

---

## Budget Gating for LLM Tool

The `llm_query` tool has special budget-aware gating beyond normal approval:

```rust
impl LlmQueryTool {
    async fn execute(&self, params: &ToolParams, budget: &CostTracker) -> Result<ToolResult> {
        let estimated_cost = self.estimate_cost(params);

        match budget.check_budget(estimated_cost) {
            BudgetDecision::Allowed => {
                // Proceed with query
                let response = self.llm_pool.query(params).await?;
                budget.record_spend(response.actual_cost);
                Ok(ToolResult::from(response))
            }
            BudgetDecision::RequireApproval { reason } => {
                // Escalate to approval even if tool category wouldn't normally require it
                let decision = self.approval_queue.submit_budget_approval(reason).await;
                match decision {
                    ApprovalDecision::Approve => {
                        let response = self.llm_pool.query(params).await?;
                        budget.record_spend(response.actual_cost);
                        Ok(ToolResult::from(response))
                    }
                    _ => Err(ToolError::BudgetExceeded),
                }
            }
        }
    }
}
```

---

## Open Questions / Design Decisions

1. **Custom tools**: Should users be able to define project-specific tools (e.g., a "deploy" tool)? Current plan: yes, via `.kc/tools/` directory with TOML definitions. Deferred to Phase 6+.

2. **Tool composition**: Should tools be composable (output of one feeds input of another)? Current plan: no explicit composition — agents handle sequencing via the goal market. Tools are atomic.

3. **Streaming tools**: Some tools (long builds, test suites) produce output over time. Current plan: `shell_exec` captures output progressively and feeds chunks to perception as they arrive.

4. **Tool versioning**: If a tool's behavior changes (e.g., new validation rule), should old tool calls in replay still work? Current plan: tools are versioned; replay uses the version active at recording time.

5. **Network-aware tools**: Should there be explicit "fetch URL" or "API call" tools beyond `shell_exec`? Current plan: no — `shell_exec` with `curl` covers this. Adding dedicated HTTP tools would duplicate functionality.

---

## Interaction with Other Subsystems

- **Agent Society**: Agents select tools as their "motor actions." Each agent has a preferred tool set based on its role (CoderAgent uses file_write, ResearchAgent uses search_semantic).
- **Approval System**: Tool category determines approval routing. The approval dialog shows tool name, params, and risk assessment.
- **Perception**: Tool results are fed back as sensory events (ProcessOutput, FileChange). This closes the perception-action loop.
- **Telemetry**: Every tool call is logged with agent, params, result, and duration. Enables replay and audit.
- **Goal Market**: Tool execution is the terminal action in a goal's lifecycle. A goal is "resolved" when its tool calls succeed.
- **Self-Modification**: The tool registry itself is constitutional — self-modification cannot add, remove, or alter tool definitions. This prevents the system from granting itself new capabilities.
- **Hardware Scaling**: Tool timeouts adapt to device tier (Minimal tier gets longer timeouts for shell_exec since compilation is slower).
- **TUI**: In Trace mode, active tool executions show in the action pipeline. In Paranoia mode, full params and streaming output are visible.
