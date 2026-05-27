<script setup>
import { ref, onMounted, nextTick } from "vue";
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
 * Architecture: 3-Pane High-Performance Agentic IDE
 * Pane 1 (Navigator): Workspace file context
 * Pane 2 (Workspace): Code viewer and task orchestration board
 * Pane 3 (Intelligence): Agent reasoning stream and autonomous chat
 */

// State Management
const chatInput = ref("");
const messages = ref([
    {
        role: "assistant",
        content:
            "Kognisant Kernel linked. All autonomous modules synchronized. How shall we proceed with our development session today?",
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
        // In a real IDE, we would fetch file contents here.
        currentCode.value = `// Refined context for ${node.name}\n// Kernel status: Monitoring\n\npub fn execute_logic() {\n    // Agentic processing logic here\n}`;
    }
};

const sendMessage = async () => {
    if (!chatInput.value.trim() || isKernelBusy.value) return;

    const userPrompt = chatInput.value;
    chatInput.value = "";

    // Add User Message
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
            // High-speed direct IPC call to Rust
            const response = await window.kognisant.kernel.execute(userPrompt);

            // Sync Agentic State from Kernel Response
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

            // If the kernel generated code, update the preview
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
    // Default preview code based on reference image
    currentCode.value = `import React, { useState } from 'react';\n\ninterface PropsType {\n  question: string;\n  options: string[];\n}\n\nexport const SurveyQuestion: React.FC<PropsType> = ({ question, options }) => {\n  const { t } = useTranslation();\n  const { account } = useAccount();\n  const [isLoading, setIsLoading] = useState<boolean>(false);\n\n  const clearSurveyCache = (): void => {\n    const prefixes: (string | undefined)[] = ['survey'];\n    Object.keys(localStorage).forEach((key) => {\n      if (prefixes.some((prefix) => key.startsWith(prefix!))) {\n        localStorage.removeItem(key);\n      }\n    });\n  };\n\n  return (\n    <div className="p-4 bg-kognisant-card rounded-lg">\n      <h3 className="text-white font-bold mb-4">{question}</h3>\n      {/* Logic continued by Kernel... */}\n    </div>\n  );\n};`;
});
</script>

<template>
    <div class="flex flex-1 overflow-hidden h-full bg-kognisant-bg">
        <!-- PANE 1: NAVIGATOR -->
        <aside
            class="w-64 border-r border-kognisant-border flex flex-col bg-kognisant-sidebar/40 select-none"
        >
            <div
                class="h-10 px-4 flex items-center justify-between border-b border-white/5"
            >
                <div class="flex items-center gap-2">
                    <Box :size="14" class="text-kognisant-accent opacity-80" />
                    <span
                        class="text-[10px] font-bold tracking-widest text-kognisant-muted uppercase"
                        >Navigator</span
                    >
                </div>
                <div class="flex items-center gap-1">
                    <Search
                        :size="12"
                        class="text-kognisant-muted hover:text-white cursor-pointer transition-colors"
                    />
                    <Plus
                        :size="12"
                        class="text-kognisant-muted hover:text-white cursor-pointer transition-colors"
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
                    class="flex flex-col items-center justify-center h-full opacity-10 gap-3"
                >
                    <div
                        class="w-6 h-6 border border-white border-t-transparent rounded-full animate-spin"
                    ></div>
                    <span
                        class="text-[9px] uppercase tracking-widest font-black"
                        >Syncing_Context</span
                    >
                </div>
            </div>
        </aside>

        <!-- PANE 2: WORKSPACE -->
        <section
            class="flex-1 flex flex-col min-w-0 bg-transparent relative border-r border-kognisant-border"
        >
            <!-- Workspace Toolbar: Tabs -->
            <div
                class="h-10 bg-kognisant-sidebar/20 border-b border-kognisant-border flex items-center px-2 gap-1 overflow-x-auto no-scrollbar"
            >
                <div
                    class="flex items-center h-7 px-3 gap-2 bg-white/5 border border-white/5 rounded-md cursor-default shadow-sm group"
                >
                    <FileCode :size="12" class="text-kognisant-accent" />
                    <span
                        class="text-[11px] font-medium text-white truncate max-w-[120px]"
                        >{{ currentFile }}</span
                    >
                    <div
                        class="w-1.5 h-1.5 rounded-full bg-amber-500 opacity-0 group-hover:opacity-100 transition-opacity"
                    ></div>
                </div>
                <div
                    class="flex items-center h-7 px-3 gap-2 hover:bg-white/5 rounded-md cursor-pointer text-kognisant-muted transition-all"
                >
                    <span class="text-[11px]">Cargo.toml</span>
                </div>
                <div
                    class="flex items-center h-7 px-3 gap-2 hover:bg-white/5 rounded-md cursor-pointer text-kognisant-muted transition-all"
                >
                    <span class="text-[11px]">Build.rs</span>
                </div>
                <Plus
                    :size="14"
                    class="ml-2 text-kognisant-muted/50 hover:text-white cursor-pointer"
                />
            </div>

            <!-- Central Content Grid -->
            <div class="flex-1 flex flex-col p-6 gap-6 overflow-hidden">
                <!-- Editor Pane -->
                <div class="flex-[3] min-h-0">
                    <CodeViewer
                        :code="currentCode"
                        language="typescript"
                        :filename="currentFile"
                        class="h-full border border-kognisant-border shadow-2xl"
                    />
                </div>

                <!-- Plan Pane -->
                <div class="flex-[1] min-h-0">
                    <TaskBoard :tasks="subTasks" />
                </div>
            </div>

            <!-- Breadcrumbs -->
            <div
                class="h-8 border-t border-kognisant-border flex items-center px-6 gap-2 text-[10px] text-kognisant-muted font-medium bg-kognisant-sidebar/10"
            >
                <span class="opacity-50">Kognisant</span>
                <ChevronRight :size="10" />
                <span class="opacity-50">App</span>
                <ChevronRight :size="10" />
                <span class="opacity-50">Components</span>
                <ChevronRight :size="10" />
                <span class="text-kognisant-accent">{{ currentFile }}</span>
            </div>
        </section>

        <!-- PANE 3: INTELLIGENCE -->
        <aside
            class="w-[420px] bg-kognisant-card/40 flex flex-col backdrop-blur-xl"
        >
            <!-- Header: Agent Roster -->
            <div
                class="h-10 px-4 border-b border-kognisant-border flex items-center justify-between"
            >
                <div class="flex items-center gap-3">
                    <div class="flex -space-x-1.5">
                        <div
                            v-for="agent in activeAgents"
                            :key="agent.id"
                            class="w-6 h-6 rounded-full bg-kognisant-accent/10 border border-kognisant-accent/30 flex items-center justify-center shadow-lg transition-transform hover:scale-110 cursor-help"
                            :title="`${agent.name}: ${agent.role}`"
                        >
                            <Zap :size="10" class="text-kognisant-accent" />
                        </div>
                    </div>
                    <span
                        class="text-[10px] font-black uppercase tracking-tighter text-white/90"
                        >Autonomous Intelligence</span
                    >
                </div>
                <div class="flex items-center gap-2">
                    <History
                        :size="14"
                        class="text-kognisant-muted hover:text-white cursor-pointer"
                    />
                    <Maximize2
                        :size="14"
                        class="text-kognisant-muted hover:text-white cursor-pointer"
                    />
                </div>
            </div>

            <!-- Interaction Flow -->
            <div
                ref="chatContainer"
                class="flex-1 overflow-y-auto custom-scrollbar flex flex-col"
            >
                <!-- Thinking Block -->
                <div class="p-5 border-b border-white/5 bg-white/[0.01]">
                    <div class="flex items-center justify-between mb-4">
                        <div class="flex items-center gap-2">
                            <Activity
                                :size="12"
                                class="text-kognisant-accent"
                            />
                            <span
                                class="text-[10px] font-black uppercase tracking-widest text-kognisant-muted"
                                >Reasoning_Stream</span
                            >
                        </div>
                        <span
                            v-if="isKernelBusy"
                            class="text-[8px] font-mono text-kognisant-accent animate-pulse"
                            >EXECUTING...</span
                        >
                    </div>
                    <ThoughtChain
                        :thoughts="thoughtProcess"
                        :is-thinking="isKernelBusy"
                    />
                </div>

                <!-- Chat Messages -->
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
                                class="flex items-center gap-1 text-[9px] font-black uppercase tracking-widest text-kognisant-accent"
                            >
                                <Sparkles :size="8" /> Kognisant_Kernel
                            </span>
                            <span
                                v-else
                                class="text-[9px] font-black uppercase tracking-widest"
                                >Operator</span
                            >
                            <Clock :size="8" />
                            <span class="text-[8px] font-mono uppercase">{{
                                msg.timestamp
                            }}</span>
                        </div>

                        <div
                            class="px-5 py-4 rounded-2xl text-[13px] leading-relaxed border shadow-2xl transition-all"
                            :class="[
                                msg.role === 'user'
                                    ? 'bg-kognisant-accent text-kognisant-bg border-transparent font-medium rounded-tr-none'
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

            <!-- Chat Input Area -->
            <div
                class="p-5 bg-kognisant-sidebar/40 border-t border-kognisant-border"
            >
                <div
                    class="relative group bg-kognisant-input border border-white/10 rounded-2xl p-1 shadow-inner hover:border-kognisant-accent/30 transition-all duration-300"
                >
                    <textarea
                        v-model="chatInput"
                        @keydown.enter.exact.prevent="sendMessage"
                        rows="2"
                        placeholder="Instruct the Kernel..."
                        class="w-full bg-transparent border-none rounded-xl px-4 py-3 text-sm text-white placeholder:text-kognisant-muted focus:ring-0 resize-none no-drag"
                    ></textarea>

                    <div
                        class="flex items-center justify-between px-3 py-2 border-t border-white/5"
                    >
                        <div class="flex items-center gap-2 opacity-40">
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
                            class="p-2 rounded-xl bg-kognisant-accent text-kognisant-bg hover:shadow-[0_0_15px_rgba(56,189,248,0.4)] transition-all disabled:opacity-20 shadow-lg"
                        >
                            <Send :size="16" />
                        </button>
                    </div>
                </div>
                <div
                    class="mt-3 flex items-center justify-center gap-3 opacity-20 select-none"
                >
                    <div class="w-1 h-1 rounded-full bg-kognisant-accent"></div>
                    <span
                        class="text-[8px] font-bold text-kognisant-muted uppercase tracking-[0.25em]"
                        >Autonomous Secure Tunnel • v1.0</span
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
    background: rgba(56, 189, 248, 0.2);
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
