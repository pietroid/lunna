import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/** One chat message, as OpenRouter's OpenAI-compatible API takes it. */
export interface ChatMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
  tool_call_id?: string;
  tool_calls?: ToolCall[];
}

/** One tool call the model asked for. */
export interface ToolCall {
  id: string;
  type: 'function';
  function: {
    name: string;
    /** JSON-encoded arguments, as the model emitted them. */
    arguments: string;
  };
}

/** A tool, as the model sees it. */
export interface ToolDefinition {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}

/** What one generation came back with. */
export type ModelOutcome =
  | { kind: 'final'; content: string }
  | { kind: 'tool_calls'; toolCalls: ToolCall[] };

/** Raised when OpenRouter could not answer, or is not configured. */
export class ModelUnavailableError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
  ) {
    super(message);
  }
}

/**
 * The model, through OpenRouter's chat completions API.
 *
 * Ported from Focus's agent, where it lived in its own container. Here it is
 * one call inside the server: Lunna's agent has two tools and both are the
 * server's own services, so there is nothing a second process would own.
 */
@Injectable()
export class OpenRouterClient {
  private readonly _url = 'https://openrouter.ai/api/v1/chat/completions';

  constructor(private readonly _config: ConfigService) {}

  /** Whether there is a key and a model to call. */
  get configured(): boolean {
    return this._apiKey !== '' && this.model !== '';
  }

  get model(): string {
    return this._config.get<string>('OPENROUTER_MODEL') ?? '';
  }

  private get _apiKey(): string {
    return this._config.get<string>('OPENROUTER_API_KEY') ?? '';
  }

  async generate(
    messages: ChatMessage[],
    tools: ToolDefinition[],
  ): Promise<ModelOutcome> {
    if (!this.configured) {
      throw new ModelUnavailableError('OpenRouter is not configured');
    }

    const response = await fetch(this._url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this._apiKey}`,
        'HTTP-Referer': 'https://lunna.pietroteruya.dev',
        'X-Title': 'Lunna',
      },
      body: JSON.stringify({
        model: this.model,
        messages,
        ...(tools.length > 0 ? { tools, tool_choice: 'auto' } : {}),
        temperature: 0.3,
      }),
      signal: AbortSignal.timeout(60_000),
    });

    const data = (await response.json()) as Record<string, unknown>;
    if (!response.ok) {
      const error = data.error as { message?: string } | undefined;
      throw new ModelUnavailableError(
        error?.message ?? `OpenRouter returned ${response.status}`,
        response.status,
      );
    }

    const choice = (data.choices as Record<string, unknown>[] | undefined)?.[0];
    const message = choice?.message as Record<string, unknown> | undefined;

    if (Array.isArray(message?.tool_calls) && message.tool_calls.length > 0) {
      return { kind: 'tool_calls', toolCalls: toolCallsOf(message.tool_calls) };
    }

    const content = message?.content;
    if (typeof content !== 'string') {
      throw new ModelUnavailableError('OpenRouter returned an empty reply');
    }

    return { kind: 'final', content };
  }
}

function toolCallsOf(value: unknown[]): ToolCall[] {
  return value.flatMap((item) => {
    const call = item as Record<string, unknown>;
    const fn = call.function as Record<string, unknown> | undefined;
    if (typeof call.id !== 'string' || fn === undefined) return [];

    return [
      {
        id: call.id,
        type: 'function' as const,
        function: {
          name: typeof fn.name === 'string' ? fn.name : '',
          arguments: typeof fn.arguments === 'string' ? fn.arguments : '{}',
        },
      },
    ];
  });
}
