<script setup>
import { ref, onMounted, nextTick } from "vue";
import {
  Send,
  Terminal,
  Sparkles,
  Search,
  Layers,
  ChevronRight,
  Database
} from "lucide-vue-next";

/**
 * CodexHome View
 * Responsibility: The primary agentic workspace.
 * Architecture: Built as a dual-pane interface with a focus on autonomous interaction.
 * Left Pane: System Context/File Tree (Coming soon)
 * Center: Active Agent Chat/Command Stream
 */

const chatInput = ref("");
const messages = ref([
  {
    role: "assistant",
    content: "Greetings. Kognisant Kernel is online and synchronized. How shall we proceed with our development session today?",
    timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  }
]);

const chatContainer = ref(null);
const isKernelBusy = ref(false);

const sendMessage = async () => {
  if (!chatInput.value.trim() || isKernelBusy.value) return;

  const userContent = chatInput.value;
  chatInput.value = "";

  messages.value.push({
    role: "user",
    content: userContent,
    timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  });

  scrollToBottom();

  isKernelBusy.value = true;

  try {
    // Direct link to Native Rust Kernel via bridge
    if (window.kognisant?.kernel) {
      const response = await window.kognisant.kernel.execute(userContent);

      messages.value.push({
        role: "assistant",
        content: response,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      });
    } else {
      throw new Error("Kernel Bridge Disconnected");
    }
  } catch (err) {
    messages.value.push({
      role: "assistant",
      content: `[KERNEL_EXCEPTION]: ${err.message}`,
      isError: true,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    });
  } finally {
    isKernelBusy.value = false;
    scrollToBottom();
  }
};

const scrollToBottom = async () => {
  await nextTick();
  if (chatContainer.value) {
    chatContainer.value.scrollTop = chatContainer.value.scrollHeight;
  }
};

onMounted(() => {
  scrollToBottom();
});
</script>

<template>
  <div class="flex flex-1 overflow-hidden">
    <!-- Context Sidebar (Navigator) -->
    <aside class="w-64 bg-kognisant-card/30 border-r border-white/5 flex flex-col hidden lg:flex">
      <div class="p-4 border-b border-white/5 flex items-center justify-between">
        <span class="text-[10px] font-bold tracking-widest text-kognisant-muted uppercase">Navigator</span>
        <Search :size="12" class="text-kognisant-muted" />
      </div>
      <div class="flex-1 overflow-y-auto p-2 space-y-1">
        <div class="flex items-center gap-2 px-2 py-1.5 rounded bg-white/5 text-xs text-white">
          <ChevronRight :size="14" class="text-kognisant-accent" />
          <Layers :size="14" />
          <span>Active Context</span>
        </div>
        <div class="flex items-center gap-2 px-2 py-1.5 rounded hover:bg-white/5 text-xs text-kognisant-muted transition-colors cursor-pointer">
          <ChevronRight :size="14" />
          <Database :size="14" />
          <span>Kernel Memory</span>
        </div>
      </div>
    </aside>

    <!-- Main Workspace -->
    <div class="flex-1 flex flex-col min-w-0 bg-kognisant-bg/50">
      <!-- Chat Display Area -->
      <div
        ref="chatContainer"
        class="flex-1 overflow-y-auto p-6 space-y-6 custom-scrollbar"
      >
        <div
          v-for="(msg, idx) in messages"
          :key="idx"
          class="flex flex-col max-w-3xl mx-auto"
          :class="msg.role === 'user' ? 'items-end' : 'items-start'"
        >
          <div class="flex items-center gap-2 mb-1 px-1">
            <span v-if="msg.role === 'assistant'" class="text-[9px] font-black uppercase tracking-tighter text-kognisant-accent flex items-center gap-1">
              <Sparkles :size="10" /> Kognisant_Kernel
            </span>
            <span v-else class="text-[9px] font-black uppercase tracking-tighter text-kognisant-muted">
              Operator
            </span>
            <span class="text-[9px] text-kognisant-muted/50">{{ msg.timestamp }}</span>
          </div>

          <div
            class="px-4 py-3 rounded-2xl text-sm leading-relaxed shadow-sm border transition-all"
            :class="[
              msg.role === 'user'
                ? 'bg-kognisant-accent text-kognisant-bg font-medium border-kognisant-accent/20 rounded-tr-none'
                : 'bg-kognisant-card/50 text-kognisant-text border-white/5 rounded-tl-none',
              msg.isError ? 'border-rose-500/50 text-rose-200 bg-rose-500/10' : ''
            ]"
          >
            <div v-if="msg.role === 'assistant' && !msg.isError" class="font-mono whitespace-pre-wrap">
              {{ msg.content }}
            </div>
            <div v-else>
              {{ msg.content }}
            </div>
          </div>
        </div>

        <!-- Kernel Thinking Indicator -->
        <div v-if="isKernelBusy" class="flex flex-col items-start max-w-3xl mx-auto animate-pulse">
           <div class="flex items-center gap-2 mb-1 px-1">
            <span class="text-[9px] font-black uppercase tracking-tighter text-kognisant-accent flex items-center gap-1">
              <Terminal :size="10" /> Processing...
            </span>
          </div>
          <div class="bg-kognisant-card/30 w-12 h-6 rounded-lg border border-white/5"></div>
        </div>
      </div>

      <!-- Input Integration -->
      <div class="p-6 border-t border-white/5 bg-kognisant-bg">
        <div class="max-w-3xl mx-auto relative group">
          <input
            v-model="chatInput"
            @keypress.enter="sendMessage"
            type="text"
            placeholder="Instruct the Kernel..."
            class="w-full bg-kognisant-card/50 border border-white/10 rounded-2xl px-5 py-4 pr-14 text-sm text-white placeholder:text-kognisant-muted focus:outline-none focus:border-kognisant-accent/30 focus:ring-1 focus:ring-kognisant-accent/10 transition-all no-drag shadow-2xl"
          />
          <button
            @click="sendMessage"
            class="absolute right-3 top-1/2 -translate-y-1/2 p-2 rounded-xl bg-kognisant-accent text-kognisant-bg hover:opacity-90 transition-all active:scale-95 no-drag disabled:opacity-30"
            :disabled="isKernelBusy || !chatInput.trim()"
          >
            <Send :size="18" />
          </button>
        </div>
        <div class="mt-3 flex justify-center gap-4">
          <span class="text-[9px] text-kognisant-muted flex items-center gap-1">
            <kbd class="px-1.5 py-0.5 rounded bg-white/5 border border-white/10 font-sans">Enter</kbd> to execute
          </span>
          <span class="text-[9px] text-kognisant-muted flex items-center gap-1">
            <kbd class="px-1.5 py-0.5 rounded bg-white/5 border border-white/10 font-sans">Shift + Enter</kbd> for newline
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.custom-scrollbar::-webkit-scrollbar {
  width: 5px;
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
