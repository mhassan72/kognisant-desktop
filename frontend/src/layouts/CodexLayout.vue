<script setup>
import TitleBar from "../components/common/TitleBar.vue";
import {
  MessageSquare,
  Code2,
  Settings,
  Activity,
  Terminal as TerminalIcon,
  Cpu
} from "lucide-vue-next";

/**
 * CodexLayout
 * Responsibility: Provides the high-density, agentic workspace structure.
 * Features: Left sidebar for tools, large central workspace, and bottom status monitoring.
 */
</script>

<template>
  <div class="flex flex-col h-screen w-screen bg-kognisant-bg text-kognisant-text overflow-hidden border border-white/5">
    <!-- Frameless TitleBar (Contains Layout Switchers) -->
    <TitleBar />

    <div class="flex flex-1 pt-8 overflow-hidden">
      <!-- Activity Bar (Far Left) -->
      <aside class="w-12 bg-kognisant-card/80 border-r border-white/5 flex flex-col items-center py-4 gap-6 select-none">
        <div class="p-2 text-kognisant-accent bg-kognisant-accent/10 rounded-lg cursor-pointer">
          <MessageSquare :size="20" />
        </div>
        <div class="p-2 text-kognisant-muted hover:text-white transition-colors cursor-pointer">
          <Code2 :size="20" />
        </div>
        <div class="p-2 text-kognisant-muted hover:text-white transition-colors cursor-pointer">
          <Activity :size="20" />
        </div>
        <div class="mt-auto mb-4 flex flex-col gap-6">
          <div class="p-2 text-kognisant-muted hover:text-white transition-colors cursor-pointer">
            <Settings :size="20" />
          </div>
        </div>
      </aside>

      <!-- Main Codex Shell -->
      <div class="flex-1 flex flex-col min-w-0 overflow-hidden">
        <!-- Secondary Sidebar / Navigator Area (Optional Placeholder) -->
        <div class="flex-1 flex overflow-hidden">
          <!-- Main Content Area -->
          <main class="flex-1 relative overflow-hidden flex flex-col">
            <slot />
          </main>
        </div>

        <!-- Codex Status Bar -->
        <footer class="h-6 bg-kognisant-card border-t border-white/5 flex items-center px-3 justify-between text-[10px] uppercase tracking-wider text-kognisant-muted select-none">
          <div class="flex items-center gap-4">
            <div class="flex items-center gap-1.5 text-kognisant-accent">
              <Cpu :size="10" />
              <span>Kernel: Active</span>
            </div>
            <div class="flex items-center gap-1.5">
              <TerminalIcon :size="10" />
              <span>Session: Autonomous</span>
            </div>
          </div>
          <div class="flex items-center gap-4">
            <span>Rust IPC: 0.02ms</span>
            <span class="flex items-center gap-1">
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
              Synchronized
            </span>
          </div>
        </footer>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Scoped layout styles */
aside div {
  -webkit-app-region: no-drag;
}
</style>
