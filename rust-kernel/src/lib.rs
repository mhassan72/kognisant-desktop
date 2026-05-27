#![deny(clippy::all)]

#[macro_use]
extern crate napi_derive;

use napi::bindgen_prelude::*;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

/// --- Agentic Interaction Models ---

#[derive(Serialize, Deserialize, Debug, Clone)]
#[napi(object)]
pub struct KernelEvent {
    pub id: String,
    pub event_type: String, // "message", "thought", "command", "file_op", "error"
    pub agent_name: String,
    pub message: String,
    pub detail: Option<String>,
    pub sub_detail: Option<String>,
    pub state: String, // "info", "success", "error", "warning", "pending"
    pub timestamp: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[napi(object)]
pub struct SubTask {
    pub id: String,
    pub description: String,
    pub status: String, // "pending", "active", "completed", "failed"
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[napi(object)]
pub struct KernelResponse {
    pub content: String,
    pub events: Vec<KernelEvent>,
    pub active_tasks: Vec<SubTask>,
}

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
    pub version: String,
}

impl KognisantEngine {
    pub fn new() -> Self {
        Self {
            version: env!("CARGO_PKG_VERSION").to_string(),
        }
    }

    /// Orchestrates a mock agentic response for UI demonstration.
    pub fn orchestrate_response(&self, input: &str) -> KernelResponse {
        let mut events = Vec::new();
        let mut tasks = Vec::new();

        events.push(KernelEvent {
            id: "ev_1".to_string(),
            event_type: "thought".to_string(),
            agent_name: "Nova".to_string(),
            message: format!("Analyzing workspace context for: '{}'", input),
            detail: None,
            sub_detail: None,
            state: "info".to_string(),
            timestamp: "14:20:01".to_string(),
        });

        events.push(KernelEvent {
            id: "ev_2".to_string(),
            event_type: "command".to_string(),
            agent_name: "System".to_string(),
            message: "Verifying environment integrity...".to_string(),
            detail: Some("cargo check".to_string()),
            sub_detail: Some(
                "Finished dev profile [unoptimized + debuginfo] target(s) in 0.04s".to_string(),
            ),
            state: "success".to_string(),
            timestamp: "14:20:02".to_string(),
        });

        tasks.push(SubTask {
            id: "task_init".to_string(),
            description: "Synchronize local project context".to_string(),
            status: "completed".to_string(),
        });

        let content = format!(
            "Kernel synchronized. I have verified the current project structure. How can I assist with your development task?"
        );

        KernelResponse {
            content,
            events,
            active_tasks: tasks,
        }
    }

    /// Recursively scans the directory to build a real file tree.
    pub fn scan_directory(&self, path: &Path) -> Result<FileNode> {
        let name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("root")
            .to_string();

        let is_directory = path.is_dir();
        let mut children = None;

        if is_directory {
            let mut nodes = Vec::new();
            if let Ok(entries) = fs::read_dir(path) {
                for entry in entries.flatten() {
                    let entry_path = entry.path();
                    let entry_name = entry_path
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or("");

                    // Filter out common ignored directories to prevent UI lag/recursion depth issues
                    if entry_name == "target"
                        || entry_name == "node_modules"
                        || entry_name == ".git"
                    {
                        continue;
                    }

                    if let Ok(node) = self.scan_directory(&entry_path) {
                        nodes.push(node);
                    }
                }
            }
            // Sort: Directories first, then alphabetical
            nodes.sort_by(|a, b| {
                if a.is_directory != b.is_directory {
                    b.is_directory.cmp(&a.is_directory)
                } else {
                    a.name.to_lowercase().cmp(&b.name.to_lowercase())
                }
            });
            children = Some(nodes);
        }

        Ok(FileNode {
            name,
            path: path.to_string_lossy().to_string(),
            is_directory,
            children,
        })
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

    #[napi]
    pub fn execute_agentic_command(&self, input: String) -> KernelResponse {
        self.engine.orchestrate_response(&input)
    }

    #[napi]
    pub fn get_workspace_tree(&self, root_path: String) -> Result<FileNode> {
        let path = Path::new(&root_path);
        self.engine.scan_directory(path)
    }

    #[napi]
    pub fn run_diagnostics(&self) -> String {
        format!(
            "KOGNISANT_KERNEL_OK\nEngine_Version: {}\nLink: Synchronous_NAPI\nMode: Agentic_IDE",
            self.engine.version
        )
    }
}
