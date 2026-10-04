import { A2uiComponent } from '../a2ui/a2ui.types';
import {
  Message,
  MessageContentType,
  MessageMetadata,
  MessageRole,
} from './entities/message.entity';

/**
 * The on-disk format for a thread.
 *
 * ```markdown
 * ---
 * created: 2026-09-15T19:23:04.123Z
 * solved: false
 * ---
 *
 * # Buy milk tomorrow
 *
 * ## user @ 2026-09-15T19:23:04.123Z
 *
 * Buy milk tomorrow
 *
 * ## agent @ 2026-09-15T19:23:05.456Z
 *
 * {"a2ui":{"component":"Text","text":"Noted."}}
 * ```
 *
 * One file is one whole conversation, however many days it runs over, and it
 * lives in the folder for the day it started. Everything known about the
 * thread is in it: there is no state file beside it and nothing about it
 * anywhere else, so a thread is a thing you can read, diff, move and delete
 * by hand.
 *
 * Markdown rather than JSON so a conversation stays readable. An agent
 * message stores its A2UI tree in the body, alongside a `meta` object
 * carrying the trace id, the model and what the validator had to fix. Keeping
 * that in the file rather than only in a log means a turn can still be
 * explained days later, after the container that logged it is gone.
 *
 * **No hours.** When something happens is the calendar's to say, and a thread
 * that remembered an hour of its own would be a second answer to a question
 * that already has one.
 */

/** Matches a message header, and only a message header. */
const HEADER = /^## (user|agent|system) @ (\d{4}-\d{2}-\d{2}T[\d:.]+Z)$/;

/** Matches the thread title heading. */
const TITLE = /^# (.+)$/;

/** Matches the fence around the front matter. */
const FENCE = '---';

/** What a thread carries besides its messages. */
export interface ThreadFront {
  /** When the first message was written, which is also its folder. */
  createdAt: Date;
  /** Whether the user considers the thread closed. */
  solved: boolean;
  /** The title, which the user or the agent may have changed. */
  title: string;
}

/** The body of an agent message, as written into the file. */
interface StoredBody {
  a2ui?: A2uiComponent;
  meta?: Omit<MessageMetadata, 'contentType' | 'a2ui'>;
}

/**
 * Reads an agent message body back, when it holds an A2UI payload.
 */
function parseBody(text: string): StoredBody | undefined {
  const trimmed = text.trim();
  if (!trimmed.startsWith('{')) return undefined;

  try {
    const parsed = JSON.parse(trimmed) as StoredBody;
    return parsed.a2ui === undefined ? undefined : parsed;
  } catch {
    return undefined;
  }
}

/** Renders a whole thread as the markdown of its file. */
export function serializeThread(
  front: ThreadFront,
  messages: Message[],
): string {
  const blocks = messages.map((message) => {
    return `## ${message.role} @ ${message.createdAt.toISOString()}\n\n${serializeBody(message)}`;
  });

  const head = [
    FENCE,
    `created: ${front.createdAt.toISOString()}`,
    `solved: ${front.solved}`,
    FENCE,
  ].join('\n');

  return [head, `# ${front.title}`, ...blocks].join('\n\n') + '\n';
}

/** One message body: the A2UI payload plus its metadata, or plain text. */
function serializeBody(message: Message): string {
  const metadata = message.metadata;
  if (metadata?.contentType !== 'a2ui' || metadata.a2ui === undefined) {
    return message.text.trim();
  }

  const { contentType: _contentType, a2ui, ...meta } = metadata;
  const body: StoredBody = { a2ui };
  if (Object.keys(meta).length > 0) body.meta = meta;

  return JSON.stringify(body);
}

/**
 * Reads a thread file back into what it says about itself and its messages.
 *
 * A line only opens a new message when it matches [HEADER] exactly, so a `##`
 * inside a message body stays part of that body.
 *
 * A file with no front matter still parses. That is a thread somebody wrote
 * by hand, which is a thing this format is meant to allow: it is open, it is
 * called whatever its heading says, and it started when its first message
 * did.
 */
export function parseThread(markdown: string): {
  front: { createdAt?: Date; solved: boolean; title: string };
  messages: Message[];
} {
  const { head, body } = splitFront(markdown);
  const lines = body.split('\n');

  let title = '';
  const messages: Message[] = [];
  let current: { role: MessageRole; createdAt: Date; body: string[] } | null =
    null;

  const flush = () => {
    if (current === null) return;

    const text = current.body.join('\n').trim();
    const stored = current.role === 'user' ? undefined : parseBody(text);
    const contentType: MessageContentType =
      stored === undefined ? 'text' : 'a2ui';

    const message: Message = {
      id: messageId(current.role, current.createdAt),
      role: current.role,
      text,
      createdAt: current.createdAt,
    };

    if (stored !== undefined) {
      message.metadata = { ...stored.meta, contentType, a2ui: stored.a2ui };
    }

    messages.push(message);
    current = null;
  };

  for (const line of lines) {
    const header = HEADER.exec(line);
    if (header !== null) {
      flush();
      current = {
        role: header[1] as MessageRole,
        createdAt: new Date(header[2]),
        body: [],
      };
      continue;
    }

    if (current !== null) {
      current.body.push(line);
      continue;
    }

    // Before the first header, the only line that carries meaning is the
    // title. Anything else is whitespace or a note someone left at the top.
    const titleMatch = TITLE.exec(line);
    if (titleMatch !== null && title === '') {
      title = titleMatch[1].trim();
    }
  }

  flush();

  return {
    front: {
      createdAt: head.created,
      solved: head.solved === true,
      title,
    },
    messages,
  };
}

/**
 * Splits the front matter off the body.
 *
 * Only a fence on the very first line counts, so a `---` used as a rule
 * inside a conversation is part of the conversation.
 */
function splitFront(markdown: string): {
  head: { created?: Date; solved?: boolean };
  body: string;
} {
  const lines = markdown.split('\n');
  if (lines[0]?.trim() !== FENCE) return { head: {}, body: markdown };

  const end = lines.indexOf(FENCE, 1);
  if (end === -1) return { head: {}, body: markdown };

  const head: { created?: Date; solved?: boolean } = {};

  for (const line of lines.slice(1, end)) {
    const separator = line.indexOf(':');
    if (separator === -1) continue;

    const key = line.slice(0, separator).trim();
    const value = line.slice(separator + 1).trim();

    if (key === 'created') {
      const created = new Date(value);
      if (!Number.isNaN(created.getTime())) head.created = created;
    }
    if (key === 'solved') head.solved = value === 'true';
  }

  return { head, body: lines.slice(end + 1).join('\n') };
}

/**
 * A message's id.
 *
 * Derived from the role and timestamp rather than stored, so the id survives a
 * hand-edit of the file and no counter has to be kept anywhere.
 */
export function messageId(role: MessageRole, createdAt: Date): string {
  return `${role}-${createdAt.getTime()}`;
}

/**
 * Turns the first message of a thread into a file name.
 *
 * Lowercase, ASCII, hyphen-separated, and capped so a long first message does
 * not become a path the filesystem refuses.
 */
export function slugify(text: string): string {
  const slug = text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48)
    .replace(/-+$/g, '');

  return slug === '' ? 'thread' : slug;
}

/**
 * Turns the first message into a thread title: one line, trimmed to length.
 */
export function titleFrom(text: string): string {
  const line = text.trim().split('\n')[0].trim();
  return line.length > 60 ? `${line.slice(0, 59).trimEnd()}...` : line;
}

/**
 * The folder a thread started on that day belongs in.
 *
 * `DD-MM-YYYY`, in the server's local timezone, so the folders line up with
 * the user's sense of a day rather than UTC's and read the way a date is
 * written here.
 */
export function dayFolder(date: Date): string {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  return `${day}-${month}-${year}`;
}

/** Whether [name] is one of those folders. */
export function isDayFolder(name: string): boolean {
  return /^\d{2}-\d{2}-\d{4}$/.test(name);
}

/**
 * Extracts a human-readable preview from a message.
 *
 * For A2UI agent messages, the preview is taken from the first Text component.
 */
export function previewFrom(message: Message): string {
  if (message.metadata?.contentType === 'a2ui' && message.metadata.a2ui) {
    const text = firstTextInTree(message.metadata.a2ui);
    if (text !== undefined) return text.split('\n')[0].trim();
  }

  return message.text.split('\n')[0].trim();
}

function firstTextInTree(component: A2uiComponent): string | undefined {
  for (const key of ['text', 'title']) {
    const value = component[key];
    if (typeof value === 'string' && value.trim() !== '') return value;
  }

  if (Array.isArray(component.children)) {
    for (const child of component.children) {
      const found = firstTextInTree(child);
      if (found !== undefined) return found;
    }
  }

  return undefined;
}
