---
description: /mockup - show a Lunna/Focus change as a step-by-step strip, cheaply and in the app's own design - 2 to 5 phone screens drawn by the real Flutter app inside the real screen (real widgets, tokens only, pt-BR copy), one short line under each, reading only the /create plan's scope, one build and at most one fix pass; writes the draft delivery README with a Build brief for /build. Use after a /create plan, or when asked for a quick mockup, prints of an idea, or "how would X look".
---

# Mockup: the strip

One flow, told left to right in 2–5 phone screens with **one short line
under each** ("Toca no + e escreve", "A tarefa entra em Em seguida"). The
screens carry the decisions: no pins, no titles, no notes. **Budget: about
0.5 % of the week** (≈ 30 turns). If it would take more, draw fewer
screens.

The strip is drawn by the **real app**: the same widgets, tokens, fonts and
icons the build will ship, so it can't drift from the product and the
build starts from the widgets written here.

**Consistent with the app, not just cheap.** A strip that looks right in
isolation can still not look like Lunna. So: the change is shown **inside
the real screen** it belongs to (`DemoApp` or the real page on fakes),
never a lookalike scaffold; it is built from the **looks like** widget the
plan names (copy its structure, paddings and type, then change what the
ask changes); and new code uses only `app_ui` widgets and the
`AppColors` / `AppSpacing` / `AppTypography` tokens, never a literal
colour, font size or numeric padding (`.tool/preview` flags them).

**Lazy on purpose.** Draw what the plan's *does* lists and nothing else:
its **Not doing** and the answers *Decided with the person* are binding.
The fewest scenes that show the decision (2 is fine), the change dropped
into the existing screen rather than a new one, no states nobody asked
for.

## Steps

1. **Read only the plan's scope** (the files it lists and the looks-like
   widget), in one batch, with `Read` `offset`/`limit` at the lines it
   gives. No `.tool/map`, no wide greps: the plan did that. Without a plan
   (a quick mockup in a terminal), `.tool/map <words>` once. Widgets are in
   `app/packages/app_ui/lib/src/widgets/`, tokens in
   `app_ui/lib/src/theme/`, icons in `app_icons.dart` (Phosphor). Reuse
   before writing.
2. **Write the change where it will live** (the package that owns it),
   every string in `app_pt.arb` (`flutter gen-l10n` in
   `app/packages/l10n`). Copy in Brazilian Portuguese, mocked but
   believable. One primary action per screen. No sparkles, wands or
   robots: the agent is `AppIcons.agent`.
3. **The entry point** `app/lib/<slug>_preview.dart`, shaped like
   `lib/preview.dart` (`AppTheme.current`, pt-BR l10n, `DemoApp` or the
   real page with `DemoTimelineRepository` and fakes with canned replies).
   `?s=<n>` (`Uri.base.queryParameters`) picks the scene, and each scene
   seeds its state directly (a cubit built with it, a sheet opened in a
   post-frame callback). When the change alters a screen that exists,
   scene 1 may be that screen as it is today, so the strip shows the
   difference.
4. **The steps file**, one line per scene, in order, in the scratchpad.
5. **Build and shoot once**: `.tool/preview <slug> 1 2 3 --steps
   <steps.txt> --out <scratchpad>/m` (foreground, ~30 s; Lunna unless the brief
   says Focus). It writes `<out>/lunna/steps.png` and `steps-thumb.png`.
6. **Look at `steps-thumb.png` only**, never a full-size PNG: overflow
   stripes, grey boxes (a build exception, often a sheet without its
   `BlocProvider.value`), clipped text, and anything that doesn't match the
   screen around it. Replace each `⚠ off-token` line the preview printed
   with a token. Fix everything in one go and reshoot once.
7. **If you changed a shared widget** (in `app_ui`, `timeline` or another
   package's public widgets), run that package's tests once:
   `flutter test -r failures-only` there. A failure is yours to fix now,
   not the build's.
8. **Write the draft** `product/delivery/<YYYY-MM-DD>-<slug>/README.md`,
   with `img/mockup-steps.png` (the strip) next to it:
   1. **The prompt**: the ask and the brief, verbatim.
   2. **The design**: the strip, then the steps as a numbered list, and
      only the decisions the screens don't show (a rule, a timing).
   - **Build brief**: every file this session wrote or changed (the
     preview entry point stays, for the build's prints), what the build
     must still do on the server and in the app as a short list, with the
     `path:line` of each spot to change, and the open questions.

Keep the work in the files: the entry point and the widgets stay for the
build, which starts from this branch.

## Revise

The reply says what to change. Change only that, reshoot, replace
`img/mockup-steps.png`, put the reply in section 1 and update the steps
and the Build brief. One pass.

## Speed

- **Batch**: independent reads and commands go in one message. Several
  greps in one Bash call.
- **Never re-read** a file you wrote or already read; never `cat` a whole
  Dart file; keep any one result under ~20k characters.
- **Write with Edit or Write**, never edit scripts in Bash: a script
  repeats the code it replaces, and all of it stays in context.
- **Short messages**: no narration.
