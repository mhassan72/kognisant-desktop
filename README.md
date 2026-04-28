# 🕊️ Phoenix Desktop

A high-performance, professional-grade desktop application boilerplate utilizing a **Native Rust Kernel** integrated directly into **Electron** via **N-API**, featuring a **Vue 3** frontend with **Tailwind CSS**.

## 🚀 The "Phoenix Kernel" Architecture

Phoenix Desktop is built on a **Zero-Server Design**. Unlike typical desktop frameworks that run a local HTTP server to bridge languages, Phoenix uses direct memory-mapped bindings. This eliminates network latency, bypasses firewall issues, and prevents port conflicts.

### Key Pillars:
- **Rust Kernel (`/rust-kernel`)**: The high-performance "Brain." Compiled into a native Node.js `.node` binary using [NAPI-RS](https://napi.rs/). Handles CPU-intensive logic and OS-level operations at native speed.
- **Electron Shell (`main.js`)**: The "Body." Loads the Rust library directly into the main process. Manages window lifecycles and secure IPC.
- **Vue 3 Frontend (`/frontend`)**: The "Face." A reactive, component-based UI using the Composition API and Tailwind CSS for rapid, modern styling.

---

## 📂 Project Structure

```text
phoenix_desktop/
├── rust-kernel/            # Rust Source (The Engine)
│   ├── src/lib.rs          # NAPI Bindings & Domain Logic
│   ├── .cargo/config.toml  # Linker flags for macOS/Linux/Windows
│   └── Cargo.toml          # Rust dependencies (Pinned for 1.85.0 compatibility)
├── frontend/               # Vue 3 Source (The Presentation)
│   ├── src/components/     # SRP-compliant nested components
│   ├── src/layouts/        # Global App layouts (e.g., Frameless shell)
│   └── vite.config.js      # Optimized Vite config for Electron
├── main.js                 # Electron Main Process (Orchestrator)
├── preload.js              # Secure Context Bridge (The IPC Link)
├── package.json            # Root configuration & build orchestration
└── auto_brain/             # Multi-agent memory & steering documentation
```

---

## 🚦 Getting Started

### 📦 Prerequisites
- **Rust**: `1.85.0` (Stable)
- **Node.js**: `18.x` or higher
- **C/C++ Compiler**: `Clang` or `MSVC` (Required by NAPI-RS for linking)

### 🛠️ Installation
Install all dependencies across the workspace (Root, Frontend, and Kernel):
```bash
npm run install:all
```

### 💻 Development
Start the full-stack development environment:
```bash
npm run dev
```
*This command concurrently builds the Rust binary, starts the Vite HMR server, and launches Electron.*

---

## 🔗 How it Works: The IPC Bridge

Phoenix follows a strict **Secure Bridge Pattern**. The UI is isolated and cannot access the Kernel directly. Instead, communication flows through a controlled tunnel:

1. **Rust**: Define a logic engine in `rust-kernel/src/lib.rs` using the `#[napi]` macro.
2. **Main Process**: `main.js` instantiates the `Kernel` class from the compiled `.node` module.
3. **Preload**: `preload.js` exposes specific methods via `contextBridge.exposeInMainWorld('phoenix', ...)`.
4. **Vue 3**: Components call `window.phoenix.kernel.execute(data)` and receive reactive updates.

---

## 🧠 Development Steering (Best Practices)

### 🧩 Single Responsibility Principle (SRP)
- **Rust**: Only for business logic, data processing, and heavy lifting. It should not know about the UI.
- **Vue**: Only for presentation. It should not contain complex algorithms or state persistence logic.

### 🏗️ Object-Oriented Programming (OOP)
- Model the Kernel using Rust structs and impl blocks.
- Inject the Kernel as a singleton in the Electron main process.

### 🖼️ Frameless UI
The app is **frameless** by design.
- Move the window using the `.drag-region` class (powered by `-webkit-app-region: drag`).
- Use the custom `TitleBar.vue` component for native-feeling minimize, maximize, and close controls.

### ⚙️ Dependency Stability
To ensure compatibility with environment-specific Rust versions (1.85.0), several crates are **version-pinned** in `rust-kernel/Cargo.toml`. Always check this file before adding new crates.

---

## 📜 Available Scripts

| Script | Description |
| :--- | :--- |
| `npm run dev` | Full development boot (Kernel + Vite + Electron) |
| `npm run build` | Production build of the Kernel and Frontend |
| `npm run build:kernel` | Compiles Rust into a production `.node` addon |
| `npm run install:all` | Recursive npm install across all directories |
| `npm run clean` | Purge all `node_modules` and build artifacts |

---
*Built with the Phoenix Kernel Architecture — Zero Servers. Zero Latency. Pure Performance.*