<script setup>
import { computed } from "vue";
import { useRouter, useRoute } from "vue-router";
import {
    ChevronDown,
    Box,
    Zap,
    Settings,
    Bell,
    Search,
    Code2,
    PenTool,
    Cpu,
} from "lucide-vue-next";

/**
 * Kognisant Core: High-Performance TitleBar
 * Architecture: Optimized for frameless window integration.
 * Reference Style: Sleek, agentic IDE (Vibe/IDE style).
 *
 * Responsibility: Handles OS-native spacing, drag regions, and layout switching.
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
        class="h-11 bg-kognisant-bg border-b border-kognisant-border flex items-center select-none fixed top-0 left-0 right-0 z-[2000] drag-region backdrop-blur-md"
    >
        <!-- macOS: Traffic Light Spacer (approx 80px) -->
        <div v-if="isMac" class="w-20" />

        <!-- Left Section: Context & Layout Toggles -->
        <div class="flex items-center gap-1 h-full px-2 no-drag">
            <!-- App Icon/Launcher -->
            <div
                class="p-1.5 hover:bg-white/5 rounded-md cursor-pointer transition-colors mr-1"
            >
                <div
                    class="w-4 h-4 bg-kognisant-accent rounded-[3px] flex items-center justify-center"
                >
                    <div class="w-1.5 h-1.5 bg-kognisant-bg rounded-full"></div>
                </div>
            </div>

            <!-- Mode Switchers (Matching Reference Design) -->
            <div
                class="flex bg-kognisant-input p-1 rounded-lg border border-white/5"
            >
                <button
                    @click="switchLayout('Codex')"
                    class="px-3 h-6 flex items-center gap-1.5 rounded-md transition-all text-[10px] font-bold uppercase tracking-tight"
                    :class="
                        currentLayout === 'Codex'
                            ? 'bg-white/10 text-white shadow-sm'
                            : 'text-kognisant-muted hover:text-kognisant-text'
                    "
                >
                    <Code2 :size="12" />
                    IDE
                </button>
                <button
                    @click="switchLayout('Studio')"
                    class="px-3 h-6 flex items-center gap-1.5 rounded-md transition-all text-[10px] font-bold uppercase tracking-tight"
                    :class="
                        currentLayout === 'Studio'
                            ? 'bg-white/10 text-white shadow-sm'
                            : 'text-kognisant-muted hover:text-kognisant-text'
                    "
                >
                    <PenTool :size="12" />
                    Vibe
                </button>
            </div>

            <!-- Project Selector -->
            <div
                class="flex items-center gap-1.5 px-3 py-1 hover:bg-white/5 rounded-md cursor-pointer transition-colors ml-2 group"
            >
                <span
                    class="text-[11px] font-medium text-kognisant-muted group-hover:text-kognisant-text transition-colors"
                >
                    Project name
                </span>
                <ChevronDown :size="12" class="text-kognisant-muted" />
            </div>
        </div>

        <!-- Center Section: System Command / Global Search -->
        <div class="flex-1 flex justify-center items-center h-full px-4 group">
            <div
                class="w-full max-w-[400px] h-7 bg-kognisant-input border border-white/5 rounded-md flex items-center px-3 gap-2 no-drag cursor-text hover:border-white/10 transition-all"
            >
                <Search :size="12" class="text-kognisant-muted" />
                <span class="text-[10px] text-kognisant-muted font-medium"
                    >Search project or run kernel command...</span
                >
                <div class="ml-auto flex items-center gap-1 opacity-40">
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

        <!-- Right Section: System Metadata & User -->
        <div
            class="flex items-center h-full no-drag"
            :class="isWin ? 'pr-[130px]' : 'pr-3'"
        >
            <div class="flex items-center gap-0.5 px-1">
                <div
                    class="p-2 text-kognisant-muted hover:text-white cursor-pointer transition-colors"
                >
                    <Bell :size="14" />
                </div>
                <div
                    class="p-2 text-kognisant-muted hover:text-white cursor-pointer transition-colors"
                >
                    <Zap :size="14" />
                </div>
                <div
                    class="p-2 text-kognisant-muted hover:text-white cursor-pointer transition-colors"
                >
                    <Cpu :size="14" />
                </div>
                <div
                    class="p-2 text-kognisant-muted hover:text-white cursor-pointer transition-colors"
                >
                    <Settings :size="14" />
                </div>
            </div>

            <!-- Profile / Config Dropdown -->
            <div class="h-6 w-[1px] bg-kognisant-border mx-2"></div>

            <div
                class="flex items-center gap-2 pl-1 pr-2 py-1 hover:bg-white/5 rounded-md cursor-pointer transition-all border border-transparent hover:border-white/5"
            >
                <div
                    class="w-5 h-5 rounded-full bg-gradient-to-br from-kognisant-accent to-syntax-keyword flex items-center justify-center overflow-hidden"
                >
                    <span class="text-[9px] font-bold text-kognisant-bg"
                        >KC</span
                    >
                </div>
                <ChevronDown :size="12" class="text-kognisant-muted" />
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

/* Specific styling to match the reference image's density */
button,
div {
    -webkit-font-smoothing: antialiased;
}

/* Ensure consistent tracking for uppercase labels */
.uppercase {
    letter-spacing: 0.05em;
}
</style>
