/**
 * A2UI: the component tree the server sends the app.
 *
 * The tree uses a flat discriminator (`{ component: "Text", text: "..." }`) so
 * it stays readable in a thread file and cheap for a model to produce.
 *
 * These types are owned by the server. The agent never sees them: it returns
 * text and tool results, and everything here is built, validated and repaired
 * on this side before it reaches the app.
 */

/** The components the app can draw. */
export type ComponentName =
  | 'Column'
  | 'Row'
  | 'Spacer'
  | 'Divider'
  | 'Text'
  | 'Icon'
  | 'Image'
  | 'Card'
  | 'Badge'
  | 'ListItem'
  | 'AppButton'
  | 'AppIconButton';

/**
 * A colour role, not a colour.
 *
 * The model picks by meaning and the app owns the hex, so the palette can
 * change without touching a prompt or a stored thread.
 */
export type ColorRole =
  | 'accent'
  | 'success'
  | 'info'
  | 'warning'
  | 'danger'
  | 'ink'
  | 'ink2'
  | 'ink3';

/** One node in the tree. */
export interface A2uiComponent {
  component: ComponentName;
  children?: A2uiComponent[];
  action?: A2uiAction;
  [key: string]: unknown;
}

/** Everything a component can ask the app to do. */
export type A2uiAction =
  | ReplyAction
  | ConfirmAction
  | DismissAction
  | OpenUrlAction
  | ThreadAction
  | TimingAction
  | SyncAction;

/**
 * Asks the server to push the day to Google again.
 *
 * Carried by the one button on the sync popup. It names nothing, because
 * there is nothing to name: the retry is "everything that did not make it",
 * and the server is the only side that knows what that is.
 */
export interface SyncAction {
  type: 'sync';
}

/** Send a message back into the thread, as if the user typed it. */
export interface ReplyAction {
  type: 'reply';
  text: string;
}

/**
 * The same as a reply, plus the user's permission to change something.
 *
 * This is the only way a write ever runs. The model proposes, describing the
 * change in full; the user taps; the turn that follows is allowed to execute,
 * once, without being asked again. The app needs to know nothing about it: it
 * posts the action like any other and the server does the rest.
 */
export interface ConfirmAction {
  type: 'confirm';
  /** Restates the whole action, because it becomes the user's next message. */
  text: string;
}

/** Close transient UI. Handled entirely in the app. */
export interface DismissAction {
  type: 'dismiss';
}

/** Open a link. Handled entirely in the app. */
export interface OpenUrlAction {
  type: 'openUrl';
  url: string;
}

/** Change the thread itself. The server does this without calling the agent. */
export interface ThreadAction {
  type: 'thread';
  op: ThreadOp;
  /** The new title, for `rename`. */
  title?: string;
}

/** What a [ThreadAction] can do. */
export type ThreadOp = 'solve' | 'reopen' | 'rename' | 'delete';

/**
 * Answers the one guard the timeline raises.
 *
 * The whole move travels on it, so nothing is pending on either side and a
 * guard abandoned halfway leaves nothing behind.
 *
 * A model never writes one of these: the type is not in [MODEL_ACTION_TYPES],
 * so the validator drops it out of a reply along with the button carrying it.
 */
export interface TimingAction {
  type: 'timing';
  /** The event being moved. */
  eventId: string;
  /** Where in the day's queue the drop left it, counting from the top. */
  index: number;
  /** What the user decided. Absent means they have not been asked yet. */
  decision?: TimingDecision;
  /** ISO 8601, the start of the gap it was dropped into, when it was. */
  after?: string;
  /** The length it was cut to, to fit that gap. */
  minutes?: number;
}

/**
 * What the guard's two buttons say about the thread that was already running.
 *
 * - `solve_current` closes it and gives its hour away.
 * - `postpone_current` keeps it, further down the day.
 */
export type TimingDecision = 'solve_current' | 'postpone_current';

/** Every decision, for validating one off the wire. */
export const TIMING_DECISIONS: TimingDecision[] = [
  'solve_current',
  'postpone_current',
];

/** What went wrong, or was quietly fixed, while validating a tree. */
export interface A2uiIssue {
  /** Dotted path to the node, e.g. `root.children[1]`. */
  path: string;
  /** `repair` was fixed in place; `reject` replaced the node. */
  severity: 'repair' | 'reject';
  message: string;
}

/** The outcome of validating a tree. */
export interface A2uiValidationResult {
  component: A2uiComponent;
  issues: A2uiIssue[];
  /** True when nothing had to be repaired or rejected. */
  clean: boolean;
}
