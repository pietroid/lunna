# Probe: can an unattended run see the subscription limits? (2026-10-17 ~22:00 BRT, Claude Code 2.1.302)

## `claude -p "/usage" --output-format json` (0 tokens, 446 ms)

```
You are currently using your subscription to power your Claude Code usage

Current session: 61% used · resets Oct 18 at 12:19am (America/Sao_Paulo)
Current week (all models): 68% used · resets Oct 18 at 9:59am (America/Sao_Paulo)

What's contributing to your limits usage?
Approximate, based on local sessions on this machine — does not include other devices or claude.ai. Behaviors are independent characteristics, not a breakdown.

Last 24h · 952 requests · 21 sessions
  45% of your usage was at >150k context
  29% of your usage went to always-on context over 40k tokens
  11% of your usage came from subagent-heavy sessions
  Top skills: /create 48%, /research 7%
  Top subagents: deep-research 2%, general-purpose 1%
  Top MCP servers: claude-in-chrome 2%

Last 7d · 2651 requests · 51 sessions
  58% of your usage was at >150k context
  21% of your usage went to always-on context over 40k tokens
  16% of your usage came from subagent-heavy sessions
  Top skills: /create 16%, /claude-api 5%, /feature 3%, /research 2%, /design-proposal 1%
  Top subagents: general-purpose 1%, deep-research 1%
  Top MCP servers: claude-in-chrome 3%
total_cost_usd 0 num_turns 0
```

## `claude -p "reply ok" --model haiku --output-format stream-json --verbose`: the rate-limit event

```json
{
 "type": "rate_limit_event",
 "rate_limit_info": {
  "status": "allowed",
  "resetsAt": 1792293600,
  "rateLimitType": "five_hour",
  "overageStatus": "rejected",
  "overageDisabledReason": "org_level_disabled",
  "isUsingOverage": false,
  "unifiedWindows": {
   "five_hour": {
    "utilization": 0.61,
    "resetsAt": 1792293600
   },
   "seven_day": {
    "utilization": 0.68,
    "resetsAt": 1792328400
   }
  }
 }
}
```
