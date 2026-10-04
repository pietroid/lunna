# Focus: Core Logic — Implementation Task Breakdown

This document breaks the implementation of the Focus core logic into concrete, deliverable tasks. Each task references the architecture, domain, backend, agent, frontend, and A2UI documents.

> **Note:** Most foundation code already exists. Tasks below that are already done are marked with ~~strikethrough~~; do not redo them.

## Phase 1: Foundation

### Backend

- ~~Initialize NestJS project structure under `server/` with modules: `Auth`, `Users`, `Threads`.~~
- [ ] Ensure integration secrets are not present in `server/.env` files.
- ~~Implement `FirebaseAuthGuard` and attach user to requests.~~
- [ ] Define Firestore collections for `users` (already implemented) and future `agentConfigs`.
- [ ] Document filesystem layout: thread messages are markdown day-files at `/app/data/threads/{userId}/{slug}/{YYYY-MM-DD}/thread.md`.
- [ ] Extend domain entities `Thread`, `Message` to support A2UI/metadata.
- ~~Implement `UsersController` with `GET /api/users/me` and `POST /api/users/signup`.~~

### Frontend

- ~~Set up Flutter project structure under `app/packages/`.~~
- ~~Add dependencies: `firebase_auth`, `google_sign_in`, `dio`, `flutter_bloc`, `go_router`.~~
- [ ] Add `genui` dependency (or decide on a custom renderer).
- [ ] Extend Dart domain models (`ChatMessage`) to support A2UI content.
- ~~Configure `env/production.json` and `.env.example` entries.~~

### Agent

- ~~Initialize Express TypeScript project under `agent/`.~~
- [ ] Add OpenRouter tool calling support.
- [ ] Define request/response types for `POST /reply` (existing contract) and `POST /execute-tool`.
- [ ] Scaffold OpenRouter tool definitions for `web_search`, `calendar_check_availability`, `calendar_create_event`, `api_call`.
- [ ] Define A2UI component catalog using flat discriminator format.

## Phase 2: Threads and Messages CRUD

### Backend

- ~~Implement `ThreadsStore` with markdown filesystem read/write.~~
- ~~Implement `ThreadsController` endpoints:~~
  - ~~`GET /api/threads`~~
  - ~~`POST /api/threads`~~
  - ~~`GET /api/threads/:slug`~~
  - ~~`POST /api/threads/:slug/messages`~~
- [ ] Extend `ThreadsController` with lifecycle endpoints (when lifecycle is added):
  - `PATCH /api/threads/:slug`
  - `POST /api/threads/:slug/solve`
  - `POST /api/threads/:slug/reopen`
- [ ] Add `POST /api/threads/:slug/tools/:toolCallId/confirm`.
- ~~Enforce ownership checks on all endpoints via `userId` folder segment.~~
- [ ] Write unit tests for A2UI message serialization in `thread-markdown.ts`.

### Frontend

- ~~Implement `ChatRepository`.~~
- ~~Implement `AuthBloc`, `ThreadsBloc`, `ChatBloc`.~~
- ~~Implement `AuthScreen`.~~
- ~~Implement `HomePage` with thread list and create-thread input.~~
- ~~Implement `ChatPage` with message list and send-message input.~~
- ~~Configure `go_router` routes.~~

## Phase 3: Agent Reply Loop

### Agent

- [ ] Write `system-prompt.txt` with Focus identity, A2UI-only output rules, and tool usage instructions.
- [ ] Write `a2ui-catalog.txt` describing the flat-discriminator component catalog.
- [ ] Extend `thread-store.ts` to parse A2UI JSON from agent message bodies.
- [ ] Add prompt assembly in `reply.ts` (or a new `prompts/` folder) combining system prompt, A2UI catalog, tool schemas, and history.
- [ ] Implement OpenRouter tool calling support in `reply.ts`.
- [ ] Implement tool loop to handle tool calls and confirmation pauses.
- [ ] Implement `A2uiValidationService` to validate every emitted A2UI tree.
- [ ] Extend `POST /reply` in `server.ts` to return A2UI JSON.
- [ ] Implement fallback A2UI response for OpenRouter failures.
- [ ] Add unit tests for context builder, A2UI validator, and tool loop.

### Backend

- [ ] Extend `AgentService` in `server/src/threads/agent.service.ts` to parse A2UI reply and call `/execute-tool`.
- [ ] Add `A2uiValidationService` in the backend to validate A2UI trees.
- [ ] Extend `ThreadsService` to write A2UI agent replies to markdown.
- [ ] Trigger agent reply on thread creation (already happens; just ensure A2UI output).
- [ ] Trigger agent reply on new user message (already happens; just ensure A2UI output).
- [ ] Handle agent failures with a fallback A2UI system message.

### Frontend

- [ ] Update `AgentMessage` widget to render A2UI trees.
- [ ] Show loading indicator while waiting for agent reply (already implemented via `AgentMessageSkeleton`).
- [ ] Handle solve/reopen actions from the thread menu (when lifecycle is added).

## Phase 4: A2UI Rendering

### All Layers

- [ ] Define the core A2UI catalog: `Column`, `Row`, `Spacer`, `Text`, `Icon`, `Image`, `AppButton`, `AppIconButton`.
- [ ] Implement JSON schemas for each component using flat discriminator format.

### Agent

- [ ] Add `A2uiValidationService` to validate emitted A2UI trees.
- [ ] Update system prompt to require A2UI output and wrap all text in `Text` components.

### Backend

- [ ] Add backend `A2uiValidationService`.
- [ ] Validate agent replies against the catalog before storage.
- [ ] Extend `thread-markdown.ts` to read/write A2UI JSON in agent message bodies.

### Frontend

- [ ] Add `genui` (or custom A2UI renderer) dependency.
- [ ] Implement `A2uiRenderer` in `app/packages/chat/lib/src/widgets/a2ui_renderer.dart`.
- [ ] Map `AppButton` to the existing `AppButton` widget and `AppIconButton` to `AppIconButton`.
- [ ] Map `Icon` names to `AppIconData` via the existing `AppIcons` catalog.
- [ ] Wire component actions (`tool`, `reply`, `dismiss`, `openUrl`) back to `ChatBloc`.

## Phase 5: Tools and Integrations

### Agent

- [ ] Implement `ToolImplementation` interface with `requiresConfirmation` flag.
- [ ] Implement `web_search` tool.
- [ ] Implement `calendar_check_availability` tool.
- [ ] Implement `calendar_create_event` tool (requires confirmation).
- [ ] Implement `api_call` tool (requires confirmation by default; read-only whitelist configurable).
- [ ] Implement `ToolRegistryService` to look up tools by name.
- [ ] Implement `ToolExecutorService` to run tools and return results.
- [ ] Add `POST /execute-tool` route in `agent/src/server.ts`.
- [ ] Update system prompt to describe tool usage and confirmation rules.
- [ ] Validate tool names against allowed list.

### Backend

- [ ] Implement `POST /api/threads/:slug/tools/:toolCallId/confirm` in `ThreadsController`.
- [ ] In `ThreadsService.confirmTool`, forward confirmed tool calls to the Agent's `/execute-tool` endpoint via `AgentService`.
- [ ] Store A2UI messages returned by the Agent after tool execution.

### Frontend

- [ ] Detect A2UI `tool` actions with `requiresConfirmation: true`.
- [ ] Show confirmation UI before sending the tool call to the backend.
- [ ] Add `ChatRepository.confirmTool` and `ChatBloc` event.
- [ ] Render the final A2UI response after tool execution.

## Phase 6: TODO List Disguise and Polish

### Backend

- [ ] Support `source: 'todo'` on thread creation.
- [ ] Ensure TODO threads behave like regular threads but without agent reply by default.

### Frontend

- [ ] Add "Add TODO" action to the Home input bar.
- [ ] Add filter chips for `pending`, `solved`, `all`.
- [ ] Add swipe actions to solve/archive threads from the inbox.

### Product

- [ ] Review whether the legacy TODO-list behavior is sufficiently preserved or needs a dedicated UI.

## Phase 7: Deployment and DevEx

### All

- [ ] Update `server/.env.example` and `agent/.env.example` with new timeout/URL variables.
- ~~Ensure Dockerfiles for backend and agent build for `linux/arm64`.~~
- ~~Update `docker-compose.yml` to include `focus-backend`, `focus-agent`, and `focus-web`.~~
- ~~Add a shared Docker volume for `/app/data/threads` mounted read-write on `focus-backend` and read-only on `focus-agent`.~~
- [ ] Verify Flutter web deploy script works end-to-end.
- [ ] Update `AGENTS.md` if deployment or environment instructions changed.

## Acceptance Criteria

- A signed-in user can create a thread, receive an agent reply, send follow-ups, and mark the thread as solved.
- Every Agent reply is a valid A2UI component tree; plain-text replies are never returned.
- The Agent uses OpenRouter tool calling for Calendar, Web Search, and API integrations.
- Write/sensitive tools require user confirmation; read-only tools execute automatically inside the Agent.
- Integration secrets (Calendar, Web Search, API keys) are loaded only by the Agent.
- Thread messages are stored as markdown files in `/app/data/threads/{userId}/{slug}/{YYYY-MM-DD}/thread.md`; the backend writes them and the Agent reads them read-only.
- Users can only access their own threads and messages.
- The app works on Web, iOS, and Android.
- All services run in Docker on the Raspberry Pi as described in `AGENTS.md`.
