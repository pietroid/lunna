---
description: /build - build one piece of a Lunna/Focus feature in the server and the app, starting from its brief (a /create plan and its scope map, or the Build brief of an approved /mockup) and reading only the files it names, prove it (prints of the real build in both brands, or the commands that show it working), and finish its product/delivery/ folder, with the docs written by the docs subagent. Use to build, implement or ship a piece of work that is already decided.
---

# Build: one piece, start to proof

A piece starts decided: the `/create` plan says what to change and its
**scope map** lists the files (`path:line`), the looks-like widget and the
spec; after a mockup, its Build brief does. **Don't explore: the scope is
the reading list.** Open those slices and the `product/spec/<feature>.md`
it names; `AGENTS.md` is in context and is the spec of how the day works.
Read outside the scope only when a compile error or a failing test points
there, and never with a wide grep. Without a plan (in a terminal),
`.tool/map <words>` once.

**Budget.** The estimate is in the plan, in **% of the weekly window**
(1 % ≈ $2.40 API-eq, about 55 turns at a 200k context; a build M ≈ 1.5 %).
Cost is turns × context, and the context only grows, so: few turns, small
results, chores to the subagent. If the piece turns out much bigger than
its estimate, build a coherent part, and name the rest in the README and
in the structured output's questions.

## 1. The delivery README

After a mockup, `product/delivery/*-<slug>/README.md` exists (sections 1
and 2, the Build brief). Without one, write it now: section 1 (the ask
and the brief, verbatim) and section 2, **The plan**, in a few lines:
the approach (files, routes, env vars), the decisions a reviewer might
want otherwise, and how it will be proved.

## 2. Server

`server/src/<feature>/`, a Nest module.

- Validate input the way `events/request.ts` does: refuse, never guess,
  refusals in Portuguese.
- Writes go through `EventLayoutService`, so the time rules hold.
- What the person must confirm or undo keeps enough state to undo
  exactly.
- New env vars in `server/.env.example` and `SETUP.md`.
- End-to-end specs with the in-memory stores and a frozen clock (the
  harness in `events/events.controller.spec.ts`); never the machine's
  zone or hour. A new write route gets its row in
  `server/src/analytics/events.ts`.

## 3. App

- A new feature is its own package under `app/packages/`.
- Every string in `app_pt.arb` (`flutter gen-l10n`); a brand's name
  selects on `AppBrand.id`; colours from tokens.
- A modal sheet is its own route: hand it the blocs it reads
  (`BlocProvider.value`). Inside a `BlocBuilder`, read `bloc.state`.
- Tooling (release, CI, deploy): the vendor's docs for the versions in
  use; secrets never in the tree. A step this machine can't run is run
  as far as it goes and named as not run.

## 4. Verify

- While working, the one spec or package you touched:
  `flutter test -r failures-only <file>`, `npx jest <file>`.
- At the end, `.tool/check` once, **in the foreground** (1–2 minutes;
  never in the background with a loop waiting for it): it prints one line per
  step and only the lines of a failure. Read more of a log only if those
  lines aren't enough. A flaky test: stash and rerun to prove it isn't
  yours.

## 5. Prove it

- **Something to see**: bring `app/lib/<slug>_preview.dart` up to the
  final code (the mockup's, or a small new one): fakes behind the real
  cubits, `?s=<n>` per scene. `.tool/preview <slug> 1 2 3 --brands
  lunna,focus --steps <steps.txt> --out <scratchpad>/b` (foreground), then
  read the two `steps-thumb.png`. Copy the two `steps.png` to the
  delivery's `img/build-lunna.png` and `img/build-focus.png`, and
  **delete the entry point**.
- **Nothing to see**: run the plan's proof for real and keep the
  commands and the lines they printed.

## 6. The docs, by the subagent

Don't write the long docs in this context. Hand them to the **docs**
subagent (Agent tool, `subagent_type: docs`) in one message with a brief:
the delivery README's path; what was built (server files and routes, app
pieces); the tests and their counts; where the build differs from the
mockup or the plan, and why; how to turn it on; the image paths; and the
feature's spec file. It finishes the README (sections 3–5, the Build
brief removed), the spec in `product/spec/`, and the feature's pointer in
`AGENTS.md`, and answers with the paths. Don't re-read what it wrote.

## Speed

- **Batch**: independent reads and commands in one message; several greps
  in one Bash call. Every turn re-reads the whole context.
- **Read slices**: `Read` with `offset`/`limit`, or `grep -n`; never a
  whole Dart file, never a result over ~20k characters, never a file
  twice.
- **Write with Edit or Write**, never edit scripts in Bash.
- **Images**: only `-thumb.png`.
- **Short messages**: no narration.

**Unattended** (`LUNNA_QUEUE=1`): `.tool/check` must pass before you
finish; in section 5 write "Measured by the queue: see the pull
request." instead of cost tables.
