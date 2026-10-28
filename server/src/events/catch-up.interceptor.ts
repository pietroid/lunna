import {
  CallHandler,
  ExecutionContext,
  Inject,
  Injectable,
  NestInterceptor,
  Optional,
} from '@nestjs/common';
import { Request } from 'express';
import { from, Observable } from 'rxjs';
import { switchMap } from 'rxjs/operators';
import { ANALYTICS, NoAnalytics } from '../analytics/analytics';
import type { Analytics } from '../analytics/analytics';
import { SILENT_CLOSE_EVENT } from '../analytics/events';
import { AuthUser } from '../auth/auth.tokens';
import { Trace } from '../common/trace';
import { EventLayoutService } from './event-layout.service';
import { owner } from './request';

/**
 * Settles what the clock changed before a route reads the day.
 *
 * Nothing on the server runs on a timer that touches Postgres, so Neon can
 * sleep while nobody looks. Whatever changed with the clock (a paused
 * block's end, a block that ran past its end with nobody answering) is
 * stored as when it happened and settled here, on the next request of that
 * person, before the handler reads or writes their day. Bound with
 * `@UseInterceptors` on every controller that reads the day; it runs after
 * [SessionGuard], which has put the person on the request.
 */
@Injectable()
export class CatchUpInterceptor implements NestInterceptor {
  constructor(
    private readonly layout: EventLayoutService,
    @Optional()
    @Inject(ANALYTICS)
    private readonly analytics: Analytics = new NoAnalytics(),
  ) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const { user } = context
      .switchToHttp()
      .getRequest<Request & { user?: AuthUser }>();
    if (user === undefined) return next.handle();

    return from(this.layout.catchUp(owner(user), Trace.start(user.id))).pipe(
      switchMap((closed) => {
        for (const { kind, overMinutes } of closed) {
          this.analytics.capture(user.id, SILENT_CLOSE_EVENT, {
            kind,
            overMinutes,
          });
        }
        return next.handle();
      }),
    );
  }
}
