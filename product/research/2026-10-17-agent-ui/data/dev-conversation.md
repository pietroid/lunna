# The one conversation in the dev database

Read from `agent_message` on the Neon dev branch, 2026-10-17 (4 turns,
`code/replies.mjs` gives the aggregates in `replies.json`). Verbatim. Steps
are what the app draws above the reply, with a green check each.

| # | Person | Steps | Agent reply | Plan |
|---|---|---|---|---|
| 1 | Organiza minha tarde | — | Sua tarde já tem Ué, Troca 2, Troca e Troca 3 até as 18:58, e de 19:03 às 22:00 há 177 minutos livres. Quer que eu encaixe o backlog (Troca 2 e Criar post) nesse tempo livre, ou tem outra coisa em mente para organizar? | no |
| 2 | sim | Achei Troca 2 · tarefa · Depois eu priorizo / Livre hoje: 19:03–22:00 / Achei Criar post · tarefa · Depois eu priorizo | Não consegui encaixar as duas tarefas hoje: o sistema recusou o Criar post, que cairia depois do fim do expediente. Quer que eu tente só a Troca 2 às 19:03, ou prefere mandar as duas para amanhã, onde há 900 minutos livres? | no |
| 3 | sim | — | Não ficou claro se você quer a Troca 2 às 19:03 hoje ou as duas tarefas amanhã, onde há 900 minutos livres. Qual dos dois você prefere? | no |
| 4 | troca 2 hoje | Achei Troca 2 · tarefa · Depois eu priorizo / Livre hoje: 19:03–22:00 | Fica assim: a Troca 2 do backlog entra hoje no primeiro horário livre, às 19:03, e sai do backlog. Nada mais muda na sua tarde. Pode aplicar? | yes |

What it shows:

- **Four turns for one plan.** Turns 1–3 end in an either/or question
  written as prose. "sim" answers neither half, so turn 3 asks again.
- **Prose that restates the screen.** Turn 1 lists the afternoon the person
  is looking at; turn 4 restates the plan card under it.
- **The machinery leaks.** "o sistema recusou" (a refusal from
  `_rehearse`/`_draft`, `agent.service.ts:1077`), "backlog" (the prompt's
  word; the app says *Depois eu priorizo*), "900 minutos livres" (the
  board's `span()` format, `board.ts:394`), 18:58 and 19:03 (raw layout
  minutes).
- The "a2" reply the user saw is not in this branch; it came from another
  database. The mechanism is in the RFC's diagnosis.
