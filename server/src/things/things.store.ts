import { promises as fs } from 'fs';
import * as path from 'path';
import { Injectable } from '@nestjs/common';
import { sanitizeSegment, writeAtomic } from '../threads/threads.store';
import { Thing } from './entities/thing.entity';

/**
 * The things list, one file per person.
 *
 * ```
 * <root>/<userId>/things.json
 * ```
 *
 * Beside the day folders rather than in one, because a thing has no day. It
 * is the one list in Focus that is not the calendar and not a conversation,
 * and it is small enough that the whole of it is read and written at once.
 */
@Injectable()
export class ThingsStore {
  private readonly _root =
    process.env.FOCUS_DATA_DIR ?? path.join(process.cwd(), 'data', 'threads');

  /** The newest queued write per person, so two never interleave. */
  private readonly _writes = new Map<string, Promise<unknown>>();

  private _file(userId: string): string {
    return path.join(this._root, sanitizeSegment(userId), 'things.json');
  }

  /** Every thing, in the order the user put them. */
  async list(userId: string): Promise<Thing[]> {
    try {
      const raw: unknown = JSON.parse(
        await fs.readFile(this._file(userId), 'utf8'),
      );
      return Array.isArray(raw) ? raw.filter(isThing) : [];
    } catch {
      return [];
    }
  }

  /**
   * Reads the list, lets [change] rewrite it, and writes the result.
   *
   * One at a time per person: two taps landing together would otherwise both
   * read the same list and the second write would drop the first.
   */
  async update(
    userId: string,
    change: (things: Thing[]) => Thing[],
  ): Promise<Thing[]> {
    const previous = this._writes.get(userId) ?? Promise.resolve();
    const next = previous
      .catch(() => undefined)
      .then(async () => {
        const things = change(await this.list(userId));
        const file = this._file(userId);

        await fs.mkdir(path.dirname(file), { recursive: true });
        await writeAtomic(file, JSON.stringify(things, null, 2));

        return things;
      });

    this._writes.set(userId, next);
    return next;
  }
}

function isThing(value: unknown): value is Thing {
  if (value === null || typeof value !== 'object') return false;

  const raw = value as Record<string, unknown>;
  return (
    typeof raw.id === 'string' &&
    typeof raw.title === 'string' &&
    typeof raw.durationMinutes === 'number' &&
    typeof raw.createdAt === 'string'
  );
}
