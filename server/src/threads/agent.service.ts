import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Trace } from '../common/trace';

/** Whether running a tool changes anything the user owns. */
export type ToolEffect = 'read' | 'write';

/** What a tool is, as far as the server needs to know. */
export interface ToolDescriptor {
  name: string;
  description: string;
  /**
   * Reported by the agent rather than decided here.
   *
   * The tool knows what it does; the server only needs to know which half of
   * the contract it falls under so the prompt can say so.
   */
  effect: ToolEffect;
}

/** One message as the agent forwards it to the model. */
export interface PromptMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
}

/** What a tool call did. */
export interface ToolTraceEntry {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
  effect: ToolEffect;
  /** The tool's own plain-Portuguese line for this call. */
  summary: string;
  ok: boolean;
  /** True when it was a write the user had not confirmed, so nothing ran. */
  blocked?: boolean;
  result?: unknown;
  error?: string;
  startedAt: string;
  durationMs: number;
}

/** One generation. */
export interface GenerateResult {
  raw: string;
  toolTrace: ToolTraceEntry[];
  model: string;
  latencyMs: number;
  iterations: number;
}

/** Raised when the agent could not answer at all. */
export class AgentUnavailableError extends Error {}

/**
 * The client for the agent container.
 *
 * The split: the agent knows how to get reliable data, the server knows how to
 * present it. So this client sends a prompt the server wrote and gets back
 * text and a record of what the tools did. Nothing about UI crosses the wire in
 * either direction.
 *
 * Failures are raised, not swallowed. The caller owns what the user sees and
 * can say something specific; a placeholder invented down here could only ever
 * be vaguer.
 */
@Injectable()
export class AgentService {
  private _tools?: ToolDescriptor[];
  private _toolsFetchedAt = 0;

  constructor(private readonly _config: ConfigService) {}

  /**
   * The tools the agent currently has, cached briefly.
   *
   * Asked for rather than hard-coded, so adding a tool to the agent changes
   * the prompt on this side without a second edit. The short cache keeps a
   * redeploy of the agent from needing one of the server.
   */
  async tools(trace: Trace): Promise<ToolDescriptor[]> {
    const ttlMs = 60_000;
    if (
      this._tools !== undefined &&
      Date.now() - this._toolsFetchedAt < ttlMs
    ) {
      return this._tools;
    }

    try {
      const response = await this._fetch(
        '/tools',
        undefined,
        trace,
        5_000,
        'GET',
      );
      const data = response as { tools?: ToolDescriptor[] };
      // An agent too old to report effects would otherwise leave every tool
      // undefined, and an undefined effect is not a read.
      this._tools = (data.tools ?? []).map((tool) => ({
        ...tool,
        effect: tool.effect === 'read' ? 'read' : 'write',
      }));
      this._toolsFetchedAt = Date.now();
      trace.log('agent.tools', { count: this._tools.length });
      return this._tools;
    } catch (error) {
      trace.warn('agent.tools.fail', {
        error: error instanceof Error ? error.message : String(error),
      });
      // A stale list beats no list: the turn can still run, it just may not
      // know about a tool added in the last minute.
      return this._tools ?? [];
    }
  }

  /**
   * Runs a prompt with tools and returns the model's text.
   *
   * `allowWrites` is the server's answer to a question only it can answer: has
   * the user authorised a change on this turn. It is passed explicitly on every
   * call, because a default here would be a default about someone's calendar.
   */
  async generate(
    input: {
      userId: string;
      slug: string;
      messages: PromptMessage[];
      allowWrites: boolean;
    },
    trace: Trace,
  ): Promise<GenerateResult> {
    const timeout =
      this._config.get<number>('AGENT_REPLY_TIMEOUT_MS') ?? 90_000;

    return trace.span(
      'agent.generate',
      { messageCount: input.messages.length, allowWrites: input.allowWrites },
      async () =>
        (await this._fetch(
          '/generate',
          input,
          trace,
          timeout,
        )) as GenerateResult,
    );
  }

  private async _fetch(
    path: string,
    body: unknown,
    trace: Trace,
    timeoutMs: number,
    method: 'GET' | 'POST' = 'POST',
  ): Promise<unknown> {
    const agentUrl =
      this._config.get<string>('AGENT_URL') ?? 'http://localhost:3002';

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(`${agentUrl}${path}`, {
        method,
        headers: { 'Content-Type': 'application/json', ...trace.headers },
        body: method === 'GET' ? undefined : JSON.stringify(body),
        signal: controller.signal,
      });

      if (!response.ok) {
        const detail = await response.text().catch(() => '');
        throw new AgentUnavailableError(
          `Agent ${path} returned ${response.status}: ${detail.slice(0, 300)}`,
        );
      }

      return await response.json();
    } catch (error) {
      if (error instanceof AgentUnavailableError) throw error;

      const message = error instanceof Error ? error.message : String(error);
      throw new AgentUnavailableError(`Agent ${path} failed: ${message}`);
    } finally {
      clearTimeout(timeoutId);
    }
  }
}
