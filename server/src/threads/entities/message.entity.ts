import { A2uiComponent, A2uiIssue } from '../../a2ui/a2ui.types';

/** Who wrote a message. */
export type MessageRole = 'user' | 'agent' | 'system';

/** Content type stored in the message body. */
export type MessageContentType = 'text' | 'a2ui';

/** What a tool did, kept for observability rather than for display. */
export interface ToolRun {
  name: string;
  /** Whether it changed anything, or only looked. */
  effect: 'read' | 'write';
  ok: boolean;
  /** True when it was a write the user had not confirmed, so nothing ran. */
  blocked?: boolean;
  durationMs: number;
  error?: string;
}

/** Extra metadata attached to a message. */
export interface MessageMetadata {
  contentType: MessageContentType;
  model?: string;
  latencyMs?: number;
  a2ui?: A2uiComponent;
  /** The turn this message belongs to. Present on every agent message. */
  traceId?: string;
  /** Tools that ran while producing it. */
  toolRuns?: ToolRun[];
  /** What the validator had to repair or reject, if anything. */
  a2uiIssues?: A2uiIssue[];
  /** How the raw model output was read: direct, fenced, salvaged, wrapped. */
  parseStrategy?: string;
  /**
   * True when this message proposed a change and is waiting on an answer.
   *
   * It is what lets the next turn run a write. A typed "pode agendar" counts as
   * the answer just as much as tapping the button does, which is the whole
   * reason the flag lives on the message rather than on the action.
   */
  proposedWrite?: boolean;
}

/** A single turn in a thread. */
export class Message {
  /** Stable id, derived from the role and timestamp. */
  id: string;
  role: MessageRole;
  /** The message body, as written in the markdown file. */
  text: string;
  createdAt: Date;
  metadata?: MessageMetadata;
}
