<script setup>
import { onMounted, ref } from "vue";

/**
 * TitleBar Component (Electron Version)
 * Responsibility (SRP): Providing custom window controls and drag region for the frameless window.
 * Logic: Uses the 'phoenix' bridge exposed in preload.js to control the Electron window.
 */

const isMaximized = ref(false);

const minimize = () => {
    if (window.phoenix?.window) {
        window.phoenix.window.minimize();
    }
};

const toggleMaximize = () => {
    if (window.phoenix?.window) {
        window.phoenix.window.maximize();
        // Since Electron's maximize event is handled in the main process,
        // we can toggle local state or listen for a main-to-renderer event if needed.
        isMaximized.value = !isMaximized.value;
    }
};

const close = () => {
    if (window.phoenix?.window) {
        window.phoenix.window.close();
    }
};

onMounted(() => {
    console.log("TitleBar linked to Electron window controls.");
});
</script>

<template>
    <div
        class="h-8 bg-phoenix-card flex justify-between items-center select-none fixed top-0 left-0 right-0 z-[1000] border-b border-white/5 drag-region"
    >
        <!-- App Branding (Non-interactive drag area) -->
        <div class="flex items-center px-3 gap-2 pointer-events-none">
            <div
                class="w-3 h-3 rounded-full bg-phoenix-accent/20 border border-phoenix-accent/40"
            ></div>
            <span
                class="text-[10px] font-bold tracking-widest text-phoenix-muted uppercase"
                >Phoenix Kernel</span
            >
        </div>

        <!-- Window Controls -->
        <div class="flex h-full no-drag">
            <!-- Minimize -->
            <button
                @click="minimize"
                class="w-11 h-full flex justify-center items-center hover:bg-white/10 transition-colors focus:outline-none"
                aria-label="Minimize"
            >
                <svg
                    width="10"
                    height="1"
                    viewBox="0 0 10 1"
                    fill="none"
                    xmlns="http://www.w3.org/2000/svg"
                >
                    <rect
                        width="10"
                        height="1"
                        fill="currentColor"
                        class="text-white"
                    />
                </svg>
            </button>

            <!-- Maximize / Restore -->
            <button
                @click="toggleMaximize"
                class="w-11 h-full flex justify-center items-center hover:bg-white/10 transition-colors focus:outline-none"
                aria-label="Toggle Maximize"
            >
                <svg
                    v-if="!isMaximized"
                    width="10"
                    height="10"
                    viewBox="0 0 10 10"
                    fill="none"
                    xmlns="http://www.w3.org/2000/svg"
                >
                    <rect
                        x="1.5"
                        y="1.5"
                        width="7"
                        height="7"
                        stroke="currentColor"
                        class="text-white"
                        stroke-width="1"
                    />
                </svg>
                <svg
                    v-else
                    width="10"
                    height="10"
                    viewBox="0 0 10 10"
                    fill="none"
                    xmlns="http://www.w3.org/2000/svg"
                >
                    <rect
                        x="3.5"
                        y="1.5"
                        width="5"
                        height="5"
                        stroke="currentColor"
                        class="text-white"
                        stroke-width="1"
                    />
                    <path
                        d="M1.5 3.5H6.5V8.5H1.5V3.5Z"
                        fill="#1e293b"
                        stroke="currentColor"
                        class="text-white"
                        stroke-width="1"
                    />
                </svg>
            </button>

            <!-- Close -->
            <button
                @click="close"
                class="w-11 h-full flex justify-center items-center hover:bg-rose-600 transition-colors focus:outline-none group"
                aria-label="Close"
            >
                <svg
                    width="10"
                    height="10"
                    viewBox="0 0 10 10"
                    fill="none"
                    xmlns="http://www.w3.org/2000/svg"
                >
                    <path
                        d="M1 1L9 9M9 1L1 9"
                        stroke="currentColor"
                        class="text-white"
                        stroke-width="1.2"
                        stroke-linecap="round"
                    />
                </svg>
            </button>
        </div>
    </div>
</template>

<style scoped>
.drag-region {
    -webkit-app-region: drag;
}

.no-drag {
    -webkit-app-region: no-drag;
}
</style>
