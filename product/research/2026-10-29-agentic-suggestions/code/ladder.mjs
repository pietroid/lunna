#!/usr/bin/env node
// Work Quality (the seven levels of a defined plan), run on five people's states, beside the tiers of
// issue #67's thin layer. Prints data/ladder.csv.
//
//   node code/ladder.mjs > data/ladder.csv
//
// Every level is arithmetic on what the server already reads (goals with
// done/queued, open deliveries, Schedule, routines, the day). The first
// level not met is what the one suggestion is about.

const LEVELS = [
  ['goal', 'a goal is running', (s) => s.goal !== null],
  ['reach', 'its open deliveries reach it (done + queued ≥ target)',
    (s) => s.goal.done + s.goal.queued >= s.goal.target],
  ['shape', 'each of them has a day, a value and a length',
    (s) => s.deliveries.every((d) => d.deadline && d.value && d.minutes)],
  ['tasks', 'the main delivery has a next task',
    (s) => s.deliveries.length === 0 || s.deliveries[0].openTasks > 0],
  ['fits', 'the work owed fits the free hours before the days due',
    (s) => s.schedule.needMinutes <= s.schedule.freeMinutes],
  ['routine', 'a routine is written and the working day is set',
    (s) => s.routines > 0 && s.workDaySet],
  ['pace', 'the goal is not behind its pace (15 % slack)',
    (s) => s.goal.done >= s.goal.target * (s.timeGone - 0.15)],
];

/** The first Work Quality level not met, or `keep` when all are. */
function ladder(state) {
  const met = [];
  for (const [name, , test] of LEVELS) {
    if (!test(state)) return { topic: name, met };
    met.push(name);
  }
  return { topic: 'keep', met };
}

/** Issue #67's tiers, as its build brief writes them. */
function tiers(state) {
  const due = state.deliveries.filter((d) => d.deadline);
  if (state.goal === null || due.length === 0) return 'goal';
  if (state.goal.done < state.goal.target * (state.timeGone - 0.15)) {
    return 'delivery';
  }
  return 'routine/backlog';
}

const goal = (target, done, queued) => ({ target, done, queued });
const delivery = (deadline, value, minutes, openTasks) =>
  ({ deadline, value, minutes, openTasks });
const free = (needMinutes, freeMinutes) => ({ needMinutes, freeMinutes });

const PEOPLE = [
  ['new: nothing written (the golden scenario)', {
    goal: null, deliveries: [], schedule: free(0, 0), routines: 0,
    workDaySet: false, timeGone: 0,
  }],
  ['goal R$ 5.000, two deliveries worth R$ 4.200', {
    goal: goal(5000, 0, 4200),
    deliveries: [delivery('11-14', 1800, 240, 0), delivery('11-25', 2400, 360, 0)],
    schedule: free(600, 9000), routines: 0, workDaySet: false, timeGone: 0.03,
  }],
  ['goal reached on paper, no tasks, no routine', {
    goal: goal(5000, 0, 5400),
    deliveries: [delivery('11-14', 1800, 240, 0), delivery('11-25', 3600, 360, 0)],
    schedule: free(600, 9000), routines: 0, workDaySet: false, timeGone: 0.1,
  }],
  ['all written, but 40 h owed in 25 h free', {
    goal: goal(5000, 1800, 3600),
    deliveries: [delivery('11-14', 1800, 1200, 3), delivery('11-25', 1800, 1200, 2)],
    schedule: free(2400, 1500), routines: 2, workDaySet: true, timeGone: 0.4,
  }],
  ['demo: everything written, behind pace', {
    goal: goal(6000, 1200, 4800),
    deliveries: [delivery('11-03', 1050, 510, 4)],
    schedule: free(510, 1860), routines: 3, workDaySet: true, timeGone: 0.7,
  }],
];

console.log('person,topic,work_quality,tiers_67');
for (const [name, state] of PEOPLE) {
  const { topic, met } = ladder(state);
  console.log(`"${name}",${topic},${met.length}/${LEVELS.length},${tiers(state)}`);
}
