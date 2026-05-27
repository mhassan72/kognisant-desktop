#![deny(clippy::all)]

#[macro_use]
extern crate napi_derive;

/// Domain Engine (SRP: Pure logic, unaware of Node.js/FFI)
/// Encapsulates the core business rules for Kognisant.
pub struct KognisantEngine {
    version: String,
}

impl KognisantEngine {
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
        format!("Kognisant Engine v{}", self.version)
    }
}

/// Native Node.js Class (OOP: Bridge between Rust and JS)
/// Responsibility (SRP): Mapping Node.js calls to the internal Kognisant Engine.
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

    /// Business logic exposed as a native function.
    /// This is called directly from Electron/Node.js memory.
    #[napi]
    pub fn execute_command(&self, input: String) -> String {
        let result = self.engine.process_text(&input);
        format!(
            "{}\n\n[Kognisant Kernel Verified: {}]",
            result,
            self.engine.get_info()
        )
    }

    /// Diagnostic report for testing the link.
    #[napi]
    pub fn run_diagnostics(&self) -> String {
        format!(
            "KOGNISANT_DIAGNOSTIC_OK\nSource: Native Rust Module\nInterface: N-API Bindings\nEngine: {}",
            self.engine.get_info()
        )
    }
}
