# Phoenix Desktop Steering Document

This document defines the core development principles, coding standards, and architectural constraints for the Phoenix Desktop project using the **Electron + Native Rust Kernel** architecture.

## 1. Architectural Philosophy: The "Native Kernel"
*   **Rust as the Core Engine**: All business logic, state management, and OS-level operations must reside in the Rust "Kernel" (`rust-kernel`).
*   **Direct Bindings (NAPI-RS)**: Rust is compiled into a native Node.js binary (`.node`). It is loaded directly into the Electron main process. **Zero Network Overhead**.
*   **No Local Servers**: Internal communication MUST NOT use HTTP, WebSockets, or local ports. All communication happens via memory-mapped IPC or direct FFI calls.
*   **Frameless UI**: The application is frameless. Window movement and controls are implemented via CSS (`-webkit-app-region: drag`) and custom HTML components calling the Electron bridge.

## 2. Coding Standards

### Rust (The Kernel)
*   **OOP (Object-Oriented Programming)**: Model domain logic using structs and traits. Encapsulate state within structs and expose behavior through `impl` blocks.
*   **SRP (Single Responsibility Principle)**: Each struct, module, and function must have one reason to change. Separate the `NAPI` bridge logic from the pure Rust domain logic.
*   **Crate Type**: The Rust project must remain a `cdylib` to be compatible with Node.js bindings.
*   **Safe FFI**: Use `napi-rs` macros to handle the conversion between JavaScript types and Rust types.

### Electron (The Bridge)
*   **Main Process**: Responsible for loading the Rust Kernel and handling window lifecycle. It acts as the "Service Provider".
*   **Preload Script**: Use `contextBridge` to expose specific, safe APIs to the frontend. Never expose the full `ipcRenderer` or `remote` modules.
*   **Isolation**: Keep `contextIsolation: true` and `nodeIntegration: false` in `webPreferences`.

### Vue 3 & Tailwind (The Presentation)
*   **Component-Based Architecture**: Use Vue 3's Composition API (`<script setup>`). Components must be self-contained and stored in nested folders.
*   **Layouts**: Use a dedicated `layouts/` directory for top-level app structures.
*   **Utility-First Styling**: Exclusively use Tailwind CSS.
*   **Stateless UI**: The UI should reflect the state of the Rust Kernel. Avoid duplicating complex logic in JavaScript.

## 3. "The No-Fly List" (Avoidance Rules)
*   **NO `axum`, `actix`, or `rocket`**: Do not start web servers in Rust.
*   **NO `localhost` fetch**: Do not use `fetch()` or `axios` for internal kernel communication.
*   **NO Global `window` Access**: Do not rely on `window.__TAURI__` or other platform-specific globals outside of the defined `window.phoenix` bridge.

## 4. Environment-Specific Constraints
*   **Rust Compatibility**: Pin dependencies in `rust-kernel/Cargo.toml` to remain compatible with **Rust 1.85.0**.
*   **Build Lifecycle**: When Rust code changes, the native module must be rebuilt (`npm run kernel:build`) before restarting Electron.