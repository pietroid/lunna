import { Injectable } from '@nestjs/common';
import { Trace } from '../common/trace';

/** Why the calendar is not saying what the screen says. */
export interface SyncFailure {
  /** The block whose hour did not make it across, as the user reads it. */
  title: string;
  /** The raw error, for the trace. Never shown to anyone. */
  error: string;
}

/** One piece of work: make Google hold what the screen is showing. */
type SyncJob = () => Promise<void>;

/**
 * The calendar, kept up to date behind the user's back.
 *
 * Google is the truth about when things happen, and a drag still has to feel
 * like a drag. So the cached day is written first and answers the request,
 * and the write to Google runs from here, behind the response. What makes
 * that safe is that a job is not an instruction but a reconciliation: it
 * pushes the hour the cache now holds, so two drags of the same card queue
 * two jobs that both end at the same place and there is no order to get
 * wrong.
 *
 * Jobs run one at a time per person, in the order they arrived, because two
 * writes to the same event at once is how one of them is lost.
 *
 * When one fails the failure is kept rather than thrown: the request that
 * queued it has long since answered. The app asks for it on [settle], and the
 * user gets a popup and a retry.
 */
@Injectable()
export class CalendarSyncService {
  /** The tail of each person's queue. Awaiting it awaits everything before. */
  private readonly _queues = new Map<string, Promise<void>>();

  /** The last failure since anyone asked, per person. */
  private readonly _failures = new Map<string, SyncFailure>();

  /** Everything that failed, kept so a retry has something to run again. */
  private readonly _pending = new Map<string, Map<string, SyncJob>>();

  /**
   * Queues [job] and returns at once.
   *
   * Nothing waits on the result here, which is the whole point: the caller
   * has a request to answer and the calendar is not on its critical path.
   *
   * [key] names what the job is about, normally an event id. One job per key
   * is kept on failure, because an older push of the same event would only
   * write the same hour twice.
   */
  enqueue(
    userId: string,
    key: string,
    title: string,
    job: SyncJob,
    trace: Trace,
  ): void {
    const previous = this._queues.get(userId) ?? Promise.resolve();

    const next = previous.then(async () => {
      try {
        await job();
        this._forget(userId, key);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        trace.error('calendar.sync.fail', { key, error: message });

        this._failures.set(userId, { title, error: message });
        this._remember(userId, key, job);
      }
    });

    this._queues.set(userId, next);
  }

  /**
   * Waits for the queue to empty and reports the first failure in it.
   *
   * The app calls this straight after a drag, off the path the finger is on.
   * It usually returns nothing a moment later and the user never learns that
   * any of this happened, which is the point.
   */
  async settle(userId: string): Promise<SyncFailure | undefined> {
    await (this._queues.get(userId) ?? Promise.resolve());

    const failure = this._failures.get(userId);
    this._failures.delete(userId);

    return failure;
  }

  /**
   * Runs everything that failed again, and says how it went.
   *
   * The jobs are the same closures that failed, and they read the cached day
   * fresh, so a retry after three more drags pushes the day as it is now
   * rather than as it was when Google first refused.
   */
  async retry(userId: string, trace: Trace): Promise<SyncFailure | undefined> {
    const pending = [...(this._pending.get(userId)?.entries() ?? [])];
    trace.log('calendar.sync.retry', { jobs: pending.length });

    for (const [key, job] of pending) {
      this.enqueue(userId, key, key, job, trace);
    }

    return this.settle(userId);
  }

  /** Whether anything is still waiting to reach Google. */
  hasPending(userId: string): boolean {
    return (this._pending.get(userId)?.size ?? 0) > 0;
  }

  private _remember(userId: string, key: string, job: SyncJob): void {
    const jobs = this._pending.get(userId) ?? new Map<string, SyncJob>();
    jobs.set(key, job);
    this._pending.set(userId, jobs);
  }

  private _forget(userId: string, key: string): void {
    this._pending.get(userId)?.delete(key);
  }
}
