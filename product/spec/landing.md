# The landing page and the demo

What someone who is not signed in sees: what the app is, with the app
itself running beside it on a day of example. Delivered in
[product/delivery/2026-10-22-landing](../delivery/2026-10-22-landing/README.md).

## The contract

**The demo is the app, on fakes, and never reaches a server.** It draws the
same widgets the app ships (Tempo, Entregas, the agent's sheet, the plan
card) over repositories that answer from memory. Nothing it does calls
`ApiClient`: `DemoAgentRepository.apiClient` throws.

**The demo is lived at ten in the morning.** While `LandingPage` is up, the
app's clock (`package:clock`, which every widget and bloc reads) reads 10:00
today in the visitor's zone and runs on from there (`DemoClock.pin`). The
app runs inside `DemoClock.around(clock)` (`main.dart`); with no demo
pinned it is the real clock, unshifted. Code in `lib/demo` and
`lib/landing` reads `clock.now()`, never `DateTime.now()`.

## The page (`lib/landing/`)

- **Wide (≥ 960 px):** the headline and pitch, three **chapters** (Peça,
  Tempo, Entregas: what the app does, said in words) and the phone. The
  demo's shell keeps Tempo, Entregas and Menu as its tabs, one per chapter,
  though the app's are Feed, Plano and Menu: a chapter is a thing the app
  does, and the home is a summary of all three. The chosen
  chapter is what the phone shows, and a tab tapped in the phone moves the
  chosen chapter: both hold one `DemoController`. Under Peça, the example
  asks (`DemoAgentRepository.asks`) as pills; a tap opens the agent in the
  phone and sends it. On load the phone asks the first.
- **Narrow:** no phone. Each chapter shows its piece, drawn by the app's
  widgets (`ChapterPieces`): Peça the ask, the reply and a `PlanCard` whose
  Aplicar only marks it applied; Entregas a `GoalCard` and the next two
  `ArtifactRow`s.
- Under the first screen: "Também no app" (Rotinas, Lembretes, Voz), "No
  dia a dia", the privacy line and the footer.

## The demo (`lib/demo/`)

| Piece | What it does |
|-------|--------------|
| `DemoTimelineRepository` | The day in memory: a running task, a queue, a backlog, two fixed blocks. Anchored tasks keep their hour (or the first room after it); the queue takes the room left. `snapshot`/`restore` for undo |
| `DemoArtifactsRepository` | An astrologer's month: catalogue, a money goal, four deliveries. Creates, renames, moves, delivers and removes; the catalogue and goals are drawn, not changed |
| `DemoAgentRepository` | Answers from a script: the delivery ask gets a new delivery, anything else the study plan. `apply` writes the plan on the demo's day and Entregas; `undo` puts back what it found |
| `DemoVoiceRecognizer` | No microphone: the bar does not offer one |
| `DemoApp` | The shell (Tempo, Entregas, the Menu drawn and inert) with its own `Navigator`, so sheets and pages stay inside the phone |
| `DemoClock` | The pin above |

`lib/preview.dart` draws `DemoApp` alone for the timeline's prints; it is
not pinned.

## The web build

`web/index.html` and `web/manifest.json` describe the app as
"`<name>`: diga o que precisa, o dia se arruma.", which
`tool/brand_web.sh` stamps with the brand's name.
