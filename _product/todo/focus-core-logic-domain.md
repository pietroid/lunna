# Focus: Core Logic — Domain Layer

This document defines the domain entities, value objects, lifecycle rules, and invariants that must be implemented in code. It is backend-agnostic but must be mirrored in the NestJS backend, the Express agent, and the Flutter app.

## 0. Current State & What to Preserve

- **`Thread`** already exists in `server/src/threads/entities/thread.entity.ts` and `app/packages/chat/lib/src/models/thread.dart` as a slug-based, file-backed entity. Do not replace it with a UUID/Firestore model.
- **`Message`** already exists in `server/src/threads/entities/message.entity.ts` and `app/packages/chat/lib/src/models/chat_message.dart` with `role` and `text`. Extend it to support A2UI content; do not delete the text field because user messages still use it.
- **Thread storage** is already implemented as markdown day-files in `server/src/threads/threads.store.ts` and `server/src/threads/thread-markdown.ts`. Preserve the layout and extend serialization to store A2UI JSON inside agent message bodies.
- **Users** are already stored in Firestore via `server/src/users/users.service.ts`. The domain shape is slightly different from the example below; align with the existing `User` entity.
- **Thread lifecycle** (`pending`/`solved`/`archived`) and TODO/source metadata do not exist yet.

## 1. Thread

### 1.1 Entity

Existing shape (preserve):

```ts
interface Thread {
  slug: string;             // Derived from the first message; folder name on disk
  title: string;            // Auto-generated from the first message
  messages: Message[];
  createdAt: Date;
  updatedAt: Date;
}
```

Future additions (not yet implemented):

```ts
enum ThreadStatus {
  Pending = 'pending',
  Solved = 'solved',
  Archived = 'archived',
}

interface ThreadMetadata {
  status: ThreadStatus;     // default 'pending'
  source: 'todo' | 'agent_prompt' | 'manual'; // default 'agent_prompt'
  tags: string[];
}
```

### 1.2 Invariants

- A thread is always owned by exactly one user (enforced by the `userId` folder segment in the filesystem path).
- The thread `slug` is derived from the first user message and must be unique per user.
- `status` (when added) may transition from `pending` to `solved` or `archived`.
- `solved` and `archived` threads do not appear in the default inbox.
- `updatedAt` is updated on every new message.
- `title` is generated from the first user message (truncated to 60 characters in the existing code).

### 1.3 Lifecycle

```
[User creates thread]
        │
        ▼
    pending
        │
        ├─── agent replies / user messages loop
        │
        ├─── PATCH status=solved
        │       │
        ▼       ▼
      solved  archived
```

## 2. Message

### 2.1 Entity

Existing shape (preserve):

```ts
export type MessageRole = 'user' | 'agent';

interface Message {
  id: string;               // `${role}-${createdAt.getTime()}`
  role: MessageRole;
  text: string;             // The raw body as written in the markdown file
  createdAt: Date;
}
```

Extended shape for A2UI:

```ts
interface Message {
  id: string;
  role: MessageRole | 'system';
  text: string;             // Raw markdown body; for agent messages this may contain JSON
  createdAt: Date;
  metadata?: MessageMetadata;
}

interface MessageMetadata {
  contentType: 'text' | 'a2ui';
  model?: string;           // For agent messages (e.g., OpenRouter model name)
  latencyMs?: number;       // Time spent generating the reply
  pendingToolCall?: ToolCall; // Present when an agent message asks for tool confirmation
}
```

### 2.2 Rules

- Every message belongs to exactly one thread.
- User messages use `content.type === 'text'` and `content.text`.
- Agent and system messages use `content.type === 'a2ui'` and `content.a2ui`.
- **There are no plain-text agent replies.** All text displayed by the Agent must be inside a `Text` component within the A2UI tree.
- A system message (e.g., "Thread marked as solved") is an A2UI tree containing a `Text` component.
- If an agent message requests tool confirmation, `metadata.pendingToolCall` contains the tool call details.

## 3. A2UI Component

```ts
interface A2uiComponent {
  component: ComponentName;
  // component-specific props, plus optional children/actions
}
```

Rules:

- The catalog uses a **flat discriminator** (A2UI v0.9): `{"component": "Text", "text": "Hello"}` instead of nested keys.
- The root component is typically a `Column` or `Row`.
- Interactive components may include an `action` prop (see §4).
- The A2UI tree is validated against the catalog schema before storage and before rendering.

### 3.1 Core Catalog

| Component | Source | Purpose |
|-----------|--------|---------|
| `Column` | Flutter primitive | Vertical layout. |
| `Row` | Flutter primitive | Horizontal layout. |
| `Spacer` | Flutter primitive | Flexible or fixed spacing. |
| `Text` | Flutter primitive | Display text. **Required for any text output.** |
| `Icon` | Flutter primitive | Display an app icon by name. |
| `Image` | Flutter primitive | Display an image from a URL. |
| `AppButton` | `app_ui` | Primary/secondary/text button. |
| `AppIconButton` | `app_ui` | Icon-only button. |

## 4. Actions

Components can declare an `action` that the app handles when the user interacts with them.

```ts
interface A2uiAction {
  type: 'tool' | 'reply' | 'dismiss' | 'openUrl';
  // type-specific fields
}
```

- `tool`: triggers an Agent tool. May include `requiresConfirmation: true`.
- `reply`: sends a pre-filled user message.
- `dismiss`: closes transient UI without sending anything.
- `openUrl`: opens a URL.

## 5. Tool Call

OpenRouter tool call representation:

```ts
interface ToolCall {
  id: string;
  type: 'function';
  function: {
    name: string;
    arguments: string; // JSON-encoded arguments
  };
}
```

Allowed tools:

- `web_search`
- `calendar_check_availability`
- `calendar_create_event`
- `api_call`

Rules:

- Tool execution happens inside the Agent container.
- Read-only tools are executed automatically inside the Agent's tool loop.
- Write/sensitive tools require user confirmation; the Agent pauses and returns an A2UI confirmation UI + `pendingToolCall`.
- The backend stores `pendingToolCall` and proxies confirmation to `POST /execute-tool`.

## 6. User

A thin domain wrapper around Firebase Auth. No local password storage.

Existing shape in the backend (`server/src/users/entities/user.entity.ts`):

```ts
interface User {
  uid: string;              // Firebase UID
  name?: string;
  email?: string;
  photoUrl?: string;
  signupDate: Date;
}
```

Existing shape in the app (`app/packages/auth/lib/src/models/app_user.dart`):

```dart
class AppUser {
  final String id;
  final String? name;
  final String? email;
  final String? photoUrl;
}
```

Future additions:

```ts
interface UserPreferences {
  defaultThreadMode: 'todo' | 'ask_agent';
  timezone: string;
}
```

## 7. Agent Configuration

```ts
interface AgentConfig {
  agentId: string;
  name: string;
  model: string;            // OpenRouter model identifier
  systemPrompt: string;
  allowedTools: string[];   // e.g., ['web_search', 'calendar_create_event']
  allowedComponents: ComponentName[];
}
```

Rules:

- The backend may support multiple agent configs in the future, but v1 can use a single default agent.
- The agent service uses this config to build prompts and validate replies.

## 8. Storage Mapping

### Firestore collections

- `users/{userId}` — user profile (already implemented in `server/src/users/users.service.ts`).
- `agentConfigs/{agentId}` — future; agent configuration currently lives in environment variables.

### Filesystem

Thread messages are stored as markdown day-files on disk (already implemented):

```
/app/data/threads/{userId}/{slug}/{YYYY-MM-DD}/thread.md
```

Example file content:

```markdown
# Buy milk tomorrow

## user @ 2026-09-15T19:23:04.123Z

Buy milk tomorrow

## agent @ 2026-09-15T19:23:05.456Z

{"a2ui":{"component":"Text","text":"Noted."}}
```

Rules:

- The backend is the only writer of `/app/data/threads/`.
- The Agent container mounts `/app/data/threads/` as read-only.
- User messages are stored as plain text in the markdown body.
- Agent messages store A2UI JSON in the markdown body.
- Message IDs are derived from `role` + `createdAt.getTime()`; sorting is done by timestamp after parsing all day files.
- Thread summaries are computed by reading all day files; there is no separate metadata index.

## 9. Validation Rules to Enforce in Code

1. `Thread.ownerId` must equal the authenticated user's UID for all reads/writes.
2. `Message.slug` must reference an existing thread folder owned by the same user.
3. A message cannot be added to a `solved` or `archived` thread unless the thread is reopened first.
4. Agent replies are only generated for threads in `pending` status.
5. Every agent message must have `content.type === 'a2ui'` and a valid `content.a2ui` tree.
6. Every component in an A2UI tree must be in the configured agent's `allowedComponents` list.
7. Every tool referenced by an A2UI `tool` action must be in the configured agent's `allowedTools` list.
