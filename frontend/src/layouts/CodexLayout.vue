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
} from "lucide-vue-next";

/**
 * CodexLayout
 * Responsibility: Providing the flat, professional frame for the Kognisant Core IDE.
 * Theme: Brand (#706fd3), Dark (#2f3640).
 * Architecture: High-density sidebar and status bar with coherent brand styling.
 */
</script>

<template>
    <div
        class="flex flex-col h-screen w-screen bg-kognisant-bg text-kognisant-text overflow-hidden selection:bg-kognisant-primary/30"
    >
        <!-- Frameless TitleBar -->
        <TitleBar />

        <!-- Main IDE Workspace Container -->
        <div class="flex flex-1 pt-10 overflow-hidden">
            <!-- Activity Bar (Far Left - Flat Neutral) -->
            <aside
                class="w-11 bg-kognisant-sidebar border-r border-kognisant-border flex flex-col items-center py-4 gap-5 select-none z-[1500]"
            >
                <div
                    class="p-2 text-white bg-kognisant-primary rounded-md cursor-pointer transition-all active:scale-95 shadow-sm"
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
                <div class="mt-auto mb-2 flex flex-col gap-4">
                    <div
                        class="p-2 text-kognisant-muted hover:text-white transition-colors cursor-pointer"
                    >
                        <Settings :size="18" />
                    </div>
                </div>
            </aside>

            <!-- Content Area (Navigator + Editor + Chat) -->
            <div class="flex-1 flex flex-col min-w-0 overflow-hidden relative">
                <main class="flex-1 relative overflow-hidden flex flex-col">
                    <slot />
                </main>

                <!-- Professional Flat Status Bar -->
                <footer
                    class="h-6 bg-kognisant-sidebar border-t border-kognisant-border flex items-center px-3 justify-between text-[10px] uppercase tracking-wider text-kognisant-muted select-none z-[1500]"
                >
                    <div class="flex items-center gap-5">
                        <div
                            class="flex items-center gap-1.5 text-kognisant-primary font-bold"
                        >
                            <Cpu :size="10" />
                            <span>System: Active</span>
                        </div>
                        <div class="flex items-center gap-1.5 opacity-70">
                            <TerminalIcon :size="10" />
                            <span>Kernel_v1.0</span>
                        </div>
                        <div class="flex items-center gap-1.5 opacity-70">
                            <GitBranch :size="10" />
                            <span>main</span>
                        </div>
                    </div>

                    <div class="flex items-center gap-4">
                        <div class="flex items-center gap-2 font-mono">
                            <span>Rust_FFI: 0.02ms</span>
                            <div class="h-2 w-[1px] bg-white/10"></div>
                            <span>UTF-8</span>
                        </div>
                        <div class="flex items-center gap-1.5">
                            <div
                                class="w-1.5 h-1.5 rounded-full bg-emerald-500 shadow-[0_0_4px_rgba(16,185,129,0.5)]"
                            ></div>
                            <span class="font-bold text-white/90"
                                >Kognisant_Core</span
                            >
                        </div>
                    </div>
                </footer>
            </div>
        </div>
    </div>
</template>

<style scoped>
/* Ensure activity bar items are not part of the drag region */
aside div {
    -webkit-app-region: no-drag;
}

/* Smooth layout transitions */
.flex-1 {
    transition: all 0.2s ease-in-out;
}

/* Typography refinement for high-density IDE feel */
span,
div {
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}

.tracking-wider {
    letter-spacing: 0.06em;
}
</style>
