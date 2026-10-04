# Time system

Now that we have three timely sections, we need to be consistent with the time system.

Let's describe the sections first.

1. Now: The top section, represents what is actually happening at the moment
2. Soon: This section groups at least what is happening today or in the next hours.
3. Later or others: This section is about things that are not prioritized or in a very primitive state.

## Source of truths

There are three source of truths for our case:

1. Calendar: always comes from focus google calendar.
2. Not timed: comes spontaneously from user creating things to be done. Its a pre-calendar thing, the goal is to live in the calendar (but the chaos of life sometimes dont allow)

### The calendar

Calendar events reflects really straightforward into the timeline structure.

- If now is between start date and end date, the thread simply appears in "now"
- If it's on the next few working hours it will be simply in the "soon" section

### Not timed

Not timed threads are very primitive, they can be open ended (with no duration), they can have duration but not a precise time. The finest planning is the one that is put into the calendar.

- When we first create anything on time page, it should go to "depois" because it is unprioritized.
- If the user moves to "Em breve" it must be blocked by a guard that asks the duration and proposes a estimated start time for that
- If the user accepts the time it is alraedy put to the calendar, if not it remains as manual but at least have some duration. 

## Guards

When things are moved between one place and the other, conflicts or strict requirements can happen.

- If you want to move a task to now or to soon, you should at least provide the duration of it
- If the now task is greater than the interval for the next instance of the calendar, it will also ask if you want to really do that now or if you want to postpone the next tasks
- If you reorder anything, and a conflict arises, you are asked to confirm about that (the default behavior is always moving the blocks postponing them)

Those are guards - They are popups that arise before confirming the action of moving

## Card information

The card can have all optional:

- Duration (15 min, 30 min, 45 min, 1 h, 1h30, 2h)
- Time of start and end time

They must show clearly on the card

Google Calendar information should match 100% in the UI.

## Implementation notes

- For now section, we should create a minute by minute routine by the agent to check what are the current tasks and move them as needed to the right filesystem.
- The confirmation is done via a communication between the server and the UI. The rules are in the server not in the UI. This can introduce some loading while reordering stuff by I think that's acceptable.
- The confirmation modals show have a very similar ui to what we have when using calendar tools, asking about time, etc. But we should have no access to AI, just best guessing based on the current information and a very clear ui for the user.
- Consider working hours (7h - 22h), this should be universal for our project
- Consider intervals between tasks of 5 min.