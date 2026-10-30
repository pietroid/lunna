import { CalendarUser } from '../calendar/calendar.types';
import { EventLayoutService } from '../events/event-layout.service';
import { AgentService } from './agent.service';
import { SuggestionTimer } from './suggestion.timer';

/** A timer whose people are known without a database. */
class TestTimer extends SuggestionTimer {
  protected _user(userId: string): Promise<CalendarUser | undefined> {
    return Promise.resolve({ id: userId } as CalendarUser);
  }
}

describe('the suggestion timer', () => {
  const NOW = new Date('2026-03-10T13:00:00Z');
  let agent: {
    onNextAt?: (userId: string, at: Date) => void;
    suggestion: jest.Mock;
    pendingSuggestions: jest.Mock;
  };
  let layout: { catchUp: jest.Mock };
  let timer: TestTimer;

  beforeEach(() => {
    jest.useFakeTimers({ now: NOW });
    agent = {
      suggestion: jest.fn(() => Promise.resolve(undefined)),
      pendingSuggestions: jest.fn(() =>
        Promise.resolve([
          { userId: 'a', nextAt: new Date('2026-03-10T16:00:00Z') },
          { userId: 'b', nextAt: new Date('2026-03-11T13:00:00Z') },
        ]),
      ),
    };
    layout = { catchUp: jest.fn(() => Promise.resolve([])) };
    timer = new TestTimer(
      agent as unknown as AgentService,
      layout as unknown as EventLayoutService,
    );
  });

  afterEach(() => {
    timer.onModuleDestroy();
    jest.useRealTimers();
  });

  it('re-arms every next suggestion at boot, and writes each at its hour', async () => {
    await timer.onApplicationBootstrap();
    expect(timer.armed).toBe(2);

    await jest.advanceTimersByTimeAsync(3 * 3_600_000);
    expect(layout.catchUp).toHaveBeenCalledTimes(1);
    expect(agent.suggestion).toHaveBeenCalledWith(
      { id: 'a' },
      new Date('2026-03-10T16:00:00Z'),
    );
    expect(timer.armed).toBe(1);
  });

  it('keeps one timer per person, the last written', async () => {
    agent.onNextAt!('a', new Date('2026-03-10T14:00:00Z'));
    agent.onNextAt!('a', new Date('2026-03-10T18:00:00Z'));
    expect(timer.armed).toBe(1);

    await jest.advanceTimersByTimeAsync(3_600_000);
    expect(agent.suggestion).not.toHaveBeenCalled();
    await jest.advanceTimersByTimeAsync(4 * 3_600_000);
    expect(agent.suggestion).toHaveBeenCalledTimes(1);
  });
});
