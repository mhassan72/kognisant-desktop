<script setup>
import { ref } from "vue";
import {
    Plus,
    Trash2,
    ChevronDown,
    Maximize2,
    X,
    MoreHorizontal,
    Columns,
    Terminal as TerminalIcon,
} from "lucide-vue-next";

/**
 * TerminalPanel Component (Kognisant Core)
 * Responsibility (SRP): Rendering a professional IDE-style terminal interface.
 * Design Reference: Bottom-docked terminal with tabs and zsh context.
 */

const tabs = ["PROBLEMS", "OUTPUT", "DEBUG CONSOLE", "TERMINAL", "PORTS"];
const activeTab = ref("TERMINAL");

const terminalHistory = ref([]);
const currentPath = "~/Documents/projects/rust/kognisant-core";
const username = "MSugroo";
</script>

<template>
    <div
        class="flex flex-col h-full bg-[#282c34] border-t border-black/20 text-[#abb2bf] font-sans overflow-hidden"
    >
        <!-- 1. TERMINAL HEADER / TABS -->
        <div
            class="flex items-center justify-between h-9 px-4 bg-[#21252b] border-b border-black/20 select-none"
        >
            <!-- Left Side: Tabs -->
            <div class="flex items-center gap-6 h-full">
                <button
                    v-for="tab in tabs"
                    :key="tab"
                    @click="activeTab = tab"
                    class="text-[10px] font-black tracking-wider h-full border-b-2 transition-all relative pt-0.5"
                    :class="
                        activeTab === tab
                            ? 'text-white border-kognisant-primary'
                            : 'text-[#8c94a1] border-transparent hover:text-[#d7dae0]'
                    "
                >
                    {{ tab }}
                </button>
            </div>

            <!-- Right Side: Terminal Controls -->
            <div class="flex items-center gap-4 opacity-50 no-drag pr-2">
                <div
                    class="flex items-center gap-1.5 hover:opacity-100 cursor-pointer transition-opacity"
                >
                    <TerminalIcon :size="12" />
                    <span class="text-[11px] font-mono font-medium">zsh</span>
                </div>
                <Plus :size="14" class="hover:opacity-100 cursor-pointer" />
                <ChevronDown
                    :size="14"
                    class="hover:opacity-100 cursor-pointer"
                />
                <div class="w-[1px] h-3 bg-white/10 mx-0.5"></div>
                <Columns :size="14" class="hover:opacity-100 cursor-pointer" />
                <Trash2 :size="14" class="hover:opacity-100 cursor-pointer" />
                <MoreHorizontal
                    :size="14"
                    class="hover:opacity-100 cursor-pointer"
                />
                <div class="w-[1px] h-3 bg-white/10 mx-0.5"></div>
                <Maximize2 :size="14" class="hover:opacity-100 cursor-pointer" />
                <X :size="14" class="hover:opacity-100 cursor-pointer" />
            </div>
        </div>

        <!-- 2. TERMINAL BUFFER -->
        <div
            class="flex-1 p-4 font-mono text-[13px] leading-6 overflow-auto custom-scrollbar bg-[#282c34]"
        >
            <!-- Previous History (Mock) -->
            <div v-for="(line, i) in terminalHistory" :key="i" class="mb-1">
                {{ line }}
            </div>

            <!-- Active Prompt -->
            <div class="flex items-center gap-2 flex-wrap">
                <!-- Status Circle -->
                <span class="text-[#8c94a1] text-[10px]">○</span>

                <!-- Context Breadcrumb -->
                <div class="flex items-center gap-1.5 select-text">
                    <span class="text-white font-bold tracking-tight">{{
                        username
                    }}</span>
                    <span class="text-[#8c94a1]">{{ currentPath }}</span>
                    <span class="text-kognisant-primary font-black">$</span>
                </div>

                <!-- Blinking Cursor -->
                <div
                    class="w-2 h-5 bg-white/50 animate-pulse ml-0.5 shadow-[0_0_8px_rgba(255,255,255,0.2)]"
                ></div>
            </div>
        </div>
    </div>
</template>

<style scoped>
/* Antialiasing for high-density terminal text */
* {
    -webkit-font-smoothing: antialiased;
}

.custom-scrollbar::-webkit-scrollbar {
    width: 6px;
}
.custom-scrollbar::-webkit-scrollbar-track {
    background: transparent;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 10px;
}
.custom-scrollbar::-webkit-scrollbar-thumb:hover {
    background: rgba(112, 111, 211, 0.2);
}

.animate-pulse {
    animation: pulse 1s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

@keyframes pulse {
    0%,
    100% {
        opacity: 1;
    }
    50% {
        opacity: 0;
    }
}
</style>
