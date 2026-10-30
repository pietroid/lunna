import { ArtifactView, GoalView } from '../artifacts/artifact.types';
import { DEFAULT_WORK_DAY } from '../time/work-hours';
import { clampFollowUp, intoWorkDay, nextAtOf } from './agent.service';
import { basisOf, requestOf, workQuality, QualityState } from './work-quality';

const TODAY = '2026-11-03';
const ZONE = 'America/Sao_Paulo';

const goal = (target: number, done: number, queued: number): GoalView => ({
  id: 'g1',
  kind: 'money',
  typeId: null,
  target,
  start: '2026-11-01',
  end: '2026-12-01',
  done,
  queued,
  queuedCount: 0,
});

const delivery = (
  title: string,
  deadline: string | null,
  value: number | null,
  minutes: number,
  openTasks: number,
): ArtifactView => ({
  id: title,
  title,
  notes: '',
  typeId: null,
  minutes,
  doneMinutes: 0,
  value,
  blockMinutes: null,
  deadline,
  createdAt: '2026-11-01T10:00:00Z',
  startedAt: null,
  doneAt: null,
  tasks: Array.from({ length: openTasks }, (_, i) => ({
    id: `${title}-${i}`,
    title: `Parte ${i + 1}`,
    notes: '',
    minutes: 60,
    place: 'queue' as never,
  })),
});

const state = (
  goals: GoalView[],
  artifacts: ArtifactView[],
  need: number,
  free: number,
  routines: number,
  timeGone: number,
): QualityState => ({
  today: TODAY,
  answer: {
    goals,
    artifacts,
    schedule: { needMinutes: need, freeMinutes: free, until: '2026-11-30' },
  },
  routines,
  timeGone,
});

/** The five people of the RFC's `data/ladder.csv`, and their topics. */
describe('Work Quality', () => {
  it.each([
    ['new: nothing written', state([], [], 0, 0, 0, 0), 'goal', 0],
    [
      'goal R$ 5.000, two deliveries worth R$ 4.200',
      state(
        [goal(5000, 0, 4200)],
        [
          delivery('Mapa', '2026-11-14', 1800, 240, 0),
          delivery('Curso', '2026-11-25', 2400, 360, 0),
        ],
        600,
        9000,
        0,
        0.03,
      ),
      'reach',
      1,
    ],
    [
      'goal reached on paper, no tasks, no routine',
      state(
        [goal(5000, 0, 5400)],
        [
          delivery('Mapa', '2026-11-14', 1800, 240, 0),
          delivery('Curso', '2026-11-25', 3600, 360, 0),
        ],
        600,
        9000,
        0,
        0.1,
      ),
      'tasks',
      3,
    ],
    [
      'all written, but 40 h owed in 25 h free',
      state(
        [goal(5000, 1800, 3600)],
        [
          delivery('Mapa', '2026-11-14', 1800, 1200, 3),
          delivery('Curso', '2026-11-25', 1800, 1200, 2),
        ],
        2400,
        1500,
        2,
        0.4,
      ),
      'fits',
      4,
    ],
    [
      'everything written, behind pace',
      state(
        [goal(6000, 1200, 4800)],
        [delivery('Mapa', '2026-11-03', 1050, 510, 4)],
        510,
        1860,
        3,
        0.7,
      ),
      'pace',
      6,
    ],
  ])('%s: %s', (_name, it, topic, score) => {
    const quality = workQuality(it);
    expect(quality.topic).toBe(topic);
    expect(quality.score).toBe(score);
  });

  it('asks for the routine after the work', () => {
    const quality = workQuality(
      state(
        [goal(5000, 0, 5000)],
        [delivery('Mapa', '2026-11-14', 5000, 240, 2)],
        240,
        9000,
        0,
        0.1,
      ),
    );
    expect(quality).toMatchObject({ topic: 'routine', score: 5 });
  });

  it('keeps everything defined and on pace', () => {
    const quality = workQuality(
      state(
        [goal(5000, 3000, 2000)],
        [delivery('Mapa', '2026-11-14', 2000, 240, 2)],
        240,
        9000,
        1,
        0.5,
      ),
    );
    expect(quality).toMatchObject({ topic: 'keep', score: 7 });
  });

  it('writes the request with the facts, and hashes only what it is about', () => {
    const reach = workQuality(state([goal(5000, 0, 4200)], [], 0, 9000, 0, 0));
    expect(reach.facts).toMatchObject({ target: 5000, short: 800 });
    expect(requestOf(reach)).toContain('Topic (Work Quality level 2 of 7');
    expect(requestOf(reach)).toContain('"lastDay":"2026-11-30"');

    // A routine written changes nothing the reach is about.
    const later = workQuality(state([goal(5000, 0, 4200)], [], 0, 9000, 1, 0));
    expect(basisOf(later)).toBe(basisOf(reach));
    const closer = workQuality(state([goal(5000, 0, 4500)], [], 0, 9000, 0, 0));
    expect(basisOf(closer)).not.toBe(basisOf(reach));
  });
});

describe('the next suggestion’s hour', () => {
  const user = { id: 'u', workDay: DEFAULT_WORK_DAY } as never;

  it('holds the follow-up to 3–24 hours, 24 when none is said', () => {
    expect(clampFollowUp(undefined)).toBe(24);
    expect(clampFollowUp(1)).toBe(3);
    expect(clampFollowUp(48)).toBe(24);
    expect(clampFollowUp(5.4)).toBe(5);
  });

  it('moves an hour outside the working day to the next one’s start', () => {
    // 21:00 in São Paulo, three hours on: midnight, so 07:00 tomorrow.
    expect(
      nextAtOf(new Date('2026-11-04T00:00:00Z'), 3, user, ZONE).toISOString(),
    ).toBe('2026-11-04T10:00:00.000Z');
    // 05:00 is before the day: 07:00 the same day.
    expect(
      intoWorkDay(new Date('2026-11-04T08:00:00Z'), user, ZONE).toISOString(),
    ).toBe('2026-11-04T10:00:00.000Z');
    // 10:00 + 3 h is 13:00, inside.
    expect(
      nextAtOf(new Date('2026-11-04T13:00:00Z'), 3, user, ZONE).toISOString(),
    ).toBe('2026-11-04T16:00:00.000Z');
  });
});
