#!/usr/bin/env node
// What three ways of making the next suggestion "at its follow-up time"
// add to Neon's awake time, for the two people we have, over 30 days.
//   node code/followup.mjs > data/followup.csv
//
// Neon sleeps after 5 quiet minutes, so each query that finds it asleep
// buys at least 5 minutes of 0.25 CU (neon-compute RFC). The people's own
// opens wake it anyway; only minutes outside those are extra.
//
//   hourly-scan     a cron asks Postgres every hour which suggestions are due
//   timer-at-next   an in-memory timer per person fires at next_at (inside
//                   the working day) and writes the new suggestion
//   on-read         nothing on the server; the phone's notification fires at
//                   next_at and the suggestion is written when the app opens
//
// Assumptions (stated, not measured): 4 opens a day per person, each keeps
// Neon up 10 min; follow-ups alternate 3 h and 24 h from the answer, which
// comes 0–40 min after the suggestion; working day 07:00–22:00.

const DAYS = 30, PEOPLE = 2, AWAKE = 5, OPEN_MIN = 10, CU = 0.25, USD = 0.106;
const DAY_START = 7 * 60, DAY_END = 22 * 60;

let seed = 69;
const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);

const opens = [];
const timers = [];
for (let p = 0; p < PEOPLE; p++) {
  for (let d = 0; d < DAYS; d++) {
    for (const h of [8, 12.5, 16, 20]) {
      opens.push(d * 1440 + h * 60 + Math.round(rand() * 40));
    }
  }
  // The suggestions: each next_at is the answer + its follow-up, moved into
  // the working day.
  let t = DAY_START + 60, i = 0;
  while (t < DAYS * 1440) {
    timers.push(t);
    const answer = t + Math.round(rand() * 40);
    t = intoDay(answer + (i++ % 2 === 0 ? 180 : 1440));
  }
}

function intoDay(t) {
  const day = Math.floor(t / 1440), m = t % 1440;
  if (m < DAY_START) return day * 1440 + DAY_START;
  if (m >= DAY_END) return (day + 1) * 1440 + DAY_START;
  return t;
}

/** Minutes awake from `wakes` that the opens don't already cover. */
function extra(wakes) {
  const awake = new Set();
  for (const o of opens) for (let m = 0; m < OPEN_MIN; m++) awake.add(o + m);
  let n = 0;
  const added = new Set();
  for (const w of wakes) {
    for (let m = 0; m < AWAKE; m++) {
      const at = w + m;
      if (!awake.has(at) && !added.has(at)) { added.add(at); n++; }
    }
  }
  return n;
}

const scans = Array.from({ length: DAYS * 24 }, (_, h) => h * 60);
const OPTIONS = [
  ['hourly-scan', scans, scans.length],
  ['timer-at-next', timers, timers.length],
  ['on-read', [], 0],
];

console.log('option,server_wakes_month,extra_awake_min_month,extra_cu_hours_month,extra_usd_month,suggestions_month');
for (const [name, wakes, count] of OPTIONS) {
  const min = extra(wakes);
  const cuh = (min / 60) * CU;
  console.log([name, count, min, cuh.toFixed(1), (cuh * USD).toFixed(2), timers.length].join(','));
}
