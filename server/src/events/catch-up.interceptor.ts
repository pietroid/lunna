import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Request } from 'express';
import { from, Observable } from 'rxjs';
import { switchMap } from 'rxjs/operators';
import { AuthUser } from '../auth/auth.tokens';
import { Trace } from '../common/trace';
import { EventLayoutService } from './event-layout.service';
import { owner } from './request';

/**
 * Settles what the clock changed before a route reads the day.
 *
 * Nothing on the server runs on a timer that touches Postgres, so Neon can
 * sleep while nobody looks. Whatever changed with the clock (a paused
 * block's end, a task whose hour ran out, a routine's day nobody began) is
 * stored as when it happened and settled here, on the next request of that
 * person, before the handler reads or writes their day. Bound with
 * `@UseInterceptors` on every controller that reads the day; it runs after
 * [SessionGuard], which has put the person on the request.
 */
@Injectable()
export class CatchUpInterceptor implements NestInterceptor {
  constructor(private readonly layout: EventLayoutService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const { user } = context
      .switchToHttp()
      .getRequest<Request & { user?: AuthUser }>();
    if (user === undefined) return next.handle();

    return from(this.layout.catchUp(owner(user), Trace.start(user.id))).pipe(
      switchMap(() => next.handle()),
    );
  }
}
