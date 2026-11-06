# Task view: notes, subtasks and dialogs

> Issue [#94](https://github.com/pietroid/lunna/issues/94), **mockup
> track** (draft; the build follows).

## 1. The prompt

From the issue, verbatim:

> Visão da tarefa: notas, subtarefas e diálogos
>
> Strip of 3-4 screens of the task page: empty state always shows Notas (same body as a delivery's 'notas pendentes e feitas', no title/text), no 'adicionar tarefa', empty Pendentes shows a button instead of 'nada esperando…', subtasks with the home's spacing, drag, swipe and confirm dialogs for done and delete.

## 2. The design

![The task page in five steps](img/mockup-steps.png)

1. With no subtasks the page opens on **Notas**: the same body a delivery's
   Notas tab has (just the hint, no title or text field of its own).
2. An empty **Pendentes** shows the home's own `AppAddRow`, **Adicionar**, that
   opens the composer about this task; the "Nada esperando…" sentence is gone.
3. Subtasks are the home's `TaskCard`s with its spacing (`kQueueGap`, 4 px).
   A long press lifts one to drag it; swipe right ticks it off, as on the
   calendar: a green check in the corner, no label, **no dialog**.
4. Swipe left shows the red bin, as on the calendar.
5. Letting go asks *Excluir “…”?* (the existing `confirmDelete`).

Reply on the issue (verbatim):

> keep design consistent. You should only use the same components as the home one. the "escrever uma tarefa" should be just adicionar and the swipe to left and to right must be the same as the home. But I liked it the swipe.

Second reply (verbatim):

> adicionar should not have red button. The rest seems good.

Third reply (verbatim):

> Adicionar should be the exact same component as home.

Revised: the empty **Adicionar** is now `AppAddRow`, the very widget the home ends its sections with (a + and Adicionar in the quiet ink), not a button.

Decided unattended: the home's list has no swipe; the calendar (`timeline_list.dart` ~1196) does, so "same as the home" is read as that: right = done at once with a green check, left = delete after `confirmDelete`. This drops the done dialog the first brief asked for.
 "the task page" is `ArtifactPage` (a task with
subtasks); the "Nova tarefa" row/`artifactAddTask` is read as the
empty-state copy to drop, and the + dock stays as the one way to add.

## 3. What was built

App only. No server change, no new routes.

Images (`img/build-lunna.png`, `img/build-focus.png`), six steps: 1 Notas on open with no subtasks; 2 empty Pendentes with Adicionar; 3 a subtask held and dragged; 4 swipe right, done; 5 swipe left, asks to delete; 6 a loose task's notes only.

**The rule that matters:** a task's page behaves like the home and the calendar. Subtasks drag to reprioritize, swipe right ticks off at once, swipe left asks before it deletes, and the empty Pendentes ends in the home's Adicionar.

App pieces:

- `app/packages/artifacts/lib/src/view/artifact_page.dart` (`ArtifactPage`): Pendentes (`_Tasks`) is a `CustomScrollView`. Agora and the "Para depois" heading sit in a `SliverList`, then the open subtasks in a `SliverReorderableList` (long press, lifted with a Material elevation 6 in `AppColors.shadow`). The gap is `AppSpacing.s1`, the home's `kQueueGap`. Letting go writes the order through the day's existing move: `subtaskMove(id, rest, at, day)` (`@visibleForTesting`) returns an `EventMoved` that takes the place of the subtask it lands before, or follows the one it lands after. It uses the day's queue when that neighbour has an hour, the backlog (`backlog: true`) when it waits there, and null when neither is on the day. Empty Pendentes shows `AppAddRow` ("Adicionar"), which opens the composer about this task (`ComposeLauncher.open(about: AgentSubject.artifact(id))`). `_restoreTab` ignores a remembered Pendentes tab when nothing is pending, so the page opens on Notas. The preview-only `previewSwipe` and `previewLifted` are gone.
- `app/packages/artifacts/lib/src/view/subtask_row.dart` (`SubtaskRow`): the calendar's swipe. Past `SubtaskRow.threshold` (96 px), right sends `EventFinished` at once with a haptic. Left asks `confirmDelete` with `confirmDeleteSubtaskBody`, then sends `EventDeleted`. A cancelled drag springs back. Only the icon (green check, red bin) shows in the corner.
- `app/packages/timeline/lib/src/view/event_page.dart`: a loose task's notes are the delivery's Notas body, with no "Notas" heading and a field of `minLines` 8.
- `app/packages/timeline/lib/src/widgets/confirm_sheet.dart`: `confirmDelete(context, title, {body})` takes a text per type. Block: `confirmDeleteBody` ("Sai da agenda e não volta."). Task: new `confirmDeleteTaskBody` ("Sai da sua lista e não volta."), used by the event page's delete and by the calendar swipe when the card is a task (`timeline_list.dart`). Subtask: new `confirmDeleteSubtaskBody` ("Sai desta lista e da agenda, e não volta."). Delivery: `artifactDeleteBody`. Goal: `goalDeleteObjectiveBody`.
- `app/packages/l10n/lib/arb/app_pt.arb`: removed `confirmDone*` (and `confirmDone()`), `artifactPendingEmpty`, `artifactAddTask`, `eventNotesLabel`.
- `app/lib/task_view_preview.dart`, the preview entry, was deleted after the prints.

Tests, in the new `app/packages/artifacts/test/artifact_page_test.dart`:

- Opens on Notas when nothing is pending, and the empty Pendentes' Adicionar opens the composer about the task.
- Swipe left asks, and only yes deletes (a tap outside is no).
- Swipe right ticks off at once; a short swipe does nothing.
- A subtask held and dragged above another posts `EventMoved(id: 'd', index: 1)`.
- Unit test of `subtaskMove`: queue, backlog after, backlog before, unknown gives null.

Counts: artifacts package 67 pass, timeline 209 pass. `.tool/check` passed every step (app-analyze, all packages under Focus and Lunna).

Where the build differs from the ask, and why (decided unattended):

- The ask says confirm before marking done. The approved mockup (the person: "the swipe to left and to right must be the same as the home… I liked it the swipe", then "The rest seems good") has right swipe as done at once, as the calendar does. Built as the mockup: no done dialog; delete asks. Open question.
- "A text per type" is read as a delete body per type (block, task, subtask, delivery, goal).
- The home's list (Plano) still has no swipe; it is on the calendar and the task page only. Open question: should the home's cards get it?
- A swipe-done on a running subtask is not possible: the running one is drawn under Agora as `NowTaskCard`, outside the swipeable list.

## 4. How to turn it on

Nothing. It ships in the app: no env vars, no commands, no flag.

## 5. Cost and time

Measured by the queue: see the pull request.
