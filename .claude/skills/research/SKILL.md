---
name: research
description: /research - research a problem in Lunna/Focus and write a thesis-style RFC in its own product/research/<date>-<slug>/ folder, with the data, code and reports behind it - trace the symptoms to the code, read the literature (papers, engineering posts, docs), recommend approaches with why and how, name the decisions the engineer must take, then verify the weakest claims with a deep-research pass and fold the corrections back in. Use when asked to "research", "investigate how to improve", write an RFC, a proposal, a thesis, or to compare approaches before building.
---

# Research: symptoms → thesis → verified RFC

The output is one Markdown RFC per topic, written in the repo, never a
Claude Doc or another hosted page (the user prefers files). It is short
and dense. The test for every paragraph: does it tell the engineer
something they'd act on, with a source or a `file:line` behind it?

Worked example of the whole flow:
`product/research/2026-10-16-agent-reliability/`.

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
4. Write the RFC skeleton and the diagnosis table **now**, and open it
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

If a project skill matches the topic, load it first and let it shape the
recommendations. For agent work that means `tool-design`,
`context-degradation`, `evaluation` and `advanced-evaluation`.

## Phase 3: Write the RFC

Sections, in this order:

1. **Thesis.** The one-sentence conclusion in bold, then 2–3
   paragraphs: why the symptoms happen, and the move that fixes them.
   Say what is *not* needed (for example "this does not need RAG", and
   why).
2. **How it works today.** A small call-flow block and the facts that
   matter (model, limits, timeouts).
3. **Diagnosis.** A table: `# | Symptom | Root cause | Where`.
4. **What the literature says, applied here.** A numbered list, one
   source per item, each ending in what it means for us.
5. **Recommendations**, in the user's priority order, with the priority
   stated in the heading. Each has: what to change (concrete: tool
   shapes, field names, the code to reuse), why, and how. Tables for
   option-like things.
6. **Decisions for you.** 3–6 choices only the engineer can make. Give
   options, mark one *(recommended)*, and say what each costs.
7. **Rollout.** A table: `Phase | Ships | Fixes | Size`. Phase 0 is
   always measuring: evals or a baseline.
8. **References.** Each with a link and the one line it supports.

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

The user comments on the RFC in the page `.tool/doc open` serves. Each
comment is written into the file as a tagged blockquote under the block it
is about: `> **Q:**`, `> **Learn:**`, `> **Decision (YYYY-MM-DD):**`,
`> **Note:**`.

- Read them with `.tool/doc notes <slug>` (or `--open` for unanswered
  questions only): line, kind and heading, without the rest of the RFC.
  Read the RFC itself only around the lines you must change.
- Answer a question with `> **A:** …` right under it (a blank line
  between). A **Decision** is binding: change the RFC to match, and drop
  the alternatives it rules out from *Decisions for you*.
- Leave the notes in place; they are the record of how the RFC was argued.

## Delivering

End each phase with a short message:

- the RFC path;
- the thesis in 2–3 lines;
- the recommendations in priority order, one line each;
- the decisions, numbered;
- anything skipped or unverified.

Make sure the RFC is open for the user (`.tool/doc open <slug>`; it reuses
a page already running). Don't commit unless asked.
