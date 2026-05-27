const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("path");
const isDev = process.env.NODE_ENV === "development" || !app.isPackaged;

/**
 * Kognisant Core: Native Rust Integration
 * Loading the compiled Rust Kernel via N-API.
 *
 * Responsibility (SRP): Maintaining the lifecycle of the Rust logic engine
 * and exposing it to the Electron process memory.
 */
let kernel;
try {
  const { Kernel } = require("./rust-kernel");
  kernel = new Kernel();
  console.log("[SHELL] Kognisant Kernel successfully linked to main process.");
} catch (err) {
  console.error(
    "[SHELL] Critical Error: Failed to load Kognisant Kernel binary:",
    err,
  );
}

function createWindow() {
  const mainWindow = new BrowserWindow({
    title: "Kognisant Core",
    width: 1400,
    height: 900,
    minWidth: 1000,
    minHeight: 700,
    frame: false, // Frameless for custom agentic UI
    backgroundColor: "#0f172a",
    show: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, "preload.js"),
    },
  });

  // In development, we use the Vite HMR server
  if (isDev) {
    mainWindow.loadURL("http://127.0.0.1:5173");
    mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadFile(path.join(__dirname, "frontend/dist/index.html"));
  }

  mainWindow.once("ready-to-show", () => {
    mainWindow.show();
  });
}

/**
 * Agentic IPC Bridge Handlers
 *
 * Responsibility (SRP): Relaying structured instructions between the Vue frontend
 * and the Native Rust Engine. This handles high-density data like ThoughtSteps,
 * SubTasks, and Directory Nodes.
 */

// Executes a prompt through the Rust agentic orchestrator
ipcMain.handle("kernel:agentic-execute", async (event, input) => {
  if (!kernel)
    throw new Error("Kognisant Kernel is offline or failed to initialize.");
  // Direct FFI call to Rust. Returns KernelResponse struct.
  return kernel.executeAgenticCommand(input);
});

// Retrieves the project workspace tree for the Codex File Navigator
ipcMain.handle("kernel:get-workspace", async (event, rootPath) => {
  if (!kernel) throw new Error("Kognisant Kernel offline.");
  const target = rootPath || app.getAppPath();
  return kernel.getWorkspaceTree(target);
});

// System diagnostics
ipcMain.handle("kernel:diagnostics", async () => {
  if (!kernel) return "STATUS_DISCONNECTED";
  return kernel.runDiagnostics();
});

/**
 * Window Management Protocol
 *
 * Powers the TitleBar component's minimize/maximize/close logic.
 */
ipcMain.on("window:minimize", () => {
  BrowserWindow.getFocusedWindow()?.minimize();
});

ipcMain.on("window:maximize", () => {
  const win = BrowserWindow.getFocusedWindow();
  if (win?.isMaximized()) {
    win.unmaximize();
  } else {
    win?.maximize();
  }
});

ipcMain.on("window:close", () => {
  app.quit();
});

// App Lifecycle
app.whenReady().then(() => {
  createWindow();

  app.on("activate", function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", function () {
  if (process.platform !== "darwin") app.quit();
});
