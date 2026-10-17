| Model | pass^4 | pass@1 | p50 | p95 | calls/turn | tokens in/turn | cost |
|---|---|---|---|---|---|---|---|
| google/gemini-3.1-flash-lite | 1/1 (100%) | 100% | 3.7 s | 5.8 s | 2.50 | 5590 | $0.010 |
| google/gemini-3.5-flash-lite | 1/1 (100%) | 100% | 3.7 s | 5.7 s | 2.25 | 4380 | $0.012 |
| anthropic/claude-haiku-5.5 | 1/1 (100%) | 100% | 5.3 s | 6.3 s | 2.00 | 6472 | $0.004 |

Every run passed.
| Model | pass^4 | pass@1 | p50 | p95 | calls/turn | tokens in/turn | cost |
|---|---|---|---|---|---|---|---|
| google/gemini-3.1-flash-lite | 1/1 (100%) | 100% | 1.2 s | 1.3 s | 1.00 | 2113 | $0.003 |
| google/gemini-3.5-flash-lite | 0/1 (0%) | 50% | 2.7 s | 2.9 s | 1.00 | 1829 | $0.007 |
| anthropic/claude-haiku-5.5 | 1/1 (100%) | 100% | 2.5 s | 2.8 s | 1.00 | 3103 | $0.002 |

Failures:
- google/gemini-3.5-flash-lite · `two-matches` 2/4: proposed instead of asking
