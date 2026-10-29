#!/usr/bin/env node
// What writing the suggestion with the model costs, per person per month.
//   node code/cost.mjs > data/cost.csv
// Prefix: ../2026-10-21-agent-full-surface/data/schema-size.txt (~4,036
// tokens, the grown answer tool). Board: 1k (nothing written) to 3k
// (a full fortnight), an estimate. Output: one answer, ~600 tokens.
// Prices ($ per 1M in/out) as the agent-reliability RFC quotes them.
const MODELS = [
  ['claude-haiku-5.5', 0.1, 0.5],
  ['gemini-3.1-flash-lite', 0.25, 1.5],
];
const PREFIX = 4036, OUT = 600;
// Calls a month: one per valid period (a day), plus one after each rung
// met during onboarding (~6), plus the basis changing (~1 a day).
const CASES = [['steady: 1 a day', 30, 3000], ['busy: 2 a day', 60, 3000], ['onboarding month', 36 + 6, 1000]];
console.log('model,case,calls,usd_per_call,usd_per_month');
for (const [model, pin, pout] of MODELS) {
  for (const [name, calls, board] of CASES) {
    const call = ((PREFIX + board) * pin + OUT * pout) / 1e6;
    console.log(`${model},${name},${calls},${call.toFixed(5)},${(call * calls).toFixed(3)}`);
  }
}
