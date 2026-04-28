const { contextBridge, ipcRenderer } = require('electron');

/**
 * Phoenix Desktop Preload Script
 *
 * Responsibility (SRP): Providing a secure, isolated bridge between the
 * Vue 3 frontend and the Electron Main process (where the Rust Kernel lives).
 *
 * This ensures the UI can never access Node.js or Native Rust memory directly,
 * maintaining the security sandbox while allowing high-speed IPC communication.
 */

contextBridge.exposeInMainWorld('phoenix', {
    /**
     * Kernel Execution API
     * Direct link to the Rust Processor Engine
     */
    kernel: {
        execute: (input) => ipcRenderer.invoke('kernel:execute', input),
        runDiagnostics: () => ipcRenderer.invoke('kernel:diagnostics')
    },

    /**
     * Window Management API
     * Powers the custom frameless titlebar controls
     */
    window: {
        minimize: () => ipcRenderer.send('window:minimize'),
        maximize: () => ipcRenderer.send('window:maximize'),
        close: () => ipcRenderer.send('window:close')
    }
});

console.log('Phoenix Security Bridge: Initialized');
