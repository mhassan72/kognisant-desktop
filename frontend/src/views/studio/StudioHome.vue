<script setup>
/**
 * StudioHome View
 * Responsibility: Entry point for the creative/visual logic module.
 * Status: Under construction.
 */
</script>

<template>
  <div class="flex flex-col items-center justify-center min-h-[60vh] text-center px-6">
    <div class="w-20 h-20 bg-kognisant-accent/10 border border-kognisant-accent/20 rounded-2xl flex items-center justify-center mb-6">
      <div class="w-10 h-10 border-2 border-kognisant-accent border-dashed rounded-lg animate-[spin_10s_linear_infinite]"></div>
    </div>

    <h1 class="text-4xl font-black tracking-tighter text-white mb-2 uppercase">
      Kognisant <span class="text-kognisant-accent">Studio</span>
    </h1>
    <p class="text-kognisant-muted max-w-md leading-relaxed mb-8">
      The creative visual suite for autonomous asset generation and logic mapping.
      This module is currently being calibrated in the Rust Kernel.
    </p>

    <div class="grid grid-cols-3 gap-4 w-full max-w-lg">
      <div v-for="i in 3" :key="i" class="h-24 bg-white/5 border border-white/5 rounded-xl flex items-end p-3">
        <div class="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
          <div class="h-full bg-kognisant-accent/30 w-1/3 animate-pulse"></div>
        </div>
      </div>
    </div>

    <div class="mt-12 text-[10px] uppercase tracking-[0.2em] text-kognisant-accent font-bold px-4 py-2 border border-kognisant-accent/20 rounded-full">
      System Calibration: 14%
    </div>
  </div>
</template>

<style scoped>
/* Scoped styles for Studio placeholder */
</style>
