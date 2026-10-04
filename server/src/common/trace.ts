import { randomBytes } from 'crypto';

/** The header that carries a trace id to the agent. */
export const TRACE_HEADER = 'x-focus-trace-id';

/** One recorded step of a turn. */
export interface TraceEvent {
  ts: string;
  event: string;
  durationMs?: number;
  data: Record<string, unknown>;
}

/** Who and what a trace belongs to. */
export interface TraceFields {
  traceId: string;
  userId?: string;
  slug?: string;
}

/**
 * The record of one turn, from tap to rendered reply.
 *
 * A turn crosses two processes and four transformations: prompt, model, tool,
 * parse, validate. When the result looks wrong, the useful question is almost
 * always "which of those changed it", and that is unanswerable from
 * interleaved logs of two containers. So every step writes one JSON line
 * keyed by the same id, the agent logs under it too, and the whole sequence is
 * kept so it can be read back after the fact.
 */
export class Trace {
  private readonly _events: TraceEvent[] = [];
  private readonly _startedAt = Date.now();

  constructor(private readonly _fields: TraceFields) {}

  /** A new trace for a turn. */
  static start(userId: string, slug?: string): Trace {
    return new Trace({ traceId: newTraceId(), userId, slug });
  }

  get id(): string {
    return this._fields.traceId;
  }

  /** How long the turn has been running. */
  get elapsedMs(): number {
    return Date.now() - this._startedAt;
  }

  /** Everything recorded so far, in order. */
  get events(): TraceEvent[] {
    return [...this._events];
  }

  /** Binds the trace to a thread once its slug is known. */
  attachSlug(slug: string): void {
    this._fields.slug = slug;
  }

  /** Headers that carry this trace to another service. */
  get headers(): Record<string, string> {
    return { [TRACE_HEADER]: this.id };
  }

  log(event: string, data: Record<string, unknown> = {}): void {
    this._record('info', event, data);
  }

  warn(event: string, data: Record<string, unknown> = {}): void {
    this._record('warn', event, data);
  }

  error(event: string, data: Record<string, unknown> = {}): void {
    this._record('error', event, data);
  }

  /** Times [work], recording both the start and the outcome. */
  async span<T>(
    event: string,
    data: Record<string, unknown>,
    work: () => Promise<T>,
  ): Promise<T> {
    const started = Date.now();
    this.log(`${event}.start`, data);

    try {
      const result = await work();
      this._record('info', `${event}.ok`, data, Date.now() - started);
      return result;
    } catch (error) {
      this._record(
        'error',
        `${event}.fail`,
        {
          ...data,
          error: error instanceof Error ? error.message : String(error),
        },
        Date.now() - started,
      );
      throw error;
    }
  }

  private _record(
    level: 'info' | 'warn' | 'error',
    event: string,
    data: Record<string, unknown>,
    durationMs?: number,
  ): void {
    const entry: TraceEvent = {
      ts: new Date().toISOString(),
      event,
      durationMs,
      data,
    };
    this._events.push(entry);

    const line = JSON.stringify({
      ts: entry.ts,
      level,
      svc: 'server',
      event,
      ...this._fields,
      ...(durationMs === undefined ? {} : { durationMs }),
      ...data,
    });

    if (level === 'error') {
      console.error(line);
      return;
    }
    console.log(line);
  }
}

/** A short, sortable, unique trace id. */
export function newTraceId(): string {
  return `t_${Date.now().toString(36)}_${randomBytes(4).toString('hex')}`;
}
