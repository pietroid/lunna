import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  ServiceUnavailableException,
  UseGuards,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { Trace } from '../common/trace';
import { Timeline } from '../events/entities/event.entity';
import { daysOf, owner } from '../events/request';
import { TimelineService } from '../events/timeline.service';
import {
  AgentMessage,
  AgentReply,
  AgentService,
  Suggestion,
} from './agent.service';
import { ModelUnavailableError } from './openrouter.client';

/** How long a conversation the app may send, in messages. */
const MAX_MESSAGES = 40;

/**
 * Talking to Lunna about the day.
 *
 * A turn never changes anything: it answers, and may hand back a plan. The
 * plan is applied, and undone, by its own routes, which answer with the whole
 * timeline as every other write does.
 */
@Controller('agent')
@UseGuards(SessionGuard)
export class AgentController {
  constructor(
    private readonly agent: AgentService,
    private readonly timeline: TimelineService,
  ) {}

  @Post('turn')
  async turn(
    @CurrentUser() user: AuthUser,
    @Body() dto: { messages?: unknown; day?: unknown },
  ): Promise<AgentReply> {
    if (!this.agent.configured) {
      throw new ServiceUnavailableException(
        'A Lunna ainda não está conectada a um modelo.',
      );
    }

    const trace = Trace.start(user.id, 'agent');
    try {
      return await this.agent.turn(
        owner(user),
        requireMessages(dto.messages),
        typeof dto.day === 'string' ? dto.day : undefined,
        trace,
      );
    } catch (error) {
      if (error instanceof ModelUnavailableError) {
        trace.warn('agent.unavailable', { error: error.message });
        throw new ServiceUnavailableException(
          'Não consegui falar com a Lunna agora. Tente de novo em instantes.',
        );
      }
      throw error;
    }
  }

  @Get('suggestion')
  async suggestion(
    @CurrentUser() user: AuthUser,
  ): Promise<{ suggestion: Suggestion | null }> {
    return { suggestion: (await this.agent.suggestion(owner(user))) ?? null };
  }

  /** Makes a plan. Answers with the day and the cards the plan touched. */
  @Post('plans/:id/apply')
  async apply(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline & { touched: string[] }> {
    const touched = await this.agent.apply(
      owner(user),
      id,
      Trace.start(user.id, id),
    );

    return { ...(await this._day(user, days)), touched };
  }

  @Post('plans/:id/undo')
  async undo(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.agent.undo(owner(user), id, Trace.start(user.id, id));

    return this._day(user, days);
  }

  private async _day(user: AuthUser, days?: string): Promise<Timeline> {
    return this.timeline.view(
      await this.timeline.day(owner(user), daysOf(days)),
    );
  }
}

/** The conversation, refusing anything that is not one. */
export function requireMessages(raw: unknown): AgentMessage[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new BadRequestException('messages must be a non-empty array');
  }

  const messages = raw.slice(-MAX_MESSAGES).map((item): AgentMessage => {
    const message = item as { role?: unknown; text?: unknown };
    if (message.role !== 'user' && message.role !== 'assistant') {
      throw new BadRequestException('role must be user or assistant');
    }
    if (typeof message.text !== 'string' || message.text.trim() === '') {
      throw new BadRequestException('text must be a non-empty string');
    }

    return { role: message.role, text: message.text.slice(0, 4000) };
  });

  if (messages[messages.length - 1].role !== 'user') {
    throw new BadRequestException("the last message must be the user's");
  }

  return messages;
}
