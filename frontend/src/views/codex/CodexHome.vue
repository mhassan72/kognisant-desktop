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
    Hash,
    X,
} from "lucide-vue-next";

// Components
import FileTree from "../../components/codex/FileTree.vue";
import CodeViewer from "../../components/codex/CodeViewer.vue";
import TaskBoard from "../../components/codex/TaskBoard.vue";
import InteractionEvent from "../../components/codex/InteractionEvent.vue";

/**
 * CodexHome: The Intelligence-First Agentic Workspace
 * Mapped to Kognisant Core Architecture.
 *
 * Responsibility (SRP): Orchestrating the 3-pane agentic environment.
 */

// UI State
const chatInput = ref("");
const searchQuery = ref("");
const isAutopilot = ref(true);

// Data State
const workspaceTree = ref(null);
const currentFile = ref("SurveyQuestion.tsx");
const currentCode = ref("");
const isKernelBusy = ref(false);

// The Agentic Stream (History of rich interactions)
const interactionStream = ref([
    {
        id: "init",
        event_type: "message",
        agent_name: "Kernel",
        message:
            "Kognisant Kernel active. Context loaded. How shall we proceed with our development session today?",
        timestamp: "12:00",
        state: "success",
    },
]);

const subTasks = ref([]);
const activeAgents = ref([
    { id: "aria", name: "Aria", role: "Orchestrator" },
    { id: "nova", name: "Nova", role: "Logic" },
]);

const streamContainer = ref(null);

/**
 * Handlers
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
        // Logic for fetching actual file content would go here via Kernel IPC
    }
};

const sendMessage = async () => {
    if (!chatInput.value.trim() || isKernelBusy.value) return;

    const userPrompt = chatInput.value;
    chatInput.value = "";

    // Push User Instruction
    interactionStream.value.push({
        id: Date.now().toString(),
        event_type: "message",
        agent_name: "Operator",
        message: userPrompt,
        timestamp: new Date().toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
        }),
        state: "info",
        role: "user",
    });

    await scrollToBottom();
    isKernelBusy.value = true;

    try {
        if (window.kognisant?.kernel) {
            // Memory-mapped FFI call to Rust
            const response = await window.kognisant.kernel.execute(userPrompt);

            // Sync Stream with Kernel Events (Thoughts, Commands, File Ops)
            if (response.events) {
                response.events.forEach((ev) =>
                    interactionStream.value.push(ev),
                );
            }

            // Push Kernel's verbal summary
            interactionStream.value.push({
                id: `msg_${Date.now()}`,
                event_type: "message",
                agent_name: "Kernel",
                message: response.content,
                timestamp: new Date().toLocaleTimeString([], {
                    hour: "2-digit",
                    minute: "2-digit",
                }),
                state: "success",
            });

            subTasks.value = response.active_tasks || [];

            // Pattern match for code updates in the workspace
            const codeMatch = response.content.match(
                /```(?:rust|typescript|tsx|javascript)?\n([\s\S]*?)```/,
            );
            if (codeMatch) {
                currentCode.value = codeMatch[1];
            }
        }
    } catch (err) {
        interactionStream.value.push({
            id: `err_${Date.now()}`,
            event_type: "error",
            agent_name: "Kernel",
            message: `Kernel Exception: ${err.message}`,
            state: "error",
            timestamp: "FAULT",
        });
    } finally {
        isKernelBusy.value = false;
        await scrollToBottom();
    }
};

const scrollToBottom = async () => {
    await nextTick();
    if (streamContainer.value) {
        streamContainer.value.scrollTop = streamContainer.value.scrollHeight;
    }
};

onMounted(() => {
    fetchWorkspace();
    // Default reference content
    currentCode.value = `import React, { useState } from 'react';\n\ninterface PropsType {\n  question: string;\n  options: string[];\n}\n\n/**\n * Kognisant Core: Survey logic module\n */\nexport const SurveyQuestion: React.FC<PropsType> = ({ question, options }) => {\n  const { t } = useTranslation();\n  const { account } = useAccount();\n  const [isLoading, setIsLoading] = useState<boolean>(false);\n\n  const clearSurveyCache = (): void => {\n    const prefixes: (string | undefined)[] = ['survey'];\n    Object.keys(localStorage).forEach((key) => {\n      if (prefixes.some((prefix) => key.startsWith(prefix!))) {\n        localStorage.removeItem(key);\n      }\n    });\n  };\n\n  return (\n    <div className="p-4 bg-kognisant-card rounded-lg border border-white/5 shadow-xl">\n      <h3 className="text-[#f5f6fa] font-bold mb-4">{question}</h3>\n      {/* Logic continued by Kernel... */}\n    </div>\n  );\n};`;
});
</script>

<template>
    <div
        class="flex flex-1 overflow-hidden h-full bg-kognisant-bg text-kognisant-text"
    >
        <!-- PANE 1: NAVIGATOR (Left Activity) -->
        <aside
            class="w-60 border-r border-kognisant-border flex flex-col bg-kognisant-sidebar/40 select-none"
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
                    class="h-full flex flex-col items-center justify-center opacity-10 gap-3"
                >
                    <div
                        class="w-5 h-5 border border-white border-t-transparent rounded-full animate-spin"
                    ></div>
                    <span class="text-[9px] uppercase tracking-widest"
                        >Linking_FS...</span
                    >
                </div>
            </div>
        </aside>

        <!-- PANE 2: WORKSPACE (Main Code Canvas) -->
        <section
            class="flex-1 flex flex-col min-w-0 bg-transparent relative border-r border-kognisant-border"
        >
            <!-- Professional Tabs -->
            <div
                class="h-10 bg-kognisant-sidebar/20 border-b border-kognisant-border flex items-center px-2 gap-0.5 overflow-x-auto no-scrollbar"
            >
                <div
                    class="flex items-center h-8 px-3 gap-2 bg-kognisant-card rounded-t-md border-x border-t border-white/5 cursor-default relative z-10 shadow-sm group"
                >
                    <div
                        class="w-2 h-2 rounded-full bg-kognisant-primary"
                    ></div>
                    <span
                        class="text-[11px] font-semibold text-white truncate max-w-[120px]"
                        >{{ currentFile }}</span
                    >
                    <X
                        :size="10"
                        class="ml-1 opacity-0 group-hover:opacity-40 hover:opacity-100 transition-opacity cursor-pointer"
                    />
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

            <!-- Central Content Display -->
            <div class="flex-1 flex flex-col p-6 gap-6 overflow-hidden">
                <!-- Editor Component -->
                <div class="flex-[3] min-h-0">
                    <CodeViewer
                        :code="currentCode"
                        language="typescript"
                        :filename="currentFile"
                        class="h-full border border-kognisant-border shadow-flat-md overflow-hidden bg-kognisant-card/50"
                    />
                </div>

                <!-- Execution Logic Board -->
                <div class="flex-[1.2] min-h-0">
                    <TaskBoard :tasks="subTasks" />
                </div>
            </div>

            <!-- System Path Breadcrumbs -->
            <div
                class="h-8 border-t border-kognisant-border flex items-center px-6 gap-2 text-[10px] text-kognisant-muted font-bold bg-black/5"
            >
                <span class="opacity-50 uppercase tracking-[0.1em]"
                    >Kognisant</span
                >
                <ChevronRight :size="10" />
                <span class="opacity-50">Core</span>
                <ChevronRight :size="10" />
                <span class="text-kognisant-primary">{{ currentFile }}</span>
            </div>
        </section>

        <!-- PANE 3: INTELLIGENCE STREAM (Right Area) -->
        <aside
            class="w-[440px] bg-kognisant-sidebar/30 flex flex-col backdrop-blur-3xl shadow-2xl"
        >
            <!-- Header: Intelligence Context -->
            <div
                class="h-10 px-4 border-b border-kognisant-border flex items-center justify-between bg-black/10"
            >
                <div class="flex items-center gap-2">
                    <div
                        class="w-1.5 h-1.5 rounded-full bg-kognisant-primary animate-pulse shadow-[0_0_8px_rgba(112,111,211,0.4)]"
                    ></div>
                    <span
                        class="text-[10px] font-black uppercase tracking-[0.2em] text-white/90"
                        >Autonomous_Chain</span
                    >
                </div>
                <div class="flex items-center gap-3">
                    <Maximize2
                        :size="14"
                        class="text-kognisant-muted hover:text-white cursor-pointer transition-colors"
                    />
                    <History
                        :size="14"
                        class="text-kognisant-muted hover:text-white cursor-pointer transition-colors"
                    />
                </div>
            </div>

            <!-- Conversation Search (Ref Image Aesthetic) -->
            <div class="p-3 border-b border-white/5 bg-black/5">
                <div
                    class="relative flex items-center bg-kognisant-input rounded-md border border-white/5 px-3 py-1.5 gap-2 group transition-all focus-within:border-kognisant-primary/40"
                >
                    <Search
                        :size="12"
                        class="text-kognisant-muted group-focus-within:text-kognisant-primary"
                    />
                    <input
                        v-model="searchQuery"
                        type="text"
                        placeholder="Search conversation (⌘F)"
                        class="bg-transparent border-none outline-none text-[11px] w-full text-white placeholder:text-kognisant-muted font-medium"
                    />
                </div>
            </div>

            <!-- Interaction Flow (High-Density Event Stream) -->
            <div
                ref="streamContainer"
                class="flex-1 overflow-y-auto custom-scrollbar flex flex-col p-5 gap-8 bg-black/5"
            >
                <template v-for="event in interactionStream" :key="event.id">
                    <!-- User Instruction Style -->
                    <div
                        v-if="event.role === 'user'"
                        class="flex flex-col items-end gap-1.5"
                    >
                        <div class="flex items-center gap-2 px-1 opacity-30">
                            <span
                                class="text-[9px] font-black uppercase tracking-widest text-white"
                                >Operator</span
                            >
                            <Clock :size="8" />
                            <span class="text-[8px] font-mono">{{
                                event.timestamp
                            }}</span>
                        </div>
                        <div
                            class="px-5 py-3.5 rounded-2xl bg-kognisant-primary text-white text-[13px] leading-relaxed shadow-lg rounded-tr-none font-medium border border-white/10"
                        >
                            {{ event.message }}
                        </div>
                    </div>

                    <!-- Kernel Event Type (Command, File Read, Thought, Message) -->
                    <InteractionEvent v-else :event="event" />
                </template>

                <!-- Activity Loading Bar (Matches Reference Image) -->
                <div
                    v-if="isKernelBusy"
                    class="flex flex-col gap-4 animate-pulse pt-4 border-t border-white/5"
                >
                    <div class="flex items-center gap-2 px-1 opacity-20">
                        <Cpu :size="10" />
                        <span
                            class="text-[9px] font-black uppercase tracking-[0.2em]"
                            >Kernel_Processing...</span
                        >
                    </div>
                </div>
            </div>

            <!-- Active Status Bar (Footer for the Intelligence pane) -->
            <div
                v-if="isKernelBusy"
                class="px-4 py-2 border-t border-white/5 flex items-center justify-between bg-kognisant-card/50"
            >
                <div class="flex items-center gap-2">
                    <div
                        class="w-1 h-1 bg-kognisant-primary animate-ping rounded-full"
                    ></div>
                    <span
                        class="text-[9px] font-bold uppercase tracking-widest text-kognisant-muted"
                        >Working</span
                    >
                </div>
                <div class="flex gap-2">
                    <button
                        class="px-3 py-1 rounded bg-white/5 border border-white/5 text-[9px] font-black uppercase tracking-tight hover:bg-white/10 no-drag transition-colors"
                    >
                        Cancel
                    </button>
                    <button
                        class="px-3 py-1 rounded bg-kognisant-primary text-white text-[9px] font-black uppercase tracking-tight hover:brightness-110 no-drag flex items-center gap-1.5 transition-all shadow-flat-sm"
                    >
                        Follow <Activity :size="10" />
                    </button>
                </div>
            </div>

            <!-- Professional Instruction Area -->
            <div
                class="p-5 bg-kognisant-sidebar/80 border-t border-kognisant-border"
            >
                <div
                    class="relative group bg-kognisant-input border border-white/10 rounded-2xl p-1 shadow-inner hover:border-kognisant-primary/40 transition-all duration-300"
                >
                    <textarea
                        v-model="chatInput"
                        @keydown.enter.exact.prevent="sendMessage"
                        rows="2"
                        placeholder="Ask a question or describe a task..."
                        class="w-full bg-transparent border-none rounded-xl px-4 py-3 text-[13px] text-white placeholder:text-kognisant-muted focus:ring-0 resize-none no-drag"
                    ></textarea>

                    <div
                        class="flex items-center justify-between px-3 py-2 border-t border-white/5"
                    >
                        <div class="flex items-center gap-4 opacity-40">
                            <Hash
                                :size="14"
                                class="hover:text-white cursor-pointer transition-colors"
                            />
                            <Paperclip
                                :size="14"
                                class="hover:text-white cursor-pointer transition-colors"
                            />
                            <div class="w-[1px] h-3 bg-white/20"></div>
                            <Sparkles
                                :size="14"
                                class="text-kognisant-primary opacity-80"
                            />
                        </div>

                        <div class="flex items-center gap-3">
                            <div
                                class="flex items-center gap-2 mr-3 no-drag opacity-60 hover:opacity-100 transition-opacity"
                            >
                                <span
                                    class="text-[9px] text-kognisant-muted font-black uppercase tracking-tighter"
                                    >Auto</span
                                >
                                <div
                                    @click="isAutopilot = !isAutopilot"
                                    class="w-8 h-4 rounded-full bg-black/30 border border-white/10 relative cursor-pointer"
                                >
                                    <div
                                        class="absolute top-0.5 w-2.5 h-2.5 rounded-full transition-all duration-300 shadow-sm"
                                        :class="
                                            isAutopilot
                                                ? 'left-4 bg-kognisant-primary'
                                                : 'left-1 bg-white/20'
                                        "
                                    ></div>
                                </div>
                                <span
                                    class="text-[9px] text-kognisant-muted font-black uppercase tracking-tighter"
                                    >Autopilot</span
                                >
                            </div>

                            <button
                                @click="sendMessage"
                                :disabled="isKernelBusy || !chatInput.trim()"
                                class="p-2 rounded-xl bg-white/5 text-white hover:bg-kognisant-primary transition-all disabled:opacity-20 shadow-flat-sm no-drag"
                            >
                                <Send :size="16" />
                            </button>
                        </div>
                    </div>
                </div>
                <div
                    class="mt-3 flex items-center justify-center gap-3 opacity-20 select-none"
                >
                    <div
                        class="w-1 h-1 rounded-full bg-kognisant-primary"
                    ></div>
                    <span
                        class="text-[8px] font-bold text-kognisant-muted uppercase tracking-[0.3em]"
                        >Synchronous Autonomous Tunnel active</span
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
    background: rgba(112, 111, 211, 0.2);
}

.no-scrollbar::-webkit-scrollbar {
    display: none;
}

textarea {
    min-height: 56px;
    max-height: 180px;
}

.shadow-flat-md {
    box-shadow: 0 4px 20px -5px rgba(0, 0, 0, 0.4);
}

/* Antialiasing for high-density IDE UI */
* {
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}

.animate-pulse {
    animation-duration: 2s;
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
