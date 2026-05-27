#![deny(clippy::all)]

#[macro_use]
extern crate napi_derive;

use napi::bindgen_prelude::*;
use serde::{Deserialize, Serialize};

/// --- Agentic Interaction Models (OOP/SRP) ---

/// Represents a single unit of work or communication from the agentic stream.
/// Matches the high-density style of modern AI IDEs (Command results, File reads, Thoughts).
#[derive(Serialize, Deserialize, Debug, Clone)]
#[napi(object)]
pub struct KernelEvent {
    pub id: String,
    pub event_type: String, // "message", "thought", "command", "file_op", "error"
    pub agent_name: String,
    pub message: String,
    pub detail: Option<String>,     // The raw command or file path
    pub sub_detail: Option<String>, // Status message or line ranges (e.g., "270 - 471")
    pub state: String,              // "info", "success", "error", "warning", "pending"
    pub timestamp: String,
}

/// Represents a discrete objective the agent is pursuing.
#[derive(Serialize, Deserialize, Debug, Clone)]
#[napi(object)]
pub struct SubTask {
    pub id: String,
    pub description: String,
    pub status: String, // "pending", "active", "completed", "failed"
}

/// The structured response from the Rust Kernel to the UI.
/// Responsibility: Providing a snapshot of the agent's mind and actions.
#[derive(Serialize, Deserialize, Debug, Clone)]
#[napi(object)]
pub struct KernelResponse {
    pub content: String,
    pub events: Vec<KernelEvent>,
    pub active_tasks: Vec<SubTask>,
}

/// Directory tree structure for the Navigator.
#[derive(Serialize, Deserialize, Debug, Clone)]
#[napi(object)]
pub struct FileNode {
    pub name: String,
    pub path: String,
    pub is_directory: bool,
    pub children: Option<Vec<FileNode>>,
}

/// --- Kognisant Core Logic Engine ---

pub struct KognisantEngine {
    version: String,
}

impl KognisantEngine {
    pub fn new() -> Self {
        Self {
            version: env!("CARGO_PKG_VERSION").to_string(),
        }
    }

    /// Orchestrates a complex agentic response.
    /// Simulates multi-step reasoning, command execution, and file interaction.
    pub fn orchestrate_response(&self, input: &str) -> KernelResponse {
        let mut events = Vec::new();
        let mut tasks = Vec::new();

        // 1. Initial Thought Step
        events.push(KernelEvent {
            id: "ev_1".to_string(),
            event_type: "thought".to_string(),
            agent_name: "Nova".to_string(),
            message: format!("Analyzing system state for: '{}'", input),
            detail: None,
            sub_detail: None,
            state: "info".to_string(),
            timestamp: "14:20:01".to_string(),
        });

        // 2. Simulated Command Execution (Error Case like the reference image)
        events.push(KernelEvent {
            id: "ev_2".to_string(),
            event_type: "command".to_string(),
            agent_name: "System".to_string(),
            message: "Running pytest verification...".to_string(),
            detail: Some("./venv/bin/python -m pytest tests/test_runtime.py".to_string()),
            sub_detail: Some("[Command timed out after 30000ms]".to_string()),
            state: "error".to_string(),
            timestamp: "14:20:31".to_string(),
        });

        // 3. File Read Action (Context Gathering)
        events.push(KernelEvent {
            id: "ev_3".to_string(),
            event_type: "file_op".to_string(),
            agent_name: "Architect".to_string(),
            message: "Reading core logic for analysis".to_string(),
            detail: Some("kognisant_core_runtime.py".to_string()),
            sub_detail: Some("270 - 471".to_string()),
            state: "info".to_string(),
            timestamp: "14:20:32".to_string(),
        });

        // Add Active Task
        tasks.push(SubTask {
            id: "task_1".to_string(),
            description: "Resolve runtime hang in Python environment".to_string(),
            status: "active".to_string(),
        });

        let content = if input.to_lowercase().contains("test") {
            "The imports appear to be hanging (likely firebase_admin trying to connect). Syntax checks pass, but a running instance is required for full validation. I recommend checking the integration points.".to_string()
        } else {
            "I have initialized the diagnostic sequence. I am monitoring the kernel-shell link and awaiting further instructions.".to_string()
        };

        KernelResponse {
            content,
            events,
            active_tasks: tasks,
        }
    }

    /// Recursively builds the directory structure.
    pub fn get_workspace_tree(&self, root: &str) -> FileNode {
        FileNode {
            name: "kognisant-core".to_string(),
            path: root.to_string(),
            is_directory: true,
            children: Some(vec![
                FileNode {
                    name: "rust-kernel".to_string(),
                    path: format!("{}/rust-kernel", root),
                    is_directory: true,
                    children: Some(vec![
                        FileNode {
                            name: "src".to_string(),
                            path: format!("{}/rust-kernel/src", root),
                            is_directory: true,
                            children: None,
                        },
                        FileNode {
                            name: "Cargo.toml".to_string(),
                            path: format!("{}/rust-kernel/Cargo.toml", root),
                            is_directory: false,
                            children: None,
                        },
                    ]),
                },
                FileNode {
                    name: "frontend".to_string(),
                    path: format!("{}/frontend", root),
                    is_directory: true,
                    children: None,
                },
                FileNode {
                    name: "main.js".to_string(),
                    path: format!("{}/main.js", root),
                    is_directory: false,
                    children: None,
                },
            ]),
        }
    }
}

/// --- Native N-API Kernel Bridge ---

#[napi]
pub struct Kernel {
    engine: KognisantEngine,
}

#[napi]
impl Kernel {
    #[napi(constructor)]
    pub fn new() -> Self {
        Kernel {
            engine: KognisantEngine::new(),
        }
    }

    /// Entry point for all agentic instructions from the UI.
    #[napi]
    pub fn execute_agentic_command(&self, input: String) -> KernelResponse {
        self.engine.orchestrate_response(&input)
    }

    /// Fetches the project hierarchy.
    #[napi]
    pub fn get_workspace_tree(&self, root_path: String) -> FileNode {
        self.engine.get_workspace_tree(&root_path)
    }

    /// Validates Kernel health and N-API bridge connectivity.
    #[napi]
    pub fn run_diagnostics(&self) -> String {
        format!(
            "KOGNISANT_KERNEL_OK\nEngine_Version: {}\nLink: Synchronous_NAPI\nMode: Agentic_IDE",
            self.engine.version
        )
    }
}
