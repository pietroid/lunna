import { randomBytes } from 'crypto';
import { promises as fs } from 'fs';
import * as path from 'path';
import { Injectable } from '@nestjs/common';
import { Message } from './entities/message.entity';
import { Thread, ThreadItem } from './entities/thread.entity';
import {
  dayFolder,
  isDayFolder,
  parseThread,
  previewFrom,
  serializeThread,
} from './thread-markdown';

/**
 * The thread store: a directory of markdown files.
 *
 * ```
 * <root>/<userId>/<DD-MM-YYYY>/<thread-slug>.md
 * <root>/<userId>/traces/<thread-slug>/<traceId>.json
 * ```
 *
 * A folder is a day and a file is a conversation: one file holds a thread
 * whole, front matter and every message, however many days it goes on for.
 * The day is the day it started, so a thread is written once and never moves,
 * and a month of them reads as an archive of what was talked about when.
 *
 * Threads are filed under the user who owns them, which keeps one person's
 * conversations from being readable by another.
 *
 * **Nothing here knows about hours.** That is the calendar's, and a thread
 * that remembered one would be the mirror this layout exists to be rid of.
 */
@Injectable()
export class ThreadsStore {
  /** Overridable so a deployment can point at a mounted volume. */
  private readonly _root =
    process.env.FOCUS_DATA_DIR ?? path.join(process.cwd(), 'data', 'threads');

  /** The newest queued write per thread, so two never interleave. */
  private readonly _writes = new Map<string, Promise<unknown>>();

  private _userDir(userId: string): string {
    return path.join(this._root, sanitizeSegment(userId));
  }

  /** Every day folder the user has, newest first. */
  private async _days(userId: string): Promise<string[]> {
    const names = (await readDirNames(this._userDir(userId))).filter(
      isDayFolder,
    );

    return names.sort((a, b) => dayKey(b) - dayKey(a));
  }

  /**
   * The file a thread lives in, or null when there is no such thread.
   *
   * Found by looking rather than by being told, because a slug is the whole
   * of what the API addresses a thread by and the day it started is not
   * something the app should have to carry around. Newest day first, since a
   * thread being opened is far more often today's than last month's.
   */
  private async _file(userId: string, slug: string): Promise<string | null> {
    const name = `${sanitizeSegment(slug)}.md`;

    for (const day of await this._days(userId)) {
      const file = path.join(this._userDir(userId), day, name);
      if (await exists(file)) return file;
    }

    return null;
  }

  /** Whether the user already has a thread by this name. */
  async exists(userId: string, slug: string): Promise<boolean> {
    return (await this._file(userId, slug)) !== null;
  }

  /** Every thread slug the user owns, newest day first. */
  async listSlugs(userId: string): Promise<string[]> {
    const slugs: string[] = [];

    for (const day of await this._days(userId)) {
      const dir = path.join(this._userDir(userId), day);
      for (const name of await readFileNames(dir)) {
        if (name.endsWith('.md')) slugs.push(name.slice(0, -3));
      }
    }

    return slugs;
  }

  /**
   * Starts a thread, in the folder for the day it started.
   *
   * The file exists from here on and is only ever appended to. Nothing else
   * creates one: a thread that appeared as a side effect of a write is a
   * thread nobody can say the age of.
   */
  async create(
    userId: string,
    slug: string,
    title: string,
    createdAt = new Date(),
  ): Promise<void> {
    const dir = path.join(this._userDir(userId), dayFolder(createdAt));
    await fs.mkdir(dir, { recursive: true });

    await writeAtomic(
      path.join(dir, `${sanitizeSegment(slug)}.md`),
      serializeThread({ createdAt, solved: false, title }, []),
    );
  }

  /**
   * Reads a thread whole.
   *
   * Returns `null` when the thread does not exist, so the caller decides
   * whether that is a 404 or a thread to create.
   */
  async read(userId: string, slug: string): Promise<Thread | null> {
    const file = await this._file(userId, slug);
    if (file === null) return null;

    const markdown = await readFileOrNull(file);
    if (markdown === null) return null;

    return toThread(slug, file, markdown);
  }

  /** Every thread the user owns, in no particular order. */
  async readAll(userId: string): Promise<Thread[]> {
    const threads: Thread[] = [];

    for (const day of await this._days(userId)) {
      const dir = path.join(this._userDir(userId), day);

      for (const name of await readFileNames(dir)) {
        if (!name.endsWith('.md')) continue;

        const markdown = await readFileOrNull(path.join(dir, name));
        if (markdown === null) continue;

        threads.push(
          toThread(name.slice(0, -3), path.join(dir, name), markdown),
        );
      }
    }

    return threads;
  }

  /**
   * Appends [messages] to a thread.
   *
   * The whole file is rewritten, which is what one file per conversation
   * costs and what it buys: there is one place a thread can be, so there is
   * no question of which day's copy is the real one. A conversation is a few
   * kilobytes, and the rewrite is atomic.
   */
  async append(
    userId: string,
    slug: string,
    messages: Message[],
  ): Promise<void> {
    await this._serialize(userId, slug, async () => {
      const file = await this._file(userId, slug);
      if (file === null) return;

      const markdown = (await readFileOrNull(file)) ?? '';
      const parsed = parseThread(markdown);

      const ordered = [...parsed.messages, ...messages].sort(
        (a, b) => a.createdAt.getTime() - b.createdAt.getTime(),
      );

      await writeAtomic(
        file,
        serializeThread(
          {
            createdAt:
              parsed.front.createdAt ?? ordered[0]?.createdAt ?? new Date(),
            solved: parsed.front.solved,
            title: parsed.front.title,
          },
          ordered,
        ),
      );
    });
  }

  /**
   * Changes what the thread says about itself.
   *
   * Read, merge, write, one thread at a time, because that sequence is not
   * atomic and the file is also being appended to by the turn that is
   * running. Serialising per thread rather than globally, so one slow thread
   * does not hold up the rest. One process holds the lock, which is all there
   * is: the store is a directory on a Pi with a single backend on it.
   */
  async updateState(
    userId: string,
    slug: string,
    changes: { solved?: boolean; title?: string },
  ): Promise<void> {
    await this._serialize(userId, slug, async () => {
      const file = await this._file(userId, slug);
      if (file === null) return;

      const markdown = (await readFileOrNull(file)) ?? '';
      const parsed = parseThread(markdown);

      await writeAtomic(
        file,
        serializeThread(
          {
            createdAt:
              parsed.front.createdAt ??
              parsed.messages[0]?.createdAt ??
              new Date(),
            solved: changes.solved ?? parsed.front.solved,
            title: changes.title ?? parsed.front.title,
          },
          parsed.messages,
        ),
      );
    });
  }

  /** Writes a turn's trace where the thread's traces go. */
  async saveTrace(
    userId: string,
    slug: string,
    traceId: string,
    payload: unknown,
  ): Promise<void> {
    const dir = this._traceDir(userId, slug);
    await fs.mkdir(dir, { recursive: true });
    await fs.writeFile(
      path.join(dir, `${sanitizeSegment(traceId)}.json`),
      JSON.stringify(payload, null, 2),
      'utf8',
    );
  }

  /** Reads one stored trace back, or null when it has been cleaned up. */
  async readTrace(
    userId: string,
    slug: string,
    traceId: string,
  ): Promise<unknown> {
    const content = await readFileOrNull(
      path.join(
        this._traceDir(userId, slug),
        `${sanitizeSegment(traceId)}.json`,
      ),
    );
    if (content === null) return null;

    try {
      return JSON.parse(content) as unknown;
    } catch {
      return null;
    }
  }

  /** Removes a thread and the traces that explain it. */
  async remove(userId: string, slug: string): Promise<void> {
    const file = await this._file(userId, slug);
    if (file !== null) await fs.rm(file, { force: true });

    await fs.rm(this._traceDir(userId, slug), {
      recursive: true,
      force: true,
    });
  }

  /**
   * Traces live beside the days rather than inside them.
   *
   * A thread's folder is a date, and a trace is not about a date: keeping
   * them out of the day folders is what leaves a day folder readable as a
   * list of the conversations that started that day.
   */
  private _traceDir(userId: string, slug: string): string {
    return path.join(this._userDir(userId), 'traces', sanitizeSegment(slug));
  }

  /** Runs [work] after everything already queued for this thread. */
  private async _serialize(
    userId: string,
    slug: string,
    work: () => Promise<void>,
  ): Promise<void> {
    const key = `${sanitizeSegment(userId)}/${sanitizeSegment(slug)}`;
    const previous = this._writes.get(key) ?? Promise.resolve();

    const next = previous.catch(() => undefined).then(work);

    // The tail swallows failures: one write that throws must not take the
    // writes queued behind it with it.
    const tail = next.then(
      () => undefined,
      () => undefined,
    );
    this._writes.set(key, tail);

    try {
      await next;
    } finally {
      // Only the last write for a thread clears the entry. One that is still
      // holding a queue keeps its place, and the map stays the size of what
      // is actually in flight.
      if (this._writes.get(key) === tail) this._writes.delete(key);
    }
  }
}

/** One file, read as a thread. */
function toThread(slug: string, file: string, markdown: string): Thread {
  const parsed = parseThread(markdown);
  const messages = parsed.messages;

  const createdAt =
    parsed.front.createdAt ??
    messages[0]?.createdAt ??
    dayOf(path.basename(path.dirname(file))) ??
    new Date();

  return {
    slug,
    title: parsed.front.title === '' ? slug : parsed.front.title,
    messages,
    solved: parsed.front.solved,
    createdAt,
    updatedAt: messages[messages.length - 1]?.createdAt ?? createdAt,
  };
}

/** [thread] as a row in a list. */
export function toItem(thread: Thread): ThreadItem {
  const last = thread.messages[thread.messages.length - 1];

  return {
    slug: thread.slug,
    title: thread.title,
    preview: last === undefined ? '' : previewFrom(last),
    messageCount: thread.messages.length,
    solved: thread.solved,
    createdAt: thread.createdAt,
    updatedAt: thread.updatedAt,
  };
}

/** A day folder as a sortable number. */
function dayKey(name: string): number {
  const [day, month, year] = name.split('-');
  return Number(`${year}${month}${day}`);
}

/** A day folder as the moment it began, or undefined when it is not one. */
function dayOf(name: string): Date | undefined {
  if (!isDayFolder(name)) return undefined;

  const [day, month, year] = name.split('-').map(Number);
  return new Date(year, month - 1, day);
}

/**
 * Keeps a slug or user id to one path segment.
 *
 * Both reach the store from the request, so neither is allowed to contain a
 * separator or a `..` that would walk out of the data directory.
 */
export function sanitizeSegment(value: string): string {
  const cleaned = value.replace(/[^a-zA-Z0-9._-]/g, '-').replace(/^\.+/, '');
  if (cleaned === '') throw new Error('Invalid path segment');
  return cleaned;
}

/**
 * Writes [contents] to [file] in one step, as far as any reader can tell.
 *
 * Through a temporary file and a rename, because a plain write is not one
 * step: it truncates and then fills, and anything reading in between gets
 * half a file. Rename is atomic on the same filesystem, so a reader sees
 * either the old file whole or the new one.
 */
export async function writeAtomic(
  file: string,
  contents: string,
): Promise<void> {
  const temp = `${file}.${randomBytes(6).toString('hex')}.tmp`;

  try {
    await fs.writeFile(temp, contents, 'utf8');
    await fs.rename(temp, file);
  } catch (error) {
    await fs.rm(temp, { force: true });
    throw error;
  }
}

async function exists(target: string): Promise<boolean> {
  try {
    await fs.access(target);
    return true;
  } catch {
    return false;
  }
}

async function readDirNames(dir: string): Promise<string[]> {
  try {
    const entries = await fs.readdir(dir, { withFileTypes: true });
    return entries
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name);
  } catch {
    return [];
  }
}

async function readFileNames(dir: string): Promise<string[]> {
  try {
    const entries = await fs.readdir(dir, { withFileTypes: true });
    return entries.filter((entry) => entry.isFile()).map((entry) => entry.name);
  } catch {
    return [];
  }
}

async function readFileOrNull(file: string): Promise<string | null> {
  try {
    return await fs.readFile(file, 'utf8');
  } catch {
    return null;
  }
}
