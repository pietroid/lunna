# Focus: Core Logic — Frontend Implementation

This document specifies the Flutter frontend (`app/`) implementation needed to support the Focus core logic.

## 0. Current State & What to Preserve

- The app is organized as a set of packages under `app/packages/`: `api_client`, `app_ui`, `auth`, `chat`, `user`. Do not move these into `app/lib/features/`.
- **`main.dart`**, **`App` router**, **`HomePage`**, **`AuthScreen`**, and **`ChatPage`** already exist. Do not recreate them.
- **`AuthRepository`**, **`AuthBloc`**, **`ChatRepository`**, **`ChatBloc`**, **`ThreadsBloc`**, **`UserRepository`**, and **`ApiClient`** already exist. Extend them; do not rewrite.
- **`ChatComposer`**, **`ChatBubble`**, **`AgentMessage`**, **`AgentMessageSkeleton`**, **`ThreadTile`**, and **`ThreadsSection`** already exist.
- The **`app_ui`** catalog (`AppButton`, `AppIconButton`, `AppIcon`, `AppIcons`, `AppTextField`, `AppSkeleton`, theme, spacing, colors) already exists.

What **must change**:

- `ChatMessage` model must support A2UI content for agent messages.
- `AgentMessage` widget must render A2UI trees instead of plain text.
- `ChatRepository` must add a `confirmTool` method.
- `ChatBloc` must handle A2UI actions (tool, reply, dismiss, openUrl).
- Add an `A2uiRenderer` widget in `app/packages/chat/lib/src/widgets/`.

## 1. Package Layout

Use the existing package structure:

```
app/packages/
  api_client/       # already exists
  app_ui/           # already exists
  auth/             # already exists
  user/             # already exists
  chat/             # extend this package
    src/
      data/chat_repository.dart
      bloc/chat_bloc.dart
      bloc/threads_bloc.dart
      models/chat_message.dart
      view/chat_page.dart
      view/threads_section.dart
      widgets/
        agent_message.dart
        chat_bubble.dart
        chat_composer.dart
        thread_tile.dart
        a2ui_renderer.dart   # new
```

## 2. Authentication

Already implemented in `app/packages/auth/`.

### 2.1 AuthRepository

- `FirebaseAuthRepository` uses `firebase_auth` and `google_sign_in`.
- Exposes `Stream<AppUser?>` and `currentUser`.
- `ApiClient` retrieves tokens via `_AuthTokenProvider` in `main.dart`.

### 2.2 AuthBloc

- Manages `AuthStatus` and calls `onUserAuthenticated` (which triggers `UserRepository.signUpUserIfNeeded`).

No changes required for the core logic.

## 3. Domain Models (Frontend)

Existing models in `app/packages/chat/lib/src/models/`:

```dart
class Thread {
  final String slug;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ThreadSummary {
  final String slug;
  final String title;
  final String preview;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum MessageRole { user, agent }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String text;
  final DateTime createdAt;
}
```

Extend `ChatMessage` to support A2UI:

```dart
class ChatMessage {
  final String id;
  final MessageRole role;
  final String text;             // Raw body; for agent messages may contain JSON
  final DateTime createdAt;
  final ChatMessageMetadata? metadata;
}

class ChatMessageMetadata {
  final MessageContentType contentType;
  final A2uiComponent? a2ui;
  final PendingToolCall? pendingToolCall;
  final String? model;
  final int? latencyMs;
}

enum MessageContentType { text, a2ui }
```

Use `json_serializable` or `freezed` for serialization.

## 4. Data Layer

### 4.1 ChatRepository (already exists)

Existing methods:

```dart
Future<List<ThreadSummary>> fetchThreads();
Future<Thread> fetchThread(String slug);
Future<Thread> createThread(String message);
Future<Thread> sendMessage(String slug, String message);
```

Add:

```dart
Future<Thread> confirmTool(String slug, String toolCallId, bool confirmed);
```

### 4.2 ApiClient (already exists)

- Dio-based client in `app/packages/api_client/`.
- Attaches Firebase ID token via `AuthInterceptor`.
- Handles 401 token refresh.

No changes required for the core logic.

## 5. State Management (BLoC)

### 5.1 ThreadsBloc (already exists)

- `ThreadsRequested` → loads `List<ThreadSummary>`.
- Extend later with status filters (`pending`, `solved`, `all`).

### 5.2 ChatBloc (already exists)

Existing events:

- `ChatThreadRequested(slug)`
- `ChatMessageSent(text)`

Add events:

- `ChatToolConfirmed(toolCallId, confirmed)`
- `ChatA2uiAction(action)` — handles `tool`, `reply`, `dismiss`, `openUrl`.

Add state fields if needed:

- `pendingToolCall` for the currently displayed confirmation UI.

## 6. Routing

Already implemented in `app/lib/app/view/app.dart` using `go_router`:

| Route | Screen | Description |
|-------|--------|-------------|
| `/` | `HomePage` | Home with clock, threads list, and composer. |
| `/chat` | `ChatPage` | New thread, receives initial message as `extra`. |
| `/chat/:slug` | `ChatPage` | Existing thread. |
| `/auth` | `AuthScreen` | Google sign-in. |

Redirect unauthenticated users to `/auth`.

## 7. UI Screens

### 7.1 HomePage (already exists)

- Clock header, threads list via `ThreadsSection`, and `ChatComposer`.
- Tapping a thread navigates to `/chat/:slug`.
- Submitting the composer navigates to `/chat` with the initial message.

Future additions:

- Pull-to-refresh on `ThreadsSection`.
- Filter chips for `pending`, `solved`, `all` (when lifecycle is added).
- "Add TODO" mode (when TODO metadata is added).

### 7.2 ChatPage (already exists)

- App bar with back button and thread title.
- Message list via `_Messages`:
  - User messages use `ChatBubble`.
  - Agent messages use `AgentMessage`.
  - `AgentMessageSkeleton` shown while awaiting reply.
- Bottom composer via `ChatComposer`.

Changes needed:

- `AgentMessage` must render A2UI trees for agent messages with `contentType == a2ui`.
- Handle A2UI actions inside the message list.

### 7.3 AuthScreen (already exists)

- Google sign-in button, loading state, error handling.

No changes required for the core logic.

## 8. A2UI Rendering

- Add `genui` (or a custom A2UI renderer) to the app.
- Create an `A2uiRenderer` widget that receives an `A2uiComponent` tree and dispatches to Flutter widgets.
- Implement a component catalog that maps A2UI component names to existing widgets:
  - `Column` → `Column`
  - `Row` → `Row`
  - `Spacer` → `Spacer` / `SizedBox` / `Expanded`
  - `Text` → `Text` with app typography
  - `Icon` → `AppIcon` using `AppIconData`
  - `Image` → `Image.network`
  - `AppButton` → `AppButton` from `app_ui`
  - `AppIconButton` → `AppIconButton` from `app_ui`
- Handle actions:
  - `tool` → send to backend (with confirmation if required).
  - `reply` → send the text as a user message.
  - `dismiss` → close transient UI.
  - `openUrl` → launch URL.
- Wire all actions back to `ChatBloc`.

## 9. Configuration

Environment files already exist:

- `app/env/development.json` and `app/env/development.local.json` for local dev.
- `app/env/production.json` for production (gitignored).
- `app/env/production.example.json` is the template.

Required keys:

```json
{
  "API_BASE_URL": "http://your-pi-hostname:3000",
  "GOOGLE_SIGN_IN_CLIENT_ID": "..."
}
```

Run with existing VS Code launch targets or:

```bash
flutter run --dart-define-from-file env/development.local.json
```

## 10. Real-Time Considerations (v1 Optional)

v1 can poll the thread detail every few seconds or pull-to-refresh. Later iterations can use Firestore snapshots for realtime updates.

## 11. Tests

- Widget tests for `ChatPage` and `AgentMessage` with mocked `ChatBloc`.
- Extend repository tests in `app/packages/chat/test/` for `confirmTool`.
- BLoC tests for `ChatBloc` covering A2UI actions and tool confirmation.
- Widget tests for the new `A2uiRenderer` mapping each component to the correct Flutter widget.
