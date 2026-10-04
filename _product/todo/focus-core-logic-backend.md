# Focus: Core Logic — Backend Implementation

This document specifies exactly what must be implemented in the NestJS backend (`server/`) to support the Focus core logic.

## 0. Current State & What to Preserve

- **`AuthModule`**, **`FirebaseAuthGuard`**, **`FirebaseStrategy`**, and **`CurrentUser`** already exist. Do not recreate them.
- **`UsersModule`**, **`UsersController`** (`POST /users/signup`, `GET /users/me`), and **`UsersService`** already exist. Do not recreate them.
- **`ThreadsModule`**, **`ThreadsController`** (`GET /threads`, `GET /threads/:slug`, `POST /threads`, `POST /threads/:slug/messages`), **`ThreadsService`**, and **`ThreadsStore`** already exist.
- **`AgentService`** already exists in `server/src/threads/agent.service.ts` and calls `POST /reply` on the Agent.
- **Thread storage** is markdown-based in `data/threads/{userId}/{slug}/{YYYY-MM-DD}/thread.md`. Do not replace it with JSON files or Firestore.

What **must change**:

- `AgentService.reply()` must accept an A2UI reply and metadata instead of plain text.
- Add `POST /threads/:slug/tools/:toolCallId/confirm` to `ThreadsController`.
- Extend `ThreadsStore`/`thread-markdown.ts` to read/write A2UI content in agent message bodies.
- Add an `A2uiValidationService` to validate Agent replies before storage.
- `Thread` and `Message` entities need optional A2UI/metadata fields.

## 1. Modules to Create

The following modules already exist and should be preserved:

- `AuthModule`
- `UsersModule`
- `ThreadsModule`

Create or extend:

- `A2uiValidationService` (can live in `threads/` or a new `common/` module).
- Optional `AgentModule` if you want to extract `AgentService` from `threads/`.

> Note: Integrations (Calendar, Web Search, API) live inside the Agent service as OpenRouter tools, not backend modules. The backend only orchestrates confirmation, validates A2UI trees, and proxies tool execution requests to the Agent.

## 2. Authentication

### 2.1 Firebase Auth Guard

Already implemented in `server/src/auth/`.

- `FirebaseAuthGuard` reads the `Authorization: Bearer <id_token>` header.
- `FirebaseStrategy` uses Firebase Admin SDK to validate the token and optionally checks `ALLOWED_GOOGLE_EMAILS`.
- `CurrentUser` decorator exposes the decoded token.

No changes required for the core logic.

### 2.2 Users

Already implemented in `server/src/users/`.

- `POST /api/users/signup`: creates or updates the user document in Firestore.
- `GET /api/users/me`: returns the current user profile.

No changes required for the core logic.

## 3. Threads API

### 3.1 DTOs

Existing DTOs in `server/src/threads/dto/`:

```ts
// CreateThreadDto
{
  message: string;             // required, non-empty
}

// CreateMessageDto
{
  message: string;             // required, non-empty
}
```

Future DTOs:

```ts
// UpdateThreadDto
{
  status?: 'pending' | 'solved' | 'archived';
  title?: string;              // max 200 chars
}

// ConfirmToolDto
{
  confirmed: boolean;
  arguments?: Record<string, unknown>; // optional override of the original tool arguments
}
```

### 3.2 Controller Endpoints (`ThreadsController`)

Already implemented:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/threads` | List threads for the authenticated user, most recently updated first. |
| GET | `/api/threads/:slug` | Get one thread with all messages. |
| POST | `/api/threads` | Create a thread from an initial message and return it with the agent's reply. |
| POST | `/api/threads/:slug/messages` | Append a message and return the thread with the agent's reply. |

To add:

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/threads/:slug/tools/:toolCallId/confirm` | Confirm or reject a pending tool call. |
| PATCH | `/api/threads/:slug` | Update status or title (when lifecycle is added). |
| POST | `/api/threads/:slug/solve` | Mark thread as solved (when lifecycle is added). |

### 3.3 Service Responsibilities (`ThreadsService`)

Existing responsibilities (preserve):

- `create(userId, text)`:
  - Derive a unique slug from the message.
  - Generate a title from the message.
  - Write the first user message to today's markdown file.
  - Call `AgentService.reply({ userId, slug, message: text })`.
  - Write the agent's A2UI reply to the markdown file.
  - Return the thread.
- `addMessage(userId, slug, text)`:
  - Read the thread; throw `404` if not found.
  - Append the user message to the markdown file.
  - Call `AgentService.reply({ userId, slug, message: text })`.
  - Write the agent's A2UI reply to the markdown file.
  - Return the thread.
- `findAll(userId)`: list thread summaries, most recently updated first.
- `findOne(userId, slug)`: read one thread; throw `404` if not found.

Future responsibilities (when lifecycle is added):

- `update(slug, dto, userId)`: update status or title.
- `solve(slug, userId)`: mark status `solved`, append a system message.
- `reopen(slug, userId)`: mark status `pending`.

### 3.4 Repositories

#### `ThreadsStore` (already implemented)

- Located in `server/src/threads/threads.store.ts`.
- Reads and writes markdown day-files at `data/threads/{userId}/{slug}/{YYYY-MM-DD}/thread.md`.
- Methods: `exists`, `listSlugs`, `read`, `readAllSummaries`, `append`.
- Ownership is enforced by the `userId` folder segment; no Firestore involvement for threads.

#### `thread-markdown.ts` (already implemented)

- Located in `server/src/threads/thread-markdown.ts`.
- `serializeThreadDay(title, messages)` and `parseThreadDay(markdown)` handle the on-disk format.
- `slugify(text)`, `titleFrom(text)`, `messageId(role, createdAt)`, and `dayFolder(date)` are already implemented.

Changes needed:

- `parseThreadDay` should detect A2UI JSON in agent message bodies and populate `MessageMetadata.contentType = 'a2ui'`.
- `serializeThreadDay` should write A2UI JSON for agent messages when metadata indicates it.
- Consider a sidecar file or YAML front-matter for `pendingToolCall` metadata if it cannot be embedded cleanly in markdown.

## 4. Tool Confirmation

### 4.1 DTO

```ts
// ConfirmToolDto
{
  confirmed: boolean;
  arguments?: Record<string, unknown>; // optional override of the original tool arguments
}
```

### 4.2 Controller Endpoint

Add to `ThreadsController`:

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/threads/:slug/tools/:toolCallId/confirm` | Confirm or reject a pending tool call. |

### 4.3 Service Responsibility

- `confirmTool(slug, toolCallId, dto, userId)`:
  - Find the pending tool call stored alongside the A2UI confirmation message.
  - If confirmed, call `AgentService.executeTool({ userId, slug, toolCall })`.
  - Validate the returned A2UI message via `A2uiValidationService`.
  - Append the final A2UI message to the markdown file.
  - If rejected, append a system A2UI message (`Text` component) indicating the action was cancelled and optionally trigger a new agent reply.

## 5. Agent Integration

### 5.1 Agent Service (`server/src/threads/agent.service.ts`)

Already exists. Update it to:

- Read `AGENT_URL` from config (default `http://localhost:3001`).
- Timeout: 60 seconds for `/reply`, 30 seconds for `/execute-tool` (configurable via env).
- Methods:
  - `reply(context: { userId, slug, message }): Promise<AgentReplyPayload>` → `POST /reply`
  - `executeTool(context: { userId, slug, toolCall }): Promise<AgentReplyPayload>` → `POST /execute-tool`

```ts
interface AgentReplyPayload {
  a2ui: A2uiComponent;         // Always present.
  pendingToolCall?: ToolCall;  // Present when confirmation is required.
  solved?: boolean;
  metadata: {
    model: string;
    latencyMs: number;
  };
}
```

- `reply(context)`:
  - Call `POST http://focus-agent:3001/reply` with `{ userId, slug, message }`.
  - The Agent reads the thread markdown files from its read-only mount.
  - Validate the returned A2UI tree via `A2uiValidationService`.
  - Return the payload to `ThreadsService` for storage.
- `executeTool(context)`:
  - Call `POST http://focus-agent:3001/execute-tool` with `{ userId, slug, toolCall }`.
  - Validate the returned A2UI tree.
  - Return the payload to `ThreadsService` for storage.
- Handle agent failures: return a fallback A2UI payload (`Text` component) so `ThreadsService` can store it.

## 6. Integrations

The backend does not implement integration adapters. All integration execution happens inside the Agent container via OpenRouter tools. The backend's responsibility is:

- Validate that every A2UI tree returned by the Agent uses only allowed components.
- Validate that tool actions in A2UI components reference allowed tool names.
- Store A2UI messages and pending tool calls.
- Proxy confirmed tool calls to `POST http://focus-agent:3001/execute-tool`.
- Never expose integration secrets (Calendar API keys, Web Search keys, etc.) in environment variables or logs.

## 7. Firestore Rules

Backend uses Firebase Admin SDK, so Firestore security rules are a secondary safety net. Only `users` are stored in Firestore. Keep them restrictive:

```
match /users/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

Threads and messages are stored as markdown files in `/app/data/threads/`; ownership is enforced by the `userId` folder segment.

## 8. Environment Variables

Existing environment variables (already in use):

```
PORT=3000
AGENT_URL=http://focus-agent:3001
FOCUS_DATA_DIR=/app/data/threads
ALLOWED_GOOGLE_EMAILS=
```

`GOOGLE_APPLICATION_CREDENTIALS` is set outside `.env` via the host mount in `docker-compose.yml`.

Add/update:

```
AGENT_REPLY_TIMEOUT_MS=60000
AGENT_EXECUTE_TOOL_TIMEOUT_MS=30000
```

> Do not add Calendar, Web Search, or API integration secrets here. Those belong only in `agent/.env.production`.

## 9. Tests

- Unit tests for `ThreadsService` and `AgentService` using mocked `ThreadsStore` and fetch mocks.
- Mock `AgentService.executeTool` to verify tool confirmation flow.
- Extend existing `thread-markdown.spec.ts` and `threads.store.spec.ts` to cover A2UI message serialization/parsing.
- E2E tests for the new `POST /api/threads/:slug/tools/:toolCallId/confirm` endpoint with a temp data directory.
- Verify that users cannot access threads they do not own.
- Verify that integration secrets are not loaded or logged by the backend.
- Verify that every agent reply contains a valid `a2ui` field.
