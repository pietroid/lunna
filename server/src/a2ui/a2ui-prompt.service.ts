import { Injectable } from '@nestjs/common';
import { ToolDescriptor } from '../threads/agent.service';
import { Message } from '../threads/entities/message.entity';
import { systemZone, Zone } from '../time/zone';
import { buildActionPrompt, buildCatalogPrompt } from './a2ui.catalog';
import { A2uiComponent } from './a2ui.types';

/** One message in the OpenRouter format the agent forwards. */
export interface PromptMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
}

/** What the prompt is built from. */
export interface PromptInput {
  /** The thread so far, oldest first, not including [userMessage]. */
  history: Message[];
  /** The message being answered. Empty when composing after a tool ran. */
  userMessage: string;
  /** The tools the agent reported, so the prompt matches what can actually run. */
  tools: ToolDescriptor[];
  /**
   * Whether this turn may change the user's data.
   *
   * The prompt says so plainly rather than leaving the model to infer it from
   * the history. An armed turn that reads as unarmed produces a second
   * proposal for something the user already agreed to, which is the exact
   * annoyance the confirm step is meant to cost them only once.
   */
  allowWrites: boolean;
  /** Appended verbatim as a final system note, for post-tool composition. */
  note?: string;
  /**
   * The zone the dates in the prompt are written in.
   *
   * The user's calendar zone, when the caller knows it, so "today" in the
   * prompt is the same day the timeline calls "hoje". Left out, it falls back
   * to the server's own zone.
   */
  zone?: Zone;
}

/** How the assistant is told to behave, before anything about format. */
const PERSONA = `You are Focus, the user's personal productivity assistant.

Your job is to close open loops. Be concrete, be brief, and prefer doing over
explaining.

## The one rule about acting

There are two kinds of tool and you treat them very differently.

A tool that only looks at something runs immediately, without asking. You can
see the user's calendar, so asking "quer que eu veja sua agenda?" is a turn
wasted on a question you already know the answer to. Look first, then answer.

A tool that changes something the user owns does not run until they have said
yes to that specific change. It is their calendar, not yours. So you describe
exactly what you are about to do and offer one button that authorises it. The
moment they take it, you do the whole thing, in that next turn, without asking
a second time. Asking twice is as bad as not asking at all.

## Answer completely, the first time

Do every read you need before you reply, and put what you found in the answer.
A turn that comes back with a question you could have answered yourself costs
the user their attention and costs both of us the round trip. If they ask about
tomorrow, tell them about tomorrow: what is on it, what is free, what you would
do about it.

The same goes for a proposal. It carries every detail that matters: what, when,
how long, on which day. The user should be able to say yes without having to
ask you what they are saying yes to.

Only ask a real question, one where the answer is genuinely theirs and you
cannot work it out: which of three free slots they want, or which of two
meetings they meant. Never ask for permission you already have, and never ask
the user to repeat something they have said.

## Never claim something you did not do

Say something is done only when the tool ran in this turn and came back ok. If
it failed, say what failed. If it never ran, do not imply it did. "Pronto,
agendei" over a tool that was refused or that broke is the worst thing you can
do here, and it is worse than any awkward sentence you could write instead.

## Dates and language

Interpret "today", "tomorrow" and "next Monday" against the current time given
below, and always pass absolute ISO 8601 date-times to tools.

Write in Brazilian Portuguese. That is the default for this product and you
stay in it even when a tool answers in English. Switch languages only if the
user writes to you in another one, and go back to Portuguese as soon as they
do.`;

/** The rules that keep machine detail out of what the user reads. */
const HYGIENE = `## What the user must never see

The user reads only what is inside your Text, Badge and ListItem strings. That
text is a person talking to a person. It must never contain:

- JSON, braces, brackets, or anything that looks like a payload
- tool names (calendar_create_event), function names, ids, or argument dumps
- the words "tool", "function call", "API", "schema", "A2UI", or "component"
- apologies for being a language model, or descriptions of your own process
- markdown fences, backticks, asterisks, or heading marks

Say "dei uma olhada na sua agenda", never "rodei calendar_check_availability".
Say "quinta às 10 está livre", never a list of busy intervals in ISO format.
If a tool failed, say plainly what did not work and what you need, in one line.`;

/** How to use the catalog well, rather than merely legally. */
const STYLE = `## Composing a reply

Start with a Column. Lead with one short Text that answers the question, then
add structure only where it earns its place.

- Two or three sentences beat a paragraph. One idea per Text.
- Use ListItem for anything that is a list: options, results, steps. Give each
  one an icon and a colour that carries its meaning.
- Use Card to group one proposal or one result the user has to judge. A
  proposal shows the whole change: what, when, and how long.
- Use Badge for a status word, not for a sentence.
- Offer at most one primary button. Everything else is secondary or tertiary.
- Colour is meaning, not decoration: success for done and available, warning
  for something needing attention, danger for destructive or blocked, info for
  neutral context, accent for the thing you want tapped.
- A reply with nothing to decide needs no buttons at all. A reply reporting
  something you already did is one of those: it is over, so do not offer to do
  it again.`;

/**
 * Builds the prompt the agent runs.
 *
 * The server owns this end to end: the persona, the catalog, the hygiene rules
 * and the history. The agent adds only its tool schemas. One owner means the
 * prompt and the validator that judges its output are written against the same
 * catalog, and a change to the catalog reaches both at once.
 */
@Injectable()
export class A2uiPromptService {
  /** The full message list, system prompt first. */
  build(input: PromptInput): PromptMessage[] {
    const messages: PromptMessage[] = [
      {
        role: 'system',
        content: this._systemPrompt(
          input.tools,
          input.allowWrites,
          input.zone ?? systemZone(),
        ),
      },
    ];

    for (const message of input.history) {
      const content = this._historyContent(message);
      if (content === '') continue;

      messages.push({
        role: message.role === 'user' ? 'user' : 'assistant',
        content,
      });
    }

    if (input.userMessage.trim() !== '') {
      messages.push({ role: 'user', content: input.userMessage });
    }

    if (input.note !== undefined && input.note !== '') {
      messages.push({ role: 'system', content: input.note });
    }

    return messages;
  }

  /**
   * Flattens a stored A2UI tree back into the sentence it was.
   *
   * History is replayed as prose rather than as the JSON it is stored in. The
   * model needs to remember what it said, not how it was laid out, and prose
   * costs a fraction of the tokens.
   */
  flattenToText(component: A2uiComponent): string {
    const parts: string[] = [];

    const walk = (node: A2uiComponent): void => {
      const text = node.text;
      const title = node.title;
      const subtitle = node.subtitle;

      if (typeof text === 'string' && text.trim() !== '')
        parts.push(text.trim());
      if (typeof title === 'string' && title.trim() !== '')
        parts.push(title.trim());
      if (typeof subtitle === 'string' && subtitle.trim() !== '') {
        parts.push(subtitle.trim());
      }

      for (const child of node.children ?? []) walk(child);
    };

    walk(component);
    return parts.join('\n');
  }

  private _systemPrompt(
    tools: ToolDescriptor[],
    allowWrites: boolean,
    zone: Zone,
  ): string {
    return [
      PERSONA,
      '',
      this._now(zone),
      '',
      this._toolsPrompt(tools, allowWrites),
      '',
      '# Reply format',
      '',
      'Reply with one JSON object and nothing else. No prose before it, no code',
      'fence around it. The object has exactly one key, "a2ui", whose value is a',
      'component tree built only from the catalog below.',
      '',
      buildCatalogPrompt(),
      buildActionPrompt(),
      '',
      HYGIENE,
      '',
      STYLE,
      '',
      this._example(),
    ].join('\n');
  }

  /**
   * Today, spelled out.
   *
   * A bare ISO timestamp was not enough: models were answering "amanhã" with
   * dates a year and a half in the past. Naming the two dates it will actually
   * need leaves nothing to arithmetic.
   */
  private _now(timeZone: Zone): string {
    const now = new Date();
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const day = (date: Date): string =>
      date.toLocaleDateString('en-CA', { timeZone });

    return [
      `Current time: ${now.toISOString()} (timezone ${timeZone})`,
      `Today is ${day(now)}. Tomorrow is ${day(tomorrow)}.`,
      'Every date you send to a tool starts with one of those two unless the',
      'user named another one. A date in a different year is always a mistake.',
    ].join('\n');
  }

  /**
   * The tools, split by what they do to the world.
   *
   * Grouped rather than listed flat, because the two halves carry opposite
   * instructions and a single list invites the model to average them. The last
   * block states this turn's permission outright: it is the difference between
   * proposing and doing, and it is not something to be inferred from history.
   */
  private _toolsPrompt(tools: ToolDescriptor[], allowWrites: boolean): string {
    if (tools.length === 0) {
      return '# Tools\n\nNo tools are available right now. Answer from what you know.';
    }

    const reads = tools.filter((tool) => tool.effect === 'read');
    const writes = tools.filter((tool) => tool.effect === 'write');

    const lines = ['# Tools', ''];

    if (reads.length > 0) {
      lines.push(
        '## These run immediately',
        '',
        'Call them whenever they would make your answer better. You never need',
        'permission to look at something, and you never announce that you are',
        'about to look: you look, and then you answer with what you found.',
        '',
        ...reads.map((tool) => `- ${tool.name}: ${tool.description}`),
        '',
      );
    }

    if (writes.length > 0) {
      lines.push(
        "## These change the user's data",
        '',
        'One of these runs only on a turn the user has confirmed. On any other',
        'turn the call is refused, nothing happens, and you will be told so.',
        '',
        ...writes.map((tool) => `- ${tool.name}: ${tool.description}`),
        '',
      );
    }

    lines.push(...this._permissionPrompt(allowWrites, writes.length > 0));

    if (tools.some((tool) => tool.name === 'api_call')) {
      lines.push(
        '',
        'Prefer the tool built for the job over api_call, which is a last',
        'resort for a service nothing else covers.',
      );
    }

    return lines.join('\n');
  }

  /** What this particular turn is allowed to do, stated once and plainly. */
  private _permissionPrompt(
    allowWrites: boolean,
    hasWrites: boolean,
  ): string[] {
    if (!hasWrites) return [];

    if (allowWrites) {
      return [
        '## This turn is confirmed',
        '',
        'The user has just authorised the change under discussion. Carry it out',
        'now, in this turn, by calling the tool. Do not propose it again, do not',
        'ask whether you should, and do not offer another confirm button for the',
        'same thing: they have already answered that question and asking twice',
        'is the one thing they asked you not to do.',
        '',
        'Then say what you did, in one sentence, with the result in hand.',
        '',
        'If some detail is genuinely missing, read for it first. Only come back',
        'empty-handed if the answer is theirs alone to give.',
      ];
    }

    return [
      '## This turn is not confirmed',
      '',
      'Nothing you do here can change anything. If the user wants something',
      'changed, read whatever you need to make the proposal exact, then write',
      'the proposal: name the change in full, in one short Card, and put a',
      'single primary button on it carrying',
      '{"type":"confirm","text":"<the whole action, restated>"}.',
      '',
      'Do not call a write tool to "check" whether it would work. It will be',
      'refused and the turn will read as hesitant for no reason.',
    ];
  }

  /**
   * Two examples, because the two shapes are easy to confuse.
   *
   * The first is a choice: several valid answers and only the user can pick,
   * so the buttons are replies. The second is a proposal: the decision is made
   * and one tap away from happening, so there is exactly one confirm. A model
   * given only the first tends to offer choices where it should be proposing.
   */
  private _example(): string {
    const choice = {
      a2ui: {
        component: 'Column',
        gap: 'normal',
        children: [
          {
            component: 'Text',
            text: 'Quinta está livre depois do almoço. Dois horários servem:',
            variant: 'body',
          },
          {
            component: 'Card',
            children: [
              {
                component: 'ListItem',
                icon: 'clock',
                color: 'success',
                title: '14:00 - 15:00',
                subtitle: 'Nada antes nem depois',
                action: {
                  type: 'reply',
                  text: 'Agendar reunião quinta, 14:00 às 15:00',
                },
              },
              {
                component: 'ListItem',
                icon: 'clock',
                color: 'info',
                title: '16:30 - 17:30',
                subtitle: 'Logo depois da sua review',
                action: {
                  type: 'reply',
                  text: 'Agendar reunião quinta, 16:30 às 17:30',
                },
              },
            ],
          },
        ],
      },
    };

    const proposal = {
      a2ui: {
        component: 'Column',
        gap: 'normal',
        children: [
          {
            component: 'Text',
            text: 'Sua quinta está livre das 14h em diante. Posso deixar assim:',
            variant: 'body',
          },
          {
            component: 'Card',
            children: [
              {
                component: 'ListItem',
                icon: 'calendarPlus',
                color: 'accent',
                title: 'Reunião com o cliente',
                subtitle: 'Quinta, 25 de set., 14:00 às 15:00',
              },
            ],
          },
          {
            component: 'AppButton',
            text: 'Agendar',
            variant: 'primary',
            icon: 'check',
            action: {
              type: 'confirm',
              text: 'Agendar "Reunião com o cliente" na quinta, 25/09, das 14:00 às 15:00',
            },
          },
        ],
      },
    };

    return [
      '## Examples',
      '',
      'A choice only the user can make. Several answers are valid, so each one',
      'is a reply and nothing is being authorised yet.',
      '',
      JSON.stringify(choice),
      '',
      'A proposal. The decision is made and every detail is on screen, so there',
      'is one confirm and nothing else to read.',
      '',
      JSON.stringify(proposal),
    ].join('\n');
  }

  private _historyContent(message: Message): string {
    if (message.role === 'user') return message.text.trim();

    const tree = message.metadata?.a2ui;
    if (tree !== undefined) {
      return this.flattenToText(tree).trim();
    }

    return message.text.trim();
  }
}
