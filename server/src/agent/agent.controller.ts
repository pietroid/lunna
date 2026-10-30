import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { Trace } from '../common/trace';
import { CatchUpInterceptor } from '../events/catch-up.interceptor';
import { Timeline } from '../events/entities/event.entity';
import { daysOf, owner } from '../events/request';
import { TimelineService } from '../events/timeline.service';
import {
  AgentMessage,
  AgentReply,
  AgentService,
  Subject,
  Suggestion,
} from './agent.service';
import { AgentError, failure } from './agent.errors';
import { Conversation } from './conversation.store';

/** How long a conversation the app may send, in messages. */
const MAX_MESSAGES = 40;

/** How many past conversations one page of history holds, at most. */
const MAX_CONVERSATIONS = 20;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Talking to Lunna about the day.
 *
 * A turn never changes anything: it answers, and may hand back a plan. The
 * plan is applied, and undone, by its own routes, which answer with the whole
 * timeline as every other write does.
 */
@Controller('agent')
@UseGuards(SessionGuard)
@UseInterceptors(CatchUpInterceptor)
export class AgentController {
  constructor(
    private readonly agent: AgentService,
    private readonly timeline: TimelineService,
  ) {}

  @Post('turn')
  async turn(
    @CurrentUser() user: AuthUser,
    @Body()
    dto: {
      conversationId?: unknown;
      messages?: unknown;
      day?: unknown;
      about?: unknown;
      suggestionId?: unknown;
    },
  ): Promise<AgentReply> {
    const trace = Trace.start(user.id, 'agent');
    try {
      if (!this.agent.configured) {
        throw new AgentError(
          'model_down',
          'A Lunna ainda não está conectada a um modelo.',
          HttpStatus.SERVICE_UNAVAILABLE,
        );
      }

      // The blocks are what `ui` encodes; leaks and raw are for evals, and
      // the follow-up is the suggestion's.
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { blocks, leaks, raw, followUp, ...reply } = await this.agent.turn(
        owner(user),
        optionalConversation(dto.conversationId),
        requireMessages(dto.messages),
        typeof dto.day === 'string' ? dto.day : undefined,
        optionalSubject(dto.about),
        trace,
        undefined,
        optionalUuid(dto.suggestionId, 'suggestionId'),
      );
      return reply;
    } catch (error) {
      throw failure(error, trace);
    }
  }

  /**
   * The conversations had before [before] (ISO 8601), most recent first, for
   * the person to read back. Nothing here is ever the agent's context.
   */
  @Get('conversations')
  async conversations(
    @CurrentUser() user: AuthUser,
    @Query('before') before?: string,
    @Query('limit') limit?: string,
  ): Promise<{ conversations: Conversation[] }> {
    const until = before === undefined ? undefined : new Date(before);
    if (until !== undefined && Number.isNaN(until.getTime())) {
      throw new BadRequestException('before must be an ISO 8601 instant');
    }
    const count = limit === undefined ? 10 : Number(limit);
    if (!Number.isInteger(count) || count < 1 || count > MAX_CONVERSATIONS) {
      throw new BadRequestException(
        `limit must be a whole number from 1 to ${MAX_CONVERSATIONS}`,
      );
    }

    return {
      conversations: await this.agent.history(owner(user), until, count),
    };
  }

  @Get('suggestion')
  async suggestion(
    @CurrentUser() user: AuthUser,
  ): Promise<{ suggestion: Suggestion | null }> {
    return { suggestion: (await this.agent.suggestion(owner(user))) ?? null };
  }

  /**
   * The ✕: puts the suggestion away, the welcome for a day and any other
   * until its next one is due.
   */
  @Post('suggestion/:id/dismiss')
  async dismiss(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<{ suggestion: null }> {
    const trace = Trace.start(user.id, 'suggestion');
    try {
      await this.agent.dismiss(owner(user), optionalUuid(id, 'id')!);
      return { suggestion: null };
    } catch (error) {
      throw failure(error, trace);
    }
  }

  /** Makes a plan. Answers with the day and the cards the plan touched. */
  @Post('plans/:id/apply')
  async apply(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline & { touched: string[] }> {
    const trace = Trace.start(user.id, id);
    try {
      const touched = await this.agent.apply(owner(user), id, trace);
      return { ...(await this._day(user, days)), touched };
    } catch (error) {
      throw failure(error, trace);
    }
  }

  @Post('plans/:id/undo')
  async undo(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    const trace = Trace.start(user.id, id);
    try {
      await this.agent.undo(owner(user), id, trace);
      return await this._day(user, days);
    } catch (error) {
      throw failure(error, trace);
    }
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
    const message = item as { role?: unknown; text?: unknown; voice?: unknown };
    if (message.role !== 'user' && message.role !== 'assistant') {
      throw new BadRequestException('role must be user or assistant');
    }
    if (typeof message.text !== 'string' || message.text.trim() === '') {
      throw new BadRequestException('text must be a non-empty string');
    }

    const voice =
      typeof message.voice === 'number' &&
      Number.isFinite(message.voice) &&
      message.voice > 0
        ? Math.min(3600, Math.round(message.voice))
        : undefined;

    return {
      role: message.role,
      text: message.text.slice(0, 4000),
      voiceSeconds: message.role === 'user' ? voice : undefined,
    };
  });

  if (messages[messages.length - 1].role !== 'user') {
    throw new BadRequestException("the last message must be the user's");
  }

  return messages;
}

/** The conversation a turn carries on, or none for the first turn. */
export function optionalConversation(raw: unknown): string | undefined {
  return optionalUuid(raw, 'conversationId');
}

/** [raw] as an id named [name], or none. */
function optionalUuid(raw: unknown, name: string): string | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== 'string' || !UUID.test(raw)) {
    throw new BadRequestException(`${name} must be a UUID`);
  }

  return raw.toLowerCase();
}

/**
 * What the conversation is about, when it was opened from a page: a task's
 * (`{ taskId }`) or an artifact's (`{ artifactId }`).
 */
export function optionalSubject(raw: unknown): Subject | undefined {
  if (raw === undefined || raw === null) return undefined;

  const about = raw as { taskId?: unknown; artifactId?: unknown };
  const { taskId, artifactId } = about;
  if (
    typeof raw !== 'object' ||
    (taskId === undefined) === (artifactId === undefined)
  ) {
    throw new BadRequestException('about must be { taskId } or { artifactId }');
  }
  const id = taskId ?? artifactId;
  if (typeof id !== 'string' || !UUID.test(id)) {
    throw new BadRequestException('about must name a UUID');
  }

  return taskId !== undefined
    ? { taskId: id.toLowerCase() }
    : { artifactId: id.toLowerCase() };
}
