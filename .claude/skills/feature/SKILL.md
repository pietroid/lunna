---
name: feature
description: /feature - take a feature for Lunna/Focus from idea to delivery, fast - an annotated mockup drawn by the real Flutter app, with PNG prints; iterate on feedback, then (when asked) build it in the server and app, screenshot the real build in both brands, and record everything in a delivery/ folder. Use when asked for a design proposal, a mockup, "prints", "how would X look", or to implement and deliver a feature that was mocked.
---

# Feature: proposal → delivery

The flow has four phases. Stop after each one, send what it produced, and
only go on when the user asks ("great, now make the changes", "build it").
Phases 1–2 should be fast (ASAP means one preview entry point and one
build-and-shoot pass).
Phase 3 is real engineering. Phase 4 always closes a build.

Worked example of the whole flow: `delivery/2026-10-15-agent/README.md`.

## Speed

Aim for the least wall-clock time and the fewest tokens that still give the
same quality. Every round trip and every re-read costs both.

- **Act on what you know.** The paths, tokens, commands and patterns are in
  this file and in `AGENTS.md` (already in context): go straight to them.
  No exploratory listing or searching for what is written here.
- **Batch.** Independent reads, edits and commands go in one message, in
  parallel. Read several files in one call; read only the lines you need.
- **Never re-read** a file you just wrote or edited, or one already in the
  conversation. Don't re-run a passing check to "make sure".
- **Run long things in the background** (`flutter build web`, `npm test`,
  `flutter test`) and write the next thing (specs, the README) meanwhile.
  Build both brands at the same time.
- **Verify narrowly first, broadly once.** While iterating, run the one spec
  or package you touched; the full matrix (both brands, every touched
  package, `npm test`) once, at the end.
- **No subagents** unless the user asks: they start cold and re-read
  everything.
- **Short messages.** Progress lines while working, one compact report at the
  end of a phase. Don't narrate options you won't take.
- **One fix pass.** Render, look, fix everything you saw in one go,
  re-render once. Don't polish what the user hasn't seen yet.

Quality is not negotiable: the pins still state every decision, the specs
still cover the rules, both brands are still checked.

## Cost and time

Every delivery records what it cost, in dollars and tokens, and how long it
took. The `usage-bars` mod (`~/.claude/mods/usage-bars`) gives Claude a
tool, `mcp__usage-bars__session_cost`, that answers
`{ usd, tokens: { input, output, cacheRead, cacheWrite, total }, at }`: this
session's running cost and the tokens its turns used so far (main loop and
subagents alike).

- **Read it when a phase starts and when it ends**, in the same message as
  the phase's first and last other calls (it costs nothing), and keep the
  readings in a running table (phase, start, end, duration, USD, tokens in,
  tokens out).
  The difference between two readings is what the work between them cost;
  their `at` timestamps give its wall-clock time.
- Report tokens simply, as two columns: **in** (`input + cacheRead +
  cacheWrite`, everything the model read) and **out** (`output`, everything
  it wrote), e.g. "960k in, 9.7k out". Round to k/M. No split beyond that.
- When the user asks to count from a given moment ("from now to the end"),
  take a reading right then and count from it.
- The figure is the session's, so it includes the talk around the work. Say
  so in the table instead of trying to split it.
- If the tool isn't listed (the mod isn't loaded), or answers without
  `tokens` (an older mod), ask the user to run `/cost` at the same points
  and paste it, and record those.

## Phase 1: Mockup and prints

**The mockup is always drawn by the real Flutter app**, never by HTML or an
image editor: the same widgets, tokens, fonts and icons the build will ship,
so the proposal can't drift from the product and Phase 3 starts from the
widgets Phase 1 already wrote.

A proposal is a **board of 3–5 phone screens** telling one flow left to right,
each with a title, a one-line why, and **lettered pins** (A, B, C…) that point
at the decisions: where a button sits, which icon, what colour, what it does,
when it goes away. The pins are the point. The user wants placement and icon
decisions stated, not just pretty screens.

1. **Ground it in the app** (2 min max).
   - Widgets: `app/packages/app_ui/lib/src/widgets/` (cards, segmented, FAB, bottom bar, sheets, text fields), tokens in `app_colors.dart`, icons in `app_icons.dart` (Phosphor). Reuse before writing anything new.
   - Screens that exist: `lib/demo/` draws Tempo against `DemoTimelineRepository`; `packages/agent` has the ask bar, the sheet, the plan card and the suggestion card.
   - Draw Lunna unless asked for Focus.
2. **References.** Name 2–3 apps whose pattern you're borrowing (Mobbin-style catalogue: ChatGPT, Notion, Motion, Structured, Sunsama, Linear, Arc…). Mobbin needs a login. If Chrome tools are connected and signed in, browse it. Otherwise say you drew from known patterns and don't pretend you browsed.
3. **Write the screens in Flutter.**
   - New UI is real widgets where it will live (the feature's package under `app/packages/`, or the package it changes), built from `app_ui` and tokens, every string in `app_pt.arb` (`flutter gen-l10n`). This is the start of Phase 3's view layer, so write it to that standard, not as a sketch.
   - No server yet. The data comes from fakes in the preview entry point.
   - Entry point `app/lib/<slug>_preview.dart`, shaped like `lib/preview.dart` (`AppTheme.current`, pt-BR l10n, `DemoTimelineRepository`, fake repositories with canned replies). `?s=<n>` (`Uri.base.queryParameters`) picks the scene: each scene seeds its state directly (a cubit built with that state, a sheet opened in a post-frame callback) rather than replaying taps.
   - Copy is in **Brazilian Portuguese**, mocked but believable: real-sounding tasks, hours that add up.
   - Accent on one primary action per screen.
   - **No generic AI iconography.** No sparkles, magic wands or robots. The agent is the brand's crescent without the check (`AppIcons.agent`). Anything new gets a brand-derived or Phosphor icon, named in a pin; a new brand icon is an SVG in `app/brands/<brand>/` on the 64-unit grid.
4. **Build and shoot.**
   - Start the build in the background (about 50 s):
     `flutter build web -t lib/<slug>_preview.dart --dart-define=BRAND=lunna --no-tree-shake-icons -o <scratchpad>/preview-lunna`.
     Write `board.json` while it builds.
   - `.claude/skills/feature/shoot-flutter.sh <scratchpad>/preview-lunna <scratchpad>/shots 1 2 3 4` gives one `<n>.png` per scene.
   - `board.json` (in the scratchpad) lists each screen's `png`, `title`, `why` and `pins` (`id`, `x`, `y` in logical px on the 390×844 shot, the pin's centre; `label`, `text`). Read the shots to place the pins.
   - `node .claude/skills/feature/board.mjs <board.json> <out_dir>` writes `board.png` and `screen1..n.png` (2x), with the pins and their notes.
5. **Look at the prints** (Read `board.png`) before sending: overflow stripes, grey boxes (a build exception), pins off their target or over text, clipped text. Fix and re-shoot once.
6. **Send** the absolute paths of `board.png` and each screen, a short list of the decisions (entry point, icon, placement, the main rule of the flow), and any open questions. The preview entry point and the new widgets stay uncommitted; if the proposal is dropped, delete them.

## Phase 2: Iterate

Feedback usually arrives as one-liners ("button location, icon, etc.", "remove that ugly icon"). Change the widgets, rebuild (background), re-shoot only the scenes that changed, move the pins, re-run `board.mjs`, look, re-send. An icon that changes becomes a real asset (SVG in `app/brands/<brand>/`, wired through `AppIcons`), never a stand-in.

## Phase 3: Build it

Only when asked. Read `AGENTS.md` first. It is the spec of how the day works, and the build must respect it.

1. **Look for prior art.** The sibling repo `../focus` is the original Focus app and often already has the feature (it had the agent: OpenRouter client, tool loop, "reads run, writes are proposed"). Port its approach rather than reinvent it. Read the git history of this repo for what was removed and why (`git log --stat`).
2. **Ask only real forks.** Use AskUserQuestion for decisions that are genuinely the user's (which model provider, a new container vs inside the server, a paid dependency), with a recommended option first. Don't ask what the code or `AGENTS.md` already answers.
3. **Server** (`server/src/<feature>/`, a Nest module):
   - Validate input the way `events/request.ts` does: refuse, never guess, and write user-facing refusals in Portuguese.
   - Writes go through `EventLayoutService`, so the time rules hold.
   - Anything the user must confirm or undo keeps enough state to undo exactly.
   - New env vars go in `server/.env.example` and `SETUP.md`.
   - End-to-end specs with the in-memory stores and a frozen clock (copy the harness in `events/events.controller.spec.ts`). Never depend on the machine's zone or hour.
4. **App:**
   - A new feature is its own package under `app/packages/` (copy `analysis_options.yaml` and the pubspec shape from `timeline`).
   - Every string goes in `app_pt.arb` (run `flutter gen-l10n`). Brand names select on `AppBrand.id`.
   - Colours come from tokens. Add a token (in both brands) rather than branching on the brand.
   - A modal sheet is its own route: hand it the blocs and repositories it reads (`BlocProvider.value`). A grey box in a release build is a build exception, very often this.
   - Inside a `BlocBuilder` builder, read `bloc.state`; `context.select` there throws.
5. **Verify:**
   - Server: `npx tsc --noEmit`, `npx eslint`, `npm test`.
   - App: `flutter analyze`, then `flutter test` in every touched package under **both** `--dart-define=BRAND=focus` and `BRAND=lunna` (CI does the same).
   - If a test is flaky, stash your tracked changes and rerun it to prove it isn't yours.

## Phase 4: Prints of the real build, and the delivery folder

1. **Screenshot the finished build**, through the same entry point:
   - Bring `app/lib/<slug>_preview.dart` up to the final code: its fakes now stand in for the real repositories (canned replies behind the real cubits), `DemoTimelineRepository` for the day, `?s=<n>` per scene (open the sheet, send a message, apply a plan).
   - Build both brands at once, in the background: `flutter build web -t lib/<slug>_preview.dart --dart-define=BRAND=<brand> --no-tree-shake-icons -o <scratchpad>/preview-<brand>`.
   - Shoot it: `.claude/skills/feature/shoot-flutter.sh <web_dir> <out_dir> 1 2 3 4` gives `<n>.png` per scene and `strip.png`.
   - Read the strips: they catch real bugs (the grey sheet above was one).
   - **Delete the preview entry point** afterwards; it is not committed.
2. **Write `delivery/<YYYY-MM-DD>-<slug>/README.md`**, one Markdown document, with images in `img/` next to it:
   1. **The prompt**: every user message of the request, verbatim and in order, plus answers given to questions.
   2. **The design**: the board as approved (`img/mockup-board.png`, plus `board.json`), the references, the decisions table matching the pins, and the icon.
   3. **What was built**: strips of the real build in both brands, the contract (the rule that matters), the server files and routes, the app pieces, the tests (with counts, and any flaky test named), and **where the build differs from the mockup** and why.
   4. **How to turn it on**: env vars, commands, and what happens without them.
   5. **Cost and time**: the readings table from the Cost and time section
      above (phase, start and end time, duration, start and end reading, spent
      in USD, tokens in, tokens out) and the totals. Wall-clock time includes the user's pauses
      between messages; say so. Note where each figure
      came from (the tool or a pasted `/cost`), and any spend outside Claude
      that the build caused (e.g. OpenRouter calls), or that there was none.
3. Add a short section for the feature to `AGENTS.md` (what it does, its contract, its routes), and its folders to the Layout block.
4. Report in a few lines: what it cost (USD, tokens in, tokens out) and how long it took, what works, what was verified and how, the deviations, what wasn't tested (e.g. "never run against a real model"), and the delivery path. Don't commit unless asked.
