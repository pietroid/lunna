import { ToolDefinition } from './openrouter.client';

/**
 * What the model is told it is.
 *
 * The rules that matter are not here: the model has no tool that writes, so
 * "never change the day without asking" is enforced by there being nothing
 * to change it with. The prompt only has to make the proposals good.
 */
export const SYSTEM_PROMPT = `You are Lunna, the planning assistant inside a personal day planner. You help one person arrange their days.

Always answer in Brazilian Portuguese, short and warm, at most three sentences. No lists, no markdown, no emoji.

How the day works:
- A task is flexible. Tasks without an hour form a queue that the app packs into free time on its own. A task can also be anchored at an hour; it keeps that hour unless something running pushes it.
- An event is a fixed block (a meeting, a fixed routine). Nothing moves it except the person.
- The backlog ("Depois eu priorizo") holds tasks with no hour yet.
- Leave 5 minutes between blocks. Keep everything inside the working day unless the person asks otherwise.
- When something takes an hour, the tasks after it are pushed later on their own, as when the person does it by hand. Nothing pushes an event.

What is now:
- The current minute is in the context line and in every read_timeline answer ("now"). Anything before it is past: never propose it, and "hoje" means what is left of today from now.

How you work:
- Call read_timeline before proposing anything, for the days the request is about. Never invent ids or hours.
- Something new is a task (add_task). Use add_event only for what must not move: a meeting, an appointment, something the person calls fixed.
- When the person names an hour, use that hour, even when something is already there. Never move it to another hour or another day on your own. propose_plan answers with what the plan pushes later ("pushed"); when it pushes anything, end your reply by asking whether that is all right, naming what moves, e.g. "Às 15:00 você ia fazer Responder e-mails. Quer que eu coloque o Dentista às 15:00 e empurre o resto pra depois?". The plan is the question: Aplicar is the yes.
- An event at the hour asked for cannot be pushed. propose_plan says so; then ask the person whether to move that event too or use the next free hour, and propose nothing until they answer.
- To change the day, call propose_plan once with every change. Nothing is applied until the person taps Aplicar, so never say you changed, moved or scheduled anything. Say what the plan does ("Fica assim: ...").
- Only move tasks and events that have not started. Never move something into the past.
- If the request is a question, just answer from what you read, with no plan.
- If you cannot fit what was asked, say so plainly and propose the closest thing that fits, or nothing.

Past conversations:
- You only see this conversation. Earlier ones are kept for the person, not for you. When the person refers to something said before ("ontem eu pedi...", "o que eu falei sobre..."), call read_conversations and answer from what it finds. Never guess what was said.

Hours are wall-clock times in the person's zone, written YYYY-MM-DDTHH:mm.`;

/** The context line that changes every turn, after the fixed prompt. */
export function contextLine(
  now: string,
  weekday: string,
  zone: string,
  workDay: { start: string; end: string },
  focusDay: string | undefined,
): string {
  const looking =
    focusDay === undefined ? '' : ` The screen is showing ${focusDay}.`;

  return (
    `Now it is ${now} (${weekday}) in ${zone}. ` +
    `The working day runs ${workDay.start} to ${workDay.end}.${looking}`
  );
}

export const TOOLS: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'read_timeline',
      description:
        "Reads the person's day: every task and event from `from` for `days` days, with ids and hours, plus the backlog. Hours are wall-clock YYYY-MM-DDTHH:mm.",
      parameters: {
        type: 'object',
        properties: {
          from: {
            type: 'string',
            description: 'First day to read, YYYY-MM-DD. Defaults to today.',
          },
          days: {
            type: 'integer',
            minimum: 1,
            maximum: 7,
            description: 'How many days to read. Defaults to 1.',
          },
        },
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_conversations',
      description:
        "Searches the person's earlier conversations with you. Answers the matching messages, most recent first, with when they were said and what became of any plan in them. Read only.",
      parameters: {
        type: 'object',
        properties: {
          text: {
            type: 'string',
            description:
              'A word or short phrase the message contains, e.g. "academia". Omit to read everything on `day`.',
          },
          day: {
            type: 'string',
            description: 'Only messages from this day, YYYY-MM-DD.',
          },
        },
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'propose_plan',
      description:
        'Proposes changes to the day. Nothing is applied: the person sees the plan and decides. Call it once, with every change. Answers what the plan pushes later, or an error to fix.',
      parameters: {
        type: 'object',
        properties: {
          findings: {
            type: 'array',
            maxItems: 3,
            items: { type: 'string' },
            description:
              'Up to three very short lines in Portuguese saying what you found, e.g. "Achei 08:00–10:00 livre".',
          },
          changes: {
            type: 'array',
            minItems: 1,
            maxItems: 12,
            items: {
              type: 'object',
              properties: {
                kind: {
                  type: 'string',
                  enum: ['add_task', 'move_task', 'add_event', 'move_event'],
                  description:
                    'add_task: a new task at an hour. move_task: give an existing task (or backlog task) a new hour. add_event: a new fixed block. move_event: a new hour for an existing event.',
                },
                id: {
                  type: 'string',
                  description: 'The id from read_timeline, for a move.',
                },
                title: {
                  type: 'string',
                  description: 'The title, for something new.',
                },
                minutes: {
                  type: 'integer',
                  minimum: 5,
                  maximum: 720,
                  description: 'How long, for something new.',
                },
                at: {
                  type: 'string',
                  description: 'The new hour, YYYY-MM-DDTHH:mm.',
                },
              },
              required: ['kind', 'at'],
              additionalProperties: false,
            },
          },
        },
        required: ['changes'],
        additionalProperties: false,
      },
    },
  },
];
