```<script setup>
import { computed } from "vue";
import {
    CheckCircle2,
    Circle,
    Loader2,
    AlertCircle,
    ClipboardList,
} from "lucide-vue-next";

/**
 * TaskBoard Component
 * Responsibility (SRP): Visualizing the execution state of autonomous sub-tasks.
 * Design: High-density list with status-specific iconography and progress tracking.
 */

const props = defineProps({
    tasks: {
        type: Array,
        default: () => [],
    },
});

const progress = computed(() => {
    if (props.tasks.length === 0) return 0;
    const completed = props.tasks.filter((t) => t.status === "completed").length;
    return Math.round((completed / props.tasks.length) * 100);
});

const getStatusIcon = (status) => {
    switch (status?.toLowerCase()) {
        case "completed":
            return CheckCircle2;
        case "active":
            return Loader2;
        case "failed":
            return AlertCircle;
        default:
            return Circle;
    }
};

const getStatusClass = (status) => {
    switch (status?.toLowerCase()) {
        case "completed":
            return "text-emerald-400";
        case "active":
            return "text-kognisant-accent animate-spin";
        case "failed":
            return "text-rose-400";
        default:
            return "text-white/20";
    }
};
</script>

<template>
    <div class="flex flex-col h-full bg-kognisant-card/20 rounded-xl border border-white/5 overflow-hidden">
        <!-- Header -->
        <div class="px-4 py-3 bg-white/5 border-b border-white/5 flex items-center justify-between">
            <div class="flex items-center gap-2">
                <ClipboardList :size="14" class="text-kognisant-accent" />
                <span class="text-[10px] font-bold tracking-widest text-kognisant-muted uppercase">
                    Execution Plan
                </span>
            </div>
            <div class="flex items-center gap-2">
                <div class="h-1.5 w-20 bg-white/5 rounded-full overflow-hidden">
                    <div
                        class="h-full bg-kognisant-accent transition-all duration-500"
                        :style="{ width: `${progress}%` }"
                    ></div>
                </div>
                <span class="text-[9px] font-mono text-kognisant-accent w-6 text-right">
                    {{ progress }}%
                </span>
            </div>
        </div>

        <!-- Task List -->
        <div class="flex-1 overflow-y-auto p-2 space-y-1 custom-scrollbar">
            <div v-if="tasks.length === 0" class="flex flex-col items-center justify-center h-full py-8 opacity-20">
                <ClipboardList :size="24" class="mb-2" />
                <span class="text-[10px] uppercase tracking-tighter italic text-center px-4">
                    No active tasks in current context
                </span>
            </div>

            <div
                v-for="task in tasks"
                :key="task.id"
                class="flex items-center gap-3 p-2 rounded-lg hover:bg-white/5 transition-all group"
            >
                <component
                    :is="getStatusIcon(task.status)"
                    :size="14"
                    :class="getStatusClass(task.status)"
                />
                <div class="flex-1 min-w-0">
                    <p class="text-[11px] text-kognisant-text truncate group-hover:text-white transition-colors">
                        {{ task.description }}
                    </p>
                </div>
                <span
                    v-if="task.status === 'completed'"
                    class="text-[8px] font-mono text-emerald-500/50 uppercase"
                >
                    Done
                </span>
            </div>
        </div>

        <!-- Footer -->
        <div class="px-4 py-2 bg-white/[0.02] border-t border-white/5">
            <p class="text-[9px] text-kognisant-muted/40 uppercase tracking-tighter text-center">
                Total Agents Reporting: {{ tasks.length > 0 ? '2' : '0' }}
            </p>
        </div>
    </div>
</template>

<style scoped>
.custom-scrollbar::-webkit-scrollbar {
    width: 4px;
}
.custom-scrollbar::-webkit-scrollbar-track {
    background: transparent;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 10px;
}
</style>
