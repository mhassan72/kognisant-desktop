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
} from "lucide-vue-next";

// Components
import FileTree from "../../components/codex/FileTree.vue";
import CodeViewer from "../../components/codex/CodeViewer.vue";
import ThoughtChain from "../../components/codex/ThoughtChain.vue";
import TaskBoard from "../../components/codex/TaskBoard.vue";

/**
 * CodexHome View (Rewrite)
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
            "Kognisant Kernel linked. All autonomous modules synchronized. How shall we proceed?",
        timestamp: new Date().toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
        }),
    },
]);

const workspaceTree = ref(null);
const currentFile = ref("main.rs");
const currentCode = ref("");
const isKernelBusy = ref(false);

// Agentic State
const thoughtProcess = ref([]);
const subTasks = ref([]);
const activeAgents = ref([]);

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
        currentFile.ref = node.name;
        // In a real IDE, we would fetch file contents here.
        // For branding/demo:
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
            activeAgents.value = response.agents || [];

            // If the kernel generated code, update the preview
            const codeMatch = response.content.match(/```rust\n([\s\S]*?)```/);
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
    // Initial content
    currentCode.value = `// Kognisant Core initialized\n// Porting project context to Rust Kernel...\n\nfn main() {\n    let status = "Linked";\n    println!("Status: {}", status);\n}`;
});
</script>

<template>
    <div class="flex flex-1 overflow-hidden h-full">
        <!-- Pane 1: Navigator (Left) -->
        <aside
            class="w-60 border-r border-white/5 bg-kognisant-card/20 flex flex-col select-none"
        >
            <div
                class="p-4 border-b border-white/5 flex items-center justify-between"
            >
                <div class="flex items-center gap-2">
                    <Box :size="14" class="text-kognisant-accent" />
                    <span
                        class="text-[10px] font-bold tracking-widest text-kognisant-muted uppercase"
                        >Navigator</span
                    >
                </div>
                <Search
                    :size="12"
                    class="text-kognisant-muted hover:text-white cursor-pointer"
                />
            </div>
            <div class="flex-1 overflow-y-auto p-2 custom-scrollbar">
                <FileTree
                    v-if="workspaceTree"
                    :node="workspaceTree"
                    @select="handleFileSelect"
                />
                <div
                    v-else
                    class="p-8 flex flex-col items-center justify-center opacity-20 text-center gap-3"
                >
                    <div
                        class="w-5 h-5 border border-white border-t-transparent rounded-full animate-spin"
                    ></div>
                    <span class="text-[9px] uppercase tracking-[0.2em]"
                        >Context_Link...</span
                    >
                </div>
            </div>
        </aside>

        <!-- Pane 2: Workspace (Center) -->
        <section
            class="flex-1 flex flex-col bg-kognisant-bg/30 min-w-0 border-r border-white/5"
        >
            <div class="flex-1 p-6 flex flex-col gap-6 overflow-hidden">
                <!-- Code Viewer (Top Center) -->
                <div class="flex-[3] min-h-0">
                    <CodeViewer
                        :code="currentCode"
                        language="rust"
                        :filename="currentFile"
                    />
                </div>

                <!-- Execution Plan (Bottom Center) -->
                <div class="flex-[1.2] min-h-0">
                    <TaskBoard :tasks="subTasks" />
                </div>
            </div>
        </section>

        <!-- Pane 3: Intelligence (Right) -->
        <aside class="w-[400px] flex flex-col bg-kognisant-card/10">
            <!-- Header: Agent Pool -->
            <div class="p-4 border-b border-white/5 flex items-center gap-3">
                <div class="flex -space-x-2">
                    <div
                        v-for="agent in activeAgents"
                        :key="agent.id"
                        class="w-6 h-6 rounded-full bg-kognisant-accent/20 border border-kognisant-accent/40 flex items-center justify-center shadow-lg"
                        :title="`${agent.name} (${agent.role})`"
                    >
                        <Zap :size="10" class="text-kognisant-accent" />
                    </div>
                    <div
                        v-if="activeAgents.length === 0"
                        class="w-6 h-6 rounded-full bg-white/5 border border-white/10 flex items-center justify-center"
                    >
                        <Cpu :size="10" class="text-kognisant-muted/50" />
                    </div>
                </div>
                <div class="flex-1 min-w-0">
                    <span
                        class="text-[10px] font-bold text-white block leading-none truncate"
                        >Autonomous Intelligence</span
                    >
                    <span
                        class="text-[8px] text-kognisant-muted uppercase tracking-tighter"
                    >
                        {{ activeAgents.length || "0" }} Modules Reporting
                    </span>
                </div>
                <History
                    :size="14"
                    class="text-kognisant-muted hover:text-white cursor-pointer"
                />
            </div>

            <!-- Content: Stream & Chat -->
            <div
                ref="chatContainer"
                class="flex-1 overflow-y-auto custom-scrollbar flex flex-col"
            >
                <!-- Reasoning Stream (Top) -->
                <div class="p-4 border-b border-white/5 bg-white/[0.01]">
                    <div class="flex items-center gap-2 mb-4">
                        <Activity :size="12" class="text-kognisant-accent" />
                        <span
                            class="text-[10px] font-black uppercase tracking-widest text-kognisant-muted"
                            >Reasoning_Stream</span
                        >
                    </div>
                    <ThoughtChain
                        :thoughts="thoughtProcess"
                        :is-thinking="isKernelBusy"
                    />
                </div>

                <!-- Chat Messages (Bottom) -->
                <div class="p-6 space-y-6">
                    <div
                        v-for="(msg, idx) in messages"
                        :key="idx"
                        class="flex flex-col"
                        :class="
                            msg.role === 'user' ? 'items-end' : 'items-start'
                        "
                    >
                        <div
                            class="flex items-center gap-2 mb-1.5 px-1 opacity-30"
                        >
                            <span
                                class="text-[9px] font-black uppercase tracking-widest"
                            >
                                {{
                                    msg.role === "assistant"
                                        ? "KERNEL"
                                        : "OPERATOR"
                                }}
                            </span>
                            <span class="text-[8px] font-mono">{{
                                msg.timestamp
                            }}</span>
                        </div>
                        <div
                            class="px-4 py-3 rounded-2xl text-[13px] leading-relaxed border transition-all shadow-xl"
                            :class="[
                                msg.role === 'user'
                                    ? 'bg-kognisant-accent text-kognisant-bg border-transparent rounded-tr-none'
                                    : 'bg-white/5 text-kognisant-text border-white/5 rounded-tl-none',
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

            <!-- Control: Instruction Input -->
            <div class="p-4 bg-kognisant-card/30 border-t border-white/5">
                <div class="relative group">
                    <textarea
                        v-model="chatInput"
                        @keydown.enter.exact.prevent="sendMessage"
                        rows="1"
                        placeholder="Instruct the Kernel..."
                        class="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3.5 pr-12 text-sm text-white placeholder:text-kognisant-muted focus:outline-none focus:border-kognisant-accent/30 transition-all resize-none no-drag"
                    ></textarea>
                    <button
                        @click="sendMessage"
                        :disabled="isKernelBusy || !chatInput.trim()"
                        class="absolute right-2 top-1/2 -translate-y-1/2 p-2.5 rounded-lg bg-kognisant-accent text-kognisant-bg hover:opacity-80 transition-all disabled:opacity-20 no-drag shadow-lg"
                    >
                        <Send :size="16" />
                    </button>
                </div>
                <div
                    class="mt-2.5 text-center flex items-center justify-center gap-2 opacity-20"
                >
                    <div class="w-1 h-1 rounded-full bg-kognisant-accent"></div>
                    <span
                        class="text-[8px] text-kognisant-muted uppercase tracking-[0.2em] font-bold"
                    >
                        Synchronous Autonomous Tunnel active
                    </span>
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
    background: rgba(255, 255, 255, 0.1);
}

textarea {
    min-height: 48px;
    max-height: 160px;
}

/* Shimmer animation for empty states */
.animate-spin {
    animation: spin 2s linear infinite;
}

@keyframes spin {
    from {
        transform: rotate(0deg);
    }
    to {
        transform: rotate(360deg);
    }
}
</style>
