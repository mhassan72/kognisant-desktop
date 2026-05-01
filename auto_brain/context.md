# Kognisant Core Project Context

## Architecture
- **Kernel**: Rust-based Native Module using **NAPI-RS**.
- **Frontend**: Vue 3 + Tailwind CSS running in **Electron**.
- **Communication**: Direct FFI (Foreign Function Interface) via Node.js native bindings.
- **IPC Link**: Electron `main.js` loads the `.node` binary and exposes it to Vue via `preload.js` and `contextBridge`.
- **Connectivity**: **Zero-Server Architecture**. No local HTTP ports, no network sockets, zero latency.

## Project Status
- **Kernel**: Rust code in `/rust-kernel`. Compiled into a native Node.js addon (`kognisant-kernel`).
- **Electron**: Configured as the main entry point (`main.js`). Manages window lifecycle and provides the "bridge" to Rust.
- **Frontend**: Vue 3 application in `/frontend`. Communicates with Rust via `window.kognisant.kernel`.
- **Environment**: Compatible with Rust 1.85.0. Problematic crates are version-pinned in `rust-kernel/Cargo.toml`.

## Key Components
- `/rust-kernel/src/lib.rs`: Native Rust logic (`KognisantEngine`) exposed via NAPI-RS macros.
- `/main.js`: Electron Main process. Loads the Kognisant kernel and handles window management.
- `/preload.js`: Secure bridge between the Electron main process and the Kognisant UI.
- `/frontend/src/App.vue`: Root UI component driving the command flow.
- `/package.json`: Root orchestrator using `concurrently` to manage kernel builds and frontend development.

## Multi-Agent Notes
- **DO NOT** use `invoke` (Tauri-specific). Use `window.kognisant.kernel.execute()` for logic.
- **DO NOT** start Axum or any HTTP servers. The Rust code must stay as a library (`cdylib`).
- Frameless window dragging is handled by `-webkit-app-region: drag` in CSS/HTML.
- Always run `npm run build:kernel` when changing Rust code to refresh the native bindings.