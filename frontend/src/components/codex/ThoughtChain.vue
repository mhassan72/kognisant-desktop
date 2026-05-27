```<script setup>
import { computed } from "vue";
import {
    Info,
    Activity,
    AlertCircle,
    Eye,
    Cpu,
    CheckCircle2,
} from "lucide-vue-next";

/**
 * ThoughtChain Component
 * Responsibility (SRP): Visualizing the granular reasoning steps of autonomous agents.
 * Features: Level-based iconography, chronological timeline, and "Thinking" state animations.
 */

const props = defineProps({
    thoughts: {
        type: Array,
        default: () => [],
    },
    isThinking: {
        type: Boolean,
        default: false,
    },
});

const getIcon = (level) => {
    switch (level?.toLowerCase()) {
        case "action":
            return Activity;
        case "error":
            return AlertCircle;
        case "observation":
            return Eye;
        case "success":
            return CheckCircle2;
        default:
            return Info;
    }
};

const getIconColor = (level) => {
    switch (level?.toLowerCase()) {
        case "action":
            return "text-kognisant-accent";
        case "error":
            return "text-rose-400";
        case "observation":
            return "text-amber-400";
        case "success":
            return "text-emerald-400";
        default:
            return "text-kognisant-muted";
    }
};
</script>

<template>
    <div class="flex flex-col gap-4 py-2">
        <div v-if="thoughts.length === 0 && !isThinking" class="text-[10px] text-kognisant-muted/30 italic px-2">
            No active thought streams detected.
        </div>

        <div class="relative flex flex-col gap-6 pl-2">
            <!-- Continuous Timeline Line -->
            <div
                v-if="thoughts.length > 0 || isThinking"
                class="absolute left-[13px] top-2 bottom-2 w-[1px] bg-gradient-to-b from-kognisant-accent/20 via-white/5 to-transparent"
            ></div>

            <!-- Individual Thought Steps -->
            <div
                v-for="(thought, index) in thoughts"
                :key="index"
                class="relative flex gap-4 group"
            >
                <!-- Timeline Node -->
                <div
                    class="relative z-10 w-3 h-3 rounded-full bg-kognisant-bg border-2 mt-1 transition-all duration-500"
                    :class="[
                        index === thoughts.length - 1 && isThinking
                            ? 'border-kognisant-accent shadow-[0_0_8px_rgba(56,189,248,0.4)] scale-110'
                            : 'border-white/10 group-hover:border-white/20'
                    ]"
                ></div>

                <!-- Thought Content -->
                <div class="flex-1 flex flex-col gap-1">
                    <div class="flex items-center gap-2">
                        <component
                            :is="getIcon(thought.level)"
                            :size="10"
                            :class="getIconColor(thought.level)"
                        />
                        <span class="text-[9px] font-black uppercase tracking-widest text-kognisant-muted">
                            {{ thought.agent_id }}
                        </span>
                        <span class="text-[8px] text-kognisant-muted/40 font-mono">
                            {{ thought.timestamp }}
                        </span>
                    </div>
                    <p class="text-[11px] leading-relaxed text-kognisant-text/80 font-medium">
                        {{ thought.message }}
                    </p>
                </div>
            </div>

            <!-- Active Thinking State Indicator -->
            <div v-if="isThinking" class="relative flex gap-4 animate-pulse">
                <div class="relative z-10 w-3 h-3 rounded-full bg-kognisant-bg border-2 border-kognisant-accent/50 mt-1">
                    <div class="absolute inset-0 rounded-full bg-kognisant-accent animate-ping opacity-20"></div>
                </div>
                <div class="flex-1 flex flex-col gap-1">
                    <div class="flex items-center gap-2">
                        <Cpu :size="10" class="text-kognisant-accent" />
                        <span class="text-[9px] font-black uppercase tracking-widest text-kognisant-accent">
                            KERNEL_PROCESSING
                        </span>
                    </div>
                    <div class="h-2 w-24 bg-white/5 rounded-full mt-1 overflow-hidden">
                        <div class="h-full bg-kognisant-accent/20 w-1/2 animate-[shimmer_2s_infinite]"></div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<style scoped>
@keyframes shimmer {
    0% { transform: translateX(-100%); }
    100% { transform: translateX(200%); }
}

.duration-500 {
    transition-duration: 500ms;
}
</style>
