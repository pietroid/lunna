✓ denies("no") = true
✓ denies("Não.") = true
✓ denies("backlog") = true
✓ denies("depois") = true
✓ denies("no, but change the icon") = false
✓ denies("approve") = false
model claude-sonnet-5-5 · tools 10 · skills 26 · first turn 36107 tokens
2 turns · $0.154 · 9 s · ✓ ok

Split into 4 pieces, 7 points in total. Nothing was left out. I did not check whether #81 and #83 were implemented. The first build's brief therefore starts with an audit, and the piece that fixes play on the calendar and the >1h dialog follows from that audit.

| # | Kind | Piece | Estimate | Impact | After |
|---|---|---|---|---|---|
| 0 | build | Auditar #81 e #83 e completar o que falta | 2.5 | high |  |
| 1 | build | Play no Calendário igual ao de Agora e das tarefas | 1 | high |  |
| 2 | mockup | Em seguida como fila: hierarquia de Agora, arrastar | 0.5 | medium |  |
| 3 | build | Em seguida arrastável e prévia discreta no arrasto | 2.5 | medium | 2 |

**Auditar #81 e #83 e completar o que falta**
Check whether #81 (the + opens the composer, `openComposer`, `POST /agent/compose`, preview with Adicionar/Ajustar) and #83 (a task over 1h asks how much on play: `PlayWhenSheet`, `PlaySheet`, `PlaceSheet`, `askPlay`) really work on every path. Check the Plano +, the section + buttons, the calendar's + and free stretches, and play on Plano, Em seguida and the calendar. Fix what is missing or broken and report what was and was not done.

**Play no Calendário igual ao de Agora e das tarefas**
On `DayPage` / Calendário cards, put the same round play button (same widget and behaviour as `TaskCard`) before the title on every task that waits. Play goes through `TimelineList.onPlay`, so it asks when and how much (`PlayWhenSheet`, then `PlaySheet`/`PlaceSheet` over 1h). Rely on the dialog fix from the audit piece, so do it after that piece.

**Em seguida como fila: hierarquia de Agora, arrastar**
Show Plano with Em seguida using the same hierarchy as Agora (same card, play on every task, the event in `fixedFill`) and cards carried as a queue. Include the drag preview: no 'Solte aqui' text, only a discreet quiet copy of the task at the future position. 3 screens: at rest, mid-drag, after the drop.

**Em seguida arrastável e prévia discreta no arrasto**
Per the mockup: Em seguida cards get Agora's hierarchy and play on all of them. They can be dragged as a queue (`move { index }`, `PlaceSheet` over an hour). In every drag target (Plano's four sections, Lista, calendar) remove the 'Solte aqui' copy (also from `app_pt.arb`) and show only the card's quiet copy where it lands.
