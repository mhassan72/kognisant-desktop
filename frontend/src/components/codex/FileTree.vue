<script setup>
import { ref, computed } from "vue";
import {
    Folder,
    File,
    ChevronDown,
    ChevronRight,
    FolderOpen,
    FileCode,
    FileJson,
    FileText,
    FileBadge,
} from "lucide-vue-next";

/**
 * FileTree Component (Kognisant Core)
 * Responsibility (SRP): Recursive rendering of directory structures.
 * Features: High-fidelity iconography, toggleable nodes, and path selection.
 * Design: Matches professional Agentic IDE style (Cursor/Vibe).
 */

const props = defineProps({
    node: {
        type: Object,
        required: true,
    },
    depth: {
        type: Number,
        default: 0,
    },
});

const emit = defineEmits(["select"]);

// State: Track which folders are expanded
const isOpen = ref(props.depth === 0);

const toggle = () => {
    if (props.node.is_directory) {
        isOpen.value = !isOpen.value;
    }
};

const handleSelect = (node) => {
    emit("select", node);
};

// Dynamic Icon Mapping based on file extensions
const getFileIcon = (filename) => {
    const ext = filename.split(".").pop().toLowerCase();
    switch (ext) {
        case "rs":
            return FileCode;
        case "js":
        case "ts":
        case "tsx":
        case "vue":
            return FileCode;
        case "json":
            return FileJson;
        case "md":
            return FileText;
        case "toml":
        case "lock":
            return FileBadge;
        default:
            return File;
    }
};

const getIconColor = (filename, isDir) => {
    if (isDir) return "text-kognisant-primary/70";
    const ext = filename.split(".").pop().toLowerCase();
    switch (ext) {
        case "rs":
            return "text-orange-400";
        case "js":
            return "text-yellow-400";
        case "ts":
            return "text-blue-400";
        case "tsx":
            return "text-blue-300";
        case "vue":
            return "text-emerald-400";
        case "json":
            return "text-amber-300";
        case "md":
            return "text-slate-400";
        default:
            return "text-kognisant-muted";
    }
};
</script>

<template>
    <div class="select-none font-sans overflow-hidden">
        <!-- Node Row -->
        <div
            @click="toggle"
            @dblclick="handleSelect(node)"
            class="flex items-center gap-2 py-1 px-2 cursor-pointer transition-all hover:bg-white/[0.03] active:bg-white/[0.05] rounded-md group relative"
            :style="{ paddingLeft: `${depth * 12 + 8}px` }"
        >
            <!-- Active Node Indicator (Dot) -->
            <div
                v-if="depth === 0"
                class="absolute left-1 w-1 h-1 rounded-full bg-kognisant-primary opacity-20"
            ></div>

            <!-- Expand Arrow -->
            <span
                class="w-4 h-4 flex items-center justify-center text-kognisant-muted/40 group-hover:text-white/60 transition-colors"
            >
                <template v-if="node.is_directory">
                    <ChevronDown v-if="isOpen" :size="12" />
                    <ChevronRight v-else :size="12" />
                </template>
            </span>

            <!-- Folder/File Icon -->
            <span :class="getIconColor(node.name, node.is_directory)">
                <template v-if="node.is_directory">
                    <FolderOpen v-if="isOpen" :size="14" stroke-width="2.5" />
                    <Folder v-else :size="14" stroke-width="2" />
                </template>
                <component
                    v-else
                    :is="getFileIcon(node.name)"
                    :size="14"
                    stroke-width="2"
                />
            </span>

            <!-- Name -->
            <span
                class="text-[12px] truncate tracking-tight transition-colors"
                :class="
                    node.is_directory
                        ? 'text-white/80 font-semibold'
                        : 'text-kognisant-muted group-hover:text-white/90'
                "
            >
                {{ node.name }}
            </span>

            <!-- Selection Badge (Hidden by default) -->
            <div
                class="ml-auto opacity-0 group-hover:opacity-10 transition-opacity"
            >
                <div
                    class="w-1.5 h-1.5 rounded-full bg-kognisant-primary"
                ></div>
            </div>
        </div>

        <!-- Recursive Children -->
        <div
            v-if="
                node.is_directory &&
                isOpen &&
                node.children &&
                node.children.length > 0
            "
        >
            <FileTree
                v-for="child in node.children"
                :key="child.path"
                :node="child"
                :depth="depth + 1"
                @select="handleSelect"
            />
        </div>
    </div>
</template>

<style scoped>
/* Antialiasing for small text labels */
* {
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}

.truncate {
    max-width: 140px;
}
</style>
