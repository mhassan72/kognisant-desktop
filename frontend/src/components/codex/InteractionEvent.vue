<script setup>
import { computed } from "vue";
import {
    Terminal,
    Eye,
    AlertCircle,
    CheckCircle2,
    Clock,
    FileCode,
    ChevronRight,
    Play,
    ExternalLink,
} from "lucide-vue-next";

/**
 * InteractionEvent Component (Kognisant Core)
 * Responsibility (SRP): Rendering high-density agentic output blocks.
 * Matches: Modern Agentic IDE (Cursor/Vibe style).
 */

const props = defineProps({
    event: {
        type: Object,
        required: true,
        // Model: { id, event_type, agent_name, message, detail, sub_detail, state, timestamp }
    },
});

const isCommand = computed(() => props.event.event_type === "command");
const isFileOp = computed(() => props.event.event_type === "file_op");
const isError = computed(() => props.event.state === "error");

const stateStyles = computed(() => {
    switch (props.event.state) {
        case "error":
            return "border-rose-500/30 bg-rose-500/5 text-rose-200 shadow-[0_10px_40px_-15px_rgba(244,63,94,0.15)]";
        case "success":
            return "border-emerald-500/30 bg-emerald-500/5 text-emerald-100 shadow-[0_10px_40px_-15px_rgba(16,185,129,0.1)]";
        case "warning":
            return "border-amber-500/30 bg-amber-500/5 text-amber-100";
        default:
            return "border-white/5 bg-white/[0.03] text-kognisant-text";
    }
});
</script>

<template>
    <div
        class="flex flex-col gap-2 w-full animate-in fade-in slide-in-from-bottom-3 duration-500"
    >
        <!-- Metadata Header -->
        <div class="flex items-center gap-2 px-1.5 opacity-30 select-none">
            <span
                class="text-[9px] font-black uppercase tracking-[0.2em] text-white"
            >
                {{ event.agent_name }}
            </span>
            <div class="w-1 h-1 rounded-full bg-white/20"></div>
            <span class="text-[8px] font-mono tracking-tighter">{{
                event.timestamp
            }}</span>
        </div>

        <!-- Block: COMMAND EXECUTION -->
        <div
            v-if="isCommand"
            class="group flex flex-col rounded-xl border overflow-hidden transition-all duration-300"
            :class="stateStyles"
        >
            <!-- Header Bar -->
            <div
                class="flex items-center justify-between px-4 py-2.5 bg-black/30 border-b border-inherit"
            >
                <div class="flex items-center gap-2.5">
                    <div
                        class="p-1 rounded-md"
                        :class="
                            isError
                                ? 'bg-rose-500/20'
                                : 'bg-kognisant-primary/20'
                        "
                    >
                        <Terminal
                            :size="12"
                            :class="
                                isError
                                    ? 'text-rose-400'
                                    : 'text-kognisant-primary'
                            "
                        />
                    </div>
                    <span
                        class="text-[11px] font-bold tracking-wide uppercase opacity-90"
                        >Command</span
                    >
                </div>
                <div class="flex items-center gap-3 no-drag">
                    <div class="text-[9px] font-mono opacity-40">30000ms</div>
                    <ExternalLink
                        :size="12"
                        class="opacity-30 hover:opacity-100 cursor-pointer transition-opacity"
                    />
                </div>
            </div>

            <!-- Content Area -->
            <div
                class="p-4 flex flex-col gap-4 font-mono text-[12px] leading-relaxed tracking-tight"
            >
                <div class="flex gap-2">
                    <span class="text-kognisant-primary opacity-50">$</span>
                    <code class="text-white/95 break-all whitespace-pre-wrap">{{
                        event.detail
                    }}</code>
                </div>

                <!-- Response / Output -->
                <div
                    v-if="event.sub_detail"
                    class="mt-1 p-3 rounded-lg bg-black/40 border border-white/5 text-[11px] text-kognisant-muted/80 italic leading-normal"
                >
                    {{ event.sub_detail }}
                </div>
            </div>
        </div>

        <!-- Block: FILE OPERATION -->
        <div
            v-else-if="isFileOp"
            class="flex items-center gap-4 px-4 py-3 rounded-xl bg-kognisant-input border border-white/5 group hover:border-kognisant-primary/40 hover:bg-black/40 transition-all cursor-pointer shadow-sm"
        >
            <!-- Icon Indicator -->
            <div
                class="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center border border-white/5 group-hover:border-kognisant-primary/20 transition-all"
            >
                <Eye
                    v-if="event.message.toLowerCase().includes('read')"
                    :size="14"
                    class="text-kognisant-primary"
                />
                <FileCode v-else :size="14" class="text-emerald-400" />
            </div>

            <!-- Path Metadata -->
            <div class="flex-1 flex flex-col gap-0.5 min-w-0">
                <span
                    class="text-[12px] text-white/90 font-semibold truncate tracking-tight"
                >
                    {{ event.message }}
                </span>
                <div class="flex items-center gap-2">
                    <span
                        class="text-[10px] font-mono text-kognisant-primary tracking-tighter opacity-80"
                    >
                        {{ event.detail }}
                    </span>
                    <div class="w-1 h-1 rounded-full bg-white/10"></div>
                    <span
                        v-if="event.sub_detail"
                        class="text-[10px] font-mono text-kognisant-muted tracking-tighter opacity-60"
                    >
                        lines {{ event.sub_detail }}
                    </span>
                </div>
            </div>

            <!-- Action Icon -->
            <ChevronRight
                :size="14"
                class="opacity-0 group-hover:opacity-100 -translate-x-2 group-hover:translate-x-0 transition-all text-kognisant-primary"
            />
        </div>

        <!-- Block: STANDARD AGENT MESSAGE / THOUGHT -->
        <div
            v-else
            class="px-5 py-4 rounded-2xl border transition-all text-[13px] leading-[1.6] shadow-flat-md"
            :class="[
                event.event_type === 'thought'
                    ? 'bg-transparent border-white/5 border-dashed italic text-kognisant-muted'
                    : 'bg-kognisant-card border-white/5 text-white/95',
            ]"
        >
            <div class="flex items-start gap-3">
                <div
                    v-if="event.event_type === 'thought'"
                    class="mt-1 flex-shrink-0"
                >
                    <div
                        class="w-1 h-3 bg-kognisant-primary/30 rounded-full"
                    ></div>
                </div>
                <div class="whitespace-pre-wrap tracking-tight">
                    {{ event.message }}
                </div>
            </div>
        </div>
    </div>
</template>

<style scoped>
/* Antialiasing for high-density rendering */
* {
    -webkit-font-smoothing: antialiased;
}

code {
    word-spacing: -0.1em;
}

.shadow-flat-md {
    box-shadow: 0 4px 20px -10px rgba(0, 0, 0, 0.5);
}

/* Custom Slide-in animation for stream fluidity */
@keyframes slideIn {
    from {
        opacity: 0;
        transform: translateY(12px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}

.animate-in {
    animation: slideIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
}
</style>
