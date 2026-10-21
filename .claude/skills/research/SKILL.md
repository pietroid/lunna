---
name: research
description: /research - research a problem in Lunna/Focus and write a short, layered RFC in its own product/research/<date>-<slug>/ folder (one minute on top, the change, then the evidence; a few ideas to keep, tracked across RFCs in product/research/concepts.md), with the data, code and reports behind it - trace the symptoms to the code, read the literature (papers, engineering posts, docs), recommend changes with why and how, name the decisions the engineer must take, answer their notes (GitHub line comments or .tool/doc), then verify the weakest claims with a deep-research pass and fold the corrections back in. Use when asked to "research", "investigate how to improve", write an RFC, a proposal, a thesis, or to compare approaches before building.
---

# Research: symptoms → thesis → verified RFC

The output is one Markdown RFC per topic, written in the repo, never a
Claude Doc or another hosted page (the user prefers files; GitHub shows
them, and takes comments on their lines). It is short, layered (a minute,
then the change, then the evidence) and teaches a few ideas that stick.
The test for every paragraph: does it tell the engineer something they'd
act on or keep, with a source or a `file:line` behind it?

Worked example of the whole flow:
`product/research/2026-10-16-agent-reliability/`.

**Unattended** (`LUNNA_QUEUE=1`, a run of `.tool/queue` for a GitHub
issue): nobody answers until the run ends. The queue's instructions in the
prompt replace every "stop and ask" here; the person answers on the issue,
and the next phase is a fresh session that starts from the files.

## Where things go

One folder per topic, the way `product/delivery/` has one per feature.
Everything the RFC rests on lives in it, so the topic can be read, moved
or deleted as one thing:

```
product/research/YYYY-MM-DD-<slug>/
  README.md                the RFC
  data/                    what was measured: tables, JSON, CSV, extracts
                           of logs or transcripts, screenshots (img/)
  code/                    the scripts that produced data/, runnable again
                           (`node code/<x>.mjs` from the folder), and any
                           prototype the RFC argues from
  reports/<topic>.md       deep-research reports (phase 4)
  notes/<topic>/*.md       the notes behind each report
```

Only create the subfolders the topic uses. Names are kebab-case, no
spaces. The RFC links everything relatively (`./data/turns.csv`), and a
number in the RFC that came from a script names the script, so it can be
measured again after the change it recommends. Scratch work that isn't
cited stays in the scratchpad.

Everything is in English (AGENTS.md). Quotes of Portuguese UI copy stay
in Portuguese.

## Phase 1: Diagnose in the code (before any web search)

The literature only helps once you know what is actually broken.

1. Read the code that owns the problem in full: the service, its prompt
   or config, the types, and the code paths it calls. Use `AGENTS.md`
   for the map, and don't list directories it already describes.
2. Trace **each symptom the user reported to a root cause** with a
   `file:line`. Look especially for:
   - **Two code paths that should be one.** The check and the action run
     different code, so they disagree. This was the agent's main bug.
   - A rule that lives only in a prompt when it could live in code.
   - Defaults that hide data (a read that covers one day by default).
   - Errors collapsed into one generic message.
3. Note what tests exist and what they don't exercise (for example, a
   scripted model means the real one was never tested).
4. Write the RFC skeleton (Phase 3's headings) with the diagnosis table
   under *Deeper* **now**, and open it
   for the user (`.tool/doc open <slug>`, in the background): the page
   redraws as the file grows, so they can follow and comment.

## Phase 2: Literature (one batch)

Send the searches in parallel, in one message. Then **open** the
3–8 pages you will cite: a search snippet is not a source. Prefer:

- Vendor engineering posts (Anthropic engineering, OpenAI, Google), for
  practice.
- Papers on arXiv / ACL / NeurIPS, for findings with numbers. Read the
  HTML full text where a claim depends on details. An abstract can omit
  what the paper says (per-model numbers, caveats).
- The docs of the exact stack in use (OpenRouter, Gemini API, NestJS),
  for what the system actually does today.

Map every finding onto **this** codebase in one sentence ("for us that
means..."). A finding with no consequence for the code doesn't go in.
Then pick the 3–5 that are worth learning for good (the *Ideas to keep*),
checking `product/research/concepts.md` for those already met.

If a project skill matches the topic, load it first and let it shape the
recommendations. For agent work that means `tool-design`,
`context-degradation`, `evaluation` and `advanced-evaluation`.

## Phase 3: Write the RFC

The reader is an engineer **learning AI engineering**, often on a phone
(the RFC is the PR description). So the RFC is short, says what to do
before why, and teaches a few ideas well rather than many in passing.
It is written in layers: each one is enough to stop at, and the next one
goes deeper.

```
# <Title>
<date> · RFC · <status>

## In one minute                 layer 1: ≤ 200 words, the whole RFC
**The thesis, one sentence.**
- **Do:** the 1–3 changes, a line each.
- **Not needed:** what it does not take, and why, in a line.
- **You decide:** each decision, a line, the recommended option named.

## Ideas to keep                 layer 1→2: 3–5 ideas, no more
1. **"A sentence that sticks."** (≤ 15 words, quotable)
   Source, linked. *For us:* one line. *New* | *Deeper than* [concept](../concepts.md#anchor)

## The change                    layer 2: what to do, why, how
| # | Change | Fixes | Size |   then one ### per change, short:
                                 what (names, shapes, the code to reuse), why, how.
## Decisions for you             3–6, options, one marked (recommended), its cost
## Decided unattended            (queue runs only)

## Deeper                        layer 3: the evidence, for when it is wanted
### How it works today           a small call-flow block and the facts
### Diagnosis                    # | Symptom | Root cause | Where
### The literature               one source per item, ending in what it means for us
### Rollout                      Phase | Ships | Fixes | Size; phase 0 is measuring
## References                    a link and the one line it supports
```

- **Budget.** Layer 1 under 200 words, the whole RFC under ~2,500 (the
  first four ran 2,600–9,400, with 1,350–3,000 words before the first
  recommendation; `product/improvements/2026-10-21-github-review-and-rfc-shape/`).
  What does not fit is not cut, it waits: a later round adds it when the
  person asks for it (below).
- **Ideas to keep** are the learning. A good one is a claim with a
  mechanism, short enough to repeat ("Grade the final state, not the
  transcript"), from a source worth reading in full, with this repo's
  case beside it. Teach from a concrete example before the general rule:
  that is what the person's questions keep asking for ("I need more real
  cases", "I have no idea what you are saying about evals").
- **The concepts ledger.** `product/research/concepts.md` keeps every idea
  an RFC taught, with its sentence, its source and the RFCs it was met in.
  Read it before writing *Ideas to keep*: an idea already there gets one
  line and a link, and this RFC goes one level deeper on it (a number, a
  failure case, the paper behind the blog post), so each topic starts
  where the last one stopped. Add the new ideas to it, and this RFC to
  the *Met in* of the old ones, in the same pass.
- A term the person may not know is explained the first time, in half a
  sentence, or linked to its concept.

If the user sends an idea mid-flight (for example "data / facts /
doubts"), don't append it as an aside. Assess it honestly, give it its
own section with an owner table (what it is, who owns it, an example),
and let it reshape the thesis if it fits.

## Phase 4: Verify (deep research)

When the user agrees, or if the RFC rests on claims taken only from
snippets, run the `anthropic-skills:deep-research` skill on the **2–4
weakest sections**. Typical ones: vendor behavior that changes often
(pricing, caching, routing), per-model numbers, and recent papers.

- Use the topic folder as its working directory, so the report lands in
  `reports/<topic>.md` and its notes in `notes/<topic>/`.
- Ask the report to end with **confirmed / corrected / unverified**
  against the RFC.
- Fold corrections back into the RFC: fix the claim in place, add any
  new reference, and link the report from References. Wrong venues,
  stale prices and outdated model lineups are the usual corrections.
- State what remains unverified. Never present an inference as a
  finding.

## Recommending skills or tools

If asked which skills would improve the research, recommend skills to
**download**, not skills the RFC proposes building. Check first what's
already installed (the session's skill list), then search the
marketplaces (anthropics/skills, community plugin marketplaces). Before
installing any third-party skill:

1. Clone it into the scratchpad and read every `SKILL.md` and reference
   file.
2. Grep its scripts for network, shell, file and eval use.
3. Install project-scoped (`.claude/skills/<name>/`), copy the license
   into each folder, and leave it uncommitted for the user to review.

## The user's notes

The person comments in one of two places, and both end up in the file:

- **On GitHub**, from the queue: a comment on a line of the README in the
  PR's *Files changed* (the phone app does this too). The run's prompt
  quotes each as ``On `<file>` line N (thread T), about: > the line`` and
  the comment. A leading `Q:`, `Learn:`, `Decision:` or `Note:` is its
  kind; with none, a question is a `Q` and anything else a `Note`.
  Write it into the RFC under the block it is about, as below, answer it
  there, and put a one- or two-sentence answer in the structured output's
  `replies` under thread T: the queue posts it under their comment, where
  they will read it.
- **On the Mac**, in the page `.tool/doc open` serves, which writes the
  note into the file itself.

Either way a note is a tagged blockquote under its block: `> **Q:**`,
`> **Learn:**`, `> **Decision (YYYY-MM-DD):**`, `> **Note:**`.

- Read them with `.tool/doc notes <slug>` (or `--open` for unanswered
  questions only): line, kind and heading, without the rest of the RFC.
  Read the RFC itself only around the lines you must change.
- Answer a question with `> **A:** …` right under it (a blank line
  between). Answer the way *Ideas to keep* teaches: a real case first,
  then the rule. A **Learn** asks to go deeper: answer it, and if the
  answer is an idea worth keeping, add it to the concepts ledger.
- A **Decision** is binding: change the RFC to match, and drop the
  alternatives it rules out from *Decisions for you*.
- "Deeper on X" adds a `### X` under *Deeper* (or a report in Phase 4),
  not more words in layer 1.
- Leave the notes in place; they are the record of how the RFC was argued.

## Delivering

End each phase with a short message:

- the RFC path;
- its *In one minute*, as written;
- the ideas it added to the concepts ledger, one line each;
- anything skipped or unverified.

Make sure the RFC is open for the user (`.tool/doc open <slug>`; it reuses
a page already running). Don't commit unless asked.
