---
name: design-proposal
description: Take a feature for Lunna/Focus from idea to delivery - annotated HTML mockup with PNG prints, iterate on feedback, then (when asked) build it in the server and app, screenshot the real build in both brands, and record everything in a delivery/ folder. Use when asked for a design proposal, a mockup, "prints", "how would X look", or to implement and deliver a feature that was mocked.
---

# Design proposal → delivery

The flow has four phases. Stop after each one, send what it produced, and
only go on when the user asks ("great, now make the changes", "build it").
Phases 1–2 should be fast (ASAP means one HTML file and one render pass).
Phase 3 is real engineering. Phase 4 always closes a build.

Worked example of the whole flow: `delivery/2026-10-15-agent/README.md`.

## Phase 1: Mockup and prints

A proposal is a **board of 3–5 phone screens** telling one flow left to right,
each with a title, a one-line why, and **lettered pins** (A, B, C…) that point
at the decisions: where a button sits, which icon, what colour, what it does,
when it goes away. The pins are the point. The user wants placement and icon
decisions stated, not just pretty screens.

1. **Ground it in the app** (2 min max).
   - Tokens: `app/packages/app_ui/lib/src/theme/app_colors.dart` (Lunna values unless asked for Focus).
   - Type: **Onest** only. Radii: 24 card / 14 chip / 12 button / pill.
   - Icons: **Phosphor** (`app_icons.dart`).
   - Screen anatomy: greeting, Lista/Calendário segment, section headers ("Fazer em breve"), task cards (`fill`), routine cards (`routineFill`), fixed cards (`fixedFill`), the + FAB with the agent's ask bar beside it on Tempo, bottom bar Tempo / Projetos / Menu.
   - Reuse what exists (`packages/agent` has the ask bar, the sheet, the plan card and the suggestion card) unless the proposal is about changing it.
2. **References.** Name 2–3 apps whose pattern you're borrowing (Mobbin-style catalogue: ChatGPT, Notion, Motion, Structured, Sunsama, Linear, Arc…). Mobbin needs a login. If Chrome tools are connected and signed in, browse it. Otherwise say you drew from known patterns and don't pretend you browsed.
3. **Build the board.** Copy `assets/example-agent.html` as the starting point. It already holds the tokens, phone frame, status bar, cards, bottom bar, FAB, ask bar, sheet, composer, plan (diff) card, toast, the brand crescent (`#moon` gradient, `#moon1` solid) and the `.pin` / `.note` annotation system. Swap the content; keep the classes.
   - All copy in **Brazilian Portuguese**, mocked but believable: real-sounding tasks, hours that add up, today's date.
   - Accent on one primary action per screen.
   - **No generic AI iconography.** No sparkles, magic wands or robots. The agent is the brand's crescent without the check (`app/brands/lunna/agent.svg`, `AppIcons.agent`). Anything new gets a brand-derived or Phosphor icon, named in a pin.
   - Pins: an absolute-positioned `.pin` inside `.phone`, explained in the `.note` under it with the same letter.
   - Don't name a CSS class `ph` (or `ph-*`). It collides with Phosphor's font class and garbles the text.
4. **Render.** `.claude/skills/design-proposal/render.sh <board.html> <out_dir> <n>` writes `board.png` and `screen1..n.png` (2x, headless Chrome) into the session scratchpad.
5. **Look at the prints** (Read the PNGs) before sending: overlaps (toasts over cards, pins over text), icons that failed to load, clipped text. Fix and re-render once.
6. **Send** the absolute paths of `board.png` and each screen, a short list of the decisions (entry point, icon, placement, the main rule of the flow), and any open questions.

## Phase 2: Iterate

Feedback usually arrives as one-liners ("button location, icon, etc.", "remove that ugly icon"). Apply it to the board, re-render, re-check, re-send. When an icon changes, make it a real asset (an SVG in `app/brands/<brand>/` on the brand's 64-unit grid, plus a PNG preview), not just a CSS shape, so phase 3 can use it as is. Keep the template in `assets/` up to date with what was approved.

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

1. **Screenshot the real Flutter UI**, not the mockup:
   - Write a throwaway entry point `app/lib/<feature>_preview.dart`: a fake repository for the new feature (canned replies), `DemoTimelineRepository` for the day, and a `?s=<n>` query parameter that drives each scene (open the sheet, send a message, apply a plan).
   - Build it once per brand: `flutter build web -t lib/<feature>_preview.dart --dart-define=BRAND=<brand> --no-tree-shake-icons -o <scratchpad>/preview-<brand>`.
   - Shoot it: `.claude/skills/design-proposal/shoot-flutter.sh <web_dir> <out_dir> 1 2 3 4` gives `<n>.png` per scene and `strip.png`.
   - Read the strips: they catch real bugs (the grey sheet above was one).
   - **Delete the preview entry point** afterwards; it is not committed.
2. **Write `delivery/<YYYY-MM-DD>-<slug>/README.md`**, one Markdown document, with images in `img/` next to it:
   1. **The prompt**: every user message of the request, verbatim and in order, plus answers given to questions.
   2. **The design**: the board (`img/mockup-board.png`, plus `mockup.html`), the references, the decisions table matching the pins, and the icon.
   3. **What was built**: strips of the real build in both brands, the contract (the rule that matters), the server files and routes, the app pieces, the tests (with counts, and any flaky test named), and **where the build differs from the mockup** and why.
   4. **How to turn it on**: env vars, commands, and what happens without them.
3. Add a short section for the feature to `AGENTS.md` (what it does, its contract, its routes), and its folders to the Layout block.
4. Report in a few lines: what works, what was verified and how, the deviations, what wasn't tested (e.g. "never run against a real model"), and the delivery path. Don't commit unless asked.
