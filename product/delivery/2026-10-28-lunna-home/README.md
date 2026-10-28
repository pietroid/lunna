# Lunna home: one home, one Painel, three tabs

Track: **mockup**. Design session, drawn by the real app (Lunna brand), waiting
for approval on [issue #59](https://github.com/pietroid/lunna/issues/59).

## 1. The prompt

> **Lunna home page**
>
> The way the user can access multiple levels of their management is not very clear.
>
> The information is perfect: timeline, deliverables and goals.
>
> However I would like to have a home page where user would have the best suggestions based on their time and what they need to do.
>
> This is agentic in nature so we can't have all the right information now.
>
> But what I would like you to do: draw the best shape of a home version that contains: next suggestin from Lunna to user, the current task playing, the next one , CTA to go to the calendar. Main deliverable, main goal (and ctas to manage them)
>
> About the other screens it is still the same but they will all live in a single tab. That way we have just three tabs: Lunna, control pane (or something shorter), and menu.
>
> In this control pane there is a tab bar where user can select t multiple levels: tasks, delivers, goals.

## 2. The design

![The board](img/mockup-board.png)

Board data: [board.json](board.json). Screens one by one:
[1](img/mockup-1.png) · [2](img/mockup-2.png) · [3](img/mockup-3.png) ·
[4](img/mockup-4.png) · [5](img/mockup-5.png).

**The flow.** The app opens on **Lunna**, the home. From top to bottom it shows
Lunna's one suggestion, **Agora** (the block running, with its buttons) and
**Em seguida** (the next one), then the **main delivery** and the **goal**.
Each section heading ends in a pill that opens its level in **Painel**:
*Ver o dia* opens Tarefas on the calendar, *Entregas* and *Objetivos* open
theirs. Painel is Tempo, Entregas and Objetivos as they are today, under one
heading whose words are the tabs.

**References** (taken from patterns I know, not browsed; Mobbin wasn't
used):
- **Sunsama / Motion "Today"**: a home that shows what is next and the
  current focus, with the full calendar one tap away.
- **Apple Music / Podcasts "Library"**: a large-text heading whose words are
  the sub-tabs, a level above the in-page segmented controls.
- **Linear's "My issues" / Things' "Today"**: summary cards on top, and each
  one leads to the full list behind it.

### Decisions

| Pin | Decision | Why |
|-----|----------|-----|
| 1A | The existing `SuggestionCard` moves from Tempo to the top of the Lunna tab | The issue's "next suggestion from Lunna" is the offer the agent already makes; the home is where it belongs, and Tempo stays the day itself |
| 1B | Encaixar is the only filled accent on the home | One primary action per screen |
| 1C, 2A, 2C | Each section heading ends in an `AppPillButton` naming where it leads: *Ver o dia* (calendar icon), *Entregas*, *Objetivos* | These are the issue's CTAs. They have one shape, the label names the destination, and none of them competes with Encaixar |
| 1D | Agora is the same `EventTile` with the same controls as Tempo's Agora (pause, −10/+10, done, or play when waiting) | "The current task playing" without a new widget to learn |
| 1E | Em seguida is **one** card: the next card on the calendar, task or fixed block | The person plans around whatever comes next. The home is not a list |
| 2B | Main delivery is Entregas' first: the most urgent under way, else the first not begun (`progressGroups`). It uses the real `ArtifactRow`, and a tap opens it on Pendentes | Entregas already decides the order, so the home doesn't invent a second ranking |
| 2D | The goal is the one being measured now, drawn as Objetivos' `GoalCard`. A tap opens its sheet | Manage it where it shows |
| 1F | Tab 1 is named after the brand (`appName`: Lunna / Focus), with the crescent (`AppIcons.agent`) | The issue names the tab "Lunna"; on Focus it reads "Focus" |
| 1G | Tab 2 is **Painel** ("control pane", shorter), icon Phosphor *squares-four* (`AppIcons.panel`, new) | A short Portuguese word. Four squares read as "the pieces" without being a list or a calendar |
| 3A | Painel's levels are a **heading of words** (`AppTitleTabs`, new in app_ui): ink for the one in front, `ink3` for the others, no pill | Picking a level picks what the screen is about, so it reads as the title. Lista/Calendário below stays the only control that looks like a control, so two segmented bars never stack |
| 3B | `TimelineModeCubit` moves up to the shell | So *Ver o dia* can open Tarefas on the calendar |
| 3C | Tempo itself is unchanged; only its greeting (and the account menu behind it) and the suggestion move to the Lunna tab | "The other screens are still the same" |
| 4A | Entregas' search moves to the end of Painel's heading, only while Entregas is in front | Its own title row is gone |
| 4C | The + follows what is in front: a delivery on Entregas, a goal on Objetivos, something on the day on Tarefas, Lunna and Menu | Same rule as today, one level deeper |

**The icon.** Only `AppIcons.panel` is new (Phosphor `squaresFour`). The
Lunna tab reuses the brand crescent (`AppIcons.agent`). There are no AI
glyphs.

### Decided unattended

- **The tab name is "Painel".** It is short, it's Portuguese, and the issue
  asked for something shorter than "control pane".
- **The app opens on Lunna**, not on Painel.
- **The + on the Lunna tab writes on the day without leaving the home.**
  The new task shows up in Em seguida when it lands there. From Menu it still
  brings Tarefas forward first.
- **The home doesn't ask the agent for anything new yet.** The issue says
  "we can't have all the right information now", so the suggestion is
  today's `GET /agent/suggestion`, and everything else on the home is read
  from data the app already loads (timeline, artifacts). A richer
  "best next step" is future work for the agent.
- **Em seguida can be a fixed block** (a meeting, lunch), not only a task.

## Build brief

Starts with `/create build lunna-home`. Phase 1 already wrote most of the
view layer, so the build checks it, finishes it, and tests it.

**Files Phase 1 wrote or changed (uncommitted until the queue commits
them):**
- `app/lib/lunna_home_preview.dart`: the preview entry point, five scenes
  (`?s=1..5`). It runs on the demo fakes plus a canned suggestion. Delete it
  after Phase 4's prints.
- `app/lib/overview/` (new): `OverviewPage`, the Lunna tab.
- `app/lib/panel/` (new): `PanelPage` and `PanelTab` (tasks, calendar,
  deliveries, goals).
- `app/lib/shell/view/shell_page.dart`: three tabs, `TimelineModeCubit`
  owned by the shell, the + per Painel level, the account menu handed to the
  home, and analytics screen names (Lunna / Tempo / Entregas / Objetivos /
  Menu).
- `app/lib/home/view/home_page.dart`: Tempo without its header or
  suggestion. It no longer creates `TimelineModeCubit` or `SuggestionCubit`.
- `app/packages/app_ui/`: `AppTitleTabs` (new widget, exported) and
  `AppIcons.panel`.
- `app/packages/artifacts/`: `ArtifactsPage(titled:)` and
  `GoalsPage(titled:)`.
- `app/packages/l10n/`: `shellPanelTab`, `panelTasks`, `overview*`,
  `demoSuggestionRenata` (`gen/` regenerated).

**What the build must do**
- **Server:** nothing. Every piece of the home reads routes that exist today
  (`/timeline`, `/artifacts`, `/agent/suggestion`).
- **App:**
  - Rename `HomePage` to something like `TempoPage` (it is no longer the
    home), and maybe `lib/home/` along with it.
  - Have the Lunna tab load the suggestion again when it comes to the front,
    and when the day changes (today it loads once).
  - Keep the bottom of the home clear of the dock. On the prints, the last
    line of the goal card ends under the bar. The same is true of Objetivos
    today, so `kNotesDockClearance` may need the bottom bar's height on
    pages that scroll under it.
  - On Lunna, *Ver o dia* also needs the calendar to scroll to now, which it
    already does when it opens.
  - The landing's demo (`lib/demo/`) keeps its own shell. Decide whether
    its phone shows the new Lunna tab as its first chapter (probably yes,
    for the "agent" chapter), and update `product/spec/landing.md` to match.
  - Tests: widget tests for `OverviewPage` (the empty states "Nada em
    andamento", "Nenhuma entrega em andamento" and "Nenhum objetivo agora";
    the main delivery being Entregas' first; each pill calling `onOpen`
    with the right `PanelTab`), for `PanelPage` (switching levels, search
    only on Entregas), and for `AppTitleTabs`. Run them under both brands.
  - AGENTS.md "The app shell": three tabs (Lunna, Painel, Menu), where the
    greeting and suggestion live now, and the Layout block (`overview/`,
    `panel/`).
  - Shoot both brands. On Focus the first tab reads "Focus".

**Open questions** (on the issue)
- Is "Painel" the name you want? Alternatives: "Gestão", "Tudo".
- Should the Lunna tab later show more than one suggestion (a short list
  ranked by the agent), or stay with one?

**Design session cost:** the queue measures it and writes the figures in the
PR (`.tool/cost` was skipped, as the queue's run instructions say).
