# Landing page: the agent first, and Entregas shown

Status: **design** (issue #24), drawn unattended on the mockup track.
Approve it, or comment on it, on the issue. The build starts from the
Build brief at the end.

## 1. The prompt

From [issue #24](https://github.com/pietroid/lunna/issues/24):

> Improve landing page
>
> Improve landing page specially for the web to showcase the agentic Lunna, it is just appearing the timeline.
>
> Also highlight the existence of the "deliveries" tab

## 2. The design

![The board](img/mockup-board.png)

Pins in [board.json](board.json). Drawn by the real app (Lunna), the web
page at 1440×900 and the narrow page at 390×844. One screen per image,
for a phone: [1](img/mockup-1.png) · [2](img/mockup-2.png) ·
[3](img/mockup-3.png) · [4](img/mockup-4.png) · [5](img/mockup-5.png).
The web shots at full size: [1](img/shot-1.png) · [2](img/shot-2.png) ·
[3](img/shot-3.png).

### The flow

1. **The web page opens on the agent.** The headline changes from "Seu
   dia, no lugar." to **"Diga o que precisa. O dia se arruma."**, and the
   pitch names what makes Lunna Lunna: you ask, it proposes a plan, you
   apply it or not; what you deliver becomes tasks on the same day. Beside
   the pitch, three **chapters**, which are the app's tabs said in words:
   **Peça** (the agent), **Tempo** and **Entregas**. The phone beside them
   is the app running on demo data, and on load it opens the agent's sheet
   and asks it the first example; the reply and its plan card come in as
   they do in the app.
2. **Entregas** is a chapter of its own. Choosing it switches the phone to
   the Entregas tab: the month's goal, the line of hours owed against free
   hours, the queue. The phone's bottom bar works both ways: a tab tapped
   in the phone moves the choice beside it.
3. **Under the first screen**, the rest of the app in three columns
   (Rotinas, Lembretes, and Voz, new) and the day in four lines, which now
   open with asking and close with a delivery.
4. **On a phone** there is no phone drawn in the page (a phone inside a
   phone is a thumbnail). Each chapter shows its piece instead, drawn by the
   app's widgets: Peça the ask, the reply and the real `PlanCard`;
   Entregas the `GoalCard` and the next two `ArtifactRow`s. Tempo is said in
   words.

### References

Drawn from known patterns; Mobbin was not browsed in this run.

- **Linear and Arc's home pages**: a short list of features beside a live
  product picture, where choosing one changes the picture. Here the picture
  is the app itself, not a video.
- **ChatGPT's and Claude's empty states**: example asks as tappable pills
  under "Experimente pedir", sent as if typed.
- **Notion's mobile landing**: on a narrow screen the product picture is
  replaced by the piece of UI each section is about.

### Decisions (the pins)

| Pin | Decision | Why |
|-----|----------|-----|
| 1A | Headline "Diga o que precisa. O dia se arruma." and a pitch that names the plan and the deliveries | The issue: the page showed only the timeline. The agent is the promise; the timeline is how it keeps it |
| 1B | Three chapters, Peça · Tempo · Entregas, the chosen one filled (`AppColors.fill`) and the only one that says its line | They are the app's tabs, so what the page teaches is what the app looks like. Peça uses the crescent (`AppIcons.agent`) in accent: no sparkles or robots |
| 1C | Two example asks as pills with the send arrow (`AppIcons.arrowUp`), one about the day, one about a delivery | Shows the agent on both halves of the app; a tap asks the phone's agent |
| 1D | The phone opens on the agent's real sheet, answering the first ask | The first thing a visitor sees move is the agent working |
| 1E | Aplicar writes the plan on the demo day; closing the sheet shows Tempo and the chapter follows | The demo is honest: the plan really lands |
| 2A | Entregas chapter, stack icon (`AppIcons.artifacts`, as on the tab) | The issue: highlight the deliveries tab |
| 2B | The real `ArtifactsPage`, on a `DemoArtifactsRepository` seeded as an astrologer's October | Same widgets the app ships, believable numbers (R$ 3.850 of R$ 6.000) |
| 2C | Bottom bar live both ways (one `DemoController`), Menu drawn and inert | The phone and the list never disagree |
| 2D | The + follows the tab: new delivery on Entregas, beside the ask bar (`AskDock`) on Tempo | As in the app |
| 3A | "Também no app": Rotinas, Lembretes, Voz | Tempo moved up into the chapters; voice is new on the page |
| 3B | "No dia a dia" opens with asking, closes with delivering | Same story as the hero, in short |
| 3C | Privacy line and footer unchanged | Says what PostHog records before anyone signs in |
| 4A–C | Narrow page: no phone; Peça shows the ask, reply and `PlanCard`, whose Aplicar only marks it applied | No day exists before signing in |
| 5A–B | Narrow Entregas: `GoalCard` + two `ArtifactRow`s, read-only | The tab's two forces in one glance |

### Decided unattended

- **Mockup track**, since the page is what the visitor sees.
- **Lunna only** in the prints; Focus gets the same page (copy selects on
  `AppBrand.id`), checked in the build's prints.
- **The web page gets wide prints.** `.tool/preview` shoots phones only, so
  the 1440×900 shots and the board with desktop screens were made by a
  copy of its scripts in the scratchpad (`shoot-wide.mjs`,
  `board-wide.mjs`). Folding a `--wide` option into `.tool/preview` and
  `board.mjs` is left for an `/improve` run.
- **Scripted agent, not the real one.** The demo's agent answers from a
  script (`DemoAgentRepository`): any text typed gets the first ask's
  answer. A real model on a page anyone can open would cost money per
  visitor and needs a session.
- **Two example asks**, one per half of the app (the day, a delivery), so
  Peça stays short enough for Tempo and Entregas to be on the first screen
  at 900 px.
- **Tempo's chapter has no piece on the narrow page**: a phone already
  knows what a day looks like, and a third block made the page long.

### Open questions of the design

- The demo reads the real clock: a visit at night shows "Boa noite" and
  a day that is over (the prints were shot at 00:31). Should the build pin
  the demo to a working hour (say 10:00 in the visitor's zone)? Recommended:
  yes.

## Build brief

### Files Phase 1 wrote or changed (uncommitted, kept for the build)

- `app/lib/landing_preview.dart`: preview entry point, `?s=1..6` (1 wide
  on Peça, 2 wide on Entregas, 3 wide scrolled under the hero, 4 narrow top,
  5 narrow at the plan, 6 narrow at Entregas). Delete after Phase 4.
- `app/lib/landing/view/landing_page.dart`: wide hero (pitch, `ChapterList`,
  phone with the mark's glow), narrow `ChapterPieces`, the two sections and
  the footer.
- `app/lib/landing/widgets/chapters.dart`: `DemoChapterCopy`,
  `ChapterList`, the ask pills, `ChapterPieces` with the ask and
  deliveries pieces.
- `app/lib/demo/view/demo_app.dart`: `DemoChapter`, `DemoController`, the
  shell with Tempo + Entregas, the agent's bloc and sheet, `AskDock`.
- `app/lib/demo/data/demo_agent.dart`: `DemoAgentRepository` (scripted
  replies and plans, `apply` writes on the demo timeline),
  `DemoVoiceRecognizer`, `demoReply`.
- `app/lib/demo/data/demo_artifacts.dart`: `DemoArtifactsRepository`,
  `demoArtifacts` (goal, catalogue, queue).
- `app/packages/l10n/lib/arb/app_pt.arb` (+ `gen/`): new `landing*` and
  `demo*` strings; `landingHowTitle`, `landingPartTimeline*`,
  `landingUseWrite`, `landingUseRoutine` gone.

### What the build must do

- **No server change.** The page is signed out and the demo is local.
- App: finish the demo's fakes (undo of an applied plan, the `+` sheets on
  Entregas writing to the demo repository, `DemoVoiceRecognizer` saying it
  is a demo), pin the demo clock if the open question is answered yes, and
  make sure nothing the demo does calls `ApiClient`.
- Tests: a widget test of `LandingPage` wide and narrow (the chapters
  switch the phone, a tab in the phone moves the chapter, an ask pill
  opens the sheet with its reply), and of `DemoAgentRepository.apply`;
  under both brands.
- The web build (`app/tool/brand_web.sh`): check the page title and meta
  description still say what the page now says; update them if they speak
  only of the timeline.
- Phase 4: prints of both brands, wide and narrow.

### Cost and time

The queue measures this run and writes the figures in the PR.
