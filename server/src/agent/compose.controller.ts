import {
  BadRequestException,
  Body,
  Controller,
  HttpStatus,
  Post,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { Trace } from '../common/trace';
import { CatchUpInterceptor } from '../events/catch-up.interceptor';
import { owner } from '../events/request';
import { optionalSubject } from './agent.controller';
import { AgentError, failure } from './agent.errors';
import { ComposeDraft, ComposeService } from './compose';
import { OpenRouterClient } from './openrouter.client';

/** The longest line the composer reads. */
const MAX_TEXT = 2000;

/**
 * The composer's one route: a line read into a draft. Writes nothing; the
 * app writes the draft through the routes the old sheet used.
 */
@Controller('agent')
@UseGuards(SessionGuard)
@UseInterceptors(CatchUpInterceptor)
export class ComposeController {
  constructor(
    private readonly compose: ComposeService,
    private readonly model: OpenRouterClient,
  ) {}

  @Post('compose')
  async read(
    @CurrentUser() user: AuthUser,
    @Body() dto: { text?: unknown; about?: unknown },
  ): Promise<{ draft: ComposeDraft }> {
    const trace = Trace.start(user.id, 'compose');
    const text = typeof dto.text === 'string' ? dto.text.trim() : '';
    if (text === '') {
      throw new BadRequestException('Escreva ou diga o que anotar.');
    }
    if (text.length > MAX_TEXT) {
      throw new BadRequestException('Isso é longo demais para uma anotação.');
    }
    const about = optionalSubject(dto.about);
    try {
      if (!this.model.configured) {
        throw new AgentError(
          'model_down',
          'A Lunna ainda não está conectada a um modelo.',
          HttpStatus.SERVICE_UNAVAILABLE,
        );
      }
      return {
        draft: await this.compose.read(owner(user), text, about, trace),
      };
    } catch (error) {
      throw failure(error, trace);
    }
  }
}
