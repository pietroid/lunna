# When tool-calling LLM agents should ask vs act (2025–2026 research)

Scope: primary papers from 2025–2026 on clarification in tool-using and task-oriented agents, read for a personal calendar agent ("put the dentist between gym and lunch tomorrow") that splits its input into data (what the user said), facts (tool results the server computes) and doubts (missing or contradictory information).
All papers below were opened as full text (arXiv HTML). Numbers marked "text only" were stated in prose but the table could not be checked. When2Call's PDF could not be parsed, so its arXiv HTML (2504.18851) was used instead.

## SAGE-Agent / ClarifyBench (arXiv 2511.08798): method, benchmark, results, When2Call results

### Takeaway
SAGE-Agent tracks which tool parameters are still unknown and only asks when a question's expected value exceeds its cost. On ClarifyBench this gave higher task coverage with about 1.5–2.7x fewer questions than prompting-only baselines (GPT-4o, ambiguous: 59.73% coverage at 1.39 questions, against 42.88–55.70% at 2.07–3.42 questions). On single-turn When2Call it gave up some ToolCall F1 for better asking and declining.

### Cited Findings
- **Authors / status:** Manan Suri (UMD, Adobe Research), Puneet Mathur, Nedim Lipka, Franck Dernoncourt, Ryan A. Rossi (Adobe Research), Dinesh Manocha (UMD). arXiv preprint, v2 dated 10 Apr 2026; no venue is named. — [arXiv 2511.08798](https://arxiv.org/html/2511.08798)
- **Belief over tool calls:**
  - Each candidate tool call gets a probability of matching the user's intent.
  - A parameter the user specified contributes 1; an unspecified one contributes 1/|domain| (ε = 1e-4 for infinite domains).
  - So the uncertainty is *structured*: it is computed from the tool schema and parameter domains, not taken from the model's self-report. — [arXiv 2511.08798](https://arxiv.org/html/2511.08798)
- **Question selection and stopping:**
  - Each candidate question is valued by EVPI, the expected gain in the best candidate's certainty.
  - Aspect-based cost: λ × the number of times the targeted parameters were already asked about. The question's score is EVPI − cost.
  - The agent stops asking and executes when the best net score falls below α × the top candidate's probability, or when that probability reaches τ_exec.
  - Settings: λ = 0.5, α = 0.1, temperature 0.5. — [arXiv 2511.08798](https://arxiv.org/html/2511.08798)
- **ClarifyBench:**
  - 716 samples, 92 tools, 5 domains (Documents, Vehicle Control, Stocks, Travel, File System).
  - Average 3.8 tool calls and 2.4 follow-up queries per sample.
  - 241 explicit, 213 ambiguous and 198 infeasible queries.
  - Built from DocPilot and BFCL-v3. Ambiguous queries were made by obscuring up to 3 arguments with GPT-4o; infeasible ones by hand-written corruption rules.
  - The user is an LLM simulator that holds the true intent. Human validation reached Cohen's κ = 0.76. — [arXiv 2511.08798](https://arxiv.org/html/2511.08798)
- **ClarifyBench results, GPT-4o, ambiguous queries (Table 3):**

  | Method | Coverage | TMR | PMR | Avg #Q |
  |---|---|---|---|---|
  | ReAct + ask_question | 42.88 | 70.41 | 62.55 | 2.68 |
  | ProCOT | 54.27 | 75.62 | 66.82 | 2.07 |
  | Active Task Disambiguation | 45.60 | 77.10 | 60.78 | 3.42 |
  | Domain-aware ReAct | 55.70 | 79.83 | 68.04 | 2.56 |
  | SAGE-Agent (heuristic, no EVPI) | 56.42 | 82.31 | 69.81 | 1.82 |
  | **SAGE-Agent** | **59.73** | **86.02** | **71.79** | **1.39** |

  — [arXiv 2511.08798](https://arxiv.org/html/2511.08798)
- **GPT-4o, explicit and infeasible queries:**
  - Explicit: SAGE-Agent 71.67 coverage at 1.08 questions, against 68.11 at 2.10 for Domain-aware ReAct.
  - Infeasible: 67.33 at 1.26 questions, against 61.48 at 2.03.
  - SAGE-Agent still asks about one question on queries that are fully explicit. — [arXiv 2511.08798](https://arxiv.org/html/2511.08798)
- **Qwen2.5-14B-Instruct:**
  - Ambiguous: SAGE-Agent 54.56 coverage at 1.41 questions; best baseline ProCOT 52.45; Domain-aware ReAct 51.10 at 2.07 questions.
  - Explicit: 64.62 at 0.93 questions. Infeasible: 61.84 at 1.49. — [arXiv 2511.08798](https://arxiv.org/html/2511.08798)
- **Ablations and cost:**
  - Raising λ from 0 to 0.5 cut questions by 18–27% with under 3% change in the metrics.
  - Dropping EVPI (the heuristic variant) added 0.2–0.4 questions and lost 1–3 points.
  - Active Task Disambiguation is described as over-questioning: about 40 LLM calls and 24K tokens.
  - SAGE-Agent uses about 22K tokens and 54% fewer calls than Active Task Disambiguation. — [arXiv 2511.08798](https://arxiv.org/html/2511.08798)
- **When2Call, single turn (Table 4, F1):**
  - GPT-4o: ReAct 0.75 / 0.64 / 0.69 (ToolCall / AskQuestion / Decline); SAGE-Agent 0.65 / 0.65 / 0.78; Active Task Disambiguation 0.34 / 0.56 / 0.73.
  - Qwen2.5-14B: ReAct 0.72 / 0.57 / 0.54; SAGE-Agent 0.59 / 0.62 / 0.77; Active Task Disambiguation 0.18 / 0.48 / 0.39.
  - SAGE-Agent has the highest ToolCall *precision* (0.80 GPT-4o, 0.76 Qwen). Its ToolCall F1 is lower than plain ReAct's for both models, which the paper does not stress. — [arXiv 2511.08798](https://arxiv.org/html/2511.08798)
- **RL on When2Call:**
  - GRPO with a certainty-weighted reward, on about 9K examples, LoRA rank 64.
  - Qwen2.5-3B: 36.5% → 65.2% accuracy. Qwen2.5-7B: 36.7% → 62.9%.
  - The 3B model with the uncertainty-weighted reward (65.2%) beats the 7B with standard GRPO (45.1%). Base models score 34.5–39.7%.
  - Per-mode numbers are only in a figure and were not verified. — [arXiv 2511.08798](https://arxiv.org/html/2511.08798)
- **Internal inconsistency:** the Results prose gives ReAct's ambiguous coverage as 52.34% and ProCOT's as 54.12%, but Table 3 gives 42.88% and 54.27%. The "+7.39pp" headline depends on the prose value. — [arXiv 2511.08798](https://arxiv.org/html/2511.08798)

### Inferences
- The method fits a calendar agent closely. A doubt is an unresolved tool parameter, such as which "gym" event, or a duration. Its value depends on how many candidate tool calls it splits. The server can compute that deterministically from the schema and the day (the facts), rather than asking the model whether it is unsure.
- The aspect-based cost amounts to "never ask about the same slot twice". It is cheap to enforce in code.
- The When2Call trade-off is a warning: a value-of-information gate raises precision but loses some recall on correct tool calls. A calendar agent that only *proposes* (and is undone with one tap) can afford to lean toward acting.

### Gaps
- Per-mode RL numbers (Figure 6) and the remaining 35K characters of the paper (appendix) were not read.
- There was no test with real users, and no test of single versus multiple questions per turn or of option lists.

## "Ask Early, Ask Late, Ask Right" (arXiv 2605.07937): timing by type of missing information and per-model asking rates

### Takeaway
Clarifying the *goal* only helps if it happens almost immediately (10% into the run recovers nearly all of the loss). *Input* clarification decays more slowly but is worth little after about 50%, and any clarification after mid-run is worse than never asking. The paper does name models and per-model ask rates, for its natural-ask study on TheAgentCompany: GPT-5.2 52%, Claude Sonnet 4.5 23%, Gemini 3 Flash 0%.

### Cited Findings
- **Authors / status:** Anmol Gulati, Hariom Gupta, Elias Lumer, Sahil Sen, Vamse Kumar Subbiah (PwC U.S.). arXiv v1, 8 May 2026. — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1)
- **Setup:**
  - 84 task variants and 6,000+ runs: MCP-Atlas (36), TheAgentCompany (30), SWE-Bench Pro (18).
  - Underspecified variants come from LHAW, along four kinds of missing information: goal, constraint, input and context.
  - Ground-truth clarifications are injected as user messages at 10/30/50/70/90% of the trajectory, with the agent's ask_user tool disabled.
  - Separately, 300 "natural ask" sessions on TheAgentCompany run with ask_user enabled and a simulated user. — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1)
- **Models:**
  - MCP-Atlas: GPT-5.2, Claude Sonnet 4.5, Gemini 3 Flash, DeepSeek V3.2.
  - TheAgentCompany and SWE-Bench Pro: the first three. DeepSeek V3.2 was excluded "due to harness integration limitations". — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1)
- **Goal (MCP-Atlas, pass@3):**
  - Injected at 10%: 0.78, against oracle 0.80 and no clarification 0.40.
  - 0.50 at 30%, 0.44 at 50%, 0.39 at 70% and 90%. By 70% it is no better than no clarification. — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1)
- **Input (MCP-Atlas, pass@3):**
  - 0.46 at 10%, 0.36 at 30% and 50%, 0.32 at 70%, 0.25 at 90%; no clarification 0.33, oracle 0.57.
  - The paper says the recovery window "extends only through approximately 50%". — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1)
- **Constraint (SWE-Bench Pro):** 0.81 at 10% falling to 0.68 at 90%, against 0.56 with no clarification. Context: n = 17, too small to conclude. — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1)
- **Late clarification:** abstract, verbatim: "Deferring _any_ clarification type past mid-trajectory degrades performance below never asking at all." The body also says "there is no sharp cutoff after which clarification becomes useless". The only significant cutoff found was at 30%, for outcome-critical variants. — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1)
- **Wasted compute:** grows with the delay. TheAgentCompany: 0.0% → 21.7%. MCP-Atlas: 38.4% → 52.9%. — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1)
- **Natural ask (TheAgentCompany, 100 sessions per model):**

  | Model | Asked in | Mean first ask | Ask calls | Label |
  |---|---|---|---|---|
  | GPT-5.2 | 52% of sessions | 43% into the run | 89 (1.71 per asking session) | "over-clarifier" |
  | Claude Sonnet 4.5 | 23% of sessions | 50% into the run | 23 | "balanced" |
  | Gemini 3 Flash | 0% ("never asks") | n/a | n/a | "under-clarifier" |

  - Per-session success was 11% for Sonnet against 3% for GPT-5.2. The authors treat the link to question quality as a hypothesis, not a finding. — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1)
- "no current frontier model asks within the empirically optimal window." — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1)
- **Recommendations (verbatim):**
  - "agents should validate goals within the first few actions"
  - "input queries can be deferred slightly longer but should be raised within the first half of the trajectory"
  - constraints "should ideally be provided before execution begins". — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1)
- **Caveats the authors note:**
  - Injected results are upper bounds, since ask_user is disabled there.
  - TheAgentCompany has floor effects.
  - The strongest signal comes from MCP-Atlas. — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1)

### Inferences
- A calendar turn is very short (a read or two, then a proposal), so "early" means *before proposing*.
  - Goal doubts ("which event is 'gym'?", "move or add?") should be asked before any plan is filed.
  - Input doubts such as duration could be resolved later or defaulted, because a proposal can be revised cheaply.
- Asking rates differ by model from 0% to 52% under the same harness. The decision to ask should not rest on the model's disposition alone, which argues for server-computed doubts.

### Gaps
- Results come from long-horizon tasks (6–121 actions), not short single-request assistants. How the timing curves transfer to a 2–3-step calendar turn is untested.
- There is no per-model natural-ask data for DeepSeek V3.2.

## Ambig-SWE (arXiv 2502.13069): detection, asking, value of interaction, model differences

### Takeaway
Agents almost never ask unless the prompt pushes them to. Interaction recovers much of the performance lost to underspecification (up to 74% better resolve rates than not interacting). Detection is unreliable for most models and responds to prompting inconsistently. Only the Claude Sonnet models reached notable detection accuracy.

### Cited Findings
- **Authors / status:** Sanidhya Vijayvargiya, Xuhui Zhou, Akhila Yerukola, Maarten Sap, Graham Neubig (CMU). arXiv v3, revised 21 Feb 2026. — [arXiv 2502.13069](https://arxiv.org/html/2502.13069)
- **Setup:**
  - 500 SWE-Bench Verified issues, each with a GPT-4o-summarised underspecified version.
  - Three settings: Full, Hidden, and Interaction (with a GPT-4o user proxy that holds the full issue).
  - Run on OpenHands.
  - Models: Claude Sonnet 3.5, Sonnet 4, Haiku 3.5, Llama 3.1 70B, DeepSeek-v2, Qwen 3 Coder 480B. — [arXiv 2502.13069](https://arxiv.org/html/2502.13069)
- **Value of interaction:**
  - "interactivity can boost performance on underspecified inputs by up to 74%."
  - Share of Full-setting performance recovered: Sonnet 4 89%; Sonnet 3.5 and Haiku 3.5 up to 80%; DeepSeek-v2 59%; Llama 3.1 70B 54%.
  - Resolve rates with interaction: Qwen 3 Coder 46%, Sonnet 4 41.8%, Sonnet 3.5 39.6%, Haiku 3.5 26.8%. — [arXiv 2502.13069](https://arxiv.org/html/2502.13069)
- **Asking without prompting:** "Models default to non-interactive behavior unless explicitly prompted". They "almost never interact, even for severely underspecified inputs." — [arXiv 2502.13069](https://arxiv.org/html/2502.13069)
- **Detection accuracy (best prompt per model):**
  - Sonnet 4: 89% with strong encouragement (FNR 0.18); 74% with a neutral prompt.
  - Sonnet 3.5: 84% with moderate encouragement.
  - Haiku 3.5: at most 63%.
  - DeepSeek-v2: 69% neutral, falling to 51% with strong encouragement.
  - Llama 3.1 70B: about 48–52%, with false-positive rates of 0.93–0.95. It over-asks.
  - Qwen 3 Coder: 50% under every prompt, with a 100% false-negative rate. It never asks.
  - "prompt engineering alone proves insufficient for reliable underspecificity detection." — [arXiv 2502.13069](https://arxiv.org/html/2502.13069)
- **Question quality (information gain / average questions):**
  - Qwen 3 Coder: 0.179 / 6.02. Sonnet 4: 0.171 / 4.03, about half as many questions as Qwen for similar gain.
  - Sonnet 3.5: 0.136 / 3.80. Haiku 3.5: 0.135 / 3.49. Llama 3.1 70B: 0.101 / 2.61.
  - "The most effective questions are specific, actionable, and task-level." — [arXiv 2502.13069](https://arxiv.org/html/2502.13069)
- **Caveats:**
  - The user proxy may be more cooperative than real users.
  - Detection was measured over the first three turns only.
  - Sonnet 4 ran on only 100 of the 500 instances in the Hidden setting. — [arXiv 2502.13069](https://arxiv.org/html/2502.13069)

### Inferences
- Prompting reacts differently across models: stronger encouragement helps Sonnet 4 and hurts DeepSeek-v2. A prompt that tells the model when to ask will not carry over between models. This is another argument for computing doubts on the server and handing them to the model as a structured fact.

### Gaps
- The full resolve-rate figure (Figure 3) was not reproduced in the text.
- The study covers coding only, with no calendar or personal-assistant domain.

## When2Call (arXiv 2504.18851, NAACL 2025): what it measures, small vs large models

### Takeaway
When2Call tests the choice between calling a tool, asking a follow-up question and saying the request cannot be done (a direct answer always counts as hallucination). Models are far from the ceiling, and scores do not improve with size: Qwen 2.5 7B and 72B score about the same. Many models call a tool with made-up parameters where they should have asked. Preference training (RPO) on When2Call data helps more than supervised fine-tuning (SFT).

### Cited Findings
- **Authors / status:** Hayley Ross (Harvard; work done at NVIDIA), Ameya Sunil Mahabaleshwarkar, Yoshi Suhara (NVIDIA). arXiv 26 Apr 2025.
  - The NAACL 2025 listing is in the ACL Anthology; the PDF there could not be parsed, so the arXiv HTML was used. — [arXiv 2504.18851](https://arxiv.org/html/2504.18851); [ACL Anthology](https://aclanthology.org/2025.naacl-long.174.pdf)
- **Design:**
  - Four answer types: tool call, follow-up question, unable to answer, direct answer (always counted as hallucination).
  - Questions were generated with Mixtral 8x22B from BFCL v2 Live (test) and APIGen (training).
  - Scored as multiple choice over log-probabilities (F1, length-normalized accuracy), plus a tool-hallucination rate on items with no tools.
  - Closed models were scored by an LLM judge (GPT-4-Turbo, 100 items per category). — [arXiv 2504.18851](https://arxiv.org/html/2504.18851)
- **Results (multiple choice):**

  | Model | F1 | Acc-norm | Tool hallucination |
  |---|---|---|---|
  | Llama 3.1 70B | 37.8 | 46.1% | 57% |
  | Qwen 2.5 7B | 32.0 | 50.9% | 21% |
  | Qwen 2.5 72B | 32.8 | 49.2% | 23% |
  | xLAM 8x22B | 34.3 | 48.3% | 9% |
  | Mistral-NeMo-Minitron 4B, When2Call-RPO | 51.0 | 69.1% | 1.9% |
  | Mistral-NeMo-Minitron 8B, When2Call-RPO | 52.4 | 70.0% | 1.2% |

  — [arXiv 2504.18851](https://arxiv.org/html/2504.18851)
- **Closed models (LLM judge):**
  - GPT-4o: F1 61.3, tool hallucination 26%. GPT-4o-mini: 52.9 and 41%. GPT-4-Turbo: 64.6 and 22%.
  - GPT-4 models beat community models on F1 but "their tool hallucination rates are not better than the community models." — [arXiv 2504.18851](https://arxiv.org/html/2504.18851)
- **Size:** performance "does not necessarily improve with model size (e.g., Qwen 2.5 3B/7B/72B)." — [arXiv 2504.18851](https://arxiv.org/html/2504.18851)
- **Over-calling:**
  - "Unwanted tool calls also occur for many of the questions where a follow-up question would be correct".
  - Even the models that ask correctly more than half the time often still produce a tool call with the missing parameters made up. — [arXiv 2504.18851](https://arxiv.org/html/2504.18851)
- **Training:**
  - SFT on When2Call data cost 6.2% on BFCL Live AST for the 4B model.
  - RPO raised the 8B model's F1 from 49.4 (SFT) to 52.4 and "yields an increase on all datasets for the 8B model."
  - Negative examples can make models overly conservative. — [arXiv 2504.18851](https://arxiv.org/html/2504.18851)

### Inferences
- The typical failure is filling a missing argument with a guess. For the calendar this means a model will happily invent a duration for "dentist" or pick one of two "gym" events. The server should check that every required argument is grounded in the user's words (data) or in tool results (facts), and flag the rest as doubts.

### Gaps
- Per-model numbers for small models other than those above were not extracted.
- Not verified: the 3,652 / 6,000 dataset counts and the "F1 16.6–37.8" range. Both come from aggregator listings, not the paper text.

## Other strong 2025–2026 papers (over-asking cost, calibrating how often to ask, small models)

### Takeaway
Recent work agrees that both failure modes are real:
- Acting too early is the dominant failure even for frontier reasoning models (CAR-bench).
- Asking too much hurts outcomes, not just user patience (information-gain clarifier, SpecBench).

The fixes that work are a fixed policy for when to ask, value-of-information scoring, or training small models with an information-gain reward. Better prompting is not among them.

### Cited Findings
- **CAR-bench** (Kirmayr, Stappen, André; BMW / Augsburg; arXiv 2601.22027, Jan 2026):
  - In-car assistant: 58 tools, 19 policies, 50 Disambiguation tasks.
  - Policy: "Internal disambiguation is preferred". Ask the user only when two or more valid options remain after gathering information. Ranking or guessing among options is disallowed.
  - Asking the user "unnecessarily" when the data was available counts as a failure.
  - No model exceeds 50% Pass^3 on Disambiguation. GPT-5 (thinking): Pass@3 68%, Pass^3 36%.
  - Premature actions are about 90% of GPT-5's Disambiguation failures, and thinking "fails to mitigate the premature action problem".
  - Per-model table values were not reliably extracted beyond these figures. — [arXiv 2601.22027](https://arxiv.org/html/2601.22027v1)
- **Uncertainty-Aware Clarification with Information Gain** (Deng et al., HKUST(GZ) and others; arXiv 2606.03135, Jun 2026; no accepted venue on the page):
  - A Qwen3-1.7B clarifier trained with DAPO on a log-likelihood "information-gain proxy" reward, on τ-Bench.
  - Average Pass@1 17.8 at 1.3 clarifying calls, against 15.4 with no clarifier and 14.9 at 4.2 calls for the untrained 1.7B.
  - Larger prompted clarifiers reach 11.9–18.1 at 2.7–5.1 calls. A Qwen3-8B clarifier slightly *lowered* performance.
  - "excessive clarification introduces context pollution and redundant interactions"
  - Success peaks at an intermediate clarification budget.
  - Test sets are small (115 / 50 tasks). — [arXiv 2606.03135](https://arxiv.org/html/2606.03135v1)
- **SpecBench** (Wang, Han, Xu, Srivastava; Red Hat / MIT-IBM; arXiv 2606.20585, 2026):
  - Gemini CLI "stops querying the user early and jumps into execution mode" (17% early submissions, and the lowest scores).
  - Claude Code and Cursor CLI "keep asking questions whenever any ambiguity remains", and "more interactions even reduce the quality of the resulting spec sheet."
  - Their agent first settles the dimensions it can infer (three simulators must agree with high confidence) and asks the user only "the most uncertain questions", one question per round with four grounded options.
  - It reached 92% after 10 rounds, against 61–80% for the others. — [arXiv 2606.20585](https://arxiv.org/html/2606.20585)
- **Modeling Future Conversation Turns** (Zhang, Knox, Choi; arXiv 2410.13788v2, Mar 2025):
  - Standard preference labeling favors answering, because "annotators prefer responses with complete but presumptuous answers over incomplete clarifying questions".
  - Training on simulated future turns gives +5% F1 and +3% accuracy on the decision of when to ask.
  - The venue is not stated on the arXiv page. (A search listing calls it ICLR 2025; not verified.) — [arXiv 2410.13788](https://arxiv.org/html/2410.13788v2)
- Not opened or verified, so not used:
  - CLARITI (arXiv 2604.14624), reportedly about 41% fewer questions (3.0 vs 5.1) at GPT-5 level on SE tasks. — [search listing](https://arxiv.org/pdf/2604.14624)
  - π-Bench (2605.14678), DiscoBench (2606.27669) and LHAW.

### Inferences
- A default bias toward acting is built in by RLHF labeling (Zhang et al.), and confirmed in tool use by When2Call, Ambig-SWE and CAR-bench. Over-asking also shows up in GPT-5.2, Llama 3.1 70B and Claude Code under SpecBench.
- So model disposition is unreliable in *both* directions, and the threshold for asking belongs in the harness.

### Gaps
- No 2025–2026 primary user study was found that compares multiple-choice and open clarifying questions on user satisfaction in an assistant. AGENT-CQ (2410.19692) only describes question formats.
- No calendar- or scheduling-specific clarification benchmark was found.

## Practical design implications (deterministic vs model-detected doubts, one question vs many, offering options)

### Takeaway
The evidence favours computing doubts on the server and sending them to the model as structured facts. It also favours asking a single, early, high-value question with concrete options, and acting (proposing) whenever the remaining uncertainty would not change the tool call.

### Cited Findings
- **Deterministic, schema-based uncertainty beats prompting-only asking:** SAGE-Agent derives uncertainty from parameter domains and gets +4 to +17 coverage points at about half the questions — [arXiv 2511.08798](https://arxiv.org/html/2511.08798). Prompting alone is "insufficient for reliable underspecificity detection" — [arXiv 2502.13069](https://arxiv.org/html/2502.13069).
- **Settle internally first, ask only for a real fork:**
  - CAR-bench's policy: gather information first, ask only if two or more valid options remain, never guess — [arXiv 2601.22027](https://arxiv.org/html/2601.22027v1).
  - SpecBench's agent infers what it can and asks only the most uncertain dimensions — [arXiv 2606.20585](https://arxiv.org/html/2606.20585).
- **Few questions:**
  - Trained or value-gated clarifiers settle at about 1.3–1.4 questions per task, where prompted models ask 2–5 — [arXiv 2606.03135](https://arxiv.org/html/2606.03135v1); [arXiv 2511.08798](https://arxiv.org/html/2511.08798).
  - Penalizing repeat questions on the same aspect removes 18–27% of questions at under 3% cost — [arXiv 2511.08798](https://arxiv.org/html/2511.08798).
- **Early:** goal doubts should be settled "within the first few actions" — [arXiv 2605.07937](https://arxiv.org/html/2605.07937v1).
- **Options:**
  - SpecBench's best agent asks one four-option question per round, with options grounded in what the user said — [arXiv 2606.20585](https://arxiv.org/html/2606.20585).
  - Effective questions are "specific, actionable, and task-level" — [arXiv 2502.13069](https://arxiv.org/html/2502.13069).

### Inferences
Mapped to the calendar cases (these are inferences, not findings):
1. **Ambiguous reference to an existing event** ("gym" matches two blocks tomorrow):
   - The server resolves it against the day.
   - Exactly one match: it is a fact, so act.
   - Two or more: it is a goal doubt, so ask one question listing the matches with their hours, before proposing.
   - None: either it is infeasible (say so) or a doubt.
2. **Missing duration:**
   - An input doubt of low value: any plausible length gives the same placement between gym and lunch, unless the gap is too small.
   - Default it (the gap's room, or a per-title or typical default), state the assumption in the proposal, and let the person edit it.
   - Ask only when the default would change where the task can go (EVPI > 0).
3. **Requested hour taken by a fixed event:**
   - The server detects it deterministically as a contradiction between data and facts.
   - This is a doubt with concrete options (nearest free stretch before or after, another day). It fits the existing "Outro horário / Empurrar" pattern.
   - Lunna already refuses plans that would push an event, which matches CAR-bench's "never guess between valid options".
4. **Budget:**
   - At most one question per turn, and never re-ask a slot already answered (aspect cost).
   - When all doubts are low-value, propose: a proposal is reversible (apply/undo), which lowers the cost of acting compared with the irreversible actions most benchmarks assume.
5. **Model choice:**
   - Asking rates vary from 0% to 52% between frontier models, and smaller models over-call tools with invented arguments (When2Call).
   - So the doubts list should come from the server, and the model's job is to phrase the question, not to decide whether one is needed.

### Gaps
- No primary paper here measures the effect of reversibility (a propose-then-confirm flow) on the best asking threshold. That is an inference specific to this design.
- No 2025–2026 paper found evaluates default-and-state-assumption against asking for missing durations.
