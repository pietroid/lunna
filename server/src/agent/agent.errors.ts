import { HttpException, HttpStatus } from '@nestjs/common';
import { Trace } from '../common/trace';
import { ModelEmptyError, ModelUnavailableError } from './openrouter.client';

/**
 * What kind of thing went wrong with a turn or a plan, each of which the app
 * says its own way.
 *
 * - `model_down`: the model did not answer, even asked twice.
 * - `model_empty`: it answered with nothing, twice.
 * - `refused`: the server would not do it, and its message says why.
 * - `drift`: the day changed since the plan, and the plan no longer fits.
 * - `bug`: anything else, ours to fix.
 */
export type FailureKind =
  'model_down' | 'model_empty' | 'refused' | 'drift' | 'bug';

/** A failure that knows its kind. */
export class AgentError extends HttpException {
  constructor(kind: FailureKind, message: string, status: HttpStatus) {
    super({ message, kind }, status);
  }
}

/**
 * [error] as the app is told it: `{ message, kind, traceId }`, so a refusal
 * keeps its words, every other kind gets its own line, and the trace can be
 * found from the screen.
 */
export function failure(error: unknown, trace: Trace): HttpException {
  let kind: FailureKind;
  let message: string;
  let status: number;

  if (error instanceof ModelUnavailableError) {
    trace.warn('agent.modelDown', { error: error.message });
    [kind, status] = ['model_down', HttpStatus.SERVICE_UNAVAILABLE];
    message = 'Não consegui falar com o modelo agora, nem tentando duas vezes.';
  } else if (error instanceof ModelEmptyError) {
    trace.warn('agent.modelEmpty');
    [kind, status] = ['model_empty', HttpStatus.BAD_GATEWAY];
    message = 'O modelo respondeu em branco, duas vezes.';
  } else if (error instanceof HttpException) {
    const body = error.getResponse() as
      string | { message?: string | string[]; kind?: FailureKind };
    status = error.getStatus();
    kind =
      typeof body === 'object' && body.kind !== undefined
        ? body.kind
        : status < 500
          ? 'refused'
          : 'bug';
    const said = typeof body === 'string' ? body : body.message;
    message = Array.isArray(said) ? said.join(' ') : (said ?? error.message);
  } else {
    trace.warn('agent.bug', {
      error: error instanceof Error ? error.message : String(error),
    });
    [kind, status] = ['bug', HttpStatus.INTERNAL_SERVER_ERROR];
    message = 'Algo deu errado do meu lado. Ficou registrado.';
  }

  return new HttpException({ message, kind, traceId: trace.id }, status);
}
