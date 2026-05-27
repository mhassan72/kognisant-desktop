<script setup>
import { ref } from 'vue';
import {
  Folder,
  File,
  ChevronDown,
  ChevronRight,
  FolderOpen
} from 'lucide-vue-next';

/**
 * FileTree Component
 * Responsibility (SRP): Recursive rendering of directory structures.
 * Features: Toggleable nodes, file vs folder iconography, and path selection.
 */

const props = defineProps({
  node: {
    type: Object,
    required: true
  },
  depth: {
    type: Number,
    default: 0
  }
});

const emit = defineEmits(['select']);
const isOpen = ref(props.depth === 0); // Root is open by default

const toggle = () => {
  if (props.node.is_directory) {
    isOpen.value = !isOpen.value;
  }
};

const handleSelect = (node) => {
  emit('select', node);
};
</script>

<template>
  <div class="select-none">
    <!-- Node Row -->
    <div
      @click="toggle"
      @dblclick="handleSelect(node)"
      class="flex items-center gap-1.5 py-1 px-2 cursor-pointer transition-colors hover:bg-white/5 rounded-md group"
      :style="{ paddingLeft: `${depth * 12 + 8}px` }"
    >
      <!-- Expand Icon -->
      <span class="w-4 h-4 flex items-center justify-center text-kognisant-muted group-hover:text-white transition-colors">
        <template v-if="node.is_directory">
          <ChevronDown v-if="isOpen" :size="12" />
          <ChevronRight v-else :size="12" />
        </template>
      </span>

      <!-- Folder/File Icon -->
      <span class="text-kognisant-accent/80">
        <template v-if="node.is_directory">
          <FolderOpen v-if="isOpen" :size="14" />
          <Folder v-else :size="14" />
        </template>
        <File v-else :size="14" class="text-kognisant-muted" />
      </span>

      <!-- Name -->
      <span
        class="text-[11px] truncate tracking-tight"
        :class="node.is_directory ? 'text-kognisant-text font-medium' : 'text-kognisant-muted group-hover:text-white'"
      >
        {{ node.name }}
      </span>
    </div>

    <!-- Children (Recursive) -->
    <div v-if="node.is_directory && isOpen && node.children">
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
/* Scoped styles for the file tree navigation */
</style>
