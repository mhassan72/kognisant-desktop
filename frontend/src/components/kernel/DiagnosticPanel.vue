<script setup>
/**
 * DiagnosticPanel Component
 * Responsibility (SRP): Rendering the output or error messages received from the Rust Kernel.
 * Design: Monospaced terminal-like output for consistency with the "Kernel" theme.
 */

defineProps({
  result: {
    type: String,
    default: ''
  },
  error: {
    type: String,
    default: ''
  },
  loading: {
    type: Boolean,
    default: false
  }
});
</script>

<template>
  <div class="mt-6">
    <div class="bg-black/40 rounded-xl overflow-hidden border border-white/5 shadow-inner">
      <!-- Panel Header -->
      <div class="bg-white/5 px-4 py-2 flex items-center justify-between border-b border-white/5">
        <div class="flex gap-1.5">
          <div class="w-2.5 h-2.5 rounded-full bg-red-500/50"></div>
          <div class="w-2.5 h-2.5 rounded-full bg-amber-500/50"></div>
          <div class="w-2.5 h-2.5 rounded-full bg-emerald-500/50"></div>
        </div>
        <span class="text-[10px] text-phoenix-muted font-mono tracking-tighter">KERNEL_OUTPUT.LOG</span>
      </div>

      <!-- Content Area -->
      <div class="p-5 min-h-[120px] font-mono text-sm overflow-x-auto">
        <!-- Loading State -->
        <div v-if="loading" class="flex flex-col gap-2 animate-pulse">
          <div class="h-4 bg-white/5 rounded w-3/4"></div>
          <div class="h-4 bg-white/5 rounded w-1/2"></div>
        </div>

        <!-- Error State -->
        <div v-else-if="error" class="text-rose-400">
          <span class="font-bold mr-2 text-rose-500 underline uppercase">[Error]</span>
          <span>{{ error }}</span>
        </div>

        <!-- Success Result -->
        <div v-else-if="result" class="text-emerald-400/90 whitespace-pre-wrap leading-relaxed">
          <span class="text-emerald-500/50 block mb-2">$ kernel --execute --verbose</span>
          {{ result }}
        </div>

        <!-- Empty/Awaiting State -->
        <div v-else class="text-phoenix-muted/40 italic flex items-center justify-center h-full pt-4">
          Awaiting kernel command...
        </div>
      </div>
    </div>

    <!-- Metadata Footer -->
    <div v-if="result && !loading" class="mt-3 flex justify-end">
      <span class="text-[10px] text-phoenix-muted bg-white/5 px-2 py-1 rounded border border-white/5 uppercase">
        Memory IPC: 0.04ms
      </span>
    </div>
  </div>
</template>

<style scoped>
pre {
  scrollbar-width: thin;
  scrollbar-color: rgba(255, 255, 255, 0.1) transparent;
}
</style>
