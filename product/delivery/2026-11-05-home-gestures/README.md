# Home: gestos, arrastar e espaçamentos

## 1. The ask

Issue #93, part of #91:

> App, app/lib/plan/. Restore swipe left/right on TaskCard to mark done and
> delete (with confirm dialog, one per type). Allow dragging an item of Para
> depois to a position of the queue to reprioritize. Give the 'Adicionar' at
> the end of the queue the same spacing as the one in 'Em seguida'. 'Ver
> calendário' gets the click cursor on web (SystemMouseCursors.click like the
> other regions).
>
> Unattended. .tool/check must pass before you finish; a failure your change
> didn't cause is proved (stash, rerun) and named in the README.

From #91: *"I cant swipe anymore to left or right to mark as done and delete
(as it was before)"*, *"I cant reprioritize an item in 'para depois' dragging
it to a position of the queue"*, *"'Adicionar' on the end of the queue should
have a bit more spacing, like the one on the 'em seguida'"*.

## 2. The plan

App only; no route changes (`move { backlog: true, index }` and
`POST /artifacts/:id/move { index }` already take a place).

- **Swipe** (`app/lib/plan/view/plan_swipe.dart`, `PlanSwipe`): every task
  card of Plano (Agora, Em seguida, Pendentes, Para depois) and every
  delivery card (Pendentes, Para depois). Right is done, left is delete,
  each asked first. Four questions, one per gesture and kind: a task
  *Concluir “x”?* (`confirmDone`, new in `timeline`'s `confirm_sheet.dart`)
  and *Excluir “x”?*; a delivery *Entregar “x”?* and *Excluir “x”?* with
  what goes with it (`artifactDeleteBody`).
- **Para depois is a queue** (`PlanQueue<T>`, made generic): a slot before
  each card and one at the end, as Em seguida. A loose task posts
  `move { backlog: true, index }` (its place in the backlog); a delivery
  `ArtifactsCubit.move` (or `stop` when it was begun) at its place in the
  queue of deliveries. Let go on the heading, it goes first.
- **Spacing**: Para depois now ends in the queue's end slot (`AppSpacing.s3`
  of room), so its + stands off the last card as Em seguida's does.
- **Cursor**: `AppPillButton` (Ver calendário) gets
  `SystemMouseCursors.click`.

Proved by widget tests in `app/test/plan/home_page_test.dart` and prints of
both brands.

### Decided unattended

- *"Dragging an item of Para depois to a position of the queue"* read as
  reordering inside Para depois (a drag from Para depois into Em seguida
  already worked). Para depois draws loose tasks first and deliveries after,
  two orders on the server, so a loose task let go among the deliveries goes
  after the last loose task, and a delivery let go among the loose tasks
  before the first delivery.
- A delivery's card in Em seguida is its next task: a swipe ticks off or
  deletes that task, not the delivery, as its play plays that task.
- Fixed blocks (events) in Em seguida have no swipe: they are not tasks and
  are never moved by hand on Plano.

## 3. What was built

App only; no server change.

Prints, both brands, three steps each: `img/build-lunna.png` and
`img/build-focus.png`. 1. Para depois's + with the same room as Em
seguida's. 2. Swipe right on a task: *Concluir …?*. 3. On a delivery:
*Entregar …?*. The drag reorder and the cursor are not in the prints; tests
prove the first and the second is a one-line change.

**Swipe** (`app/lib/plan/view/plan_swipe.dart`): `PlanSwipe.task(card:)` and
`PlanSwipe.delivery(artifact:)`, a `Dismissible` around each task card
(Agora, Em seguida, Pendentes, Para depois) and each delivery card
(Pendentes, Para depois). Right is done, left is delete; both ask first with
a bottom sheet.

- Task done: `confirmDone` *Concluir “x”?* / *Sai da lista e vai para
  Feitas.* (`EventFinished`). Task delete: `confirmDelete`, body *Sai da
  lista e não volta.* (`EventDeleted`).
- Delivery done: *Entregar “x”?* / *Conta como entregue hoje, com o valor
  dela.* (`ArtifactsCubit.setDone`). Delivery delete: `confirmDelete` with
  `artifactDeleteBody` (`ArtifactsCubit.delete`).
- Cancel puts the card back. Once confirmed the card draws as nothing until
  the list drops it; a delivery the server refused comes back. Haptic on
  swipe.
- `timeline` package: new `confirmDone(context, title, {question, body,
  action})` in `confirm_sheet.dart`, with a success-coloured button. New l10n
  keys: `confirmDoneTitle/Body/Action`, `confirmDeliverTitle/Body/Action`,
  `confirmDeleteTaskBody`.

**Para depois is a queue** (`app/lib/plan/view/plan_drag.dart`):
`PlanQueue<T>` is generic (`items`, `idOf`, `itemBuilder`, `onDrop(carry,
before)`); Para depois is a `PlanQueue<Later>`. `dropOnPlan(...,
beforeLater:)`: a loose task posts `move { backlog: true, index }`
(`_backlogPlace`); a delivery `ArtifactsCubit.move(id, index)`, or
`stop(id, index)` if begun (`_deliveryPlace`). `laterDropper` is new. A
drop from another section into a slot now lands at that place (it was
always the top). The heading drop is the first place.

**Spacing**: Para depois ends in the queue's end slot (`AppSpacing.s3`).

**Cursor**: `AppPillButton` (`app_segmented.dart`) is wrapped in
`MouseRegion(SystemMouseCursors.click)`.

**Tests**: six new widget tests in `app/test/plan/home_page_test.dart`:
reorder a loose task in Para depois (`EventMoved`, index 0, backlog);
reorder deliveries (`move('v', 0)`); a loose task dropped on a delivery
lands after the loose ones; swipe right asks and finishes; swipe left,
cancel leaves it and confirm deletes; a delivery asks to deliver, then to
delete. `flutter test test/plan`: 27 passed. `.tool/check` passed.

**Differs from the plan**: the cursor sits on `AppPillButton` itself, so
every pill gets it, not only Ver calendário.

## 4. How to turn it on

Nothing. It is in the app.

## 5. Cost and time

Measured by the queue: see the pull request.
