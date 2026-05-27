<script setup>
import { computed } from "vue";
import { useRoute } from "vue-router";
import CodexLayout from "./layouts/CodexLayout.vue";
import StudioLayout from "./layouts/StudioLayout.vue";

/**
 * App Root Component
 * Responsibility: Orchestrates dynamic layout switching based on the current route.
 * Architecture: Uses a mapping object to resolve layouts, defaulting to Codex.
 */

const route = useRoute();

const layouts = {
    Codex: CodexLayout,
    Studio: StudioLayout,
};

const currentLayout = computed(() => {
    const layoutName = route.meta.layout || "Codex";
    return layouts[layoutName] || CodexLayout;
});
</script>

<template>
    <!-- Dynamic Layout Component -->
    <component :is="currentLayout">
        <router-view v-slot="{ Component }">
            <transition name="fade" mode="out-in">
                <component :is="Component" />
            </transition>
        </router-view>
    </component>
</template>

<style>
/* Global App Transitions */
.fade-enter-active,
.fade-leave-active {
    transition: opacity 0.15s ease;
}

.fade-enter-from,
.fade-leave-to {
    opacity: 0;
}

/* Base Styles */
html,
body {
    margin: 0;
    padding: 0;
    background-color: #0f172a;
    color: #f8fafc;
    user-select: none;
}

#app {
    width: 100vw;
    height: 100vh;
}
</style>
