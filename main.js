const { app, BrowserWindow, ipcMain, nativeTheme } = require("electron");
const path = require("path");
const isDev = process.env.NODE_ENV === "development" || !app.isPackaged;

// Force application name for menu and system indicators
app.name = "Kognisant Core";

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
    width: 1440,
    height: 960,
    minWidth: 1024,
    minHeight: 768,

    // Frameless configuration using OS-native controls
    // Reference Style: Modern Transparent/Vibrant IDE
    frame: false,
    titleBarStyle: "hidden",

    // Standardize traffic light position for macOS
    ...(process.platform === "darwin"
      ? {
          trafficLightPosition: { x: 16, y: 12 },
        }
      : {}),

    // Support for Windows 10/11 native title bar buttons in a frameless window
    titleBarOverlay:
      process.platform === "win32"
        ? {
            color: "#2f3640",
            symbolColor: "#f5f6fa",
            height: 32,
          }
        : false,

    // Aesthetic: Coherent flat theme matching brand colors
    transparent: false,
    backgroundColor: "#2f3640",

    show: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, "preload.js"),
      // Required for specific CSS filter effects
      enablePreferredColorScheme: true,
    },
  });

  // In development, we use the Vite HMR server
  if (isDev) {
    mainWindow.loadURL("http://127.0.0.1:5173");
    // Detach DevTools to prevent layout disruption in agentic workspace
    mainWindow.webContents.openDevTools({ mode: "detach" });
  } else {
    mainWindow.loadFile(path.join(__dirname, "frontend/dist/index.html"));
  }

  // Graceful show to prevent white flash
  mainWindow.once("ready-to-show", () => {
    mainWindow.show();
  });
}

/**
 * Agentic IPC Bridge Handlers
 *
 * Responsibility (SRP): Relaying structured instructions between the Vue frontend
 * and the Native Rust Engine.
 */

// Executes a prompt through the Rust agentic orchestrator
ipcMain.handle("kernel:agentic-execute", async (event, input) => {
  if (!kernel)
    throw new Error("Kognisant Kernel is offline or failed to initialize.");
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
 * Native Window Control Fallbacks
 *
 * While we use titleBarStyle: 'hidden' for native buttons,
 * these handlers remain for custom UI triggers if needed.
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

// Application Lifecycle
app.whenReady().then(() => {
  createWindow();

  app.on("activate", function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", function () {
  if (process.platform !== "darwin") app.quit();
});
