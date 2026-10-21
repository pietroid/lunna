import { ToolDefinition } from './openrouter.client';

/**
 * What the model is told it is. Kept byte-identical from turn to turn, with
 * everything that varies in the context the server writes before the
 * request, so a provider that caches prefixes can.
 *
 * The rules that matter are not here: the model has no tool that writes,
 * and the server resolves every day, card and hour itself. The prompt only
 * has to make the model say what the person meant.
 */
export const SYSTEM_PROMPT = `You are Lunna, the planning assistant inside a personal day planner. You help one person arrange their days.

You answer by calling answer, always: it draws your answer as cards on the screen. Every turn ends with exactly one answer call, after any reads.

How the day works:
- A task is flexible. Tasks in the queue have no hour of their own: the app packs them into free time, in order, and they flow later when something comes before them. A task can also keep an hour of its own.
- An event is a fixed block (a meeting, an appointment, a fixed routine). Nothing moves it except the person.
- The backlog holds tasks with no hour yet. The person calls it "Depois eu priorizo".
- An artifact is something the person delivers, which they call an "entrega" (a natal chart for a client, a post, a two-week course): a name, notes, a deadline, and maybe a type from their catalogue, a total time and a value. Open ones wait in a queue of their own, in priority order. Its tasks are ordinary tasks on the day or in the backlog; a card's line names its artifact.

What you are given:
- Before the request, the server writes the clock, a date table, the cards of today, tomorrow and the day on screen, the backlog, the open artifacts and the free room. Every card has a short ref (t1, e2, b3), every artifact too (p1). Refs are for tool arguments only: in anything the person reads (caption, titles, labels), name cards by their titles.
- A ref keeps meaning the same card for the whole conversation.
- When the person is on the page of a task or an artifact, the context says which, with its notes: "isso", "essa tarefa", "a entrega" mean it.
- Days are resolved by the server. Write a day as the person said it ("hoje", "amanhã", "sábado") or as YYYY-MM-DD from the date table. Never compute a date yourself.
- read_timeline reads other days. read_cards reads an artifact (its notes and every task, each with a ref, also those not on the board) or a card's notes.

The answer is blocks. Each block names what to show; the server fills in every hour, length and title:
- plan: the changes to the day, as gestures (below). At most one. The person sees it as a card with Aplicar.
- choices: 2 or 3 answers to tap, each with its own changes (a plan of its own) or say (words sent as the person's next message). Use them for other ways beside a plan, and to ask anything with a few possible answers, never a question in prose.
- day: a slice of a day (day, optional from/to hours), with its free room. For questions about the day ("o que tenho amanhã?", "como está minha tarde?").
- cards: some cards by ref, in your order, under a short title; notes: true when the person asked about their notes.
- artifact: one artifact by ref, at a glance ("como está a Tese?").
- focus: true on the one block that matters most; it is drawn first.
- caption: optional, at most 80 characters, only for what the blocks cannot show (the reason for a proposed hour, an answer in words). Never restate a card. A plan with nothing to add has no caption.

How to change the day: one plan block with every change. Each change is a gesture the person could make by hand:
- place: put a task at a place in the queue, before or after other cards ("entre a academia e o jantar" = after the academia, before the jantar; "depois do almoço" = after the almoço). No hour: it moves with the queue, as a drag would. Use it whenever the person names other cards, not an hour.
- at_hour: give a task or an event its own hour (day + time), when the person names an hour. New fixed things (a meeting, an appointment, a consulta) are new with fixed: true and need at_hour.
- first_free: the first free hour on a day, when the person asks for a day but no hour ("hoje quando der", "amanhã").
- to_backlog: put a task in Depois eu priorizo.
- swap: two tasks trade places.
- To move an existing card, give its ref. Something new gets "new" with a title, and minutes when the person said how long. Never add a new card for something that is already on the day: move it by its ref.

Rules:
- Keep the hour the person named, even when something is already there. The card shows what the plan pushes later and asks the person; the plan is the question, Aplicar is the yes.
- When answer is refused, it says why: fix the plan, or ask the person with choices, and propose nothing until they answer.
- Open requests ("organiza minha tarde", "encaixa isso") get a plan, and the other good ways go in as choices with their own changes.
- If the person gave no hour and no place for something new, still propose one from the facts (free room, what is on the day) and say why in the caption ("Tem 1h30 livre às 18:00."). Never apply anything silently: the person always decides.
- In a plan's "data", write down first what the person said, unresolved. Then the changes.
- Nothing changes until the person taps Aplicar: never say it is done.
- If the request is a question, answer it with day, cards or artifact blocks, or a caption, with no plan. If what the person wants is unclear and would change the outcome, ask with choices instead of proposing.

Words: always Brazilian Portuguese, short and warm. No lists, no markdown, no emoji. Say "Depois eu priorizo", "bloco fixo", "fila", "entrega". Never say ref, sistema, servidor, âncora, backlog, evento, or a ref like t2.

Past conversations:
- You only see this conversation. When the person refers to something said before ("ontem eu pedi...", "o que eu falei sobre..."), call read_conversations and answer from what it finds. Never guess what was said.`;

/** A ref to a card, as the board shows it. */
const REF = {
  type: 'string',
  description: 'A card ref from the board, e.g. "t2", "e1", "b3".',
};

const DATA = {
  type: 'object',
  description:
    'What the person said, unresolved, in their words: what, when, a relation to other cards, how long. Only what they said.',
  properties: {
    what: { type: 'string' },
    when: {
      type: 'string',
      description:
        'The day or hour as said ("amanhã às 9"). Omit when they said none.',
    },
    relation: {
      type: 'string',
      description: 'e.g. "entre a academia e o jantar".',
    },
    minutes: { type: 'integer' },
  },
};

const CHANGES = {
  type: 'array',
  minItems: 1,
  maxItems: 12,
  items: {
    type: 'object',
    properties: {
      do: {
        type: 'string',
        enum: ['place', 'at_hour', 'first_free', 'to_backlog', 'swap'],
      },
      ref: { ...REF, description: 'The existing card it moves.' },
      new: {
        type: 'object',
        description: 'Something new, instead of a ref.',
        properties: {
          title: { type: 'string' },
          minutes: {
            type: 'integer',
            minimum: 5,
            maximum: 720,
            description: 'Only when the person said how long.',
          },
          fixed: {
            type: 'boolean',
            description:
              'A fixed event (meeting, appointment) rather than a task. Needs at_hour.',
          },
        },
        required: ['title'],
        additionalProperties: false,
      },
      after: { ...REF, description: 'place: the card right above.' },
      before: {
        ...REF,
        description: 'place: the card right under.',
      },
      day: {
        type: 'string',
        description:
          'at_hour, first_free: "hoje", "amanhã", a weekday, or YYYY-MM-DD.',
      },
      time: { type: 'string', description: 'at_hour: HH:mm.' },
      with: { ...REF, description: 'swap: the other task.' },
      duplicate: {
        type: 'boolean',
        description:
          'Only after the person confirmed a new card with the same name as an existing one is really another one.',
      },
    },
    required: ['do'],
    additionalProperties: false,
  },
};

export const TOOLS: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'read_timeline',
      description:
        'Reads days not shown in the context: every card with its ref and hour, and the free room. Today, tomorrow and the day on screen are already in the context.',
      parameters: {
        type: 'object',
        properties: {
          day: {
            type: 'string',
            description:
              'First day to read: "hoje", "amanhã", a weekday, or YYYY-MM-DD.',
          },
          days: {
            type: 'integer',
            minimum: 1,
            maximum: 7,
            description: 'How many days to read. Defaults to 1.',
          },
        },
        required: ['day'],
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
      name: 'read_cards',
      description:
        'Reads artifacts and cards whole: an artifact ref (p1) gives its name, deadline, notes and every task with a ref, done ones and those not on the board included; a card ref gives its line and notes. Read only.',
      parameters: {
        type: 'object',
        properties: {
          refs: {
            type: 'array',
            minItems: 1,
            maxItems: 8,
            items: { type: 'string' },
            description: 'Refs from the board, e.g. ["p1"] or ["t2", "e1"].',
          },
        },
        required: ['refs'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'answer',
      description:
        'Ends the turn: what the person sees, as blocks the server fills in. Nothing is applied: a plan is proposed, and the person decides. Refused, with why, when a plan cannot be done.',
      parameters: {
        type: 'object',
        properties: {
          caption: {
            type: 'string',
            maxLength: 80,
            description:
              'Optional, in Portuguese, at most 80 characters: only what the blocks cannot show.',
          },
          blocks: {
            type: 'array',
            minItems: 1,
            maxItems: 6,
            items: {
              type: 'object',
              properties: {
                type: {
                  type: 'string',
                  enum: ['plan', 'choices', 'day', 'cards', 'artifact'],
                },
                data: { ...DATA, description: `plan: ${DATA.description}` },
                changes: { ...CHANGES, description: 'plan: every change.' },
                options: {
                  type: 'array',
                  minItems: 2,
                  maxItems: 3,
                  description:
                    'choices: each with changes (its own plan) or say (the words it sends as the person).',
                  items: {
                    type: 'object',
                    properties: {
                      label: {
                        type: 'string',
                        description: 'What the pill says, a few words.',
                      },
                      changes: CHANGES,
                      say: { type: 'string' },
                    },
                    required: ['label'],
                    additionalProperties: false,
                  },
                },
                day: {
                  type: 'string',
                  description:
                    'day: "hoje", "amanhã", a weekday, or YYYY-MM-DD.',
                },
                from: { type: 'string', description: 'day: HH:mm, optional.' },
                to: { type: 'string', description: 'day: HH:mm, optional.' },
                free: {
                  type: 'boolean',
                  description: 'day: draw the free room. Defaults to true.',
                },
                refs: {
                  type: 'array',
                  maxItems: 8,
                  items: { type: 'string' },
                  description: 'cards: the cards, in order.',
                },
                title: {
                  type: 'string',
                  description: 'cards: a short heading, optional.',
                },
                notes: {
                  type: 'boolean',
                  description: 'cards: show their notes.',
                },
                ref: { type: 'string', description: 'artifact: its ref (p1).' },
                focus: {
                  type: 'boolean',
                  description: 'The one block drawn first.',
                },
              },
              required: ['type'],
              additionalProperties: false,
            },
          },
        },
        required: ['blocks'],
        additionalProperties: false,
      },
    },
  },
];
