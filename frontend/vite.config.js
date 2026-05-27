import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],

  // Vite options tailored for Electron development
  clearScreen: false,

  server: {
    port: 5173,
    strictPort: true,
    host: "127.0.0.1", // Force 127.0.0.1 to match Electron's loadURL
    hmr: {
      protocol: "ws",
      host: "127.0.0.1",
      port: 5173,
    },
  },

  // Fix for assets loading in Electron
  base: "./",

  build: {
    // Produce sourcemaps for debug builds
    sourcemap: true,
    // Ensure the output directory is consistent with main.js expectations
    outDir: "dist",
    emptyOutDir: true,
  },
});
