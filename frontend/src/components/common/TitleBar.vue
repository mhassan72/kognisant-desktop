```
<script setup>
import { computed } from "vue";
import { useRouter, useRoute } from "vue-router";
import {
    ChevronDown,
    Zap,
    Settings,
    Bell,
    Search,
    Code2,
    PenTool,
    Cpu,
} from "lucide-vue-next";

/**
 * Kognisant Core: Flat Professional TitleBar
 * Architecture: Optimized for frameless window with brand-specific color palette.
 * Colors: Primary (#706fd3), Dark (#2f3640), Light (#f5f6fa).
 */

const router = useRouter();
const route = useRoute();

// Platform Detection via Native Bridge
const platform = window.kognisant?.platform || "win32";
const isMac = computed(() => platform === "darwin");
const isWin = computed(() => platform === "win32");

const currentLayout = computed(() => route.meta.layout || "Codex");

const switchLayout = (layoutName) => {
    const targetPath = layoutName === "Codex" ? "/codex" : "/studio";
    router.push(targetPath);
};
</script>

<template>
    <header
        class="h-10 bg-kognisant-bg border-b border-kognisant-border flex items-center select-none fixed top-0 left-0 right-0 z-[2000] drag-region"
    >
        <!-- macOS: Traffic Light Spacer -->
        <div v-if="isMac" class="w-20" />

        <!-- Left Section: Mode Switchers -->
        <div class="flex items-center gap-1 h-full px-2 no-drag">
            <!-- Brand Mark -->
            <div class="mr-2 flex items-center justify-center pl-1">
                <div
                    class="w-4 h-4 bg-kognisant-primary rounded-sm flex items-center justify-center"
                >
                    <div class="w-1.5 h-1.5 bg-white rounded-full"></div>
                </div>
            </div>

            <!-- Flat Mode Toggle -->
            <div
                class="flex bg-kognisant-input p-0.5 rounded-md border border-kognisant-border"
            >
                <button
                    @click="switchLayout('Codex')"
                    class="px-3 h-6 flex items-center gap-1.5 rounded-sm transition-all text-[10px] font-bold uppercase tracking-tight"
                    :class="
                        currentLayout === 'Codex'
                            ? 'bg-kognisant-primary text-white'
                            : 'text-kognisant-muted hover:text-kognisant-text'
                    "
                >
                    <Code2 :size="12" />
                    IDE
                </button>
                <button
                    @click="switchLayout('Studio')"
                    class="px-3 h-6 flex items-center gap-1.5 rounded-sm transition-all text-[10px] font-bold uppercase tracking-tight"
                    :class="
                        currentLayout === 'Studio'
                            ? 'bg-kognisant-primary text-white'
                            : 'text-kognisant-muted hover:text-kognisant-text'
                    "
                >
                    <PenTool :size="12" />
                    Vibe
                </button>
            </div>

            <!-- Project Breadcrumb -->
            <div
                class="flex items-center gap-1.5 px-3 py-1 hover:bg-white/5 rounded-md cursor-pointer transition-colors ml-1 group"
            >
                <span
                    class="text-[11px] font-semibold text-kognisant-muted group-hover:text-kognisant-text"
                >
                    Project_Context
                </span>
                <ChevronDown :size="12" class="text-kognisant-muted" />
            </div>
        </div>

        <!-- Center Section: Command Bar -->
        <div class="flex-1 flex justify-center items-center h-full px-4 group">
            <div
                class="w-full max-w-[360px] h-7 bg-kognisant-input border border-kognisant-border rounded-md flex items-center px-3 gap-2 no-drag cursor-text hover:bg-black/20 transition-all"
            >
                <Search :size="12" class="text-kognisant-muted" />
                <span
                    class="text-[10px] text-kognisant-muted font-medium truncate"
                    >Search or instruct the kernel...</span
                >
                <div class="ml-auto flex items-center gap-1 opacity-30">
                    <span
                        class="px-1 py-0.5 rounded bg-white/5 text-[9px] font-mono border border-white/10"
                        >⌘</span
                    >
                    <span
                        class="px-1 py-0.5 rounded bg-white/5 text-[9px] font-mono border border-white/10"
                        >K</span
                    >
                </div>
            </div>
        </div>

        <!-- Right Section: System Status & Profile -->
        <div
            class="flex items-center h-full no-drag"
            :class="isWin ? 'pr-[132px]' : 'pr-2'"
        >
            <div class="flex items-center gap-0.5">
                <div
                    class="p-2 text-kognisant-muted hover:text-kognisant-primary cursor-pointer transition-colors"
                >
                    <Zap :size="14" />
                </div>
                <div
                    class="p-2 text-kognisant-muted hover:text-kognisant-primary cursor-pointer transition-colors"
                >
                    <Cpu :size="14" />
                </div>
                <div
                    class="p-2 text-kognisant-muted hover:text-kognisant-primary cursor-pointer transition-colors"
                >
                    <Settings :size="14" />
                </div>
            </div>

            <div class="h-5 w-[1px] bg-kognisant-border mx-2"></div>

            <!-- Profile Circle -->
            <div
                class="flex items-center gap-2 pl-1 pr-1 py-1 hover:bg-white/5 rounded-md cursor-pointer transition-all"
            >
                <div
                    class="w-5 h-5 rounded-full bg-kognisant-primary flex items-center justify-center border border-white/10 shadow-sm"
                >
                    <span class="text-[9px] font-black text-white">KC</span>
                </div>
            </div>
        </div>
    </header>
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

/* Antialiasing for high-density small text */
* {
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}

.uppercase {
    letter-spacing: 0.04em;
}
</style>
