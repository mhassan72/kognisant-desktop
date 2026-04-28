<script setup>
import { ref, onMounted } from "vue";
import DefaultLayout from "./layouts/DefaultLayout.vue";
import CommandInput from "./components/kernel/CommandInput.vue";
import DiagnosticPanel from "./components/kernel/DiagnosticPanel.vue";

/**
 * App Root Component (Electron + Native Rust Kernel)
 * Responsibility (SRP): Orchestrates the state flow between the UI components
 * and the Rust Kernel via the Electron Context Bridge (NAPI-RS).
 */

const result = ref("");
const error = ref("");
const isLoading = ref(false);

/**
 * Handle execution requests from the CommandInput component.
 * Maps UI interactions to the 'phoenix' bridge exposed in preload.js.
 * This calls Rust code directly in the Electron main process.
 */
const handleKernelExecution = async (input) => {
    // Check if the bridge is available
    if (!window.phoenix || !window.phoenix.kernel) {
        error.value = "Electron Native Bridge not found. Check preload.js.";
        return;
    }

    // Reset states
    error.value = "";
    result.value = "";
    isLoading.value = true;

    try {
        let response;

        // Routing based on input
        if (input === "DIAGNOSTIC_RUN") {
            response = await window.phoenix.kernel.runDiagnostics();
        } else {
            response = await window.phoenix.kernel.execute(input);
        }

        result.value = response;
    } catch (err) {
        console.error("Kernel Bridge Exception:", err);
        error.value = String(err);
    } finally {
        isLoading.value = false;
    }
};

onMounted(() => {
    console.log(
        "Phoenix UI initialized. Linking to Native Rust Kernel via Electron Bridge...",
    );
});
</script>

<template>
    <DefaultLayout>
        <div class="flex flex-col gap-8 py-4">
            <!-- Header Section -->
            <section class="space-y-2">
                <h2 class="text-2xl font-bold text-white tracking-tight">
                    Native Kernel Control
                </h2>
                <p class="text-sm text-phoenix-muted max-w-lg leading-relaxed">
                    The Phoenix Engine is a native Rust module loaded directly
                    into this process. There are no local servers or open ports.
                    Communication is handled via high-speed memory-mapped IPC.
                </p>
            </section>

            <!-- Interaction Section -->
            <section class="grid grid-cols-1 md:grid-cols-5 gap-8 items-start">
                <!-- Left: Input Control (SRP Component) -->
                <div class="md:col-span-2">
                    <CommandInput
                        :loading="isLoading"
                        @execute="handleKernelExecution"
                    />
                </div>

                <!-- Right: Diagnostic Output (SRP Component) -->
                <div class="md:col-span-3">
                    <DiagnosticPanel
                        :result="result"
                        :error="error"
                        :loading="isLoading"
                    />
                </div>
            </section>

            <!-- Documentation/Help Footer -->
            <section
                class="mt-12 p-4 rounded-lg bg-white/[0.02] border border-white/5"
            >
                <h3
                    class="text-xs font-bold text-phoenix-accent uppercase tracking-widest mb-3"
                >
                    Architecture: Native Bindings (NAPI-RS)
                </h3>
                <p class="text-[11px] text-phoenix-muted leading-loose">
                    Unlike traditional desktop apps that run a local HTTP
                    server, Phoenix uses direct <code>.node</code> bindings.
                    When "EXECUTE" is clicked, the string is passed across the
                    FFI (Foreign Function Interface) boundary into the Rust
                    Kernel. This provides zero-latency execution and prevents
                    firewall or network-related interference.
                </p>
            </section>
        </div>
    </DefaultLayout>
</template>

<style>
/* Global layout styles are handled by Tailwind and DefaultLayout */
</style>
