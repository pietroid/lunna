import { randomBytes } from 'crypto';
import { Injectable, NotFoundException } from '@nestjs/common';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { EventLayoutService } from '../events/event-layout.service';
import { ScheduledThing, Thing } from './entities/thing.entity';
import { ThingsStore } from './things.store';

/**
 * Coisas: what the user means to do, in the order they mean to do it.
 *
 * It behaves like the timeline with the clock taken out. Things are written
 * down, dragged into order, finished or thrown away, and none of that
 * involves an hour. The one way out that does is [schedule], which hands the
 * thing to the layout as a flexible block and takes it off this list.
 */
@Injectable()
export class ThingsService {
  constructor(
    private readonly _store: ThingsStore,
    private readonly _layout: EventLayoutService,
  ) {}

  list(user: CalendarUser): Promise<Thing[]> {
    return this._store.list(user.id);
  }

  /** Writes a thing down at the bottom of the list. */
  add(
    user: CalendarUser,
    request: { title: string; durationMinutes: number },
    now = new Date(),
  ): Promise<Thing[]> {
    const thing: Thing = {
      id: `t_${now.getTime().toString(36)}_${randomBytes(3).toString('hex')}`,
      title: request.title,
      durationMinutes: request.durationMinutes,
      createdAt: now.toISOString(),
    };

    return this._store.update(user.id, (things) => [...things, thing]);
  }

  /** Renames a thing or changes how long it will take. */
  async edit(
    user: CalendarUser,
    id: string,
    changes: { title?: string; durationMinutes?: number },
  ): Promise<Thing[]> {
    await this._require(user, id);

    return this._store.update(user.id, (things) =>
      things.map((thing) =>
        thing.id === id ? { ...thing, ...changes } : thing,
      ),
    );
  }

  /** Lifts a thing out of the list and puts it back at [index]. */
  async move(user: CalendarUser, id: string, index: number): Promise<Thing[]> {
    await this._require(user, id);

    return this._store.update(user.id, (things) => {
      const from = things.findIndex((thing) => thing.id === id);
      if (from === -1) return things;

      const rest = [...things];
      const [moved] = rest.splice(from, 1);
      rest.splice(Math.min(index, rest.length), 0, moved);

      return rest;
    });
  }

  /** Takes a thing off the list, done or not wanted. */
  async remove(user: CalendarUser, id: string): Promise<Thing[]> {
    await this._require(user, id);

    return this._store.update(user.id, (things) =>
      things.filter((thing) => thing.id !== id),
    );
  }

  /**
   * Moves a thing onto the timeline.
   *
   * Booked first and taken off the list after, so a calendar that refuses
   * leaves the thing where it was rather than losing it between the two.
   */
  async schedule(
    user: CalendarUser,
    id: string,
    trace: Trace,
  ): Promise<ScheduledThing> {
    const thing = await this._require(user, id);

    trace.log('thing.schedule', { id });
    const cards = await this._layout.create(
      user,
      {
        title: thing.title,
        durationMinutes: thing.durationMinutes,
        fixed: false,
      },
      trace,
    );

    const things = await this._store.update(user.id, (all) =>
      all.filter((it) => it.id !== id),
    );

    return { things, cards };
  }

  private async _require(user: CalendarUser, id: string): Promise<Thing> {
    const thing = (await this._store.list(user.id)).find((it) => it.id === id);
    if (thing === undefined) throw new NotFoundException(`No thing "${id}"`);

    return thing;
  }
}
