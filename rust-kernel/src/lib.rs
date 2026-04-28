#![deny(clippy::all)]

#[macro_use]
extern crate napi_derive;

use napi::bindgen_prelude::*;
use serde::{Deserialize, Serialize};

/// Domain Engine (SRP: Pure logic, unaware of Node.js/FFI)
/// Encapsulates the core business rules.
pub struct PhoenixEngine {
    version: String,
}

impl PhoenixEngine {
    pub fn new() -> Self {
        Self {
            version: env!("CARGO_PKG_VERSION").to_string(),
        }
    }

    pub fn process_text(&self, input: &str) -> String {
        let reversed: String = input.chars().rev().collect();
        reversed.to_uppercase()
    }

    pub fn get_info(&self) -> String {
        format!("Phoenix Engine v{}", self.version)
    }
}

/// Native Node.js Class (OOP: Bridge between Rust and JS)
/// Responsibility (SRP): Mapping Node.js calls to the internal Engine.
#[napi]
pub struct Kernel {
    engine: PhoenixEngine,
}

#[napi]
impl Kernel {
    #[napi(constructor)]
    pub fn new() -> Self {
        Kernel {
            engine: PhoenixEngine::new(),
        }
    }

    /// Business logic exposed as a native function.
    /// This is called directly from Electron/Node.js memory.
    #[napi]
    pub fn execute_command(&self, input: String) -> String {
        let result = self.engine.process_text(&input);
        format!(
            "{}\n\n[Kernel Verified: {}]",
            result,
            self.engine.get_info()
        )
    }

    /// Diagnostic report for testing the link.
    #[napi]
    pub fn run_diagnostics(&self) -> String {
        format!(
            "DIAGNOSTIC_OK\nSource: Native Rust Module\nInterface: N-API Bindings\nEngine: {}",
            self.engine.get_info()
        )
    }
}
