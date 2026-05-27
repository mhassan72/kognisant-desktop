<script setup>
import { ref, onMounted, watch } from "vue";
import { codeToHtml } from "shiki";
import { Copy, Check, FileCode } from "lucide-vue-next";

/**
 * CodeViewer Component
 * Responsibility (SRP): Rendering syntax-highlighted code blocks using Shiki.
 * Logic: Transforms raw code strings into HTML asynchronously based on the detected language.
 */

const props = defineProps({
    code: {
        type: String,
        default: "",
    },
    language: {
        type: String,
        default: "javascript",
    },
    filename: {
        type: String,
        default: "preview.js",
    },
});

const highlightedCode = ref("");
const isCopying = ref(false);

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
        console.error("Shiki Highlighting Error:", err);
        highlightedCode.value = `<pre class="shiki"><code>${props.code}</code></pre>`;
    }
};

const copyToClipboard = async () => {
    await navigator.clipboard.writeText(props.code);
    isCopying.value = true;
    setTimeout(() => (isCopying.value = false), 2000);
};

onMounted(updateHighlighting);
watch(() => props.code, updateHighlighting);
watch(() => props.language, updateHighlighting);
</script>

<template>
    <div
        class="flex flex-col h-full bg-kognisant-card/20 rounded-xl border border-white/5 overflow-hidden shadow-2xl"
    >
        <!-- Editor Header -->
        <div
            class="flex items-center justify-between px-4 py-2 bg-white/5 border-b border-white/5 select-none"
        >
            <div class="flex items-center gap-2">
                <FileCode :size="14" class="text-kognisant-accent" />
                <span class="text-[10px] font-bold tracking-widest text-kognisant-muted uppercase">
                    {{ filename }}
                </span>
            </div>

            <button
                @click="copyToClipboard"
                class="p-1.5 rounded-md hover:bg-white/10 text-kognisant-muted hover:text-white transition-all active:scale-95 no-drag"
                :title="isCopying ? 'Copied!' : 'Copy Code'"
            >
                <Check v-if="isCopying" :size="14" class="text-emerald-400" />
                <Copy v-else :size="14" />
            </button>
        </div>

        <!-- Code Content -->
        <div class="flex-1 overflow-auto custom-scrollbar p-4 font-mono text-sm relative">
            <div v-if="!highlightedCode" class="flex items-center justify-center h-full opacity-20">
                <div class="w-8 h-8 border-2 border-kognisant-accent border-t-transparent rounded-full animate-spin"></div>
            </div>
            <div v-else v-html="highlightedCode" class="shiki-container"></div>
        </div>

        <!-- Editor Footer -->
        <div class="px-4 py-1.5 bg-white/[0.02] border-t border-white/5 flex justify-end">
            <span class="text-[9px] font-mono text-kognisant-muted/50 uppercase tracking-tighter">
                {{ language }} • UTF-8 • Shiki_Engine
            </span>
        </div>
    </div>
</template>

<style>
/* Shiki Global Overrides */
.shiki-container pre {
    background-color: transparent !important;
    margin: 0;
    padding: 0;
}

.shiki-container code {
    counter-reset: step;
    counter-increment: step 0;
}

/* Custom Scrollbar for Code */
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
    background: rgba(255, 255, 255, 0.1);
}
</style>
