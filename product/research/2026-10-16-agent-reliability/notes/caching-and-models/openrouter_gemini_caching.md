# OpenRouter + Gemini 3.x Flash / Flash-Lite: prompt caching, latency routing and fallbacks (as of 2026-10-16)

Context for the reader: the Lunna agent sends ~2k tokens of fixed system prompt + tool definitions, then variable context, 2–4 sequential chat-completions calls per turn, `tools` + `tool_choice: "auto"`. All pages below were opened on 2026-10-16. OpenRouter numbers marked "API" come from the live `GET https://openrouter.ai/api/v1/models` and `GET https://openrouter.ai/api/v1/models/google/<id>/endpoints` responses on that day; they change over time.

Model landscape note (version-dependent): `google/gemini-3.1-flash-lite` (GA, released 2026-05-07, slug `google/gemini-3.1-flash-lite-20260507`) is no longer the newest Flash-Lite. OpenRouter also lists `google/gemini-3.5-flash-lite`, `google/gemini-3.5-flash`, `google/gemini-3.6-flash`, `google/gemini-3.7-flash`, `google/gemini-3.8-flash` and the older `google/gemini-3-flash-preview` / `google/gemini-3.1-flash-lite-preview` — [OpenRouter models API](https://openrouter.ai/api/v1/models). Google calls `gemini-3-flash-preview` "our legacy Flash model" and `gemini-3.6-flash` "our previous generation Flash model" — [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing).

## 1. Implicit vs explicit caching for Gemini 3.x through OpenRouter

### Takeaway
Both exist. Implicit caching is automatic (no `cache_control`) on Gemini 2.5 and newer, including 3.x; explicit caching uses Anthropic-style `cache_control` breakpoints, costs a write (input price + 5 min of storage) and has a fixed 5-minute TTL. Flash-Lite 3.1 supports caching per Google, and OpenRouter prices both cache reads and cache writes for it, but OpenRouter's endpoint metadata currently flags `supports_implicit_caching: false` for every Gemini Flash endpoint, which contradicts its own docs. Verify with a live call.

### Cited Findings
- OpenRouter: Gemini 2.5 models and newer "support **implicit caching**"; it is automatic and needs no `cache_control` — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching)
- OpenRouter explicit Gemini caching: insert `cache_control` breakpoints "similar to Anthropic"; no limit on the number of breakpoints, but only the last one is used for Gemini caching across normal message content; OpenRouter creates, updates and deletes the underlying Gemini cache itself ("You do not need to manually create, update, or delete caches") — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching)
- Explicit caching caveat: Gemini's `systemInstruction` is immutable once cached, so a `cache_control` block in the first `system`/`developer` message cannot be followed by an uncached dynamic tail in that same message. Put dynamic content in a later `user` message — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching)
- Google: "Implicit caching is enabled by default for all Gemini 2.5 and newer models." — [Gemini API caching](https://ai.google.dev/gemini-api/docs/caching)
- Google: explicit caching is not supported in the Interactions API or on Gemini 4 Argon and later. For supported Gemini 3 and 2.5 models, use the generateContent API — [Gemini API caching](https://ai.google.dev/gemini-api/docs/caching)
- Vertex: "All Google Cloud projects have implicit caching enabled by default." It has an in-memory tier on most models and a "durable" tier on only Gemini 4 Argon (+Cyber Permissive) and Gemini 3.8 Flash (+Cyber). A cached prefix expires no later than 24 h after creation, and most entries are evicted sooner — [Vertex context cache overview](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/context-cache/context-cache-overview)
- `gemini-3.1-flash-lite` model card: "Caching: Supported" (no implicit/explicit split given); function calling, structured outputs, thinking, Batch, Flex and Priority inference are all supported; stable version `gemini-3.1-flash-lite`, last updated May 2026 — [Gemini 3.1 Flash-Lite model page](https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-lite)
- OpenRouter endpoint metadata for `google/gemini-3.1-flash-lite` lists 8 endpoints (Google AI Studio standard/flex/priority; Vertex global, global/flex, global/priority, eu, us). Each carries `input_cache_read` and `input_cache_write` prices, but `"supports_implicit_caching": false` on all of them. The same flag is false on every endpoint of `gemini-3.8-flash`, `gemini-3.5-flash-lite` and `gemini-3-flash-preview` — [OpenRouter endpoints API](https://openrouter.ai/api/v1/models/google/gemini-3.1-flash-lite/endpoints) **(conflicts with the prompt-caching doc above)**

### Inferences
- The `supports_implicit_caching` flag probably drives OpenRouter's sticky routing. If that is right, OpenRouter may not keep a session pinned to one Google endpoint for implicit hits on Gemini 3.x, while Google may still apply implicit hits on its side. This is unconfirmed. Run a quick test: send the same >min-size prefix twice within a minute and read `usage.prompt_tokens_details.cached_tokens`.
- Because only the last `cache_control` breakpoint is honored for Gemini, one breakpoint at the end of the static block (system + tools) is the whole explicit strategy.

### Gaps
- No OpenRouter page explains what `supports_implicit_caching: false` means for Gemini 3.x, or whether OpenRouter's Gemini doc (written around Gemini 2.5) was updated for 3.x. The prompt-caching page does not mention Gemini 3 at all.
- Neither source says whether OpenRouter's explicit Gemini cache includes the `tools` declarations in the cached content.

## 2. Minimum size, TTL, pricing and how to see hits

### Takeaway
The minimum cacheable prefix for Gemini 3.x is **4,096 tokens** (Google/Vertex), and **6,144** on some Flash models (3.0 Flash Preview, 3.7 Flash, 3.8 Flash) for implicit caching. So a ~2k-token system prompt plus tools is **below the threshold on its own and will not cache**. Only calls whose total prefix (static + accumulated conversation/tool results) passes ~4k can hit. Cache reads cost about 10% of input on Gemini 3.x per both Google and OpenRouter's live prices; OpenRouter's docs still say 0.25x, which is stale. Implicit has no write cost. Explicit writes cost input price + 5 minutes of storage. Hits show up in `usage.prompt_tokens_details.cached_tokens`.

### Cited Findings
- Minimums, Gemini API: 4,096 tokens for Gemini 4 Argon, 3.8 Flash, 3.6 Flash and 3.1 Pro Preview; 2,048 for 2.5 Flash and 2.5 Pro. No row for 3.1 Flash-Lite — [Gemini API caching](https://ai.google.dev/gemini-api/docs/caching)
- Minimums, Vertex: "Gemini 3 (with exceptions) and Gemini 4: 4,096 tokens"; Gemini 3.0 Flash Preview, 3.1 Pro Preview, 3.7 Flash and 3.8 Flash: 6,144 (implicit caching only); Gemini 2: 2,048. Flash-Lite is not listed separately — [Vertex context cache overview](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/context-cache/context-cache-overview)
- OpenRouter docs give older minimums: 1,024 (2.5 Flash) and 4,096 (2.5 Pro), and "typically 4,096" for explicit caching — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching) **(conflicts with Google's current 2,048 for 2.5; stale)**
- TTL, implicit: OpenRouter says "on average 3-5 minutes, but will vary" — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching). Vertex says no later than 24 h and mostly sooner — [Vertex](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/context-cache/context-cache-overview)
- TTL, explicit via OpenRouter: "Cache Writes have a 5 minute Time-to-Live (TTL) that does not update", after which a new cache must be written — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching). By contrast, Vertex's native explicit cache defaults to 60 min, with a 1-minute minimum and no maximum — [Vertex](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/context-cache/context-cache-overview)
- Read discount: OpenRouter docs say "Cached tokens are charged at 0.25x the original input token cost" — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching). Vertex says "Implicit caching provides a 90% discount on cached tokens", and for explicit "On Gemini 2.5 or later models, this discount is 90%" — [Vertex](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/context-cache/context-cache-overview) **(conflict; OpenRouter's live prices below match Google's 90%)**
- Live OpenRouter prices for `google/gemini-3.1-flash-lite`, default tier (AI Studio / Vertex global): prompt $0.25/M, completion $1.50/M, `input_cache_read` $0.025/M (10% of input), `input_cache_write` $0.0833/M. Vertex eu/us: $0.275 in, $1.65 out, $0.0275 cache read. Flex: $0.125 in, $0.75 out, $0.0125 read. Priority: cache read $0.045/M, write $0.15/M — [OpenRouter endpoints API](https://openrouter.ai/api/v1/models/google/gemini-3.1-flash-lite/endpoints)
- Google list price for `gemini-3.1-flash-lite`: input $0.25 (text/image/video), output $1.50, context caching $0.025, storage $1.00 per 1M tokens per hour — [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing)
- Other Flash prices on Google's list: `gemini-3.8-flash` and `gemini-3.6-flash` input $0.75 / output $3.75 / cache $0.075 "through Dec 31, 2026", doubling to $1.50 / $7.50 / $0.15 from Jan 1, 2027; `gemini-3.5-flash-lite` $0.30 / $2.50 / $0.03; `gemini-3-flash-preview` $0.50 / $3.00 / $0.05 — [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing). OpenRouter's live `google/gemini-3.8-flash` row shows $0.825 prompt / $4.125 completion / $0.0825 cache read (probably Vertex regional pricing as the headline) — [OpenRouter models API](https://openrouter.ai/api/v1/models)
- Write cost, explicit, via OpenRouter: "Input token price + (Cache storage price × (5 minutes / 60 minutes))" — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching). This matches the API's `input_cache_write` of $0.0833/M = $1.00/M/h × 5/60.
- Implicit: "No cache write or storage costs" — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching); "There are no storage costs for implicit caching" — [Vertex](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/context-cache/context-cache-overview)
- Response fields: `usage` is always included (`usage: {include: true}` and `stream_options.include_usage` are deprecated no-ops). `prompt_tokens_details.cached_tokens` = tokens read from cache. `prompt_tokens_details.cache_write_tokens` appears only for models with explicit caching and write pricing. `cost` is credits charged. When streaming, `usage` comes in the last SSE message — [OpenRouter usage accounting](https://openrouter.ai/docs/guides/administration/usage-accounting). `cache_discount` in the response body reports the saving, and the Activity page and `/api/v1/generation` show it too — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching)
- Native Google field names: `usage.total_cached_tokens` (Interactions API) — [Gemini API caching](https://ai.google.dev/gemini-api/docs/caching); `cachedContentTokenCount` (Vertex) — [Vertex](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/context-cache/context-cache-overview)

### Inferences
- For a ~2k static prefix, caching saves nothing on the **first** call of a turn. Calls 2–4 of the same turn carry the first call's messages plus tool results. If the whole prefix up to the last unchanged message passes 4,096 (or 6,144 on 3.7/3.8 Flash), those calls can hit. Implicit hits are free to try. Explicit caching has a write cost of about 1/3 of the full input price per cached token on 3.1 Flash-Lite ($0.0833 vs $0.25/M), a 5-minute TTL and a 4k minimum, so it only pays off when one prefix is reused about once or more within 5 minutes.
- At $0.25/M input, a 2k-token prefix costs about $0.0005 per call. The money at stake from caching is small for this workload, so latency (TTFT) is the more relevant benefit, and neither Google nor OpenRouter publishes figures for that.
- Padding the static prefix past 4,096 tokens just to reach the cache would be a deliberate trade. It is an option, not a documented recommendation.

### Gaps
- No primary source gives the minimum cacheable size for Flash-Lite (3.1 or 3.5) specifically. 4,096 is inferred from the "Gemini 3 (with exceptions)" default.
- No source quantifies the latency (TTFT) reduction from a Gemini cache hit.

## 3. Do tools / tool_choice / response_format affect cache hits?

### Takeaway
No primary source (OpenRouter, Gemini API, Vertex) documents any interaction between tool calling or structured output and Gemini cache hits. Because caching is prefix-based, anything that changes bytes early in the request, including tool definitions, must stay byte-identical across calls.

### Cited Findings
- OpenRouter's prompt-caching page does not mention tools or structured output for Gemini — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching)
- The Vertex overview does not cover tools, function calling or structured output; it mentions only "Chatbots with extensive system instructions" as a use case — [Vertex](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/context-cache/context-cache-overview)
- Under `require_parameters: false`, `tools` and `response_format` still act as soft routing preferences that narrow routing to providers supporting them — [OpenRouter provider selection](https://openrouter.ai/docs/guides/routing/provider-selection)
- All `google/gemini-3.1-flash-lite` endpoints list `tools`, `tool_choice` (none/auto/required/function), `response_format` and `structured_outputs` as supported — [OpenRouter endpoints API](https://openrouter.ai/api/v1/models/google/gemini-3.1-flash-lite/endpoints)

### Inferences
- Keep the `tools` array and its JSON (key order, descriptions) deterministic and identical across calls in a turn and across turns. Do not add or remove tools per call, for example by dropping `propose_plan` on the last step. Switching `tool_choice` or `response_format` between calls may change the translated request to Gemini, so changing them mid-turn is a plausible risk to hits. This is unverified.
- How OpenRouter orders tools relative to the system instruction when translating to Gemini is not documented. Measure `cached_tokens` instead of assuming.

### Gaps
- No documented statement anywhere on tools or response_format vs Gemini caching. A live A/B test is the only way to know.

## 4. Prompt ordering for best hit rate

### Takeaway
Static first, dynamic last, and for explicit caching keep the dynamic part out of the system message entirely (put it in a later `user` message).

### Cited Findings
- OpenRouter: keep the start of the messages array consistent and put variable content toward the end — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching)
- Google: "Place large and common contents at the beginning of your prompt" and "Send requests with a similar prefix in a short amount of time" — [Vertex](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/context-cache/context-cache-overview); same advice in [Gemini API caching](https://ai.google.dev/gemini-api/docs/caching)
- Gemini's `systemInstruction` is immutable when cached, so dynamic content (for example `now`, the day's timeline) belongs in a later `user` message, not appended to the system message — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching)
- Sticky routing (for providers flagged with implicit caching): OpenRouter routes back to the provider that served the last cached request, only when cache reads are cheaper than prompt price. "Sticky sessions expire after 10 minutes of inactivity". `session_id` (body) or the `x-session-id` header can be the sticky key. Sticky routing is skipped when `provider.order` is set — [OpenRouter prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching)

### Inferences
- Concretely: [system (fixed, no timestamps)] + [tools (fixed)] → [user: per-turn context such as now and the timeline snapshot] → [conversation] → [tool results]. Within a turn, each follow-up call should append and never rewrite earlier messages. Send a stable `session_id` per conversation. Avoid `provider.order` if relying on sticky routing, or pin a single provider with `order` + `allow_fallbacks: false`, which also keeps hits on one cache.
- Vertex and AI Studio are separate Google backends with presumably separate caches (inference). Load balancing between them, which is the default for this model, can split cache hits, so pinning one provider likely raises the hit rate.

### Gaps
- Whether Google's cache is shared between OpenRouter's AI Studio and Vertex endpoints, or across Vertex regions, is not documented.

## 5. Fallbacks (`models: [...]`), `provider.sort`, `:nitro`, latency/throughput options

### Takeaway
`models` falls back on any error from the primary model (context length, moderation, rate limit, downtime). Timeouts are not mentioned. The docs describe one fallback hop. `provider.sort: "latency"` disables load balancing and orders providers by latency. `:nitro` = sort by throughput and also admit priority-tier endpoints. Soft `preferred_max_latency` and `preferred_min_throughput` (with p50–p99 cutoffs) exist. `service_tier: "priority"` is available for Gemini 3.1 Flash-Lite on both Google providers.

### Cited Findings
- Model fallbacks: "If the model you selected returns an error, OpenRouter will try to use the fallback model instead." By default any error triggers it: context length validation, moderation flags, rate limiting, downtime. "If the fallback model is down or returns an error, OpenRouter will return that error." Billing is "priced using the model that was ultimately used". The serving model is in the response's `model` field. No maximum list size is stated for `models`; the Anthropic Messages `fallbacks` param accepts at most 3 — [OpenRouter model fallbacks](https://openrouter.ai/docs/guides/routing/model-fallbacks)
- Timeouts as a fallback trigger: not mentioned — [OpenRouter model fallbacks](https://openrouter.ai/docs/guides/routing/model-fallbacks)
- Default provider load balancing: prefers providers with no significant outage in the last 30 s, then picks among the cheapest weighted by inverse square of price; the rest are fallbacks — [OpenRouter provider selection](https://openrouter.ai/docs/guides/routing/provider-selection)
- `provider` fields: `order`, `allow_fallbacks` (default true), `require_parameters`, `data_collection`, `zdr`, `only`, `ignore`, `quantizations`, `max_price` (hard limit), and `sort` ("price" | "throughput" | "latency", or `{by, partition}` where `partition: "model"` (default) tries the primary model's endpoints first and `"none"` sorts across all models in `models`). "Setting `order` or `sort` turns off default load balancing." — [OpenRouter provider selection](https://openrouter.ai/docs/guides/routing/provider-selection)
- `preferred_min_throughput` (tokens/s) and `preferred_max_latency` (seconds): a number means p50, or pass an object with `p50`/`p75`/`p90`/`p99`. Metrics use a rolling 5-minute window. They are soft: providers that miss are moved to the end, and these settings "should therefore never prevent your request from being executed" — [OpenRouter provider selection](https://openrouter.ai/docs/guides/routing/provider-selection)
- `:nitro` sorts by throughput and makes priority-tier endpoints eligible (a superset of `sort: "throughput"`). `:floor` sorts by price and admits flex endpoints — [OpenRouter provider selection](https://openrouter.ai/docs/guides/routing/provider-selection)
- `service_tier` (top-level): `default`/`standard`, `flex`, `priority` (alias `fast`), `ultrafast`. The tier is not guaranteed. Priority falls back to default endpoints, and billing follows the endpoint that served the request, reported in the response's `service_tier`. Flex only falls back to endpoints priced at or below flex, otherwise it returns a capacity error. `:nitro` admits priority endpoints only if they win the throughput sort. `provider.order` or an explicit `service_tier: "default"` disables tier admission. `provider.sort` does not opt into any tier — [OpenRouter service tiers](https://openrouter.ai/docs/guides/features/service-tiers)
- Gemini 3.1 Flash-Lite has priority endpoints on both `google-ai-studio/priority` and `google-vertex/global/priority`, and flex endpoints on both. On 2026-10-16, `google-vertex/global/flex` showed 1-day uptime ≈63% and 30-min uptime ≈53%; the others were ≈100% — [OpenRouter endpoints API](https://openrouter.ai/api/v1/models/google/gemini-3.1-flash-lite/endpoints)

### Inferences
- Avoid flex for an interactive agent. It is cheaper but slower, can return capacity errors, and Vertex flex showed poor uptime on this day.
- For latency: `provider: { sort: "latency" }`, or `service_tier: "priority"`. Priority costs more: the cache read price rises from $0.025 to $0.045/M, so the input price likely rises too; the exact priority input price was in the truncated API output, so check it. Sorting conflicts with sticky caching because both pick the provider, so pick one strategy.
- A short `models` list (for example `["google/gemini-3.1-flash-lite", "google/gemini-3.5-flash-lite"]`) covers outages and 429s. A slow-but-successful primary will not fall back, so keep a client-side timeout in NestJS.

### Gaps
- Whether OpenRouter treats an upstream timeout as an error that triggers `models` fallback is undocumented.
- How `models` fallback interacts with `provider` settings is not described on the fallbacks page, beyond `sort.partition`.

## 6. Published latency/throughput for gemini-3.1-flash-lite on OpenRouter

### Takeaway
Not available from primary sources reachable today. The model and performance pages served no TTFT or tokens/s figures to a static fetch, and the endpoints API returned `latency_last_30m: null` and `throughput_last_30m: null` for every endpoint.

### Cited Findings
- Model/performance page text gives price ($0.25 / $1.50), 1.0M context, released May 7, 2026, thinking levels minimal/low/medium/high, and "optimized for low-latency, high-volume workloads", with no numbers — [OpenRouter performance page](https://openrouter.ai/google/gemini-3.1-flash-lite/performance)
- Endpoints API: `latency_last_30m: null`, `throughput_last_30m: null` on all 8 endpoints; max completion tokens 65,536; context 1,048,576 — [OpenRouter endpoints API](https://openrouter.ai/api/v1/models/google/gemini-3.1-flash-lite/endpoints)

### Inferences
- Thinking level matters for latency on this model (it supports `reasoning` / `reasoning_effort`). Setting minimal or low thinking is likely the biggest TTFT lever, bigger than caching. This is inferred from the model page and not measured.

### Gaps
- No TTFT or throughput numbers could be verified. The live OpenRouter page renders them client-side, so open it in a browser, or time the calls from the NestJS server.
