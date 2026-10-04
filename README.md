# Focus

<div align="center">
    <img src="./focus.png" alt="Focuslab Logo" width="200"/>
</div>

_Informational human organicity_

## What it is

Focus is a system designed to make me work and live focused and properly - with the help of AI Agents and any other needed tool. It's my own homemade version of Clawdbot tuned to my necessities.

## Current state

Focus is made of three components:

(1) The Control Center App - works for iPhone, Android and Web.
(2) A server - communicates with the App and with the AI Agent.
(3) An AI Agent - An fully autonomous and sandboxed Agent that can integrate to any tool and do anything needed.

### The App Interaction

The basic interaction is a Chat where we can do anything - paste a link, ask something.

We will have a history of chats and related themes.

### Agent Integrations

The integrations with the Agent are:

- Google Calendar: a separate google account just for the focus system. No worries about messing stuff - full ownership.
- Github Account: the Agent can change the code from focus itself and deploy a new version if needed.
- Websearch: Agent can do web search
- OpenRouter: To decide which LLM provider to use, we should have something like openRouter.

### Use Cases

- Add things to todo list
- Schedule task time.
- Ask for anything, regardless of Agent Provider.
- Agents, tokens and accounts management.

## Development

See [SETUP.md](./SETUP.md) for build, Firebase and deployment instructions.
