<script setup>
import { ref, onMounted, nextTick } from "vue";
import {
    Send,
    Box,
    Search,
    History,
    Activity,
    Cpu,
    Plus,
    Maximize2,
    Sparkles,
    Clock,
    Paperclip,
    Hash,
    MoreHorizontal,
} from "lucide-vue-next";

// Components
import FileTree from "../../components/codex/FileTree.vue";
import CodeViewer from "../../components/codex/CodeViewer.vue";
import TerminalPanel from "../../components/codex/TerminalPanel.vue";
import InteractionEvent from "../../components/codex/InteractionEvent.vue";

/**
 * CodexHome View
 * Architecture: High-Fidelity 3-Pane Agentic IDE
 *
 * PANE 1: Navigator (Contextual Workspace)
 * PANE 2: Development Stack (Editor Top / Terminal Bottom)
 * PANE 3: Intelligence (Reasoning Stream & Autonomous Control)
 */

// UI State
const chatInput = ref("");
const searchQuery = ref("");
const isAutopilot = ref(true);
const isKernelBusy = ref(false);

// Data State
const workspaceTree = ref(null);
const currentFile = ref("conversation_memory_rtdb.py");
const currentFilePath = ref(
    "src > features > agents > services > kognisant_core",
);
const currentCode = ref("");

// Agentic Stream
const interactionStream = ref([
    {
        id: "init",
        event_type: "message",
        agent_name: "Kernel",
        message:
            "Kognisant Kernel active. Project context loaded. Awaiting instructions.",
        timestamp: "12:00",
        state: "success",
    },
]);

const streamContainer = ref(null);

/**
 * IPC Handlers
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
        // Mocking path update based on node
        currentFilePath.value = node.path
            .replace(/\//g, " > ")
            .replace(/^ > /, "");
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
            const response = await window.kognisant.kernel.execute(userPrompt);

            if (response.events) {
                response.events.forEach((ev) =>
                    interactionStream.value.push(ev),
                );
            }

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

            // Update code preview if found
            const codeMatch = response.content.match(
                /```(?:rust|python|typescript|tsx|javascript)?\n([\s\S]*?)```/,
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
    // High-fidelity placeholder code from reference
    currentCode.value = `"""Conversation memory backed by Firebase RTDB.

Primary storage for conversation history. Always
available since Firebase RTDB is the app's core DB.

Architecture:
- Writes and reads are separate, non-coupled operations
- Trimming is deferred (not inline with writes)
- History loading returns a consistent snapshot
- Summary is always written BEFORE deletes (atomic-safe)
"""

import asyncio
import logging
import time
from functools import import partial
from typing import import Any

from firebase_admin import import db

logger = logging.getLogger(__name__)

_SHORT_TERM_LIMIT = 20
_TRIM_BUFFER = 5
_MSG_PREFIX = "conversations"
_SUMMARY_MAX_CHARS = 4000

class ConversationMemoryRTDB:
    """RTDB-primary conversation memory."""

    # Responsibilities:
    # - append_message: Write-only. No side effects.
    # - get_history: Returns consistent (summary + messages)
    # - snapshot for LLM context building.
    # - run_maintenance: Deferred trim + metadata + hooks.
`;
});
</script>

<template>
    <div class="flex flex-1 overflow-hidden h-full bg-kognisant-bg">
        <!-- PANE 1: NAVIGATOR (Left) -->
        <aside
            class="w-60 border-r border-kognisant-border flex flex-col bg-kognisant-sidebar/40 select-none"
        >
            <div
                class="h-10 px-4 flex items-center justify-between border-b border-white/5"
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
                    <span class="text-[9px] uppercase tracking-widest font-bold"
                        >Linking_FS...</span
                    >
                </div>
            </div>
        </aside>

        <!-- PANE 2: WORKSPACE (Center Stack) -->
        <section
            class="flex-1 flex flex-col min-w-0 bg-transparent relative border-r border-kognisant-border"
        >
            <!-- Top Editor -->
            <div class="flex-[1.5] min-h-0 overflow-hidden">
                <CodeViewer
                    :code="currentCode"
                    language="python"
                    :filename="currentFile"
                    :filepath="currentFilePath"
                />
            </div>

            <!-- Bottom Terminal -->
            <div class="flex-1 min-h-0">
                <TerminalPanel />
            </div>
        </section>

        <!-- PANE 3: INTELLIGENCE (Right) -->
        <aside
            class="w-[440px] bg-kognisant-sidebar/30 flex flex-col backdrop-blur-3xl"
        >
            <!-- Header: Context -->
            <div
                class="h-10 px-4 border-b border-kognisant-border flex items-center justify-between bg-black/10"
            >
                <div class="flex items-center gap-2">
                    <div
                        class="w-1.5 h-1.5 rounded-full bg-kognisant-primary animate-pulse"
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

            <!-- Thread Search -->
            <div class="p-3 border-b border-white/5 bg-black/5">
                <div
                    class="relative flex items-center bg-kognisant-input rounded-md border border-white/5 px-3 py-1.5 gap-2 group focus-within:border-kognisant-primary/40 transition-all"
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

            <!-- Interaction Flow -->
            <div
                ref="streamContainer"
                class="flex-1 overflow-y-auto custom-scrollbar flex flex-col p-5 gap-8 bg-black/5"
            >
                <template v-for="event in interactionStream" :key="event.id">
                    <!-- User Message -->
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

                    <!-- Kernel Event -->
                    <InteractionEvent v-else :event="event" />
                </template>

                <!-- Thinking -->
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

            <!-- Working Status -->
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
                        class="px-3 py-1 rounded bg-white/5 border border-white/5 text-[9px] font-black uppercase tracking-tight hover:bg-white/10 transition-colors"
                    >
                        Cancel
                    </button>
                    <button
                        class="px-3 py-1 rounded bg-kognisant-primary text-white text-[9px] font-black uppercase tracking-tight shadow-lg"
                    >
                        Follow
                    </button>
                </div>
            </div>

            <!-- Input Box -->
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
                        class="w-full bg-transparent border-none rounded-xl px-4 py-3 text-[13px] text-white placeholder:text-kognisant-muted focus:ring-0 resize-none"
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
                                class="flex items-center gap-2 mr-3 opacity-60 hover:opacity-100 transition-opacity"
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
                            </div>
                            <button
                                @click="sendMessage"
                                :disabled="isKernelBusy || !chatInput.trim()"
                                class="p-2 rounded-xl bg-white/5 text-white hover:bg-kognisant-primary transition-all disabled:opacity-20 shadow-sm"
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

textarea {
    min-height: 56px;
    max-height: 180px;
}

* {
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}
</style>
