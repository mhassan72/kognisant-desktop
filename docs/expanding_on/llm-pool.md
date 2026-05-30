# LLM Pool — Deep Dive

The LLM Pool is a local multi-provider router that selects the best available model for each query based on cost, speed, capability, and availability. It abstracts away provider differences and enables the system to function with any combination of local and remote models.

---

## Summary

The LLM Pool discovers available providers (Kognisant API, Ollama, OpenAI-compatible endpoints), scores models against query requirements, routes requests to the best candidate, handles failures with fallback chains, and tracks costs. LLM inference is one cognitive modality among many — not the center of the architecture.

---

## Provider Discovery Flow

### Boot-Time Discovery

```
1. CHECK AUTHENTICATION
   └── Read global.db for Kognisant API token
   └── If valid JWT → add KognisantProvider (default, 109+ models)
   └── If expired → attempt refresh → add if successful

2. DETECT LOCAL OLLAMA
   └── GET http://localhost:11434/api/tags
   └── If responds (200 OK):
       └── Parse model list from response
       └── Add OllamaProvider with detected models
   └── If connection refused → skip (Ollama not running)
   └── Also check: OLLAMA_HOST env var for custom port/host

3. SCAN ENVIRONMENT VARIABLES
   └── OPENAI_API_KEY → add OpenAI provider
   └── ANTHROPIC_API_KEY → add Anthropic provider
   └── GROQ_API_KEY → add Groq provider
   └── TOGETHER_API_KEY → add Together provider
   └── FIREWORKS_API_KEY → add Fireworks provider
   └── DEEPSEEK_API_KEY → add DeepSeek provider
   └── KOGNISANT_LLM_*_URL + KOGNISANT_LLM_*_KEY → add custom providers

4. LOAD USER CONFIG
   └── Read custom_providers from global.db
   └── For each: validate endpoint (GET /models or /v1/models)
   └── Add validated providers

5. HEALTH CHECK ALL
   └── For each provider: lightweight health check
   └── Mark unavailable providers (will be retried periodically)
   └── Log available providers + model count
```

### Runtime Re-Discovery

Providers are re-checked periodically:

```
every 60 seconds:
    - Re-check unavailable providers (maybe Ollama was started)
    - Refresh Ollama model list (user may have pulled new models)
    - Validate API tokens (refresh if expiring soon)

every 300 seconds:
    - Full provider health check
    - Update model capability metadata (if provider supports /models endpoint)
```

### Ollama Auto-Detection Details

```
fn detect_ollama() -> Option<OllamaProvider> {
    let host = env::var("OLLAMA_HOST").unwrap_or("http://localhost:11434".into());

    // 1. Health check
    let health = http_get(&format!("{}/", host), timeout: 2s);
    if health.is_err() { return None; }

    // 2. List models
    let response = http_get(&format!("{}/api/tags", host), timeout: 5s)?;
    let models: Vec<OllamaModel> = parse_json(response.body)?;

    // 3. Classify models by capability
    let classified = models.iter().map(|m| ModelInfo {
        id: m.name.clone(),
        supports_tools: is_tool_capable(&m.name),  // llama3, mistral, etc.
        supports_vision: is_vision_capable(&m.name),  // llava, etc.
        max_context: estimate_context(&m.name),  // From model name heuristics
        quality_tier: estimate_quality(&m.name, m.size),
        is_local: true,
        cost_per_token: 0.0,  // Free!
    }).collect();

    Some(OllamaProvider { base_url: host, models: classified })
}
```

---

## Model Scoring Algorithm

### Scoring Dimensions

Each model is scored against the current request on multiple dimensions:

```
struct ModelScore {
    capability_match: f64,   // Does it support required features? (0 or 1, disqualifying)
    quality: f64,            // Model quality tier (0.1 - 1.0)
    speed: f64,              // Expected latency score (0.1 - 1.0)
    cost: f64,               // Cost efficiency (0.1 - 1.0, higher = cheaper)
    locality: f64,           // Local preference bonus (0 or 0.2)
    user_preference: f64,    // Explicit user preference (0 or 0.5)
    reliability: f64,        // Historical success rate (0.5 - 1.0)
}
```

### Scoring Formula

> Note: For the authoritative implementation with exact weights, see `docs/architecture-decisions.md` Section 6.

```
total_score = (
    capability_match *  // Binary gate — 0 disqualifies
    (speed * 0.25 +
     cost * 0.25 +
     quality * 0.15 +
     user_preference * 0.05 +
     reliability * 0.10 +
     locality_bonus(request.complexity))  // 0.05-0.30 depending on complexity
)
```

### Capability Matching

Hard requirements that disqualify models:

```
fn capability_match(model: &ModelInfo, request: &LlmRequest) -> f64 {
    // Tool use required but model doesn't support it
    if request.needs_tools && !model.supports_tools { return 0.0; }

    // Vision required but model doesn't support it
    if request.needs_vision && !model.supports_vision { return 0.0; }

    // Context too long for model
    if request.estimated_tokens > model.max_context { return 0.0; }

    // Passed all gates
    1.0
}
```

### Quality Tier Classification

```
enum QualityTier {
    Frontier = 5,    // GPT-4o, Claude 3.5 Sonnet, Llama 3.1 405B
    High = 4,        // GPT-4o-mini, Claude Haiku, Llama 3.1 70B, Mistral Large
    Medium = 3,      // Llama 3.1 8B, Mistral 7B, Phi-3
    Low = 2,         // Tiny models, quantized small models
    Embedding = 1,   // Embedding-only models (not for completion)
}
```

### Speed Estimation

```
fn estimate_speed(model: &ModelInfo, provider: &dyn LlmProvider) -> f64 {
    if provider.is_local() {
        // Local models: speed depends on model size and hardware
        match model.parameter_count {
            0..=3_000_000_000 => 0.9,      // <3B: very fast locally
            3..=8_000_000_000 => 0.7,      // 3-8B: fast
            8..=30_000_000_000 => 0.5,     // 8-30B: moderate
            _ => 0.3,                       // >30B: slow locally
        }
    } else {
        // Remote models: speed depends on provider latency
        match provider.avg_latency_ms() {
            0..=200 => 0.8,
            200..=500 => 0.6,
            500..=1000 => 0.4,
            _ => 0.2,
        }
    }
}
```

---

## Cache Invalidation Strategy

### Response Cache Design

```
struct ResponseCache {
    entries: HashMap<CacheKey, CacheEntry>,
    max_size_mb: usize,
    eviction_policy: LruPolicy,
}

struct CacheKey {
    messages_hash: [u8; 32],    // BLAKE3 of serialized messages
    model_id: String,           // Same model required for cache hit
    tools_hash: Option<[u8; 32]>,  // Tool schemas affect output
    temperature: OrderedFloat<f32>,  // Different temp = different output
}

struct CacheEntry {
    response: CompletionResponse,
    created_at: Instant,
    hit_count: u32,
    cost_saved: f64,  // How much this cache hit saves
}
```

### Invalidation Rules

```
1. TTL-based: Entries expire after 1 hour (configurable)
   - Rationale: LLM outputs for same input are non-deterministic,
     but within a session, caching identical queries is safe

2. Context-change: Invalidate entries whose messages reference
   files that have changed since cache creation
   - Track file modification times in cache metadata
   - If any referenced file changed → invalidate

3. Model-change: If a model is updated (Ollama pull), invalidate
   all entries for that model
   - Ollama model digest changes → full invalidation for that model

4. Size-based: LRU eviction when cache exceeds max_size_mb
   - Default: 100MB for Standard tier, 500MB for Performance tier

5. Manual: User can clear cache from Settings
```

### What Gets Cached

| Query Type | Cached? | Rationale |
|-----------|---------|-----------|
| Code generation | Yes (1h TTL) | Same prompt → same code (mostly) |
| Explanation | Yes (1h TTL) | Deterministic for same input |
| Embedding | Yes (24h TTL) | Embeddings are deterministic |
| Tool-use queries | No | Tool outputs change (file contents, etc.) |
| Streaming responses | No | Can't cache partial streams |
| Self-modification patches | No | Must be fresh each time |

---

## Streaming SSE Parsing

### The Problem

All providers use Server-Sent Events (SSE) for streaming, but with slightly different formats:

```
// OpenAI format:
data: {"id":"chatcmpl-xxx","choices":[{"delta":{"content":"Hello"}}]}

// Ollama format:
{"model":"llama3","message":{"content":"Hello"},"done":false}

// Anthropic format:
event: content_block_delta
data: {"type":"content_block_delta","delta":{"text":"Hello"}}
```

### Unified Stream Parser

```
trait StreamParser: Send + Sync {
    fn parse_chunk(&self, raw: &[u8]) -> Vec<StreamEvent>;
}

enum StreamEvent {
    Token(String),              // Content token
    ToolCall(ToolCallDelta),    // Partial tool call
    Done(FinishReason),         // Stream complete
    Error(String),              // Provider error
}

// Provider-specific parsers
struct OpenAiStreamParser;      // Handles OpenAI, Groq, Together, Fireworks, DeepSeek
struct OllamaStreamParser;      // Handles Ollama's NDJSON format
struct AnthropicStreamParser;   // Handles Anthropic's event-based format
```

### Backpressure Handling

```
// If the consumer (cognitive kernel) can't keep up with tokens:
let (tx, rx) = mpsc::channel(buffer_size: 100);

// Producer (HTTP stream) sends tokens
// If channel is full, apply backpressure (slow down reading from socket)
// This prevents unbounded memory growth from fast providers

// Consumer reads at its own pace (tick-aligned)
// Tokens accumulate in channel buffer between ticks
```

---

## Fallback Chains

### Fallback Strategy

When the primary selected model fails:

```
fn query_with_fallback(request: &LlmRequest) -> Result<LlmResponse> {
    let candidates = selector.select(request, &providers);

    for (i, candidate) in candidates.ranked_candidates.iter().enumerate() {
        match candidate.provider.complete_stream(...).await {
            Ok(stream) => {
                // Record success for this provider
                reliability_tracker.record_success(candidate.provider_name);
                return Ok(stream);
            }
            Err(e) => {
                // Record failure
                reliability_tracker.record_failure(candidate.provider_name, &e);

                // Classify error
                match classify_error(&e) {
                    ErrorClass::Transient => continue,  // Try next candidate
                    ErrorClass::RateLimit => {
                        // Mark provider as rate-limited, skip for 60s
                        provider_status.rate_limited(candidate.provider_name, 60s);
                        continue;
                    }
                    ErrorClass::AuthFailure => {
                        // Mark provider as unavailable until re-auth
                        provider_status.mark_unavailable(candidate.provider_name);
                        continue;
                    }
                    ErrorClass::ModelNotFound => {
                        // Remove model from provider's list
                        provider_status.remove_model(candidate.provider_name, candidate.model);
                        continue;
                    }
                    ErrorClass::Fatal => {
                        // Provider is down, mark unavailable
                        provider_status.mark_unavailable(candidate.provider_name);
                        continue;
                    }
                }
            }
        }
    }

    Err(LlmError::NoAvailableProvider)
}
```

### Fallback Priority

```
Default fallback chain:
1. Best-scored model (from selector)
2. Same provider, different model (if available)
3. Local provider (Ollama) — always available offline
4. Kognisant API (reliable, managed)
5. Any remaining provider

If ALL fail:
    - Queue the request for retry in 30s
    - Notify MCC that LLM is unavailable
    - System continues operating without LLM (reduced capability)
```

---

## Cost Tracking

### Per-Query Cost Computation

```
struct QueryCost {
    provider: String,
    model: String,
    input_tokens: u32,
    output_tokens: u32,
    cost_usd: f64,
    cached: bool,  // If served from cache, cost = 0
}

fn compute_cost(provider: &str, model: &str, input: u32, output: u32) -> f64 {
    match provider {
        "ollama" => 0.0,  // Always free
        "kognisant" => {
            // Credits-based (1 credit ≈ $0.001)
            let rate = get_kognisant_rate(model);
            (input as f64 * rate.input + output as f64 * rate.output) / 1_000_000.0
        }
        _ => {
            // Standard per-token pricing
            let rate = get_provider_rate(provider, model);
            (input as f64 * rate.input + output as f64 * rate.output) / 1_000_000.0
        }
    }
}
```

### Budget Enforcement

```
struct CostBudget {
    max_per_query: f64,        // From LlmConfig (default: $0.05)
    max_per_hour: f64,         // Default: $1.00
    max_per_day: f64,          // Default: $10.00
    spent_this_hour: f64,
    spent_today: f64,
}

impl CostBudget {
    fn can_afford(&self, estimated_cost: f64) -> bool {
        estimated_cost <= self.max_per_query
        && self.spent_this_hour + estimated_cost <= self.max_per_hour
        && self.spent_today + estimated_cost <= self.max_per_day
    }
}
```

### Cost Optimization Strategies

| Strategy | Mechanism | Savings |
|----------|-----------|---------|
| Local-first routing | Prefer Ollama for simple queries | 100% (free) |
| Response caching | Don't re-query identical prompts | 50-80% of repeated queries |
| Token estimation | Reject queries that would exceed budget before sending | Prevents waste |
| Model downsizing | Use smaller model when task is simple | 50-90% per query |
| Batch embedding | Batch multiple embed requests into one call | 30-50% on embedding costs |

---

## Environment Variable Conventions

### Standard Variables

```
# Provider API keys (auto-detected)
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GROQ_API_KEY=gsk_...
TOGETHER_API_KEY=...
FIREWORKS_API_KEY=...
DEEPSEEK_API_KEY=...

# Ollama configuration
OLLAMA_HOST=http://localhost:11434  # Custom Ollama host/port

# Custom providers (pattern: KOGNISANT_LLM_{NAME}_URL + KOGNISANT_LLM_{NAME}_KEY)
KOGNISANT_LLM_MYSERVER_URL=http://localhost:8080/v1
KOGNISANT_LLM_MYSERVER_KEY=sk-local-xxx

KOGNISANT_LLM_VLLM_URL=http://gpu-server:8000/v1
KOGNISANT_LLM_VLLM_KEY=  # Empty key = no auth required

# Budget overrides
KOGNISANT_LLM_MAX_COST_PER_QUERY=0.10
KOGNISANT_LLM_MAX_COST_PER_DAY=20.00
KOGNISANT_LLM_PREFER_LOCAL=true
```

### Discovery Algorithm

```
fn discover_from_env() -> Vec<ProviderConfig> {
    let mut configs = vec![];

    // 1. Standard mappings
    for (env_var, base_url, name) in STANDARD_MAPPINGS {
        if let Ok(key) = env::var(env_var) {
            configs.push(ProviderConfig { name, base_url, api_key: key, is_local: false });
        }
    }

    // 2. Custom KOGNISANT_LLM_* pattern
    let url_vars: Vec<_> = env::vars()
        .filter(|(k, _)| k.starts_with("KOGNISANT_LLM_") && k.ends_with("_URL"))
        .collect();

    for (url_var, url_value) in url_vars {
        let name = url_var
            .strip_prefix("KOGNISANT_LLM_").unwrap()
            .strip_suffix("_URL").unwrap()
            .to_lowercase();

        let key_var = format!("KOGNISANT_LLM_{}_KEY", name.to_uppercase());
        let api_key = env::var(&key_var).unwrap_or_default();

        let is_local = url_value.contains("localhost") || url_value.contains("127.0.0.1");

        configs.push(ProviderConfig { name, base_url: url_value, api_key, is_local });
    }

    configs
}
```

---

## Open Questions / Design Decisions

1. **Model capability detection**: How to know if a model supports tools without trying? Current plan: maintain a known-models database with capability flags. For unknown models, probe with a simple tool-use query on first use.

2. **Ollama model quality assessment**: Ollama models vary wildly in quality (quantization levels, fine-tunes). How to score them? Current plan: use model size as proxy for quality, with user override capability.

3. **Streaming vs non-streaming**: Should all queries stream? Streaming is better for UX (progressive display) but adds complexity. Current plan: stream by default, non-streaming only for embedding and very short queries.

4. **Provider health monitoring**: How aggressively to mark providers as unhealthy? Current plan: 3 consecutive failures → mark unavailable for 60s. Single failure → just try next candidate.

5. **Multi-model queries**: Should the system ever query multiple models and compare outputs? (Ensemble approach.) Current plan: no for v1 — too expensive. But could be valuable for high-stakes decisions (self-modification patches).

6. **Token counting accuracy**: Different tokenizers produce different counts. How to estimate cost before sending? Current plan: use tiktoken (OpenAI tokenizer) as approximation for all providers. Slightly inaccurate but consistent.

---

## Research References

- **Jiang et al. (2023)**. "LLM-Blender: Ensembling Large Language Models with Pairwise Ranking" — Model selection
- **Chen et al. (2023)**. "FrugalGPT: How to Use Large Language Models While Reducing Cost" — Cost optimization
- **Zheng et al. (2023)**. "Judging LLM-as-a-Judge" — Model quality assessment
- **Relevant crates**: `reqwest` (HTTP client), `tokio-stream` (async streaming), `eventsource-stream` (SSE parsing), `tiktoken-rs` (token counting)

---

## Edge Cases and Failure Modes

1. **All providers down**: No LLM available at all. System continues operating in "LLM-free mode" — can still perceive, predict (using local models), and act on procedural memory. Cannot generate new code or complex reasoning.

2. **Ollama OOM**: Local model runs out of memory mid-generation. Mitigation: detect truncated response, retry with smaller model or fall back to remote.

3. **Rate limit cascade**: All remote providers rate-limited simultaneously. Mitigation: exponential backoff per provider, queue requests, prefer local models during rate-limit periods.

4. **Cost spike**: Unexpected expensive query (very long context). Mitigation: pre-estimate cost before sending, reject if over budget, notify user if daily budget is approaching limit.

5. **Model deprecation**: Provider removes a model the system relies on. Mitigation: ModelNotFound error triggers removal from model list + fallback to next best model. User notified in Settings.

6. **Stale cache serving wrong answers**: Cached response is no longer valid because context changed. Mitigation: file-change tracking in cache keys, conservative TTL (1 hour).

---

## Interaction with Other Subsystems

- **Meta-Cognitive Controller**: The MCC decides WHEN to query the LLM (budget gating, timing). The Pool decides WHERE to route the query.
- **Affective Economy**: Cost budget is modulated by affect — high fatigue reduces LLM query rate, high curiosity increases it.
- **Self-Modification**: Patch generation requires LLM queries. These are budgeted separately (higher cost tolerance for self-improvement).
- **Predictive Processing**: Layers 2+ may request LLM queries for semantic disambiguation. The Pool handles these like any other query.
- **Agent Society**: Different agents may prefer different models (CoderAgent prefers code-specialized models, ExplainAgent prefers instruction-following models). Routing hints in the request enable this.
- **Hardware Scaling**: On Minimal tier, local models may not be available (no GPU, limited RAM). The Pool adapts by routing everything to remote providers.
- **Telemetry**: Every LLM query is logged with provider, model, tokens, cost, latency, and success/failure.
- **TUI**: In Trace mode, active LLM queries show provider and model. In Paranoia mode, full routing decisions, cache hits, and cost tracking are visible. Streaming tokens render progressively in the conversation pane.
- **Skill Extraction**: The SkillMiningAgent may use LLM queries to assess skill generalizability and generate natural-language skill descriptions from observed patterns.
