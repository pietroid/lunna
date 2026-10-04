import { promises as fs } from 'fs';
import * as os from 'os';
import * as path from 'path';
import { Trace } from '../common/trace';
import { EventLayoutService } from '../events/event-layout.service';
import { ThingsService } from './things.service';
import { ThingsStore } from './things.store';

const USER = { id: 'test-user' };

describe('Coisas', () => {
  let root: string;
  let booked: { title: string; durationMinutes: number; fixed: boolean }[];
  let refuse: boolean;
  let things: ThingsService;

  beforeEach(async () => {
    root = await fs.mkdtemp(path.join(os.tmpdir(), 'focus-things-'));
    process.env.FOCUS_DATA_DIR = root;
    booked = [];
    refuse = false;

    const layout = {
      create: (
        _user: unknown,
        request: { title: string; durationMinutes: number; fixed: boolean },
      ) => {
        if (refuse) return Promise.reject(new Error('agenda fora do ar'));
        booked.push(request);
        return Promise.resolve([]);
      },
    } as unknown as EventLayoutService;

    things = new ThingsService(new ThingsStore(), layout);
  });

  afterEach(async () => {
    delete process.env.FOCUS_DATA_DIR;
    await fs.rm(root, { recursive: true, force: true });
  });

  it('keeps things in the order they were written down', async () => {
    await things.add(USER, { title: 'Um', durationMinutes: 30 });
    const list = await things.add(USER, { title: 'Dois', durationMinutes: 15 });

    expect(list.map((it) => it.title)).toEqual(['Um', 'Dois']);
  });

  it('moves a thing to the place it was dropped', async () => {
    await things.add(USER, { title: 'Um', durationMinutes: 30 });
    await things.add(USER, { title: 'Dois', durationMinutes: 30 });
    const list = await things.add(USER, { title: 'Três', durationMinutes: 30 });

    const moved = await things.move(USER, list[2].id, 0);

    expect(moved.map((it) => it.title)).toEqual(['Três', 'Um', 'Dois']);
  });

  it('puts a thing on the timeline as a flexible block and off the list', async () => {
    const [thing] = await things.add(USER, {
      title: 'Um',
      durationMinutes: 45,
    });

    const result = await things.schedule(USER, thing.id, Trace.start(USER.id));

    expect(booked).toEqual([
      { title: 'Um', durationMinutes: 45, fixed: false },
    ]);
    expect(result.things).toEqual([]);
  });

  it('keeps the thing when the calendar refuses it', async () => {
    const [thing] = await things.add(USER, {
      title: 'Um',
      durationMinutes: 45,
    });
    refuse = true;

    await expect(
      things.schedule(USER, thing.id, Trace.start(USER.id)),
    ).rejects.toThrow();
    expect((await things.list(USER)).map((it) => it.id)).toEqual([thing.id]);
  });
});
