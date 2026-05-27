<script setup>
import TitleBar from "../components/common/TitleBar.vue";

/**
 * Studio Layout
 * Responsibility (SRP): Providing the visual structure for the Studio module.
 * Status: Placeholder for future creative/visual logic implementation.
 */
</script>

<template>
    <div
        class="flex flex-col h-screen w-screen bg-kognisant-bg text-kognisant-text overflow-hidden border border-white/5"
    >
        <!-- Frameless TitleBar -->
        <TitleBar />

        <!-- Studio Shell -->
        <main class="flex-grow pt-8 relative overflow-hidden flex flex-col">
            <!-- Studio Toolbar Placeholder -->
            <div class="h-12 bg-white/5 border-b border-white/5 flex items-center px-4 gap-4">
                <div class="h-6 w-32 bg-white/5 rounded animate-pulse"></div>
                <div class="h-6 w-24 bg-white/5 rounded animate-pulse"></div>
            </div>

            <!-- Content -->
            <div class="flex-grow relative overflow-y-auto custom-scrollbar">
                <slot />
            </div>
        </main>

        <!-- Status Bar -->
        <footer
            class="h-6 bg-kognisant-accent/10 border-t border-kognisant-accent/20 flex items-center px-3 justify-between text-[10px] uppercase tracking-widest text-kognisant-accent select-none"
        >
            <div class="flex items-center gap-4">
                <span class="font-bold">STUDIO_MODE</span>
                <span class="flex items-center gap-1">
                    <span class="w-1.5 h-1.5 rounded-full bg-kognisant-accent shadow-[0_0_5px_rgba(56,189,248,0.5)]"></span>
                    READY
                </span>
            </div>
            <div>
                <span>Development Build</span>
            </div>
        </footer>
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
    background: rgba(56, 189, 248, 0.2);
    border-radius: 10px;
}
</style>
