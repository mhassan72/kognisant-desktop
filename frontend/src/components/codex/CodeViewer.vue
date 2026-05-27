<script setup>
import { ref, onMounted, watch, computed } from "vue";
import { codeToHtml } from "shiki";
import {
    ChevronRight,
    MoreHorizontal,
    Columns,
    FileCode,
} from "lucide-vue-next";

/**
 * CodeViewer Component (Kognisant Core)
 * Responsibility (SRP): Rendering a high-fidelity code editor interface.
 * Design Reference: Modern professional IDE with breadcrumbs, gutter, and minimap.
 */

const props = defineProps({
    code: {
        type: String,
        default: "",
    },
    language: {
        type: String,
        default: "python",
    },
    filename: {
        type: String,
        default: "conversation_memory_rtdb.py",
    },
    filepath: {
        type: String,
        default: "src > features > agents > services > kognisant_core",
    },
});

const highlightedCode = ref("");
const lines = computed(() => props.code.split("\n"));

const updateHighlighting = async () => {
    if (!props.code) {
        highlightedCode.value = "";
        return;
    }

    try {
        highlightedCode.value = await codeToHtml(props.code, {
            lang: props.language,
            theme: "one-dark-pro",
        });
    } catch (err) {
        console.error("Highlighting Error:", err);
        highlightedCode.value = `<pre><code>${props.code}</code></pre>`;
    }
};

onMounted(updateHighlighting);
watch(() => props.code, updateHighlighting);
</script>

<template>
    <div
        class="flex flex-col h-full bg-[#1e2227] text-[#abb2bf] font-sans selection:bg-[#3e4451]"
    >
        <!-- 1. TAB BAR -->
        <div
            class="flex items-center h-9 bg-[#21252b] border-b border-black/20 select-none"
        >
            <div
                class="flex items-center h-full px-3 gap-2 bg-[#282c34] border-r border-black/20 relative group"
            >
                <FileCode :size="14" class="text-[#519aba]" />
                <span class="text-[11px] text-[#d7dae0] font-medium">{{
                    filename
                }}</span>
                <button
                    class="opacity-0 group-hover:opacity-100 hover:bg-white/10 rounded p-0.5 transition-all"
                >
                    <svg width="8" height="8" viewBox="0 0 8 8" fill="none">
                        <path
                            d="M1 1L7 7M7 1L1 7"
                            stroke="currentColor"
                            stroke-width="1.2"
                        />
                    </svg>
                </button>
                <div
                    class="absolute bottom-0 left-0 right-0 h-[2px] bg-kognisant-primary"
                ></div>
            </div>
            <div class="flex-1 flex justify-end px-4 gap-4 opacity-40">
                <Columns :size="14" class="hover:opacity-100 cursor-pointer" />
                <MoreHorizontal
                    :size="14"
                    class="hover:opacity-100 cursor-pointer"
                />
            </div>
        </div>

        <!-- 2. BREADCRUMBS -->
        <div
            class="flex items-center h-7 px-4 gap-2 bg-[#282c34] border-b border-black/10 text-[10px] text-[#8c94a1] select-none uppercase tracking-tighter"
        >
            <span>{{ filepath.split(" > ")[0] }}</span>
            <ChevronRight :size="10" />
            <span>{{ filepath.split(" > ")[1] }}</span>
            <ChevronRight :size="10" />
            <span>{{ filepath.split(" > ")[2] }}</span>
            <ChevronRight :size="10" />
            <div class="flex items-center gap-1 text-[#d7dae0]">
                <FileCode :size="10" />
                <span>{{ filename }}</span>
            </div>
        </div>

        <!-- 3. EDITOR SURFACE -->
        <div class="flex-1 flex overflow-hidden relative">
            <!-- Gutter -->
            <div
                class="w-12 bg-[#282c34] flex flex-col items-end py-4 pr-3 select-none border-r border-black/5"
            >
                <div
                    v-for="(_, i) in lines"
                    :key="i"
                    class="text-[11px] font-mono leading-6 opacity-20 hover:opacity-100 transition-opacity cursor-default"
                >
                    {{ i + 1 }}
                </div>
            </div>

            <!-- Code Area -->
            <div
                class="flex-1 overflow-auto custom-scrollbar bg-[#282c34] p-4 pt-4 font-mono text-[13px] leading-6 relative"
            >
                <div
                    v-if="highlightedCode"
                    v-html="highlightedCode"
                    class="shiki-surface"
                ></div>
                <div v-else class="animate-pulse flex flex-col gap-2">
                    <div class="h-4 w-3/4 bg-white/5 rounded"></div>
                    <div class="h-4 w-1/2 bg-white/5 rounded"></div>
                </div>
            </div>

            <!-- Minimap Placeholder -->
            <div
                class="w-24 border-l border-black/10 bg-[#282c34]/50 select-none hidden lg:block overflow-hidden opacity-30"
            >
                <div
                    class="w-full h-full transform scale-50 origin-top pointer-events-none p-2 space-y-1"
                >
                    <div
                        v-for="i in 40"
                        :key="i"
                        class="h-1 bg-white/10 rounded-full"
                        :style="{ width: `${Math.random() * 100}%` }"
                    ></div>
                </div>
            </div>
        </div>
    </div>
</template>

<style>
.shiki-surface pre {
    background-color: transparent !important;
    margin: 0;
    padding: 0;
}

.shiki-surface code {
    white-space: pre-wrap;
    word-break: break-all;
}

/* Matching the requested IDE aesthetic */
.custom-scrollbar::-webkit-scrollbar {
    width: 6px;
    height: 6px;
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
</style>
