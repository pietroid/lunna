import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Request } from 'express';
import { Observable, throwError } from 'rxjs';
import { catchError, tap } from 'rxjs/operators';

interface RequestWithUser extends Request {
  user?: { uid?: string };
}

/**
 * Logs every HTTP request/response pair with timing, user id, status code and
 * errors. This is the main server observability surface: keep it verbose.
 */
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const http = context.switchToHttp();
    const req = http.getRequest<RequestWithUser>();
    const res = http.getResponse();

    const start = Date.now();
    const userId = req.user?.uid ?? 'anonymous';
    const method = req.method;
    const url = req.originalUrl ?? req.url;

    const logContext = {
      method,
      url,
      userId,
      query: req.query,
      body: this._sanitizeBody(req.body),
    };

    this.logger.log(`>> ${method} ${url} - user=${userId}`, logContext);

    return next.handle().pipe(
      tap(() => {
        const duration = Date.now() - start;
        const status = res.statusCode;
        this.logger.log(
          `<< ${method} ${url} - user=${userId} status=${status} duration=${duration}ms`,
        );
      }),
      catchError((error) => {
        const duration = Date.now() - start;
        const status = error.status ?? res.statusCode ?? 500;
        const message = error.message ?? String(error);
        const stack = error.stack;

        this.logger.error(
          `<< ${method} ${url} - user=${userId} status=${status} duration=${duration}ms error=${message}`,
          stack,
        );

        return throwError(() => error);
      }),
    );
  }

  private _sanitizeBody(body: unknown): unknown {
    if (body === null || typeof body !== 'object') return body;

    const clone = { ...(body as Record<string, unknown>) };
    for (const key of Object.keys(clone)) {
      if (/token|password|secret|key|authorization/i.test(key)) {
        clone[key] = '<redacted>';
      }
    }
    return clone;
  }
}
