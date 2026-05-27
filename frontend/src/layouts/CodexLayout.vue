<script setup>
import TitleBar from "../components/common/TitleBar.vue";
import {
    MessageSquare,
    Code2,
    Settings,
    Activity,
    Terminal as TerminalIcon,
    Cpu,
    GitBranch,
    Search,
    Layers,
    Layout,
} from "lucide-vue-next";

/**
 * CodexLayout
 * Responsibility: Providing the high-density frame for the Agentic IDE.
 * Architecture: Optimized for a frameless window with native OS controls.
 * Reference: Modern, transparent-capable neutral dark theme (#0f1115).
 */
</script>

<template>
    <div
        class="flex flex-col h-screen w-screen bg-kognisant-bg text-kognisant-text overflow-hidden selection:bg-kognisant-accent/30"
    >
        <!-- Frameless TitleBar (Contains global search and mode toggles) -->
        <TitleBar />

        <!-- Main IDE Core -->
        <div class="flex flex-1 pt-11 overflow-hidden">
            <!-- Activity Bar (Far Left - Ultra Slim) -->
            <aside
                class="w-11 bg-kognisant-sidebar border-r border-kognisant-border flex flex-col items-center py-4 gap-6 select-none z-[1500]"
            >
                <div
                    class="p-2 text-kognisant-accent bg-kognisant-accent/10 border border-kognisant-accent/20 rounded-lg cursor-pointer transition-all active:scale-90"
                >
                    <MessageSquare :size="18" stroke-width="2.5" />
                </div>
                <div
                    class="p-2 text-kognisant-muted hover:text-white transition-colors cursor-pointer"
                >
                    <Code2 :size="18" />
                </div>
                <div
                    class="p-2 text-kognisant-muted hover:text-white transition-colors cursor-pointer"
                >
                    <GitBranch :size="18" />
                </div>
                <div
                    class="p-2 text-kognisant-muted hover:text-white transition-colors cursor-pointer"
                >
                    <Layers :size="18" />
                </div>
                <div
                    class="p-2 text-kognisant-muted hover:text-white transition-colors cursor-pointer"
                >
                    <Search :size="18" />
                </div>

                <!-- Bottom Activity Items -->
                <div class="mt-auto mb-2 flex flex-col gap-5">
                    <div
                        class="p-2 text-kognisant-muted hover:text-white transition-colors cursor-pointer"
                    >
                        <Settings :size="18" />
                    </div>
                </div>
            </aside>

            <!-- Workspace Root (Navigator + Content + Intelligence) -->
            <div class="flex-1 flex flex-col min-w-0 overflow-hidden relative">
                <!-- Inner Application Content -->
                <main class="flex-1 relative overflow-hidden flex flex-col">
                    <slot />
                </main>

                <!-- Professional Status Bar -->
                <footer
                    class="h-6 bg-kognisant-sidebar border-t border-kognisant-border flex items-center px-3 justify-between text-[10px] uppercase tracking-wider text-kognisant-muted select-none z-[1500]"
                >
                    <div class="flex items-center gap-5">
                        <div
                            class="flex items-center gap-1.5 text-kognisant-accent font-bold"
                        >
                            <Cpu :size="10" />
                            <span>Kernel: Synchronized</span>
                        </div>
                        <div class="flex items-center gap-1.5 opacity-60">
                            <TerminalIcon :size="10" />
                            <span>Shell: Active</span>
                        </div>
                        <div class="flex items-center gap-1.5 opacity-60">
                            <GitBranch :size="10" />
                            <span>main*</span>
                        </div>
                    </div>

                    <div class="flex items-center gap-5">
                        <div class="flex items-center gap-2">
                            <span>Latency: 0.04ms</span>
                            <div class="h-2.5 w-[1px] bg-white/10"></div>
                            <span>Encoding: UTF-8</span>
                        </div>
                        <div class="flex items-center gap-1.5">
                            <span
                                class="w-1.5 h-1.5 rounded-full bg-emerald-500 shadow-[0_0_5px_rgba(16,185,129,0.5)]"
                            ></span>
                            <span class="font-bold">v1.0.0-Stable</span>
                        </div>
                    </div>
                </footer>
            </div>
        </div>
    </div>
</template>

<style scoped>
/* Ensure activity bar items are not draggable */
aside div {
    -webkit-app-region: no-drag;
}

/* Custom transitions for high-density components */
.flex-1 {
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}

/* Layout Specific Typography matching reference density */
span {
    -webkit-font-smoothing: antialiased;
}

.tracking-wider {
    letter-spacing: 0.08em;
}
</style>
