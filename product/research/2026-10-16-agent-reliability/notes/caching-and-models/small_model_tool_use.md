# Small/cheap LLMs and multi-turn tool calling (as of 2026-10-16): gemini-3.1-flash-lite vs Gemini Flash vs Claude Haiku 5.5

Research date: 2026-10-16. Every number below carries the date of the source it came from. "Unverified" means it comes only from a secondary aggregator, not a primary page I opened.

Model landscape check (primary, Google pricing page, fetched 2026-10-16): Google currently lists `gemini-3.8-flash` ("Our most intelligent Flash model"), `gemini-3.6-flash` ("previous generation"), `gemini-3-flash-preview`, `gemini-2.5-flash`, `gemini-3.5-flash-lite`, `gemini-3.1-flash-lite`, `gemini-2.5-flash-lite` — [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing). So the "current Gemini Flash" is **Gemini 3.8 Flash**, and there is a newer Flash-Lite (**3.5 Flash-Lite**) than the one Lunna uses. Claude Haiku 5.5 was released 2026-10-07 (model id `claude-haiku-5-5`) — [Anthropic, Claude Haiku 5.5](https://www.anthropic.com/news/claude-haiku-5-5).

## Q1. BFCL v4 standings (overall, multi-turn, relevance/irrelevance)

### Takeaway
BFCL's current snapshot (last updated 2026-04-12) lists **none** of the three candidate models (no Gemini 3.1 Flash-Lite, no Gemini 3.x Flash, no Haiku 5.5). The newest comparable rows are Claude Haiku 4.5 (rank 6, 68.70% overall, 53.62% multi-turn) and Gemini 2.5 Flash / 2.5 Flash-Lite (56.24% / 36.87% overall; 36.25% / 13.50% multi-turn). Among older small models, multi-turn is where they collapse, and the FC vs prompt mode gap is very large.

### Cited Findings
- Leaderboard last updated **2026-04-12**, evaluated at commit f7cf735 = PyPI `bfcl-eval==2025.12.17` — [BFCL leaderboard](https://gorilla.cs.berkeley.edu/leaderboard.html)
- The leaderboard data file (`data_overall.csv`, 108 model rows, fetched 2026-10-16) contains no row for Gemini 3.1 Flash-Lite, Gemini 3/3.5/3.6/3.8 Flash, or any Haiku newer than 4.5. The only Gemini 3 rows are Gemini-3-Pro-Preview — [BFCL data_overall.csv](https://gorilla.cs.berkeley.edu/data_overall.csv)
- Rows from that file (columns: rank, overall, multi-turn overall, MT base / miss-func / miss-param / long-context, relevance, irrelevance, mean latency s, total cost $) — [BFCL data_overall.csv](https://gorilla.cs.berkeley.edu/data_overall.csv):

| Model (mode) | Rank | Overall | Multi-turn | MT base / miss func / miss param / long ctx | Relevance | Irrelevance | Latency mean (s) | Cost ($) |
|---|---|---|---|---|---|---|---|---|
| Claude-Opus-4-5 (FC) | 1 | 77.47% | 68.38% | 81.0 / 64.0 / 58.0 / 70.5 | 62.50% | 84.72% | 4.38 | 86.55 |
| Claude-Sonnet-4-5 (FC) | 2 | 73.24% | 61.37% | 69.0 / 65.0 / 52.5 / 59.0 | 68.75% | 86.61% | 4.31 | 43.73 |
| Gemini-3-Pro-Preview (Prompt) | 3 | 72.51% | 60.75% | 64.5 / 60.0 / 54.5 / 64.0 | 68.75% | 85.59% | 12.08 | 298.47 |
| Claude-Haiku-4-5 (FC) | 6 | 68.70% | 53.62% | 63.5 / 42.5 / 52.5 / 56.0 | 62.50% | 85.11% | 1.68 | 14.23 |
| Gemini-2.5-Flash (FC) | 15 | 56.24% | 36.25% | 41.5 / 36.0 / 32.0 / 35.5 | 75.00% | 93.67% | 2.99 | 26.36 |
| Gemini-2.5-Flash (Prompt) | 26 | 50.90% | 16.75% | 14.5 / 16.5 / 17.5 / 18.5 | 62.50% | 91.09% | 3.18 | 33.45 |
| Gemini-2.5-Flash-Lite (FC) | 52 | 36.87% | 13.50% | 20.0 / 1.5 / 15.0 / 17.5 | 43.75% | 92.50% | 1.18 | 7.55 |
| Gemini-2.5-Flash-Lite (Prompt) | 73 | 28.03% | 7.63% | 10.0 / 5.0 / 6.5 / 9.0 | 50.00% | 93.33% | 1.00 | 7.05 |
| Claude-Haiku-4-5 (Prompt) | 87 | 25.26% | 1.75% | 1.5 / 0.0 / 4.0 / 1.5 | 31.25% | 95.29% | 3.75 | 45.13 |

### Inferences
- The previous-generation Flash-Lite (2.5) scored 13.5% multi-turn in native FC mode, and **1.5%** on "missing function" turns (where the right move is to notice a tool is unavailable and not fake it). If 3.1 Flash-Lite inherits even part of that profile, open-ended multi-turn tool use is its weakest area. This is an inference from the predecessor, not a measurement of 3.1 Flash-Lite.
- High "irrelevance" scores (≈92–95%) for Flash/Flash-Lite mean they rarely call a tool when none applies; the low "relevance" (43.75% for 2.5 Flash-Lite) means they also miss calls that should happen. A conservative small model tends to answer without calling a tool.
- Native function calling (FC) beat prompt mode on every small model (Haiku 4.5: 68.70% vs 25.26%), so use the provider's native tool API, not a prompt-format tool protocol.
- Haiku 4.5 had the lowest mean latency among the strong models (1.68 s), and only 2.5 Flash-Lite was faster (1.18 s).

### Gaps
- No BFCL v4 numbers exist for gemini-3.1-flash-lite, gemini-3.8-flash (or 3.5/3.6 Flash), or Claude Haiku 5.5 as of the 2026-04-12 snapshot. Haiku 5.5 (Oct 2026) and 3.8 Flash (reported Sep 2026) were released after the snapshot. 3.1 Flash-Lite (Mar 2026) came out before it but is not listed.

## Q2. tau-bench / tau2-bench results (incl. pass^k) and vendor-reported numbers

### Takeaway
I found **no primary-source tau2-bench number for any of the three candidates**. The Gemini 3.1 Flash-Lite and 3.5 Flash model cards and the Anthropic Haiku 5.5 announcement report no tau2-bench score. The official taubench.com preview shows only the top-3 models (pass^1), and the full table was not retrievable. Vendor-reported agentic tool-use numbers do exist for Gemini 3.5 Flash (MCP Atlas, Toolathlon) but not for 3.1 Flash-Lite or Haiku 5.5.

### Cited Findings
- Gemini 3.1 Flash-Lite model card (published 2026-03-03): the eval table covers HLE, GPQA, MMMU-Pro, CharXiv, Video-MMMU, SimpleQA, FACTS, MMMLU, LiveCodeBench and MRCR v2. It has **no tau2-bench, BFCL or other numeric tool-use score**, although the card says the model was evaluated on "agentic tool use" — [DeepMind model card, Gemini 3.1 Flash-Lite](https://deepmind.google/models/model-cards/gemini-3-1-flash-lite/)
- Gemini 3.5 Flash model card (published 2026-05-19) reports agentic tool-use benchmarks: **MCP Atlas 83.6%** (Gemini 3 Flash 62.0%, Claude Sonnet 4.6 69.5%, Opus 4.7 79.1%, GPT-5.5 75.3%), **Toolathlon 56.5%** (3 Flash 49.4%, GPT-5.5 55.6%), Terminal-bench 2.1 76.2%, OSWorld-Verified 78.4%, Finance Agent v2 57.9%, GDPval-AA 1656. No tau2-bench — [DeepMind model card, Gemini 3.5 Flash](https://deepmind.google/models/model-cards/gemini-3-5-flash/)
- Claude Haiku 5.5 announcement (2026-10-07) reports GDPval-AA v2.1 1620 Elo (Haiku 4.5: 735; Sonnet 5.5: 1840), OSWorld 2.1 offline subset 72.4% (Haiku 4.5: 15.7%), Terminal-Bench 4.0 39.2%, FrontierCode 1.1 46.4%, HLE no tools 45.9% / with tools 57.4%. **No tau2-bench, BFCL or MCP Atlas** — [Anthropic, Claude Haiku 5.5](https://www.anthropic.com/news/claude-haiku-5-5)
- Customer-reported results in the Haiku 5.5 announcement, all vendor-selected: HubSpot "92.8% averaged over three runs" on its CRM suite; Asana "over a 30% reduction in latency for task completions and up to 2.5x faster inference per agent turn"; Box "11 points higher than Haiku 4.5 at about half the latency" — [Anthropic, Claude Haiku 5.5](https://www.anthropic.com/news/claude-haiku-5-5)
- taubench.com (fetched 2026-10-16) preview, τ²-bench text (retail/airline/telecom), pass^1: 1) Qwen3.5-397B-A17B 87.9%, 2) Gemini 3.0 Pro 85.4%, 3) Claude Opus 4.5 85.3%. It also now hosts τ³-Banking (knowledge retrieval; top: Qwen 3.8 Max 55.2%, Claude Opus 5 48.7%) and τ³-Voice. Flash/Flash-Lite/Haiku rows were not in the retrievable content, and pass^k was not shown — [taubench.com](https://taubench.com)
- The tau2-bench repo lists domains `mock`, `airline`, `retail`, `telecom`, `banking_knowledge` and points to taubench.com for the leaderboard — [sierra-research/tau2-bench](https://github.com/sierra-research/tau2-bench)
- Unverified (third-party aggregator): DataLearner lists τ²-Bench 90.20 for Gemini 3.0 Flash. BenchLM (snapshot 2026-07-29) warns that its tau2 rows mix harnesses and user simulators, so they are not comparable — [web search summary of DataLearner/BenchLM](https://benchlm.ai/benchmarks/tau2-bench). I did not open these pages, so treat both as unverified.

### Inferences
- For a calendar agent, MCP Atlas and Toolathlon (multi-step tool use) are the closest vendor-reported proxies. Only the Gemini Flash line reports them, and 3.5 Flash's 83.6% MCP Atlas beat several frontier models in Google's own table. Nothing comparable exists for 3.1 Flash-Lite.
- The large Haiku 4.5 → 5.5 jumps on agentic suites (OSWorld 15.7% → 72.4%, Terminal-Bench 0.0% → 39.2%) suggest a step change in agentic ability. These are not tool-calling benchmarks of the tau2 kind, though, so they don't stand in for one.
- The safest evidence for this decision is an in-house eval on Lunna's own transcripts (pass^k over repeated runs), since no public tau2 pass^k exists for any of the three candidates.

### Gaps
- tau2-bench pass^1/pass^k for gemini-3.1-flash-lite, gemini-3.8-flash and Claude Haiku 5.5: not found in any primary source.
- Haiku 5.5 system card: not opened (not linked in the fetched content). It may contain tau2 numbers.
- Gemini 3.8 Flash official model card: not opened. The release date (2026-09-02) and benchmarks come only from secondary sources (computingforgeeks, Vellum, eesel), so they are unverified.

## Q3. Latency / throughput / price

### Takeaway
On list price Haiku 5.5 is now the cheapest of the three ($0.10 in / $0.50 out per 1M tokens under 100k prompt tokens). 3.1 Flash-Lite costs $0.25/$1.50 and 3.8 Flash $0.75/$3.75 (rising to $1.50/$7.50 on 2027-01-01). On speed, Google's card claims 363 output tok/s for 3.1 Flash-Lite. Anthropic calls Haiku 5.5 its "fastest model to date" but gives no tok/s figure. I found no independent latency/TTFT measurements.

### Cited Findings
- Gemini API standard paid tier, per 1M tokens (fetched 2026-10-16) — [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing):
  - `gemini-3.1-flash-lite`: input $0.25 (text/image/video), output $1.50, cached input $0.025
  - `gemini-3.5-flash-lite`: input $0.30, output $2.50, cached $0.03
  - `gemini-3.8-flash`: input $0.75 through 2026-12-31 then $1.50 from 2027-01-01; output $3.75 then $7.50; cached $0.075 then $0.15 (+ cache storage $0.50/1M tok/hour, then $1.00)
  - `gemini-3.6-flash`: same price as 3.8 Flash
  - `gemini-3-flash-preview`: $0.50 / $3.00
- Claude Haiku 5.5 (2026-10-07): input $0.10 (≤100k prompt) / $0.50 (>100k); output $0.50 / $2.50; cache reads $0.01 / $0.05; cache writes $0.125 / $0.625. Haiku 4.5 was $1.00 / $5.00. Anthropic says it is "around 75% less to run" than Haiku 4.5 on average, and calls it "our fastest model to date", "at each model's standard speed" — [Anthropic, Claude Haiku 5.5](https://www.anthropic.com/news/claude-haiku-5-5)
- Google-reported output speed (Mar 2026 card): Gemini 3.1 Flash-Lite (High) **363 tok/s**, 2.5 Flash 249, 2.5 Flash-Lite 366, Claude 4.5 Haiku 108, GPT-5 mini 71, Grok 4.1 Fast 145 — [DeepMind model card, Gemini 3.1 Flash-Lite](https://deepmind.google/models/model-cards/gemini-3-1-flash-lite/)
- OpenRouter's page for `google/gemini-3.1-flash-lite` showed only the EU in-region Vertex price ($0.275 in / $1.65 out). Context, TTFT and throughput were not in the fetched content — [OpenRouter](https://openrouter.ai/google/gemini-3.1-flash-lite)
- BFCL-measured mean latency per call (older models, 2026-04-12 snapshot): Haiku 4.5 FC 1.68 s, 2.5 Flash FC 2.99 s, 2.5 Flash-Lite FC 1.18 s — [BFCL data_overall.csv](https://gorilla.cs.berkeley.edu/data_overall.csv)
- Secondary, unverified: 3.7/3.8 Flash reportedly reject the "minimal" thinking level that older Flash models accepted, which would set a floor on latency — [computingforgeeks](https://computingforgeeks.com/gemini-3-8-flash-released-features-benchmarks/)

### Inferences
- Lunna's agent re-sends the day (read_timeline output) every turn, so input tokens dominate cost. Haiku 5.5's $0.10 input and $0.01 cache read are 2.5x cheaper than 3.1 Flash-Lite and 7.5x cheaper than 3.8 Flash for input under 100k tokens. Price no longer argues for Flash-Lite.
- Latency for a multi-step tool loop depends on TTFT × number of round trips, not on throughput alone. 363 tok/s says little about TTFT, and cutting tool round trips (see Q4) may matter more than the model choice.

### Gaps
- Independent TTFT / end-to-end latency for 3.1 Flash-Lite, 3.8 Flash and Haiku 5.5: Artificial Analysis returned 404 for the page I tried, and the OpenRouter content held no throughput stats. No independent measurement found.
- Haiku 5.5 tokens/s: not stated by Anthropic.

## Q4. Evidence that tool design (consolidation, fewer tools, constrained args, deterministic server logic) improves (small-)model tool use

### Takeaway
There is solid vendor-engineering and academic evidence that fewer and better-shaped tools, constrained arguments and short tool outputs improve tool-use accuracy and cut steps and latency. Quantitative evidence specific to *small* models is thinner, but it points the same way: pruning the tool set helped small models most.

### Cited Findings
- Anthropic, "Building effective agents" (2024-12-19): "Poka-yoke your tools. Change the arguments so that it is harder to make mistakes." For SWE-bench, "we changed the tool to always require absolute filepaths" and "we found that the model used this method flawlessly". The post also recommends formats close to natural text and avoiding formatting overhead — [Anthropic, Building effective agents](https://www.anthropic.com/engineering/building-effective-agents)
- Anthropic, "Writing effective tools for agents" (2025-09-11): "We recommend building a few thoughtful tools targeting specific high-impact workflows"; "More tools don't always lead to better outcomes"; consolidate related calls (e.g. one scheduling tool instead of separate list and create tools); return natural-language identifiers instead of UUIDs (fewer hallucinations); add a `response_format` concise/detailed option (concise used ~⅓ of the tokens, 72 vs 206); write actionable error messages; use unambiguous parameter names and strict input models — [Anthropic, Writing effective tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents)
- Vercel (2025-12-22): removing ~80% of their data agent's specialized tools (down to one bash tool, model Claude Opus 4.5) on 5 queries took success from 80% to 100%, time from 274.8 s to 77.4 s (3.5x faster), tokens from ~102k to ~61k (−37%) and steps from ~12 to ~7 (−42%). Note: frontier model, tiny sample, and the change was toward a *general* tool, so it shows "fewer tools" rather than "more constrained tools" — [Vercel blog](https://vercel.com/blog/we-removed-80-percent-of-our-agents-tools)
- LongFuncEval (IBM authors, arXiv 2505.10570, 2025-04-30): "a performance drop of 7% to 85% as the number of tools increases"; "a 7% to 91% degradation in answer retrieval as the tool responses length increases"; "13% and 40% degradation for as multi-turn conversations get longer" — [arXiv 2505.10570](https://arxiv.org/abs/2505.10570)
- Secondary summary, abstract not opened: DTDR (arXiv 2512.17052, ACL 2026 Findings) finds that hard-masking (pruning) the tool set shown to the model gave the highest accuracy for smaller on-device models — [arXiv 2512.17052](https://arxiv.org/pdf/2512.17052). CONFETTI (arXiv 2506.01859) reports a tendency to lower performance as the number of APIs grows, though not uniformly by model size — [arXiv 2506.01859](https://arxiv.org/pdf/2506.01859)

### Inferences
- For Lunna: moving wall-clock/date resolution (e.g. "amanhã às 15h" → ISO instant), id lookup by name, and validity checks into deterministic server code is the "poka-yoke" pattern Anthropic describes. It shrinks the error surface where small models fail most (see Q5). Lunna's current design (three tools, server-side `rehearse`, errors returned to the model) is already aligned. The remaining levers are argument shapes (enums, relative-day + HH:MM instead of free timestamps, titles/ids resolved server-side) and a compact `read_timeline` output.
- Fewer round trips (e.g. putting the day in the first message, or having `propose_plan` return the rehearsed result) cuts latency directly, whichever model is used.

### Gaps
- I found no controlled study that measures the same small model with consolidated vs fragmented tools on a calendar/scheduling task. The evidence is vendor anecdotes plus general tool-count studies.

## Q5. Known weaknesses of small models in multi-turn tool use

### Takeaway
The measured weak points are multi-turn state (BFCL multi-turn scores roughly halve from frontier to small models), recognizing a missing function or parameter (2.5 Flash-Lite: 1.5% on miss-func), long context and long tool outputs, and conversation length. I found no primary source that measures date arithmetic directly.

### Cited Findings
- BFCL multi-turn subcategories (2026-04-12): Gemini-2.5-Flash-Lite FC base 20.0%, miss-func 1.5%, miss-param 15.0%, long-context 17.5%; Haiku 4.5 FC 63.5 / 42.5 / 52.5 / 56.0; Opus 4.5 FC 81.0 / 64.0 / 58.0 / 70.5 — [BFCL data_overall.csv](https://gorilla.cs.berkeley.edu/data_overall.csv)
- BFCL memory category (state kept across turns): 2.5 Flash-Lite FC 20.65% vs Haiku 4.5 FC 54.41% vs Opus 4.5 73.76% — [BFCL data_overall.csv](https://gorilla.cs.berkeley.edu/data_overall.csv)
- Accuracy degrades with more tools (7–85%), longer tool responses (7–91%) and longer multi-turn conversations (13–40%) — [arXiv 2505.10570](https://arxiv.org/abs/2505.10570)
- Long-context retrieval (MRCR v2 8-needle, 128k): 3.1 Flash-Lite 60.1% (Mar 2026 card); 3.5 Flash 77.3% (May 2026 card) — [3.1 Flash-Lite card](https://deepmind.google/models/model-cards/gemini-3-1-flash-lite/); [3.5 Flash card](https://deepmind.google/models/model-cards/gemini-3-5-flash/)
- Anthropic saw Claude append "2025" to search queries (a stale sense of the date) and fixed it with the tool description — [Anthropic, Writing effective tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents)

### Inferences
- A calendar agent leans on exactly these weak areas: tracking which proposal is live across turns, asking instead of guessing when a parameter (hour, day) is missing (the "miss param" category), and computing relative dates in a zone. Keeping conversations short (Lunna already starts a fresh conversation per sheet opening) and tool outputs compact works against the measured degradations.
- Recommendation (inference): run a small in-house eval (e.g. 30–50 recorded Portuguese requests × k=4 runs, pass^k on correct `propose_plan` arguments) on 3.1 Flash-Lite, 3.5 Flash-Lite, 3.8 Flash and Haiku 5.5. No public benchmark covers all of them, and Haiku 5.5 is now cheapest on input.

### Gaps
- No primary-source measurement of date/time arithmetic errors in small models found within this budget.
- No BFCL multi-turn data for any 2026 small model, so the weakness profile above comes from 2025-generation models (2.5 Flash-Lite, Haiku 4.5).
