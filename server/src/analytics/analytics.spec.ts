import {
  BadRequestException,
  CallHandler,
  ExecutionContext,
  InternalServerErrorException,
} from '@nestjs/common';
import { lastValueFrom, of, throwError } from 'rxjs';
import { LoggingInterceptor } from '../common/logging.interceptor';
import { Analytics, NoAnalytics, analyticsFrom } from './analytics';
import { eventFor, routeOf } from './events';

class FakeAnalytics implements Analytics {
  readonly events: { userId: string; event: string; properties?: object }[] =
    [];
  readonly exceptions: {
    error: unknown;
    userId?: string;
    properties: object;
  }[] = [];

  capture(userId: string, event: string, properties?: object): void {
    this.events.push({ userId, event, properties });
  }

  captureException(
    error: unknown,
    userId: string | undefined,
    properties: object,
  ): void {
    this.exceptions.push({ error, userId, properties });
  }

  async shutdown(): Promise<void> {}
}

function contextFor(
  method: string,
  path: string,
  url: string,
  status = 200,
  userId: string | null = 'user-1',
): ExecutionContext {
  const req = {
    method,
    originalUrl: url,
    url,
    query: {},
    body: { title: 'Consulta com a Dra. Ana', notes: 'senha do portão' },
    route: { path },
    user: userId ? { id: userId } : undefined,
  };
  const res = { statusCode: status };
  return {
    switchToHttp: () => ({ getRequest: () => req, getResponse: () => res }),
  } as unknown as ExecutionContext;
}

const answering = (value: unknown): CallHandler => ({
  handle: () => of(value),
});
const failing = (error: unknown): CallHandler => ({
  handle: () => throwError(() => error),
});

describe('analytics', () => {
  let analytics: FakeAnalytics;
  let interceptor: LoggingInterceptor;

  beforeEach(() => {
    analytics = new FakeAnalytics();
    interceptor = new LoggingInterceptor(analytics);
    jest.spyOn(interceptor['logger'], 'log').mockImplementation(() => {});
    jest.spyOn(interceptor['logger'], 'error').mockImplementation(() => {});
  });

  it('counts a write that succeeded as the person’s event', async () => {
    await lastValueFrom(
      interceptor.intercept(
        contextFor('POST', '/api/tasks/:id/done', '/api/tasks/t-9/done?days=3'),
        answering({}),
      ),
    );

    expect(analytics.events).toEqual([
      {
        userId: 'user-1',
        event: 'task_done',
        properties: { route: '/tasks/:id/done', status: 200 },
      },
    ]);
    expect(analytics.exceptions).toEqual([]);
  });

  it('sends nothing the person wrote', async () => {
    await lastValueFrom(
      interceptor.intercept(
        contextFor('POST', '/api/tasks', '/api/tasks?days=3', 201),
        answering({}),
      ),
    );

    const sent = JSON.stringify(analytics.events);
    expect(sent).not.toContain('Consulta');
    expect(sent).not.toContain('senha');
    expect(sent).not.toContain('days=');
  });

  it('counts no read', async () => {
    await lastValueFrom(
      interceptor.intercept(
        contextFor('GET', '/api/tasks/done', '/api/tasks/done?q=médico'),
        answering({}),
      ),
    );

    expect(analytics.events).toEqual([]);
  });

  it('counts nothing without a person', async () => {
    await lastValueFrom(
      interceptor.intercept(
        contextFor('POST', '/api/tasks', '/api/tasks', 201, null),
        answering({}),
      ),
    );

    expect(analytics.events).toEqual([]);
  });

  it('reports a 5xx as an exception, with the route and the person', async () => {
    const error = new InternalServerErrorException('boom');

    await expect(
      lastValueFrom(
        interceptor.intercept(
          contextFor('POST', '/api/tasks/:id/start', '/api/tasks/t-1/start'),
          failing(error),
        ),
      ),
    ).rejects.toBe(error);

    expect(analytics.exceptions).toEqual([
      {
        error,
        userId: 'user-1',
        properties: {
          method: 'POST',
          route: '/tasks/:id/start',
          status: 500,
        },
      },
    ]);
    expect(analytics.events).toEqual([]);
  });

  it('reports an error with no status as a 500', async () => {
    const error = new TypeError('undefined is not a function');

    await expect(
      lastValueFrom(
        interceptor.intercept(
          contextFor('GET', '/api/timeline', '/api/timeline?days=3'),
          failing(error),
        ),
      ),
    ).rejects.toBe(error);

    expect(analytics.exceptions).toHaveLength(1);
    expect(analytics.exceptions[0].properties).toMatchObject({ status: 500 });
  });

  it('does not report a refusal', async () => {
    const error = new BadRequestException('Esse horário já passou.');

    await expect(
      lastValueFrom(
        interceptor.intercept(
          contextFor('POST', '/api/tasks/:id/start', '/api/tasks/t-1/start'),
          failing(error),
        ),
      ),
    ).rejects.toBe(error);

    expect(analytics.exceptions).toEqual([]);
    expect(analytics.events).toEqual([]);
  });

  it('names events by the declared route, without the prefix', () => {
    expect(routeOf('/api/agent/plans/:id/apply')).toBe(
      '/agent/plans/:id/apply',
    );
    expect(eventFor('post', '/agent/plans/:id/apply')).toBe('plan_applied');
    expect(eventFor('DELETE', '/tasks/:id')).toBe('task_deleted');
    expect(eventFor('GET', '/timeline')).toBeUndefined();
    expect(eventFor('POST', undefined)).toBeUndefined();
  });

  it('is off without a key', () => {
    expect(analyticsFrom({})).toBeInstanceOf(NoAnalytics);
    expect(analyticsFrom({ POSTHOG_KEY: '  ' })).toBeInstanceOf(NoAnalytics);
  });
});
