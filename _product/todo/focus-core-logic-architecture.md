# Focus: Core Logic — Architecture

This document defines the software architecture that implements the product ideas described in `focus-core-logic.md`. It is intended to guide implementation across the Flutter app, NestJS backend, and Express agent.

## 0. Current State & What to Preserve

A lot of the architecture already exists in the repo. Treat the sections below as the target shape, but **do not re-implement** the following:

- **Backend auth**: `FirebaseAuthGuard`, `FirebaseStrategy`, `CurrentUser` decorator, and allowed-email logic already exist in `server/src/auth/`.
- **Backend users**: `UsersController` (`POST /users/signup`, `GET /users/me`) and `UsersService` already exist in `server/src/users/`.
- **Backend threads**: `ThreadsController`, `ThreadsService`, and `ThreadsStore` already exist in `server/src/threads/`. The store uses a markdown-based layout, not JSON files or Firestore.
- **Backend agent client**: `AgentService` already exists in `server/src/threads/agent.service.ts`; it only needs to accept an A2UI reply and a confirmation endpoint.
- **App auth**: `AuthRepository`, `AuthBloc`, and `AuthScreen` already exist in `app/packages/auth/`.
- **App API client**: `ApiClient`, `TokenProvider`, and `AuthInterceptor` already exist in `app/packages/api_client/`.
- **App routing & screens**: `App` router (`/`, `/chat`, `/chat/:slug`, `/auth`), `HomePage`, and `ChatPage` already exist.
- **App state management**: `ChatBloc`, `ThreadsBloc`, `ChatRepository`, and `UserRepository` already exist in `app/packages/chat/` and `app/packages/user/`.
- **App UI catalog**: `AppButton`, `AppIconButton`, `AppIcon`, `AppIcons`, `AppTextField`, `AppSkeleton`, theme, spacing, and colors already exist in `app/packages/app_ui/`.

What **must change**:

- The Agent must stop returning plain text and return A2UI trees.
- The Agent must add OpenRouter tool calling for integrations.
- The backend must store and forward A2UI messages and pending tool calls.
- The app must render A2UI trees inside `AgentMessage` and handle A2UI actions.
- Thread lifecycle (pending/solved/archived) does not exist yet.

## 1. System Context

Focus has three runnable parts (see `AGENTS.md`):

| Part | Technology | Responsibility |
|------|------------|----------------|
| App | Flutter + BLoC + go_router + `genui` | User interface: inbox, thread detail, auth, A2UI rendering. |
| Backend | NestJS + Firebase Admin | Public REST API, Firestore persistence, Firebase Auth verification, agent orchestration, A2UI validation. |
| Agent | Express + TypeScript | Internal LLM service + integration executor. Generates A2UI replies and executes tools via OpenRouter. |
| Infrastructure | Firestore, Firebase Auth, Docker, nginx | Data, identity, hosting, routing. |

Communication rules:

- App ↔ Backend: HTTPS/REST over `/api/` (proxied by nginx).
- Backend ↔ Agent: internal HTTP at `http://focus-agent:3001` inside the Docker network.
- Backend ↔ Firestore: via Firebase Admin SDK (users only).
- Backend ↔ Filesystem: writes thread message markdown files to `/app/data/threads/{userId}/{slug}/{YYYY-MM-DD}/thread.md`.
- App ↔ Firebase Auth: client-side sign-in (Google Sign-In), ID tokens sent to backend on every request.
- Agent ↔ OpenRouter: outbound HTTPS to generate replies.
- Agent ↔ External APIs: outbound HTTPS to Calendar, Web Search, and configured third-party APIs.
- Agent ↔ Filesystem: read-only mount of `/app/data/threads/` to build thread context.

## 2. Core Concept: Threads

A **thread** is the central domain entity. It represents an open item in the user's mind that should eventually be **solved/closed**.

Key architectural implications:

- Every visible item on the Home page is a thread (including legacy TODO-list items).
- A thread has a lifecycle: `pending` → `solved` (with possible `archived`).
- A thread contains ordered messages.
- Threads are owned by a user.
- Agents participate in threads by adding messages, but they do so to drive the thread toward resolution, not just to chat.

## 3. High-Level Layers

### 3.1 Backend Layers

```
Controllers (HTTP /api/*)
    │
Application Services (ThreadsService, AgentService)
    │
Domain Layer (entities, value objects, thread lifecycle rules)
    │
Repositories (Firestore adapter for users, markdown filesystem adapter for threads)
    │
Infrastructure (Firebase Admin SDK, filesystem, HTTP client to Agent, Docker)
```

### 3.2 Frontend Layers

```
Presentation (HomePage, ChatPage, AuthScreen, Widgets)
    │
State Management (BLoC: AppBloc, ThreadsBloc, ChatBloc, AuthBloc)
    │
Domain / Models (Thread, ChatMessage, AppUser, A2uiComponent)
    │
Data Layer (ChatRepository, UserRepository, AuthRepository)
    │
Infrastructure (ApiClient/Dio, Firebase Auth, app_ui catalog)
```

### 3.3 Agent Layers

```
HTTP Routes (/reply, /execute-tool)
    │
Thread Context Builder (reads /app/data/threads) / Tool Executor
    │
Prompt Assembler (system prompt + A2UI catalog + tool schemas)
    │
OpenRouter Client (tool calling)
    │
Tool Loop Orchestrator
    │
A2UI Validator
    │
Tool Implementations (Calendar, Web Search, API)
```

## 4. Data Flows

### 4.1 Create a Thread (TODO, no instant agent reply)

1. User types text in Home input and chooses "Add as TODO" (when TODO mode is added).
2. App posts `POST /api/threads` with `{ message }` and a TODO source flag.
3. Backend derives a slug, creates the thread folder, and writes the user message to the markdown file.
4. Backend returns the thread (no agent reply for TODOs).
5. App adds the thread to the inbox.

### 4.2 Create a Thread with Agent Reply

1. User types text on the home screen and submits.
2. App navigates to `/chat` with the initial message and posts `POST /api/threads` with `{ message }`.
3. Backend derives a slug from the message, creates the thread folder, and writes the initial message to `/app/data/threads/{userId}/{slug}/{YYYY-MM-DD}/thread.md`.
4. Backend calls `POST http://focus-agent:3001/reply` with `{ userId, slug, message }`.
5. Agent reads the thread markdown files from its read-only mount at `/app/data/threads/{userId}/{slug}`.
6. Agent calls OpenRouter with the A2UI catalog and tool definitions.
7. Agent runs the tool loop: executes safe tools directly, pauses for confirmation on write tools.
8. Agent returns a final A2UI component tree (and a `pendingToolCall` if confirmation is needed).
9. Backend validates and writes the agent A2UI message to the same markdown file.
10. Backend returns the thread with messages to the app.

### 4.3 User Sends a Follow-Up

1. App posts `POST /api/threads/{slug}/messages` with `{ message }`.
2. Backend appends the message to today's markdown file for the thread.
3. Backend calls the Agent's `/reply` endpoint with `{ userId, slug, message }` (if the thread is not solved).
4. Agent reads the updated thread files and runs the OpenRouter tool loop.
5. Backend validates and writes the agent A2UI message to the markdown file.
6. Backend returns the thread with messages to the app.

### 4.4 Tool Confirmation Flow

1. The Agent's `/reply` returns an A2UI confirmation UI and a `pendingToolCall`.
2. Backend appends the A2UI message to the markdown file and stores the pending tool call alongside it (e.g., in the message metadata or a sidecar file).
3. App renders the A2UI confirmation UI.
4. User confirms; app calls `POST /api/threads/{slug}/tools/{toolCallId}/confirm`.
5. Backend forwards the confirmation to `POST http://focus-agent:3001/execute-tool`.
6. Agent executes the tool, feeds the result back to OpenRouter, and returns the final A2UI response.
7. Backend appends the final A2UI response to the markdown file.

### 4.5 Solve a Thread

1. User marks thread as solved (manually or via agent suggestion).
2. App calls `PATCH /api/threads/{slug}` with `{ status: "solved" }` or `POST /api/threads/{slug}/solve`.
3. Backend validates, updates the thread, possibly appends a system message.
4. Solved threads are filtered from the default inbox but accessible in history.

## 5. Integration Points

All integrations live inside the Agent layer and are exposed to the LLM as OpenRouter tools. The backend does not execute integrations; it orchestrates confirmation, stores A2UI messages, and proxies user confirmations to the Agent.

| Tool | Location | Purpose | Confirmation |
|------|----------|---------|--------------|
| `web_search` | Agent | Search the web for current information. | No |
| `calendar_check_availability` | Agent | Check free/busy times on the user's calendar. | No |
| `calendar_create_event` | Agent | Create a calendar event. | Yes |
| `api_call` | Agent | Call a configured third-party API. | Yes by default; read-only endpoints can be whitelisted. |

Flow:

1. Agent calls OpenRouter with the thread context and tool definitions.
2. The model may request one or more tool calls.
3. Read-only/safe tools are executed immediately inside the Agent's tool loop.
4. Write/sensitive tools pause the loop; the Agent returns an A2UI confirmation UI + `pendingToolCall`.
5. The app asks the user for confirmation.
6. When confirmed, the backend calls the Agent's `/execute-tool` endpoint.
7. The Agent executes the tool, feeds the result back to OpenRouter, and returns the final A2UI response.
8. The backend stores the final A2UI response.

## 6. A2UI Flow

1. Agent returns a message whose content is an A2UI component tree (`a2ui` field).
2. Backend validates the A2UI tree against the catalog schema.
3. App receives the message and renders the component tree using `genui` or a custom renderer.
4. User interacts with the component (e.g., taps an `AppButton`).
5. App handles the action locally (`openUrl`, `dismiss`) or sends it to the backend (`reply`, `tool`).
6. For tool actions requiring confirmation, the app shows a confirmation UI before calling the backend.

## 7. Non-Functional Requirements

- All endpoints require a valid Firebase ID token.
- Threads and messages are scoped per user; a user can only access their own data.
- Agent container has no public port and read-only access to thread data at `/app/data/threads/`.
- Backend must handle OpenRouter failures and Agent tool execution failures gracefully, returning a fallback A2UI message.
- Agent secrets for OpenRouter, Calendar, Web Search, and API integrations must be injected via environment variables and never exposed to the backend or app.
- Thread messages are stored as markdown files in `/app/data/threads/{userId}/{slug}/{YYYY-MM-DD}/thread.md`; the backend owns writes, the Agent owns reads.
- Every Agent reply must be a valid A2UI tree; plain-text replies are not allowed.
- App must work on iOS, Android, and Web from a single codebase.
- Docker images are built for `linux/arm64` and deployed to the Raspberry Pi.

## 8. File Organization

```
server/
  src/
    auth/                            # already exists
    users/                           # already exists
    threads/
      threads.controller.ts          # already exists; extend with tool-confirm endpoint
      threads.service.ts             # already exists; extend to write A2UI messages
      threads.store.ts               # already exists; extend to read/write A2UI markdown
      thread-markdown.ts             # already exists; extend parsing/serialization
      agent.service.ts               # already exists; extend payload and add executeTool
      dto/
      entities/
    agent/                           # optional refactor of agent-client.service.ts

agent/
  src/
    main.ts                          # already exists
    server.ts                        # already exists; extend /reply, add /execute-tool
    reply.ts                         # already exists; replace with tool loop + A2UI output
    thread-store.ts                  # already exists; extend if needed
    services/                        # new folder if reply.ts grows too large
      openrouter.service.ts
      tool-loop.service.ts
      a2ui-validation.service.ts
      tool-executor.service.ts
      tool-registry.service.ts
      tools/
        web-search.tool.ts
        calendar.tool.ts
        api-call.tool.ts
    prompts/
      system-prompt.txt
      a2ui-catalog.txt

app/
  lib/
    main.dart                        # already exists
    app/view/app.dart                # already exists
    home/view/home_page.dart         # already exists
    packages/
      api_client/                    # already exists
      app_ui/                        # already exists
      auth/                          # already exists
      user/                          # already exists
      chat/
        src/
          data/chat_repository.dart  # already exists; extend for tool confirmation
          bloc/chat_bloc.dart        # already exists; extend for A2UI actions
          bloc/threads_bloc.dart     # already exists
          models/chat_message.dart   # already exists; extend for A2UI content
          view/chat_page.dart        # already exists
          view/threads_section.dart  # already exists
          widgets/
            agent_message.dart       # already exists; replace text with A2UI renderer
            chat_bubble.dart         # already exists
            chat_composer.dart       # already exists
            thread_tile.dart         # already exists
            a2ui_renderer.dart       # new
```
