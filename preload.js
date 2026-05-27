const { contextBridge, ipcRenderer } = require("electron");

/**
 * Kognisant Core Preload Script (Agentic IDE Bridge)
 *
 * Responsibility (SRP): Providing a secure, high-speed hardware-accelerated
 * tunnel between the Vue 3 Frontend and the Native Rust Kernel.
 *
 * This bridge enables the UI to interact with autonomous agent state,
 * directory structures, and code execution without exposing Node.js internals.
 */

contextBridge.exposeInMainWorld("kognisant", {
  /**
   * Environment Metadata
   * Used for OS-native UI styling (e.g., window control placement).
   * Values: 'darwin' (macOS), 'win32' (Windows), 'linux' (Linux).
   */
  platform: process.platform,

  /**
   * Kernel Execution API
   * Direct links to the Native Rust Engine's agentic capabilities.
   */
  kernel: {
    /**
     * Executes a multi-turn prompt through the Rust orchestrator.
     * Returns a KernelResponse containing content, thought processes, and sub-tasks.
     */
    execute: (input) => ipcRenderer.invoke("kernel:agentic-execute", input),

    /**
     * Fetches the project directory tree for the Codex Navigator.
     * @param {string} rootPath - The base directory to scan.
     */
    getWorkspace: (rootPath) =>
      ipcRenderer.invoke("kernel:get-workspace", rootPath),

    /**
     * Checks the health and sync state of the Rust-to-JS bridge.
     */
    runDiagnostics: () => ipcRenderer.invoke("kernel:diagnostics"),
  },

  /**
   * Window Management API
   * Powers the custom frameless titlebar and native window behaviors.
   */
  window: {
    minimize: () => ipcRenderer.send("window:minimize"),
    maximize: () => ipcRenderer.send("window:maximize"),
    close: () => ipcRenderer.send("window:close"),
  },
});

console.log("[BRIDGE] Kognisant Agentic Security Tunnel: Synchronized");
