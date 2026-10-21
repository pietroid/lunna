import { Day } from '../events/timeline.service';
import { DEFAULT_WORK_DAY } from '../time/work-hours';
import { Board, sameTitle } from './board';

/** An empty day at [now], in [zone]. */
function boardAt(now: string, zone = 'America/Sao_Paulo'): Board {
  const day: Day = {
    now: new Date(now),
    zone,
    workDay: DEFAULT_WORK_DAY,
    until: new Date(now),
    events: [],
    tasks: [],
    backlog: [],
    live: new Map(),
    placed: new Map(),
    routines: new Map(),
    artifacts: new Map(),
  };

  return new Board(day, {
    tasks: [],
    backlog: [],
    cards: [],
    workDay: { start: '07:00', end: '22:00' },
  });
}

describe('the board', () => {
  // Friday 16 October 2026, 15:50 in São Paulo.
  const friday = boardAt('2026-10-16T18:50:00Z');

  it('resolves the days a person names', () => {
    expect(friday.dayOf('hoje')).toBe('2026-10-16');
    expect(friday.dayOf('Amanhã')).toBe('2026-10-17');
    expect(friday.dayOf('depois de amanhã')).toBe('2026-10-18');
    expect(friday.dayOf('segunda-feira')).toBe('2026-10-19');
    expect(friday.dayOf('sábado')).toBe('2026-10-17');
    expect(friday.dayOf('sexta')).toBe('2026-10-16');
    expect(friday.dayOf('2026-10-20')).toBe('2026-10-20');
  });

  it('refuses days out of reach', () => {
    expect(friday.dayOf('2026-10-15')).toBeUndefined();
    expect(friday.dayOf('2026-10-30')).toBeUndefined();
    expect(friday.dayOf('semana que vem')).toBeUndefined();
  });

  it('takes a weekday said on that day to be next week once the day is over', () => {
    // Friday 16 October, 22:30 in São Paulo: the working day is over.
    const late = boardAt('2026-10-17T01:30:00Z');

    expect(late.over('2026-10-16')).toBe(true);
    expect(late.dayOf('sexta')).toBe('2026-10-23');
    expect(late.context(undefined, '')).toContain('working day OVER');
  });

  it('measures the day in the zone it is given, not the machine’s', () => {
    // The same instant is already Saturday in Tokyo.
    const tokyo = boardAt('2026-10-16T18:50:00Z', 'Asia/Tokyo');

    expect(tokyo.dayOf('hoje')).toBe('2026-10-17');
    expect(tokyo.dayLabel('2026-10-19')).toBe('seg 19/10');
  });

  it('names the same thing under another spelling', () => {
    expect(sameTitle('Dentista', 'dentista')).toBe(true);
    expect(sameTitle('Ir ao dentista', 'Dentista')).toBe(true);
    expect(sameTitle('Reunião com a Ana', 'reuniao com a ana')).toBe(true);
    expect(sameTitle('Academia', 'Almoço')).toBe(false);
    expect(sameTitle('Ler', 'Ler artigo sobre filas')).toBe(false);
  });
});
