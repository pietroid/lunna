# Routines

A routine is one row in `routine` with a rule (`daily`, `weekdays`,
`weekend`), a first occurrence whose wall-clock hour, in the person's zone,
is every day's, and `fixed`. **Reading a window writes down each day of each
routine that falls in it**, with `INSERT … ON CONFLICT DO NOTHING` on
(`routine_id`, `occurrence`):

Every routine is **fixed** (`fixed` defaults to true; the flexible kind
was removed with the reminders' lifecycle, see "Reminders"): each day is
written as an `event` row, in `CalendarStore.window`. Nothing moves it.

From then on that day is its own row and the other days are untouched.
Taking a day off marks it `cancelled` rather than deleting it, so the next
read does not bring it back.

Changing a routine deletes its days that have not begun yet;
the next read writes them again at the new hour and name. Removing a
routine deletes the days ahead and keeps the ones that happened.

A routine may have a **checklist** (`routine.checklist`, titles in order:
breakfast is the coffee, meditating, the dishes). Each day is written down
with its own copy (`task.checklist` or `event.checklist`, `[{ title, done
}]`, null for no list), so ticking an item off today leaves tomorrow alone;
a new list reaches the days not begun, like a new hour. The card carries it
as `checklist`, and `PATCH /api/tasks|events/:id { checklist }` ticks it
(the whole list, at most 30 items). Ticking the last item off finishes
nothing. The card draws the list where the notes would go: the next item
and "1 de 3" in Lista and Agora, every item on the calendar when the card
has a line (20 px) for each; items are ticked on the event page.
