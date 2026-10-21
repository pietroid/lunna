import { Interval } from '../time/work-hours';
import { atMinuteIn, formatTimeIn, isoDayIn } from '../time/zone';
import { Board, BoardCard, BoardArtifact, formatSpan, noonOf } from './board';
import type { PlanView, QuickReply } from './agent.service';

/** Where our catalog lives: the components below, by these names. */
export const CATALOG_ID = 'https://lunna.pietroteruya.dev/a2ui/v1/catalog.json';

/** The A2UI version `toA2ui` writes and the app reads. */
export const A2UI_VERSION = 'v0.9';

/** A card, read only: what Lista says of it. */
export interface PeekCard {
  id: string;
  title: string;
  minutes: number;
  /** ISO 8601, its hour. Absent in Depois eu priorizo. */
  at?: string;
  fixed: boolean;
  done: boolean;
  artifact?: string;
  /** Only when they were asked about. */
  notes?: string;
}

/** One row of a day's slice. */
export interface PeekItem {
  kind: 'task' | 'running' | 'fixed' | 'routine' | 'free';
  /** Empty for a free stretch. */
  title: string;
  start: string;
  end: string;
  artifact?: string;
}

/** An artifact at a glance: the Entregas row, and what comes next in it. */
export interface PeekArtifact {
  id: string;
  title: string;
  createdAt: string;
  deadline?: string;
  done: number;
  total: number;
  /** At most three open tasks: those with an hour first, then the backlog. */
  next: PeekCard[];
}

/** One answer offered to tap: a plan of its own, or words to say next. */
export interface Choice {
  label: string;
  plan?: PlanView;
  /** Sent as the person's next message when tapped. */
  say?: string;
}

/**
 * One block of an answer, every fact filled in by the server: what the
 * model chose to show, bound to the day.
 */
export type Block =
  | { kind: 'caption'; text: string }
  | { kind: 'plan'; plan: PlanView }
  | { kind: 'choices'; options: Choice[] }
  | { kind: 'day'; day: string; from: string; to: string; items: PeekItem[] }
  | { kind: 'cards'; title?: string; cards: PeekCard[] }
  | { kind: 'artifact'; artifact: PeekArtifact };

/** How many next tasks an artifact shows. */
const MAX_NEXT = 3;

/** A free stretch shorter than this is not drawn. */
const MIN_FREE_MINUTES = 15;

/** [card] as a read-only row. */
export function peekCard(
  board: Board,
  card: BoardCard,
  withNotes = false,
): PeekCard {
  const artifact = board.artifactOf(card);
  const notes = card.notes.trim();
  return {
    id: card.id,
    title: card.title,
    minutes: card.minutes,
    ...(card.start === undefined ? {} : { at: card.start.toISOString() }),
    fixed: card.kind === 'event',
    done: card.done,
    ...(artifact === undefined ? {} : { artifact }),
    ...(withNotes && notes !== '' ? { notes } : {}),
  };
}

/**
 * The slice [from]–[to] (minutes after midnight, within the working day) of
 * [day]: its cards, and with [free] the free room between them.
 */
export function peekDay(
  board: Board,
  day: string,
  from: number | undefined,
  to: number | undefined,
  free: boolean,
): Extract<Block, { kind: 'day' }> {
  const zone = board.zone;
  const window = board.window(day);
  const noon = noonOf(day, zone);
  const start = new Date(
    Math.max(
      window.start.getTime(),
      from === undefined ? 0 : atMinuteIn(noon, from, zone).getTime(),
    ),
  );
  const end = new Date(
    Math.min(
      window.end.getTime(),
      to === undefined ? Infinity : atMinuteIn(noon, to, zone).getTime(),
    ),
  );
  const within = (it: Interval) => it.start < end && it.end > start;

  const items: PeekItem[] = board.cards
    .filter((card) => card.day === day && card.start !== undefined)
    .filter((card) => within({ start: card.start!, end: card.end! }))
    .map((card) => {
      const artifact = board.artifactOf(card);
      return {
        kind:
          card.kind === 'event'
            ? card.routine
              ? 'routine'
              : 'fixed'
            : card.started
              ? 'running'
              : card.routine
                ? 'routine'
                : 'task',
        title: card.title,
        start: card.start!.toISOString(),
        end: card.end!.toISOString(),
        ...(artifact === undefined ? {} : { artifact }),
      };
    });
  if (free) {
    for (const room of board.free(day)) {
      const cut = {
        start: new Date(Math.max(room.start.getTime(), start.getTime())),
        end: new Date(Math.min(room.end.getTime(), end.getTime())),
      };
      if (cut.end.getTime() - cut.start.getTime() < MIN_FREE_MINUTES * 60_000)
        continue;
      items.push({
        kind: 'free',
        title: '',
        start: cut.start.toISOString(),
        end: cut.end.toISOString(),
      });
    }
  }

  return {
    kind: 'day',
    day,
    from: start.toISOString(),
    to: end.toISOString(),
    items: items.sort((a, b) => Date.parse(a.start) - Date.parse(b.start)),
  };
}

/** [it] at a glance: its counts and its next open tasks, each with a ref. */
export function peekArtifact(board: Board, it: BoardArtifact): PeekArtifact {
  const open = it.tasks.filter((task) => task.doneAt === undefined);
  const cards = open.map((task) => board.reach(task));
  const next = [
    ...cards
      .filter((card) => card.start !== undefined)
      .sort((a, b) => a.start!.getTime() - b.start!.getTime()),
    ...cards.filter((card) => card.start === undefined),
  ].slice(0, MAX_NEXT);

  return {
    id: it.artifact.id,
    title: it.artifact.title,
    createdAt: it.artifact.createdAt,
    ...(it.artifact.deadline === undefined
      ? {}
      : { deadline: it.artifact.deadline }),
    done: it.tasks.length - open.length,
    total: it.tasks.length,
    next: next.map((card) => peekCard(board, card)),
  };
}

/** A2UI's server-to-client messages, as v0.9 writes them. */
export type A2uiMessage =
  | {
      version: typeof A2UI_VERSION;
      createSurface: { surfaceId: string; catalogId: string };
    }
  | {
      version: typeof A2UI_VERSION;
      updateComponents: {
        surfaceId: string;
        components: Record<string, unknown>[];
      };
    }
  | {
      version: typeof A2UI_VERSION;
      updateDataModel: { surfaceId: string; path: string; value: unknown };
    };

/** A component's name in our catalog, by block. */
const COMPONENT: Record<Block['kind'], string> = {
  caption: 'Caption',
  plan: 'Plan',
  choices: 'Choices',
  day: 'DayPeek',
  cards: 'Cards',
  artifact: 'ArtifactPeek',
};

/** What tapping a choice sends back: its plan to apply, or its words. */
function chooseOf(choice: Choice): Record<string, unknown> {
  return {
    event: {
      name: 'choose',
      context:
        choice.plan === undefined
          ? { say: choice.say }
          : { planId: choice.plan.id },
    },
  };
}

/**
 * [blocks] as one A2UI surface: the components in order under a column,
 * each bound to its facts in the data model. Every id, path and action is
 * written here; the model never types one.
 */
export function toA2ui(surfaceId: string, blocks: Block[]): A2uiMessage[] {
  const ids = blocks.map((_, i) => `b${i + 1}`);
  const value: Record<string, unknown> = {};
  const components: Record<string, unknown>[] = [
    { id: 'root', component: 'Column', children: ids },
  ];

  blocks.forEach((block, i) => {
    const id = ids[i];
    const component = { id, component: COMPONENT[block.kind] };
    switch (block.kind) {
      case 'caption':
        components.push({ ...component, text: block.text });
        return;
      case 'plan':
        value[id] = block.plan;
        components.push({
          ...component,
          plan: { path: `/${id}` },
          apply: {
            event: { name: 'apply', context: { planId: block.plan.id } },
          },
          adjust: {
            event: { name: 'adjust', context: { planId: block.plan.id } },
          },
        });
        return;
      case 'choices':
        value[id] = block.options.map((it) => ({
          ...it,
          action: chooseOf(it),
        }));
        components.push({ ...component, options: { path: `/${id}` } });
        return;
      case 'day':
        value[id] = { day: block.day, from: block.from, to: block.to };
        value[`${id}items`] = block.items;
        components.push({
          ...component,
          day: { path: `/${id}` },
          items: { path: `/${id}items` },
        });
        return;
      case 'cards':
        value[id] = block.cards;
        components.push({
          ...component,
          ...(block.title === undefined ? {} : { title: block.title }),
          cards: { path: `/${id}` },
        });
        return;
      case 'artifact':
        value[id] = block.artifact;
        components.push({ ...component, artifact: { path: `/${id}` } });
        return;
    }
  });

  return [
    {
      version: A2UI_VERSION,
      createSurface: { surfaceId, catalogId: CATALOG_ID },
    },
    { version: A2UI_VERSION, updateComponents: { surfaceId, components } },
    {
      version: A2UI_VERSION,
      updateDataModel: { surfaceId, path: '/', value },
    },
  ];
}

/**
 * The answer in words, for what reads only text: the conversation as it is
 * sent back on the next turn and kept, and builds older than the surface.
 * The caption when there is one, or one line per block.
 */
export function summary(board: Board, blocks: Block[]): string {
  const caption = blocks.find((it) => it.kind === 'caption');
  if (caption !== undefined) return caption.text;

  const when = (iso?: string) =>
    iso === undefined ? 'Depois eu priorizo' : board.when(new Date(iso));
  const lines = blocks.map((block): string | undefined => {
    switch (block.kind) {
      case 'plan':
        return `Proposta: ${block.plan.changes.map((it) => `${it.title} → ${when(it.at)}`).join('; ')}.`;
      case 'choices':
        return `Opções: ${block.options.map((it) => it.label).join(' · ')}.`;
      case 'day': {
        const free = block.items
          .filter((it) => it.kind === 'free')
          .reduce(
            (sum, it) => sum + Date.parse(it.end) - Date.parse(it.start),
            0,
          );
        const from = new Date(block.from);
        const to = new Date(block.to);
        return `${board.dayLabel(block.day)} ${formatTimeIn(from, board.zone)}–${formatTimeIn(to, board.zone)}: ${
          block.items
            .filter((it) => it.kind !== 'free')
            .map(
              (it) =>
                `${it.title} ${formatTimeIn(new Date(it.start), board.zone)}`,
            )
            .join(', ') || 'nada'
        }${free > 0 ? `; ${formatSpan(free)} livres` : ''}.`;
      }
      case 'cards':
        return `${block.title ?? 'Cartões'}: ${block.cards.map((it) => it.title).join(', ')}.`;
      case 'artifact':
        return `Entrega ${block.artifact.title}: ${block.artifact.done} de ${block.artifact.total} feitas.`;
      default:
        return undefined;
    }
  });

  return lines.filter((it) => it !== undefined).join(' ') || 'Pronto.';
}

/** [choices] as the quick replies older builds draw: those with a plan. */
export function legacyOptions(choices: Choice[]): QuickReply[] {
  return choices.flatMap((it) =>
    it.plan === undefined ? [] : [{ label: it.label, plan: it.plan }],
  );
}

/** "YYYY-MM-DD" of [iso] in the board's zone. */
export function dayOf(board: Board, iso: string): string {
  return isoDayIn(new Date(iso), board.zone);
}
