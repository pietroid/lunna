| Model | pass^4 | pass@1 | p50 | p95 | calls/turn | tokens in/turn | cost |
|---|---|---|---|---|---|---|---|
| google/gemini-3.1-flash-lite | 22/24 (92%) | 97% | 1.3 s | 4.6 s | 1.27 | 2724 | $0.116 |
| google/gemini-3.5-flash-lite | 22/24 (92%) | 96% | 1.8 s | 3.6 s | 1.23 | 2600 | $0.172 |
| anthropic/claude-haiku-5.5 | 24/24 (100%) | 100% | 3.0 s | 5.8 s | 1.18 | 3689 | $0.051 |

Failures:
- google/gemini-3.1-flash-lite · `blocked-by-event` 2/4: on top of the meeting
- google/gemini-3.1-flash-lite · `two-matches` 1/4: proposed instead of asking
- google/gemini-3.5-flash-lite · `blocked-by-event` 3/4: on top of the meeting
- google/gemini-3.5-flash-lite · `two-matches` 1/4: proposed instead of asking
