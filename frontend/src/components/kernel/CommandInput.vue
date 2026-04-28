<script setup>
import { ref } from 'vue';

/**
 * CommandInput Component
 * Responsibility (SRP): Handles user input collection and emission of kernel execution requests.
 * Logic: Statelessly captures data and emits to parent for processing via the Rust Kernel bridge.
 */

const props = defineProps({
  placeholder: {
    type: String,
    default: 'Enter command for Rust kernel...'
  },
  loading: {
    type: Boolean,
    default: false
  }
});

const emit = defineEmits(['execute']);
const inputValue = ref('');

const demoChips = [
  { label: 'Hello Kernel', value: 'Hello Kernel' },
  { label: 'Phoenix-1.0', value: 'Phoenix-1.0' },
  { label: 'System Check', value: 'System Check' }
];

const handleExecute = () => {
  if (!inputValue.value || props.loading) return;
  emit('execute', inputValue.value);
};

const fillInput = (text) => {
  inputValue.value = text;
};
</script>

<template>
  <div class="flex flex-col gap-4 w-full">
    <!-- Demo Data Chips -->
    <div class="flex flex-wrap gap-2 mb-2">
      <button
        v-for="chip in demoChips"
        :key="chip.value"
        @click="fillInput(chip.value)"
        class="px-3 py-1.5 bg-phoenix-card border border-white/5 rounded-md text-[11px] font-medium text-phoenix-muted hover:text-phoenix-accent hover:border-phoenix-accent/50 transition-all active:scale-95 no-drag"
      >
        {{ chip.label }}
      </button>
    </div>

    <!-- Input Group -->
    <div class="flex flex-col gap-3 group">
      <div class="relative flex items-center">
        <input
          v-model="inputValue"
          type="text"
          :placeholder="placeholder"
          :disabled="loading"
          @keypress.enter="handleExecute"
          class="w-full bg-black/20 border border-white/10 rounded-lg px-4 py-3 text-sm text-phoenix-text placeholder:text-phoenix-muted focus:outline-none focus:border-phoenix-accent/50 focus:ring-1 focus:ring-phoenix-accent/20 transition-all disabled:opacity-50 no-drag"
        />

        <!-- Loading Spinner -->
        <div v-if="loading" class="absolute right-4">
          <div class="w-4 h-4 border-2 border-phoenix-accent/30 border-t-phoenix-accent rounded-full animate-spin"></div>
        </div>
      </div>

      <div class="flex flex-col gap-2">
        <button
          @click="handleExecute"
          :disabled="loading || !inputValue"
          class="w-full bg-phoenix-accent text-phoenix-bg font-bold py-3 rounded-lg text-sm hover:opacity-90 active:scale-[0.99] transition-all disabled:opacity-30 disabled:cursor-not-allowed disabled:active:scale-100 no-drag"
        >
          {{ loading ? 'PROCESSING...' : 'EXECUTE IN RUST' }}
        </button>

        <button
          @click="emit('execute', 'DIAGNOSTIC_RUN')"
          :disabled="loading"
          class="w-full bg-white/5 border border-white/5 text-phoenix-muted font-medium py-2 rounded-lg text-xs hover:bg-white/10 hover:text-white transition-all active:scale-[0.99] no-drag"
        >
          RUN KERNEL DIAGNOSTICS
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Scoped component styles following SRP */
input::placeholder {
  font-style: italic;
  opacity: 0.6;
}
</style>
