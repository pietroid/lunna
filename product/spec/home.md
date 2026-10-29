# The home: Feed and Plano

Delivered in [2026-10-28-lunna-home](../delivery/2026-10-28-lunna-home/README.md)
(issue #59). The app has three tabs: **Feed**, **Plano**, **Menu**. It
opens on Feed.

## Feed (`app/lib/feed/`, `FeedPage`)

One of each, never a list, so the screen is the same size whatever the day
holds. From the top:

| Section | What it shows | Chosen by | Empty |
|---------|---------------|-----------|-------|
| Header | greeting (the account menu: Rotina, Sair), long date, `AppDayClock` | | |
| Offer | `SuggestionCard`, the agent's one offer | `GET /agent/suggestion` (no model) | not drawn |
| Agora | the card in section `agora`, as `EventTile` with Tempo's controls | `TimelineState.cards` | "Nada em andamento" |
| Em seguida | the first card in section `dia`, task **or** fixed block, no controls | `TimelineState.cards` | not drawn |
| Entrega principal | `ArtifactRow`; a tap opens it on Pendentes | `progressGroups`: first begun, else first not begun | "Nenhuma entrega em andamento" |
| Objetivo | `GoalCard`; a tap opens its sheet | the money goal whose days are running | "Nenhum objetivo agora" |

Each heading ends in an `AppPillButton` into Plano: *Ver o dia*
(`PlanTab.calendar`: Tarefas on the calendar), *Entregas*, *Objetivos*.

The offer is asked for when the tab comes forward (`shown`), at midnight,
and on coming back from the background on another day. Nothing else on
Feed asks the server for anything the app does not already load.

## Plano (`app/lib/plan/`, `PlanPage`)

Tarefas (`TempoPage`, `app/lib/tempo/`), Entregas (`ArtifactsPage(titled:
false)`) and Objetivos (`GoalsPage(titled: false)`) behind an
`IndexedStack`, under `AppTitleTabs`: the words are the levels, the one in
front in ink. Entregas' search sits at the end of the heading while it is
in front. `TimelineModeCubit` belongs to the shell, so Feed can pick the
calendar.

## The shell (`app/lib/shell/`)

- The + writes a delivery on Plano › Entregas, a goal on Plano ›
  Objetivos, and anywhere else something on the day where Tempo is looking
  (from Menu it brings Tarefas forward first; from Feed it stays).
- Screens reported to analytics: `Feed`, `Tempo`, `Entregas`, `Objetivos`,
  `Menu`.
- Entregas and Objetivos (and Feed, which reads them) load the artifacts
  again when they come forward.
