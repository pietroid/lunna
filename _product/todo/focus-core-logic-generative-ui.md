# Focus: Core Logic — A2UI / GenUI Catalog

This document defines the Generative UI system used by the Agent and rendered by the Flutter app. It follows the A2UI v0.9 protocol and Flutter's `genui` package conventions.

## 0. Current State & What to Preserve

- The app already has a full UI widget catalog in `app/packages/app_ui/`.
- `AgentMessage` currently renders plain text. It must be extended to render A2UI trees, but the widget itself and its alignment/skeleton should be preserved.
- There is no existing A2UI renderer. A new `A2uiRenderer` widget must be created in `app/packages/chat/lib/src/widgets/`.

## 1. Design Principle

Every Agent response is an A2UI component tree. There is no plain-text reply channel. If the Agent only has text to show, it must return a `Text` component. This makes the UI layer predictable: the app always renders a component tree, never raw markdown or text bubbles.

A2UI v0.9 uses a **prompt-first** approach: the catalog schema and rendering rules are injected into the Agent's system prompt as plain text. The Agent emits JSON component trees directly in its response; the app parses and renders them.

## 2. Agent Response Format

The Agent's final reply (and any intermediate confirmation UI) is a JSON object with an `a2ui` field:

```json
{
  "a2ui": {
    "component": "Column",
    "children": [
      {
        "component": "Text",
        "text": "I can schedule the meeting for tomorrow at 10am."
      },
      {
        "component": "Row",
        "children": [
          {
            "component": "AppButton",
            "text": "Confirm",
            "variant": "primary",
            "action": {
              "type": "tool",
              "tool": "calendar_create_event",
              "arguments": { "title": "Standup", "startTime": "2026-09-20T10:00:00" }
            }
          },
          { "component": "Spacer", "width": 8 },
          {
            "component": "AppButton",
            "text": "Cancel",
            "variant": "text",
            "action": { "type": "dismiss" }
          }
        ]
      }
    ]
  }
}
```

Rules:

- The root component is typically a `Column` or `Row` so the Agent can compose multiple widgets.
- Every string the Agent wants to display must be inside a `Text` component.
- The `a2ui` tree is the only payload returned to the backend; there is no separate `text` field.
- The Agent must never emit a component outside the approved catalog.

## 3. Component Catalog

The catalog is deliberately small. It combines the current app-specific widgets (excluding app bar, text field, skeleton, and text editor) with a minimal set of Flutter primitives.

| Component | Source | Purpose |
|-----------|--------|---------|
| `Column` | Flutter primitive | Vertical layout. |
| `Row` | Flutter primitive | Horizontal layout. |
| `Spacer` | Flutter primitive | Add flexible or fixed spacing. |
| `Text` | Flutter primitive | Display text. |
| `Icon` | Flutter primitive | Display an app icon by name. |
| `Image` | Flutter primitive | Display an image from a URL. |
| `AppButton` | `app_ui` | Primary/secondary/text button. |
| `AppIconButton` | `app_ui` | Icon-only button. |

### 3.1 Column

```json
{
  "component": "Column",
  "mainAxisAlignment": "start",
  "crossAxisAlignment": "stretch",
  "children": [
    { "component": "Text", "text": "Line 1" },
    { "component": "Text", "text": "Line 2" }
  ]
}
```

Supported props:

- `children`: array of A2UI components.
- `mainAxisAlignment`: `start`, `end`, `center`, `spaceBetween`, `spaceAround`, `spaceEvenly`.
- `crossAxisAlignment`: `start`, `end`, `center`, `stretch`.

### 3.2 Row

```json
{
  "component": "Row",
  "mainAxisAlignment": "start",
  "crossAxisAlignment": "center",
  "children": [
    { "component": "Text", "text": "Left" },
    { "component": "Spacer" },
    { "component": "Text", "text": "Right" }
  ]
}
```

Supported props: same alignment values as `Column`.

### 3.3 Spacer

```json
{ "component": "Spacer" }
```

Or fixed size:

```json
{ "component": "Spacer", "width": 16, "height": 8 }
```

Rules:

- If neither `width` nor `height` is provided, the spacer expands to fill available space (like `Expanded`).
- Use fixed `width`/`height` for explicit gaps.

### 3.4 Text

```json
{
  "component": "Text",
  "text": "This is the only way the Agent may display text.",
  "variant": "body"
}
```

Supported props:

- `text`: string (required).
- `variant`: `headline`, `title`, `body`, `caption`, `label`.

### 3.5 Icon

```json
{
  "component": "Icon",
  "icon": "check",
  "size": 24,
  "color": "accent"
}
```

Supported props:

- `icon`: string name from `AppIcons` (required).
- `size`: number.
- `color`: `accent`, `ink`, `ink2`, `ink3`, `error`.

### 3.6 Image

```json
{
  "component": "Image",
  "src": "https://example.com/chart.png",
  "width": 200,
  "height": 200,
  "fit": "cover"
}
```

Supported props:

- `src`: URL string (required).
- `width`, `height`: number.
- `fit`: `cover`, `contain`, `fill`, `fitWidth`, `fitHeight`, `none`.

### 3.7 AppButton

```json
{
  "component": "AppButton",
  "text": "Add to calendar",
  "variant": "primary",
  "expand": true,
  "action": {
    "type": "tool",
    "tool": "calendar_create_event",
    "arguments": { "title": "Standup", "startTime": "2026-09-20T10:00:00" }
  }
}
```

Supported props:

- `text`: string (required).
- `variant`: `primary`, `secondary`, `text`.
- `expand`: boolean.
- `icon`: optional icon name to display before the label.
- `action`: optional interaction payload (see §4).

### 3.8 AppIconButton

```json
{
  "component": "AppIconButton",
  "icon": "more",
  "size": 24,
  "action": { "type": "dismiss" }
}
```

Supported props:

- `icon`: string name from `AppIcons` (required).
- `size`: number.
- `color`: `accent`, `ink`, `ink2`, `ink3`, `error`.
- `action`: optional interaction payload.

## 4. Actions

Components can declare an `action` that the app sends back to the backend when the user interacts with them.

### 4.1 Tool Action

Triggers an Agent tool. The backend forwards it to the Agent's tool execution endpoint.

```json
{
  "type": "tool",
  "tool": "calendar_create_event",
  "arguments": { "title": "Standup", "startTime": "2026-09-20T10:00:00" },
  "requiresConfirmation": true
}
```

- `tool`: the tool name (must match an allowed tool).
- `arguments`: tool-specific parameters.
- `requiresConfirmation`: if `true`, the app shows a confirmation sheet before sending the action to the backend.

### 4.2 Reply Action

Sends a pre-filled user message, as if the user typed it.

```json
{
  "type": "reply",
  "text": "Tomorrow at 10am works."
}
```

### 4.3 Dismiss Action

Closes a transient UI (e.g., a confirmation sheet) without sending anything.

```json
{
  "type": "dismiss"
}
```

### 4.4 Open URL Action

Opens a URL in the browser or appropriate app.

```json
{
  "type": "openUrl",
  "url": "https://example.com"
}
```

## 5. Tool Calling with OpenRouter

The Agent uses OpenRouter's standard tool-calling interface to expose integrations to the model. The Agent itself executes the tools.

### 5.1 Tool Definitions

Register these tools with every chat request:

```json
{
  "type": "function",
  "function": {
    "name": "web_search",
    "description": "Search the web for current information.",
    "parameters": {
      "type": "object",
      "properties": {
        "query": { "type": "string" }
      },
      "required": ["query"]
    }
  }
}
```

```json
{
  "type": "function",
  "function": {
    "name": "calendar_check_availability",
    "description": "Check free/busy times on the user's calendar.",
    "parameters": {
      "type": "object",
      "properties": {
        "date": { "type": "string", "description": "ISO 8601 date" },
        "durationMinutes": { "type": "number" }
      },
      "required": ["date", "durationMinutes"]
    }
  }
}
```

```json
{
  "type": "function",
  "function": {
    "name": "calendar_create_event",
    "description": "Create a calendar event. Only call this after the user has explicitly confirmed.",
    "parameters": {
      "type": "object",
      "properties": {
        "title": { "type": "string" },
        "startTime": { "type": "string", "description": "ISO 8601 date-time" },
        "endTime": { "type": "string", "description": "ISO 8601 date-time" }
      },
      "required": ["title", "startTime", "endTime"]
    }
  }
}
```

```json
{
  "type": "function",
  "function": {
    "name": "api_call",
    "description": "Call a configured third-party API.",
    "parameters": {
      "type": "object",
      "properties": {
        "integration": { "type": "string" },
        "endpoint": { "type": "string" },
        "method": { "type": "string", "enum": ["GET", "POST", "PUT", "DELETE"] },
        "payload": { "type": "object" }
      },
      "required": ["integration", "endpoint", "method"]
    }
  }
}
```

### 5.2 Tool Execution Flow

1. The Agent sends the thread context + tool definitions to OpenRouter.
2. The model may return:
   - A final A2UI response (finish), or
   - One or more `tool_calls`.
3. The Agent processes `tool_calls`:
   - For read-only/safe tools (`web_search`, `calendar_check_availability`), execute immediately and append a `role: "tool"` message.
   - For write/sensitive tools (`calendar_create_event`, mutating `api_call`), stop the loop and return an A2UI confirmation component. Store the pending tool call so it can be resumed after confirmation.
4. After executing all safe tools, send the results back to OpenRouter and continue the loop.
5. When the model returns a final A2UI response, return it to the backend.

### 5.3 Confirmation Flow

When the model requests a tool that requires confirmation:

1. The Agent returns an A2UI message containing a confirmation UI (e.g., `Text` + `Row` of `AppButton`s).
2. The backend stores the A2UI message and the pending tool call.
3. The app renders the confirmation UI.
4. If the user confirms, the app sends the action to `POST /api/threads/:slug/tools/:toolCallId/confirm`.
5. The backend forwards the confirmation to the Agent.
6. The Agent executes the tool, appends the result, and continues the OpenRouter loop until a final A2UI response is produced.
7. The backend stores the final A2UI response.

## 6. Schema Validation

### 6.1 Agent-Side Validation

- Validate every emitted component against the catalog schema.
- Reject unknown components and strip unknown props.
- Ensure the top-level payload always contains a valid `a2ui` object.
- If validation fails, log the error and return a fallback A2UI tree:

```json
{
  "a2ui": {
    "component": "Text",
    "text": "I'm unable to render this reply right now. Please try again."
  }
}
```

### 6.2 Backend Validation

- Re-validate the A2UI tree before storing it.
- Reject messages without a valid `a2ui` field.
- Validate tool action payloads against allowed tools.

### 6.3 App-Side Validation

- The renderer only instantiates components in the catalog.
- Unknown components render a fallback `Text` with a generic error message.
- Malformed actions are ignored and logged.

## 7. Component Registry Format

TypeScript (Agent / backend):

```ts
export const A2UI_CATALOG = {
  Column: columnSchema,
  Row: rowSchema,
  Spacer: spacerSchema,
  Text: textSchema,
  Icon: iconSchema,
  Image: imageSchema,
  AppButton: appButtonSchema,
  AppIconButton: appIconButtonSchema,
} as const;

export type ComponentName = keyof typeof A2UI_CATALOG;
```

Dart (Flutter app):

```dart
enum A2uiComponent {
  column,
  row,
  spacer,
  text,
  icon,
  image,
  appButton,
  appIconButton,
}
```

## 8. Accessibility

- Every `AppButton` must have a non-empty `text` label.
- Every `AppIconButton` must have an `accessibilityLabel` prop.
- `Text` components should use appropriate `variant` values so the app can apply semantic styles.
- Interactive components must expose tap handlers and focus traversal.

## 9. Extending the Catalog

To add a new component:

1. Define the JSON schema with flat discriminator props.
2. Add it to `A2UI_CATALOG` in the Agent and backend.
3. Add the Dart enum value.
4. Implement the Flutter widget renderer.
5. Update the Agent's system prompt to describe the new component and its props.
6. Add examples to tests.

## 10. Flutter Rendering Notes

The Flutter app uses the `genui` package or a custom renderer to render A2UI trees. Key implementation points:

- Use a `SurfaceController` (or custom equivalent) to manage A2UI surfaces.
- Implement an `A2uiTransportAdapter` that forwards user interactions to the backend.
- Parse the flat discriminator format (`{"component": "Text", "text": "..."}`) into widget constructors.
- Map `AppButton` props to the existing `AppButton` widget from `app_ui`.
- Map `Icon` names to `AppIconData` via the existing `AppIcons` catalog.
- For tool actions, call the backend and show loading/confirmation UI as needed.
