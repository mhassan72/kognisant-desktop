<script setup>
import { ref, onMounted, nextTick, computed } from "vue";
import {
    Send,
    Box,
    Search,
    Zap,
    History,
    Activity,
    Cpu,
    Terminal,
    ChevronRight,
    Plus,
    FileCode,
    Maximize2,
    Sparkles,
    Clock,
    Paperclip,
    MoreHorizontal,
} from "lucide-vue-next";

// Components
import FileTree from "../../components/codex/FileTree.vue";
import CodeViewer from "../../components/codex/CodeViewer.vue";
import ThoughtChain from "../../components/codex/ThoughtChain.vue";
import TaskBoard from "../../components/codex/TaskBoard.vue";

/**
 * CodexHome View
 * Architecture: 3-Pane Agentic Workspace
 * Responsibility: Orchestrating the primary user interface for Kognisant Core.
 */

// State Management
const chatInput = ref("");
const messages = ref([
    {
        role: "assistant",
        content:
            "Kognisant Kernel active. Context loaded. How shall we proceed with our development session today?",
        timestamp: new Date().toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
        }),
    },
]);

const workspaceTree = ref(null);
const currentFile = ref("SurveyQuestion.tsx");
const currentCode = ref("");
const isKernelBusy = ref(false);

// Agentic State
const thoughtProcess = ref([]);
const subTasks = ref([]);
const activeAgents = ref([
    { id: "supervisor", name: "Aria", role: "Orchestrator", status: "idle" },
    { id: "coder", name: "Nova", role: "Systems Logic", status: "idle" },
]);

const chatContainer = ref(null);

/**
 * IPC Handlers: Communicating with the Native Rust Kernel
 */
const fetchWorkspace = async () => {
    try {
        if (window.kognisant?.kernel) {
            workspaceTree.value = await window.kognisant.kernel.getWorkspace();
        }
    } catch (err) {
        console.error("Workspace Fetch Error:", err);
    }
};

const handleFileSelect = (node) => {
    if (!node.is_directory) {
        currentFile.value = node.name;
        // Mocking file content load for the demonstration
        currentCode.value = `// Refined context for ${node.name}\n// Kernel status: Active monitoring\n\nexport const logic = () => {\n    // Agentic processing logic for ${node.name}\n};`;
    }
};

const sendMessage = async () => {
    if (!chatInput.value.trim() || isKernelBusy.value) return;

    const userPrompt = chatInput.value;
    chatInput.value = "";

    messages.value.push({
        role: "user",
        content: userPrompt,
        timestamp: new Date().toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
        }),
    });

    await scrollToBottom();
    isKernelBusy.value = true;

    try {
        if (window.kognisant?.kernel) {
            // Direct N-API call to Rust
            const response = await window.kognisant.kernel.execute(userPrompt);

            messages.value.push({
                role: "assistant",
                content: response.content,
                timestamp: new Date().toLocaleTimeString([], {
                    hour: "2-digit",
                    minute: "2-digit",
                }),
            });

            thoughtProcess.value = response.thought_process || [];
            subTasks.value = response.sub_tasks || [];

            // Pattern match for code updates
            const codeMatch = response.content.match(
                /```(?:rust|typescript|javascript|tsx)?\n([\s\S]*?)```/,
            );
            if (codeMatch) {
                currentCode.value = codeMatch[1];
            }
        }
    } catch (err) {
        messages.value.push({
            role: "assistant",
            content: `[KERNEL_EXCEPTION]: ${err.message}`,
            isError: true,
            timestamp: new Date().toLocaleTimeString([], {
                hour: "2-digit",
                minute: "2-digit",
            }),
        });
    } finally {
        isKernelBusy.value = false;
        await scrollToBottom();
    }
};

const scrollToBottom = async () => {
    await nextTick();
    if (chatContainer.value) {
        chatContainer.value.scrollTop = chatContainer.value.scrollHeight;
    }
};

onMounted(() => {
    fetchWorkspace();
    // Default preview code matching branding palette
    currentCode.value = `import React, { useState } from 'react';\n\ninterface PropsType {\n  question: string;\n  options: string[];\n}\n\n/**\n * Kognisant Core: Survey Logic Module\n * Theme: Flat Brand #706fd3\n */\nexport const SurveyQuestion: React.FC<PropsType> = ({ question, options }) => {\n  const [isLoading, setIsLoading] = useState<boolean>(false);\n\n  const clearSurveyCache = (): void => {\n    localStorage.clear();\n    console.log("Kernel: Cache Cleaned");\n  };\n\n  return (\n    <div className="p-4 bg-[#353d48] rounded-lg border border-white/5">\n      <h3 className="text-[#f5f6fa] font-bold mb-4">{question}</h3>\n      {/* Logic continued by Kernel Nova... */}\n    </div>\n  );\n};`;
});
</script>

<template>
    <div class="flex flex-1 overflow-hidden h-full bg-kognisant-bg">
        <!-- PANE 1: NAVIGATOR (Left) -->
        <aside
            class="w-64 border-r border-kognisant-border flex flex-col bg-kognisant-sidebar select-none"
        >
            <div
                class="h-10 px-4 flex items-center justify-between border-b border-white/5 bg-black/5"
            >
                <div class="flex items-center gap-2">
                    <Box :size="14" class="text-kognisant-primary" />
                    <span
                        class="text-[10px] font-bold tracking-widest text-kognisant-muted uppercase"
                        >Navigator</span
                    >
                </div>
                <div class="flex items-center gap-1">
                    <Search
                        :size="12"
                        class="text-kognisant-muted hover:text-white cursor-pointer"
                    />
                    <Plus
                        :size="12"
                        class="text-kognisant-muted hover:text-white cursor-pointer"
                    />
                </div>
            </div>

            <div class="flex-1 overflow-y-auto p-2 custom-scrollbar">
                <FileTree
                    v-if="workspaceTree"
                    :node="workspaceTree"
                    @select="handleFileSelect"
                />
                <div
                    v-else
                    class="flex flex-col items-center justify-center h-full opacity-20 gap-3"
                >
                    <div
                        class="w-5 h-5 border border-white border-t-transparent rounded-full animate-spin"
                    ></div>
                    <span class="text-[9px] uppercase tracking-widest"
                        >Linking_Context</span
                    >
                </div>
            </div>
        </aside>

        <!-- PANE 2: WORKSPACE (Center) -->
        <section
            class="flex-1 flex flex-col min-w-0 bg-transparent relative border-r border-kognisant-border"
        >
            <!-- Tabs Bar -->
            <div
                class="h-10 bg-kognisant-sidebar/30 border-b border-kognisant-border flex items-center px-2 gap-0.5 overflow-x-auto no-scrollbar"
            >
                <div
                    class="flex items-center h-8 px-3 gap-2 bg-kognisant-card rounded-t-md border-x border-t border-white/5 cursor-default relative z-10"
                >
                    <FileCode :size="12" class="text-kognisant-primary" />
                    <span
                        class="text-[11px] font-medium text-white truncate max-w-[120px]"
                        >{{ currentFile }}</span
                    >
                    <div
                        class="w-1.5 h-1.5 rounded-full bg-kognisant-primary"
                    ></div>
                </div>
                <div
                    class="flex items-center h-8 px-3 gap-2 hover:bg-white/5 rounded-t-md text-kognisant-muted transition-all cursor-pointer"
                >
                    <span class="text-[11px]">Cargo.toml</span>
                </div>
                <div
                    class="flex items-center h-8 px-3 gap-2 hover:bg-white/5 rounded-t-md text-kognisant-muted transition-all cursor-pointer"
                >
                    <span class="text-[11px]">Build.rs</span>
                </div>
            </div>

            <!-- Main Content Area -->
            <div class="flex-1 flex flex-col p-6 gap-6 overflow-hidden">
                <!-- Code Component -->
                <div class="flex-[3] min-h-0">
                    <CodeViewer
                        :code="currentCode"
                        language="typescript"
                        :filename="currentFile"
                        class="h-full border border-kognisant-border rounded-xl shadow-flat-md overflow-hidden bg-kognisant-card/50"
                    />
                </div>

                <!-- Plan Component -->
                <div class="flex-[1.2] min-h-0">
                    <TaskBoard :tasks="subTasks" class="shadow-flat-sm" />
                </div>
            </div>

            <!-- Breadcrumb Footer -->
            <div
                class="h-8 border-t border-kognisant-border flex items-center px-6 gap-2 text-[10px] text-kognisant-muted font-bold bg-black/5"
            >
                <span class="opacity-50">Kognisant</span>
                <ChevronRight :size="10" />
                <span class="opacity-50">App</span>
                <ChevronRight :size="10" />
                <span class="text-kognisant-primary">{{ currentFile }}</span>
            </div>
        </section>

        <!-- PANE 3: INTELLIGENCE (Right) -->
        <aside class="w-[420px] bg-kognisant-sidebar/40 flex flex-col">
            <!-- Agent Header -->
            <div
                class="h-10 px-4 border-b border-kognisant-border flex items-center justify-between bg-black/5"
            >
                <div class="flex items-center gap-3">
                    <div class="flex -space-x-1.5">
                        <div
                            v-for="agent in activeAgents"
                            :key="agent.id"
                            class="w-6 h-6 rounded-full bg-kognisant-primary/20 border border-kognisant-primary/30 flex items-center justify-center transition-all hover:scale-110"
                            :title="`${agent.name}: ${agent.role}`"
                        >
                            <Zap :size="10" class="text-kognisant-primary" />
                        </div>
                    </div>
                    <span
                        class="text-[10px] font-black uppercase tracking-tighter text-white/80"
                        >Intelligence_Pool</span
                    >
                </div>
                <div class="flex items-center gap-2">
                    <History
                        :size="14"
                        class="text-kognisant-muted hover:text-kognisant-primary cursor-pointer transition-colors"
                    />
                    <Maximize2
                        :size="14"
                        class="text-kognisant-muted hover:text-kognisant-primary cursor-pointer transition-colors"
                    />
                </div>
            </div>

            <!-- Stream and Chat Area -->
            <div
                ref="chatContainer"
                class="flex-1 overflow-y-auto custom-scrollbar flex flex-col"
            >
                <!-- Reasoning Component -->
                <div class="p-5 border-b border-white/5 bg-white/[0.01]">
                    <div class="flex items-center justify-between mb-4">
                        <div class="flex items-center gap-2">
                            <Activity
                                :size="12"
                                class="text-kognisant-primary"
                            />
                            <span
                                class="text-[10px] font-black uppercase tracking-widest text-kognisant-muted"
                                >Reasoning_Stream</span
                            >
                        </div>
                        <span
                            v-if="isKernelBusy"
                            class="text-[8px] font-mono text-kognisant-primary animate-pulse"
                            >FFI_BUSY</span
                        >
                    </div>
                    <ThoughtChain
                        :thoughts="thoughtProcess"
                        :is-thinking="isKernelBusy"
                    />
                </div>

                <!-- Messages -->
                <div class="p-6 space-y-8 flex-grow">
                    <div
                        v-for="(msg, idx) in messages"
                        :key="idx"
                        class="flex flex-col"
                        :class="
                            msg.role === 'user' ? 'items-end' : 'items-start'
                        "
                    >
                        <div
                            class="flex items-center gap-2 mb-2 px-1 opacity-40"
                        >
                            <span
                                v-if="msg.role === 'assistant'"
                                class="flex items-center gap-1 text-[9px] font-black uppercase tracking-widest text-kognisant-primary"
                            >
                                <Sparkles :size="8" /> Kognisant_Kernel
                            </span>
                            <span
                                v-else
                                class="text-[9px] font-black uppercase tracking-widest text-white/60"
                                >Operator</span
                            >
                            <Clock :size="8" />
                            <span class="text-[8px] font-mono uppercase">{{
                                msg.timestamp
                            }}</span>
                        </div>

                        <div
                            class="px-5 py-4 rounded-2xl text-[13px] leading-relaxed border shadow-flat-md transition-all"
                            :class="[
                                msg.role === 'user'
                                    ? 'bg-kognisant-primary text-white border-transparent rounded-tr-none'
                                    : 'bg-kognisant-input text-kognisant-text border-white/5 rounded-tl-none',
                                msg.isError
                                    ? 'border-rose-500/30 text-rose-200 bg-rose-500/5'
                                    : '',
                            ]"
                        >
                            <div class="whitespace-pre-wrap">
                                {{ msg.content }}
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Input Box -->
            <div
                class="p-5 bg-kognisant-sidebar/80 border-t border-kognisant-border"
            >
                <div
                    class="relative group bg-kognisant-input border border-white/10 rounded-2xl p-1 hover:border-kognisant-primary/40 transition-all duration-300"
                >
                    <textarea
                        v-model="chatInput"
                        @keydown.enter.exact.prevent="sendMessage"
                        rows="2"
                        placeholder="Instruct Kernel..."
                        class="w-full bg-transparent border-none rounded-xl px-4 py-3 text-sm text-white placeholder:text-kognisant-muted focus:ring-0 resize-none no-drag"
                    ></textarea>

                    <div
                        class="flex items-center justify-between px-3 py-2 border-t border-white/5"
                    >
                        <div class="flex items-center gap-3 opacity-40">
                            <Paperclip
                                :size="14"
                                class="hover:text-white cursor-pointer transition-colors"
                            />
                            <MoreHorizontal
                                :size="14"
                                class="hover:text-white cursor-pointer transition-colors"
                            />
                        </div>
                        <button
                            @click="sendMessage"
                            :disabled="isKernelBusy || !chatInput.trim()"
                            class="p-2 rounded-xl bg-kognisant-primary text-white hover:brightness-110 transition-all disabled:opacity-20 shadow-flat-sm"
                        >
                            <Send :size="16" />
                        </button>
                    </div>
                </div>
                <div
                    class="mt-3 flex items-center justify-center gap-3 opacity-20 select-none"
                >
                    <div
                        class="w-1 h-1 rounded-full bg-kognisant-primary"
                    ></div>
                    <span
                        class="text-[8px] font-bold text-kognisant-muted uppercase tracking-[0.25em]"
                        >Secure Autonomous Link v1.0</span
                    >
                </div>
            </div>
        </aside>
    </div>
</template>

<style scoped>
.custom-scrollbar::-webkit-scrollbar {
    width: 4px;
    height: 4px;
}
.custom-scrollbar::-webkit-scrollbar-track {
    background: transparent;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 10px;
}
.custom-scrollbar::-webkit-scrollbar-thumb:hover {
    background: rgba(112, 111, 211, 0.2); /* Brand color hover */
}

.no-scrollbar::-webkit-scrollbar {
    display: none;
}

textarea {
    min-height: 54px;
}

@keyframes spin {
    from {
        transform: rotate(0deg);
    }
    to {
        transform: rotate(360deg);
    }
}
.animate-spin {
    animation: spin 3s linear infinite;
}
</style>
