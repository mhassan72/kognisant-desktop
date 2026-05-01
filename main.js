const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("path");
const isDev = process.env.NODE_ENV === "development" || !app.isPackaged;

/**
 * Native Rust Integration
 * We load the compiled Rust binary directly into the Node.js process.
 * This is the "Kognisant Kernel" - no HTTP server, no ports, zero latency.
 */
let kernel;
try {
  // The .node binary is generated in the rust-kernel folder
  const { Kernel } = require("./rust-kernel");
  kernel = new Kernel();
  console.log("Kognisant Kernel successfully linked to Electron process.");
} catch (err) {
  console.error("Failed to load Kognisant Kernel:", err);
}

function createWindow() {
  const mainWindow = new BrowserWindow({
    title: "Kognisant Core",
    width: 1000,
    height: 750,
    frame: false, // Frameless as requested
    backgroundColor: "#0f172a",
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, "preload.js"),
    },
  });

  // In development, load from the Vite dev server
  // In production, load the built index.html
  if (isDev) {
    mainWindow.loadURL("http://localhost:5173");
    // mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadFile(path.join(__dirname, "frontend/dist/index.html"));
  }
}

/**
 * IPC Bridge: The "Link" between UI and Kognisant Kernel
 * Responsibility (SRP): Relaying messages from the Vue frontend
 * directly to the native Rust functions.
 */
ipcMain.handle("kernel:execute", async (event, input) => {
  if (!kernel) return "Error: Kognisant Kernel not loaded.";

  // This call happens in-process. No network stack involved.
  return kernel.executeCommand(input);
});

ipcMain.handle("kernel:diagnostics", async () => {
  if (!kernel) return "Error: Kognisant Kernel not loaded.";
  return kernel.runDiagnostics();
});

// Window Controls for Frameless UI
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

app.whenReady().then(() => {
  createWindow();

  app.on("activate", function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", function () {
  if (process.platform !== "darwin") app.quit();
});
