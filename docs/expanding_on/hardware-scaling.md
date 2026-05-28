# Hardware-Aware Scaling — Deep Dive

The hardware scaling system ensures Kognisant runs well on everything from a Raspberry Pi to a 32-core workstation. Every cognitive limit derives from physical constraints — no magic numbers, no hardcoded caps. The system profiles hardware at boot, computes dynamic bounds, and continuously adapts to runtime conditions.

---

## Summary

On first boot, the kernel profiles CPU, RAM, disk, GPU, and thermal state. From this profile, it computes dynamic bounds for every subsystem (tick rate, agent count, memory capacity, simulation depth). These bounds are recomputed continuously as conditions change — thermal throttling, memory pressure, or resource recovery all trigger automatic adaptation.

---

## Device Profiling Implementation

### Boot-Time Profiling

```
fn profile_device() -> DeviceProfile {
    // CPU
    let cpu_cores = num_cpus::get() as u8;
    let cpu_arch = std::env::consts::ARCH;  // x86_64, aarch64
    let cpu_model = read_cpu_model();  // /proc/cpuinfo or sysctl

    // RAM
    let total_ram_mb = sys_info::mem_info().total / 1024;
    let available_ram_mb = sys_info::mem_info().avail / 1024;

    // Disk
    let disk_type = detect_disk_type();  // SSD, HDD, SD card
    let disk_free_mb = fs2::available_space(data_dir) / (1024 * 1024);
    let disk_speed = benchmark_disk_io();  // Sequential write MB/s

    // GPU
    let gpu = detect_gpu();  // CUDA, Metal, Vulkan, or None
    let gpu_vram_mb = gpu.as_ref().map(|g| g.vram_mb).unwrap_or(0);

    // Thermal
    let cpu_temp = read_cpu_temperature();  // Platform-specific

    // Classify into tier
    let tier = classify_tier(total_ram_mb, cpu_cores, gpu);

    DeviceProfile {
        tier, cpu_cores, cpu_arch, cpu_model,
        total_ram_mb, available_ram_mb,
        disk_type, disk_free_mb, disk_speed,
        gpu, gpu_vram_mb,
        cpu_temp,
        os: std::env::consts::OS,
    }
}
```

### Tier Classification Logic

```
fn classify_tier(ram_mb: u32, cores: u8, gpu: Option<GpuInfo>) -> DeviceTier {
    match (ram_mb, cores) {
        (0..=4096, _) => DeviceTier::Minimal,
        (4097..=8192, 0..=4) => DeviceTier::Minimal,  // Low RAM + few cores
        (4097..=16384, _) => DeviceTier::Standard,
        (16385..=32768, _) if gpu.is_some() => DeviceTier::Performance,
        (16385..=32768, _) => DeviceTier::Standard,  // High RAM but no GPU
        _ => DeviceTier::Server,
    }
}
```

### Platform-Specific Detection

| Metric | macOS | Linux | Windows |
|--------|-------|-------|---------|
| CPU temp | `sysctl hw.sensors` | `/sys/class/thermal/` | WMI `MSAcpi_ThermalZoneTemperature` |
| GPU detection | Metal (always on Apple Silicon) | `/proc/driver/nvidia/` or Vulkan probe | DXGI adapter enumeration |
| Disk type | `diskutil info` | `/sys/block/*/queue/rotational` | WMI `Win32_DiskDrive` |
| RAM | `sysctl hw.memsize` | `/proc/meminfo` | `GlobalMemoryStatusEx` |

---

## Dynamic Bounds Computation Formulas

### Working Memory Capacity

```
fn working_memory_capacity(profile: &DeviceProfile, llm_context: usize) -> usize {
    let tokens_per_chunk = 500;  // Average serialized chunk size

    // Bound 1: LLM context window (max 10% for WM)
    let context_limit = llm_context / 10 / tokens_per_chunk;

    // Bound 2: Available RAM (max 5% for WM data structures)
    let ram_bytes_for_wm = profile.available_ram_mb as usize * 1024 * 1024 / 20;
    let bytes_per_chunk = tokens_per_chunk * 4;  // 4 bytes per token (f32 embedding)
    let ram_limit = ram_bytes_for_wm / bytes_per_chunk;

    // Take the minimum, clamp to sane range
    context_limit.min(ram_limit).min(50).max(2)
}
```

### Agent Count

```
fn max_agents(profile: &DeviceProfile, tick_rate: u8) -> usize {
    let tick_budget_ms = 1000 / tick_rate as u64;
    let agent_cost_ms = 2;  // ~2ms per agent per tick (perception + bid generation)
    let kernel_overhead_ms = 20;  // Fixed overhead per tick

    let available_ms = tick_budget_ms.saturating_sub(kernel_overhead_ms);
    let max_from_budget = (available_ms / agent_cost_ms) as usize;

    // Also bound by RAM (each agent holds state)
    let agent_ram_mb = 5;  // ~5MB per agent (perception buffers, strategy state)
    let max_from_ram = (profile.available_ram_mb / 50) as usize;  // Max 2% of RAM for agents

    max_from_budget.min(max_from_ram).min(20).max(2)
}
```

### Tick Rate

```
fn compute_tick_rate(profile: &DeviceProfile, thermal_state: &ThermalState) -> u8 {
    let base_rate = match profile.tier {
        DeviceTier::Minimal => 2,
        DeviceTier::Standard => 10,
        DeviceTier::Performance => 10,
        DeviceTier::Server => 10,
    };

    // Thermal throttling
    let thermal_factor = if thermal_state.cpu_temp > 85.0 {
        0.5  // Halve tick rate when hot
    } else if thermal_state.cpu_temp > 75.0 {
        0.75  // Reduce by 25%
    } else {
        1.0
    };

    ((base_rate as f64 * thermal_factor) as u8).max(1)
}
```

### Episodic Buffer Size

```
fn episodic_buffer_size(profile: &DeviceProfile) -> u32 {
    // Each tick entry: ~10KB (sensory data + predictions + surprise)
    let entry_size_kb = 10;

    // Budget: 5% of available RAM
    let ram_budget_kb = profile.available_ram_mb as u64 * 1024 / 20;
    let ram_limit = (ram_budget_kb / entry_size_kb) as u32;

    // Also bound by disk I/O (SQLite writes)
    let io_limit = match profile.disk_type {
        DiskType::SdCard => 200,    // SD cards are slow
        DiskType::Hdd => 2000,
        DiskType::Ssd => 50000,
    };

    ram_limit.min(io_limit).min(50000).max(100)
}
```

### Simulation Steps

```
fn simulation_steps(profile: &DeviceProfile) -> u8 {
    let ms_per_step = 5;  // ~5ms per causal propagation step

    let budget_ms = match profile.tier {
        DeviceTier::Minimal => 10,
        DeviceTier::Standard => 40,
        DeviceTier::Performance => 100,
        DeviceTier::Server => 200,
    };

    (budget_ms / ms_per_step).min(20).max(1) as u8
}
```

### Embedding Model Selection

```
fn select_embedding_model(profile: &DeviceProfile) -> EmbeddingConfig {
    match profile.tier {
        DeviceTier::Minimal => EmbeddingConfig::ApiOnly,  // No local model
        DeviceTier::Standard => EmbeddingConfig::Local {
            model: "all-MiniLM-L6-v2",
            dimensions: 384,
            runtime: OnnxRuntime::Cpu,
        },
        DeviceTier::Performance | DeviceTier::Server => {
            if profile.gpu.is_some() {
                EmbeddingConfig::Local {
                    model: "nomic-embed-text-v1.5",
                    dimensions: 768,
                    runtime: OnnxRuntime::Gpu,
                }
            } else {
                EmbeddingConfig::Local {
                    model: "nomic-embed-text-v1.5",
                    dimensions: 768,
                    runtime: OnnxRuntime::Cpu,
                }
            }
        }
    }
}
```

---

## Runtime Adaptation Algorithm

### Continuous Monitoring

Every 100 ticks (~10s), the MCC checks system health:

```
fn check_system_pressure(state: &SystemState) -> PressureLevel {
    let tick_overrun = state.avg_tick_duration > state.target_tick_duration * 1.5;
    let memory_pressure = state.process_rss_mb > (state.device_profile.total_ram_mb as f64 * 0.4);
    let thermal_throttle = state.cpu_temp > 80.0;
    let disk_pressure = state.disk_free_mb < 500;

    if tick_overrun && memory_pressure {
        PressureLevel::Critical
    } else if tick_overrun || memory_pressure || thermal_throttle {
        PressureLevel::High
    } else if state.avg_tick_duration > state.target_tick_duration * 1.2 {
        PressureLevel::Moderate
    } else if state.avg_tick_duration < state.target_tick_duration * 0.5 {
        PressureLevel::Underutilized
    } else {
        PressureLevel::Normal
    }
}
```

### Adaptation Response

```
fn adapt_to_pressure(pressure: PressureLevel, state: &mut SystemState) {
    match pressure {
        PressureLevel::Critical => {
            // Emergency: shed to minimum viable configuration
            state.effective_ram_mb = (state.device_profile.total_ram_mb as f64 * 0.3) as u32;
            state.tick_rate = 1;  // Survival mode
            state.agent_society.shed_to(2);  // Planner + Safety only
            state.self_modification_allowed = false;
            state.force_consolidation = true;
        }
        PressureLevel::High => {
            // Reduce: shrink resource envelope by 40%
            state.effective_ram_mb = (state.device_profile.total_ram_mb as f64 * 0.6) as u32;
            state.effective_cpu_budget_ms *= 0.7;
            // Bounds auto-recompute from reduced effective values
            recompute_all_bounds(state);
            // Shed lowest-priority agents
            let max_agents = compute_max_agents(state);
            state.agent_society.shed_to(max_agents);
        }
        PressureLevel::Moderate => {
            // Gentle reduction: shrink by 20%
            state.effective_ram_mb = (state.device_profile.total_ram_mb as f64 * 0.8) as u32;
            recompute_all_bounds(state);
        }
        PressureLevel::Normal => {
            // Maintain current configuration
        }
        PressureLevel::Underutilized => {
            // Restore: expand back to full capacity
            state.effective_ram_mb = state.device_profile.total_ram_mb;
            state.effective_cpu_budget_ms = state.target_tick_duration;
            recompute_all_bounds(state);
            // Restore shed agents
            let max_agents = compute_max_agents(state);
            state.agent_society.restore_to(max_agents);
        }
    }
}
```

---

## Thermal Throttling Response

### Temperature Zones

```
enum ThermalZone {
    Cool,       // < 60°C — full performance
    Warm,       // 60-75°C — normal, no action
    Hot,        // 75-85°C — reduce load
    Critical,   // > 85°C — emergency reduction
}

fn thermal_response(temp: f64) -> ThermalAction {
    match temp {
        t if t < 60.0 => ThermalAction::None,
        t if t < 75.0 => ThermalAction::None,
        t if t < 80.0 => ThermalAction::ReduceTickRate(0.75),
        t if t < 85.0 => ThermalAction::ReduceTickRate(0.5) + ShedAgents(2),
        _ => ThermalAction::EmergencyThrottle,  // 1Hz, 2 agents, no LLM
    }
}
```

### Thermal Hysteresis

To prevent oscillation (throttle → cool → restore → heat → throttle):

```
// Don't restore until temperature drops 5°C below throttle threshold
if currently_throttled && temp < (throttle_threshold - 5.0) {
    restore_performance();
}

// Don't throttle until temperature exceeds threshold for 3 consecutive checks
if !currently_throttled && temp > throttle_threshold {
    consecutive_hot_checks += 1;
    if consecutive_hot_checks >= 3 {
        apply_throttle();
    }
}
```

### Platform-Specific Thermal Reading

```
#[cfg(target_os = "macos")]
fn read_cpu_temp() -> Option<f64> {
    // Apple Silicon: IOKit SMC reading
    // Intel Mac: smc tool or IOKit
    smc::read_key("TC0P")  // CPU proximity temperature
}

#[cfg(target_os = "linux")]
fn read_cpu_temp() -> Option<f64> {
    // Read from thermal zone
    let path = "/sys/class/thermal/thermal_zone0/temp";
    let millidegrees: i64 = fs::read_to_string(path).ok()?.trim().parse().ok()?;
    Some(millidegrees as f64 / 1000.0)
}

#[cfg(target_os = "windows")]
fn read_cpu_temp() -> Option<f64> {
    // WMI query (requires admin on some systems)
    // Fallback: estimate from CPU frequency throttling
    None  // May not be available without admin
}
```

---

## Agent Shedding Priority Order

### Shedding Algorithm

When the system needs to reduce agent count:

```
fn shed_to(target_count: usize, agents: &mut Vec<Agent>) {
    if agents.len() <= target_count { return; }

    // Sort by shedding priority (lowest priority = shed first)
    agents.sort_by_key(|a| a.shedding_priority());

    // Shed from the bottom
    while agents.len() > target_count {
        let agent = agents.pop().unwrap();  // Remove lowest priority
        agent.enter_dormant_state();
        shed_log.push(ShedEvent { agent: agent.name(), tick: current_tick });
    }
}
```

### Priority Scoring

```
fn shedding_priority(agent: &Agent) -> u32 {
    // Higher = more important = shed last
    let base = match agent.name() {
        "SafetyAgent" => 1000,    // NEVER shed
        "PlannerAgent" => 900,
        "SocialAgent" => 800,
        "CoderAgent" => 700,
        "DebuggerAgent" => 500,
        "ResearchAgent" => 400,
        "TestAgent" => 350,
        "MemoryAgent" => 300,
        "MetaAgent" => 250,
        "ExplainAgent" => 200,
        "RefactorAgent" => 150,
        "CuriosityAgent" => 100,  // First to shed
        _ => 50,
    };

    // Adjust by recent utility (agents that have been useful recently get a boost)
    let recency_boost = if agent.last_successful_action_ticks < 1000 { 50 } else { 0 };

    // Adjust by current relevance (agent with active coalition gets boost)
    let coalition_boost = if agent.in_active_coalition() { 100 } else { 0 };

    base + recency_boost + coalition_boost
}
```

### Restoration Algorithm

When resources become available again:

```
fn restore_to(target_count: usize, dormant_agents: &mut Vec<Agent>, active: &mut Vec<Agent>) {
    while active.len() < target_count && !dormant_agents.is_empty() {
        // Restore in reverse shedding order (highest priority first)
        dormant_agents.sort_by_key(|a| std::cmp::Reverse(a.shedding_priority()));
        let agent = dormant_agents.remove(0);
        agent.exit_dormant_state();
        active.push(agent);
    }
}
```

---

## Tick Rate Adjustment Logic

### Adaptive Tick Rate

The tick rate is not fixed — it adapts to workload:

```
fn compute_adaptive_tick_rate(state: &SystemState) -> u8 {
    let base = match state.device_profile.tier {
        DeviceTier::Minimal => 2,
        _ => 10,
    };

    // Factor 1: Activity level
    let activity_factor = if state.user_active {
        1.0  // Full rate when user is engaged
    } else if state.idle_duration < Duration::from_secs(30) {
        0.8  // Slightly reduced when briefly idle
    } else if state.idle_duration < Duration::from_secs(300) {
        0.3  // Low rate when idle (save power)
    } else {
        0.1  // Minimal rate when long idle (just heartbeat)
    };

    // Factor 2: Cognitive load
    let load_factor = if state.pending_actions > 5 {
        1.0  // Full rate when there's work to do
    } else if state.pending_actions > 0 {
        0.8
    } else {
        0.5  // Reduce when nothing to process
    };

    // Factor 3: Thermal
    let thermal_factor = thermal_response(state.cpu_temp).rate_multiplier();

    // Factor 4: Fatigue (from affect)
    let fatigue_factor = 1.0 - state.affect.fatigue * 0.5;

    let effective_rate = base as f64 * activity_factor * load_factor * thermal_factor * fatigue_factor;
    (effective_rate as u8).max(1)  // Never below 1Hz
}
```

### Tick Rate Transitions

Tick rate changes are not instant — they ramp:

```
fn transition_tick_rate(current: u8, target: u8) -> u8 {
    if target > current {
        // Ramp up: increase by 1 per second
        (current + 1).min(target)
    } else if target < current {
        // Ramp down: decrease by 2 per second (faster reduction)
        current.saturating_sub(2).max(target)
    } else {
        current
    }
}
```

This prevents jarring transitions and gives subsystems time to adapt.

---

## Open Questions / Design Decisions

1. **GPU utilization**: Currently GPU is only used for embeddings (ONNX). Should it also be used for the predictive stack's neural components? Current plan: yes for Performance tier, using `burn` or `candle` with Metal/CUDA backends.

2. **Battery awareness**: On laptops, should the system reduce load when on battery? Current plan: yes — treat battery mode as a soft thermal constraint (reduce tick rate by 30%).

3. **Multi-process scaling**: On Server tier with many cores, should the system spawn multiple kernel processes? Current plan: no — single process with tokio multi-threaded runtime. Multiple processes add IPC complexity.

4. **Disk speed benchmarking**: Should the system benchmark disk I/O at boot? Current plan: yes, a quick sequential write test (1MB) to calibrate SQLite write expectations.

5. **Dynamic tier reclassification**: If the user plugs in an eGPU or adds RAM, should the tier change at runtime? Current plan: re-profile on significant hardware change detection (USB device events, memory hotplug).

6. **Power consumption target**: Should there be an explicit power budget? (e.g., "use no more than 5W average on laptop"). Current plan: no explicit power budget — thermal throttling is the proxy for power management.

---

## Research References

- **Hennessy & Patterson (2017)**. "Computer Architecture: A Quantitative Approach" — Performance modeling
- **Mittal, S. (2014)**. "A Survey of Techniques for Improving Energy Efficiency in Embedded Computing Systems" — Power-aware computing
- **ARM (2023)**. "big.LITTLE Technology" — Heterogeneous compute scheduling
- **Relevant crates**: `sys-info` (system metrics), `num_cpus` (core count), `sysinfo` (comprehensive system info), `nvml-wrapper` (NVIDIA GPU monitoring), `metal` (Apple GPU)

---

## Edge Cases and Failure Modes

1. **Thermal sensor unavailable**: Some systems (especially Windows without admin) can't read CPU temperature. Mitigation: fall back to tick duration as proxy (if ticks are taking longer, assume thermal throttling).

2. **RAM reporting inaccuracy**: Virtual machines may report incorrect available RAM. Mitigation: use process RSS as ground truth, not system-reported available RAM.

3. **SD card wear**: On Raspberry Pi, frequent SQLite writes can wear out the SD card. Mitigation: reduce write frequency on SD card (longer journal intervals, less frequent telemetry).

4. **Sudden resource loss**: Another application starts consuming resources. Mitigation: continuous monitoring detects pressure within 10s, adaptation kicks in automatically.

5. **Over-adaptation**: System keeps oscillating between pressure states. Mitigation: hysteresis on all adaptation decisions (require sustained pressure before reducing, sustained recovery before restoring).

6. **Minimal tier too minimal**: On very low-end hardware (1GB RAM, single core), even 2 agents at 2Hz might be too much. Mitigation: absolute minimum configuration: 1 agent (PlannerAgent absorbs all roles), 1Hz, no local embedding, API-only LLM.

---

## Interaction with Other Subsystems

- **Meta-Cognitive Controller**: The MCC is the primary consumer of dynamic bounds. It uses them to gate all resource allocation decisions.
- **Agent Society**: Agent count is directly bounded by hardware scaling. Shedding/restoration is triggered by the adaptation algorithm.
- **Memory Palace**: Working memory capacity, episodic buffer size, and semantic network limits all derive from hardware bounds.
- **LLM Pool**: Embedding model selection is hardware-dependent. Local model availability depends on RAM and GPU.
- **Affective Economy**: Fatigue dimension is artificially increased during thermal throttling (natural load reduction). Hardware pressure maps to cognitive fatigue.
- **Self-Modification**: Disabled on Minimal tier (no compiler typically available). On other tiers, compilation budget is bounded by available CPU time.
- **Cognitive Homeostasis**: The supervisor monitors hardware metrics. Critical thermal or memory events trigger homeostasis interventions.
- **Telemetry**: Hardware metrics are recorded for trend analysis. Helps identify if the system is consistently under-provisioned.
