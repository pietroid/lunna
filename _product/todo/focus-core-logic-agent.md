# Focus: Core Logic — Agent Implementation

This document specifies the Express-based Agent service (`agent/`) that generates A2UI replies for Focus threads using an LLM and OpenRouter tool calling.

## 0. Current State & What to Preserve

- **`agent/src/main.ts`** and **`agent/src/server.ts`** already implement an Express server with `/health` and `/reply` endpoints. Do not recreate the server boilerplate.
- **`agent/src/thread-store.ts`** already reads thread markdown files from `data/threads/{userId}/{slug}/{YYYY-MM-DD}/thread.md`. Reuse or extend it.
- **`agent/src/reply.ts`** already calls OpenRouter with a basic system prompt and returns plain text. This file must be rewritten to support tool calling and A2UI output, but the OpenRouter fetch structure can be reused.
- The Agent currently receives `{ userId, slug, message }` from the backend. Keep this contract for `/reply`; add `/execute-tool` for confirmations.

What **must change**:

- Replace plain-text output with A2UI JSON.
- Add OpenRouter tool definitions and a tool-execution loop.
- Add `/execute-tool` endpoint.
- Add tool implementations for Calendar, Web Search, and API calls.
- Add A2UI validation.

## 1. Service Overview

- The Agent is an internal HTTP service exposed only inside the Docker network on port `3001`.
- It has read-only access to thread data mounted at `/app/data/threads`. The Agent reads message files directly from this directory to build context.
- It uses the OpenRouter API for LLM inference.
- It exposes integrations (Calendar, Web Search, API) as OpenRouter tools and executes them directly.
- **Every response to the backend is an A2UI component tree.** Plain text is not a valid response; text must be wrapped in a `Text` component.

## 2. Routes to Implement

### 2.1 `POST /reply`

Generates the next A2UI message in a thread.

Request body (keep the existing backend contract):

```ts
interface ReplyRequest {
  userId: string;
  slug: string;
  message: string;
}
```

The Agent reads the full message history from `/app/data/threads/{userId}/{slug}/{YYYY-MM-DD}/thread.md`.

Response body:

```ts
interface ReplyResponse {
  a2ui: A2uiComponent;           // Always present. Root component tree.
  pendingToolCall?: ToolCall;    // Present when the model requested a tool that requires confirmation.
  solved?: boolean;              // If true, the backend may mark the thread as solved.
  metadata: {
    model: string;
    latencyMs: number;
  };
}
```

Behavior:

- Return `200 OK` with a valid A2UI tree.
- Return `400 Bad Request` for invalid input.
- Return `503 Service Unavailable` if OpenRouter fails and include a fallback A2UI reply.

### 2.2 `POST /execute-tool`

Executes a confirmed tool call. Called by the backend after the user confirms a tool action in the app.

Request body:

```ts
interface ExecuteToolRequest {
  userId: string;
  slug: string;
  toolCall: ToolCall;
}
```

Response body:

```ts
interface ExecuteToolResponse {
  a2ui: A2uiComponent;
  metadata?: {
    latencyMs: number;
  };
}
```

Behavior:

- Validate the `toolCall.name` against `allowedTools`.
- Execute the tool via `ToolExecutorService`.
- Feed the result into the OpenRouter loop and return the final A2UI response.
- Return `400 Bad Request` for invalid input or disallowed tool names.
- Return `503 Service Unavailable` if the external API fails; return a fallback A2UI error message.

## 3. Core Services

### 3.1 Context Builder (`ContextBuilderService`)

- Reuse `readThread` from `agent/src/thread-store.ts` to read markdown day-files from `/app/data/threads/{userId}/{slug}/`.
- Parse each message; for agent messages, detect and parse A2UI JSON in the body.
- Build an OpenRouter message list where:
  - User messages are `role: 'user'`, `content: text`.
  - Agent messages are `role: 'assistant'`, `content: <A2UI JSON string>`.
- Include the new user `message` as the final user turn.
- Truncate long message history to fit within the model's context window.
- Handle missing or unreadable files gracefully (log and continue with available data).

### 3.2 Prompt Assembler (`PromptAssemblerService`)

Load a system prompt from `src/prompts/system-prompt.txt`. The prompt must instruct the model to:

1. Act as Focus, a productivity assistant.
2. Help the user solve the thread, not just chat.
3. Use the available OpenRouter tools (Calendar, Web Search, API) when useful.
4. Return every reply as a valid A2UI JSON object with an `a2ui` root.
5. Wrap all text in a `Text` component.
6. Compose layouts using `Column`, `Row`, and `Spacer`.
7. Use `AppButton` or `AppIconButton` for interactive actions.
8. Ask clarifying questions only when necessary.
9. Be concise.

Append at runtime:

- The A2UI component catalog schema (flat discriminator format).
- The list of allowed tools with their JSON schemas.
- A small example of a valid A2UI response.

Example runtime appendix:

```
You must respond with valid JSON matching this schema:
{
  "a2ui": {
    "component": "Column",
    "children": [
      { "component": "Text", "text": "Your message here." }
    ]
  }
}

Available components: Column, Row, Spacer, Text, Icon, Image, AppButton, AppIconButton.
Available tools: web_search, calendar_check_availability, calendar_create_event, api_call.
```

### 3.3 OpenRouter Client (`OpenRouterService`)

- Read `OPENROUTER_API_KEY` and `OPENROUTER_MODEL` from environment.
- POST to `https://openrouter.ai/api/v1/chat/completions`.
- Request body includes:

```ts
{
  model: string;
  messages: ChatMessage[];
  tools: ToolDefinition[];
  tool_choice: 'auto';
  temperature: 0.7;
}
```

- Parse the response:
  - If `finish_reason === 'tool_calls'`, extract `tool_calls` and return them to the orchestrator.
  - Otherwise, parse the assistant's `content` as A2UI JSON.
- Track latency and model used.
- On failure, throw a typed error that the route handler converts to a fallback A2UI response.

### 3.4 Tool Loop Orchestrator (`ToolLoopService`)

- Runs the OpenRouter request/response loop.
- On each iteration:
  1. Call `OpenRouterService.generate` with current messages + tools.
  2. If the response contains tool calls, process them:
     - Read-only/safe tools (`web_search`, `calendar_check_availability`): execute immediately and append `role: "tool"` messages.
     - Confirmation-required tools (`calendar_create_event`, mutating `api_call`): stop the loop and return an A2UI confirmation UI + `pendingToolCall`.
  3. If the response is final A2UI JSON, validate it and return it.
- Maintain a `latencyMs` total across all loop iterations.

### 3.5 A2UI Validator (`A2uiValidationService`)

- Maintain the catalog of component schemas.
- Validate that the top-level response has an `a2ui` field.
- Validate every component in the tree recursively.
- Reject unknown components and strip unknown props.
- Ensure every `Text` component has non-empty `text`.
- On validation failure, replace the invalid tree with a fallback A2UI error message.

### 3.6 Tool Registry (`ToolRegistryService`)

- Maintains a registry of tool implementations.
- Looks up the implementation for a given tool name.
- Validates that the requested tool is in `allowedTools`.

### 3.7 Tool Implementations

Implement behind a common interface:

```ts
interface ToolImplementation {
  readonly name: string;
  readonly requiresConfirmation: boolean;
  execute(args: Record<string, unknown>, user: UserContext): Promise<unknown>;
}
```

Initial tools:

- `web_search` (`requiresConfirmation: false`)
  - Performs a web search and returns summarized results.
- `calendar_check_availability` (`requiresConfirmation: false`)
  - Checks free/busy times on the user's calendar.
- `calendar_create_event` (`requiresConfirmation: true`)
  - Creates a calendar event. Must only be called after user confirmation.
- `api_call` (`requiresConfirmation: true`)
  - Calls a configured third-party API. Read-only endpoints can be whitelisted to `requiresConfirmation: false` via config.

### 3.8 Tool Executor (`ToolExecutorService`)

- Receives a `ToolCall` from `/execute-tool` or from the tool loop.
- Resolves the implementation via `ToolRegistryService`.
- Validates arguments against the tool's JSON schema.
- Executes the tool and returns the result.
- Catches errors and converts them into a structured error result.

## 4. System Prompt Requirements

Create `agent/src/prompts/system-prompt.txt` with the following responsibilities covered:

- Identity: "You are Focus, a productivity assistant."
- Goal: "Your job is to help close open threads in the user's mind."
- Constraint: "Always prefer actions over plain explanations."
- Tool model: "You have access to tools. Read-only tools can be called directly. Write or sensitive tools require the user's explicit confirmation, which you request by calling the tool; the system will pause and ask the user."
- Output format: "Every response must be valid JSON with a top-level `a2ui` field. Wrap all displayed text in a `Text` component. Never return plain text outside the A2UI tree."
- Allowed tools and components are injected at runtime; do not hardcode them in the prompt file.

## 5. Failure Handling

If OpenRouter is unavailable, the API key is missing, parsing fails, or A2UI validation fails:

- Return a fallback `ReplyResponse`:

```ts
{
  a2ui: {
    component: 'Text',
    text: "I'm unable to reply right now. Please try again in a moment."
  },
  metadata: { model: 'fallback', latencyMs: 0 }
}
```

- Log the original error with `slug` and `userId` (do not log the API key).

## 6. Environment Variables

Existing variable (already in use):

```
FOCUS_DATA_DIR=/app/data/threads
```

Add/update:

```
PORT=3001
OPENROUTER_API_KEY=
OPENROUTER_MODEL=openai/gpt-4o-mini

# Integrations
CALENDAR_API_KEY=
CALENDAR_API_BASE_URL=
WEB_SEARCH_API_KEY=
WEB_SEARCH_API_BASE_URL=
API_INTEGRATION_BASE_URL=
API_INTEGRATION_API_KEY=
```

> `FOCUS_DATA_DIR` must match the read-only mount in `docker-compose.yml`.
> Integration secrets are loaded only by the Agent. The backend must not have access to them.

## 7. Docker

The agent Dockerfile (`agent/Dockerfile`) must:

- Use a Node.js image.
- Build TypeScript.
- Expose port `3001` only inside the Docker network (do not publish publicly in `docker-compose.yml`).
- Mount `/app/data/threads` read-only from a shared Docker volume.
- Inject integration secrets (`OPENROUTER_API_KEY`, `CALENDAR_API_KEY`, etc.) via environment variables at runtime, not build time.

## 8. Tests

- Unit tests for `ContextBuilderService`, `A2uiValidationService`, and `ToolExecutorService`.
- Use a temporary directory of message files for `ContextBuilderService` tests.
- Mock OpenRouter client and test `POST /reply` success, tool-call, and fallback paths.
- Mock tool implementations and test `POST /execute-tool` success and failure paths.
- Validate that the Agent never returns a response without a valid `a2ui` field.
- Validate that the Agent never calls or executes a tool outside the allowed list.
- Verify that integration secrets are loaded from environment and not logged.
