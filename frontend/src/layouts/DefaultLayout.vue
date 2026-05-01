<script setup>
import TitleBar from "../components/common/TitleBar.vue";
</script>

<template>
    <div
        class="flex flex-col h-screen w-screen bg-kognisant-bg text-kognisant-text overflow-hidden border border-white/5"
    >
        <!-- Frameless TitleBar -->
        <TitleBar />

        <!-- Main Content Area -->
        <main class="flex-grow pt-8 overflow-y-auto relative custom-scrollbar">
            <div class="container mx-auto h-full p-6 max-w-4xl">
                <slot />
            </div>
        </main>

        <!-- Global Footer / Status Bar -->
        <footer
            class="h-6 bg-kognisant-card/50 border-t border-white/5 flex items-center px-3 justify-between text-[10px] uppercase tracking-tighter text-kognisant-muted select-none"
        >
            <div class="flex items-center gap-4">
                <span>Engine: Ready</span>
                <span class="flex items-center gap-1">
                    <span
                        class="w-1.5 h-1.5 rounded-full bg-emerald-500 shadow-[0_0_5px_rgba(16,185,129,0.5)]"
                    ></span>
                    IPC Linked
                </span>
            </div>
            <div>
                <span>v0.1.0-alpha</span>
            </div>
        </footer>
    </div>
</template>

<style>
.custom-scrollbar::-webkit-scrollbar {
    width: 6px;
}
.custom-scrollbar::-webkit-scrollbar-track {
    background: transparent;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.1);
    border-radius: 10px;
}
.custom-scrollbar::-webkit-scrollbar-thumb:hover {
    background: rgba(255, 255, 255, 0.2);
}
</style>
