<script setup>
import { onMounted, ref, computed } from "vue";
import { useRouter, useRoute } from "vue-router";
import { Code2, PenTool } from "lucide-vue-next";

/**
 * TitleBar Component (Kognisant Core)
 * Responsibility (SRP): Window controls, drag region, and top-level Layout Switching.
 */

const router = useRouter();
const route = useRoute();
const isMaximized = ref(false);

const currentLayout = computed(() => route.meta.layout || "Codex");

const switchLayout = (layoutName) => {
    const targetPath = layoutName === "Codex" ? "/codex" : "/studio";
    router.push(targetPath);
};

const minimize = () => {
    if (window.kognisant?.window) {
        window.kognisant.window.minimize();
    }
};

const toggleMaximize = () => {
    if (window.kognisant?.window) {
        window.kognisant.window.maximize();
        isMaximized.value = !isMaximized.value;
    }
};

const close = () => {
    if (window.kognisant?.window) {
        window.kognisant.window.close();
    }
};

onMounted(() => {
    console.log("TitleBar initialized with Layout Switcher.");
});
</script>

<template>
    <div
        class="h-8 bg-kognisant-card flex justify-between items-center select-none fixed top-0 left-0 right-0 z-[1000] border-b border-white/5 drag-region"
    >
        <!-- Left: Layout Switcher -->
        <div class="flex items-center h-full no-drag pl-2 gap-1">
            <button
                @click="switchLayout('Codex')"
                class="flex items-center gap-1.5 px-3 h-6 rounded-md transition-all text-[10px] font-bold tracking-wider uppercase"
                :class="
                    currentLayout === 'Codex'
                        ? 'bg-kognisant-accent/10 text-kognisant-accent border border-kognisant-accent/20'
                        : 'text-kognisant-muted hover:text-white hover:bg-white/5 border border-transparent'
                "
            >
                <Code2 :size="12" />
                Codex
            </button>
            <button
                @click="switchLayout('Studio')"
                class="flex items-center gap-1.5 px-3 h-6 rounded-md transition-all text-[10px] font-bold tracking-wider uppercase"
                :class="
                    currentLayout === 'Studio'
                        ? 'bg-kognisant-accent/10 text-kognisant-accent border border-kognisant-accent/20'
                        : 'text-kognisant-muted hover:text-white hover:bg-white/5 border border-transparent'
                "
            >
                <PenTool :size="12" />
                Studio
            </button>
        </div>

        <!-- Center: App Branding -->
        <div
            class="absolute left-1/2 -translate-x-1/2 flex items-center gap-2 pointer-events-none opacity-50"
        >
            <div class="w-1.5 h-1.5 rounded-full bg-kognisant-accent"></div>
            <span
                class="text-[9px] font-black tracking-[0.3em] text-kognisant-text uppercase"
                >Kognisant</span
            >
        </div>

        <!-- Right: Window Controls -->
        <div class="flex h-full no-drag">
            <button
                @click="minimize"
                class="w-11 h-full flex justify-center items-center hover:bg-white/10 transition-colors focus:outline-none"
            >
                <svg width="10" height="1" viewBox="0 0 10 1" fill="none">
                    <rect width="10" height="1" fill="white" />
                </svg>
            </button>

            <button
                @click="toggleMaximize"
                class="w-11 h-full flex justify-center items-center hover:bg-white/10 transition-colors focus:outline-none"
            >
                <svg
                    v-if="!isMaximized"
                    width="10"
                    height="10"
                    viewBox="0 0 10 10"
                    fill="none"
                >
                    <rect
                        x="1.5"
                        y="1.5"
                        width="7"
                        height="7"
                        stroke="white"
                        stroke-width="1"
                    />
                </svg>
                <svg
                    v-else
                    width="10"
                    height="10"
                    viewBox="0 0 10 10"
                    fill="none"
                >
                    <rect
                        x="3.5"
                        y="1.5"
                        width="5"
                        height="5"
                        stroke="white"
                        stroke-width="1"
                    />
                    <path
                        d="M1.5 3.5H6.5V8.5H1.5V3.5Z"
                        fill="#1e293b"
                        stroke="white"
                        stroke-width="1"
                    />
                </svg>
            </button>

            <button
                @click="close"
                class="w-11 h-full flex justify-center items-center hover:bg-rose-600 transition-colors focus:outline-none"
            >
                <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                    <path
                        d="M1 1L9 9M9 1L1 9"
                        stroke="white"
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

button {
    outline: none !important;
}
</style>
