import { GoalKind } from '../../artifacts/artifact.types';
import { BoardArtifact, sameTitle } from '../board';
import { PlanChange } from '../plan';
import { Action, as, Draft, Refusal, Resolving } from './action';

/** The ref a change names a delivery by, in its own words. */
const DELIVERY = 'The delivery (p1).';

/**
 * Entregas' own gestures: a delivery written down, changed, delivered,
 * removed or moved in its queue; a kind for the catalogue; a goal. Each is
 * what the person does on Entregas, through `ArtifactsService`.
 */
export const ARTIFACTS: Action[] = [
  {
    name: 'new_artifact',
    domain: 'artifact',
    does: 'A new delivery, at the end of the queue of deliveries (or the top).',
    args: {
      as: true,
      title: true,
      kind: true,
      deadline: true,
      minutes: true,
      value: true,
      at: true,
      duplicate: true,
    },
    required: ['title'],
    resolve(r, item) {
      const title = text(item.title);
      if (title === '') throw new Refusal('new_artifact needs a title.');
      const same = r.board.artifacts.find(
        (it) =>
          it.artifact.doneAt === undefined &&
          sameTitle(it.artifact.title, title),
      );
      if (same !== undefined && item.duplicate !== true) {
        throw new Refusal(
          `"${same.artifact.title}" is already a delivery (${same.ref}). Use its ref, or confirm with the person that this is another one and send duplicate: true.`,
        );
      }
      const kind = kindOf(r, item.kind);
      const deadline = deadlineOf(r, item.deadline);
      const minutes = intOf(item.minutes, 5);
      const value = intOf(item.value, 0);
      const name = declare(r, item.as, 'artifact', title);

      return {
        gesture: {
          do: 'new_artifact',
          ...(name === undefined ? {} : { as: name }),
          title: title.slice(0, 200),
          ...kind.ids,
          ...(deadline == null ? {} : { deadline }),
          ...(minutes === undefined ? {} : { minutes }),
          ...(value === undefined ? {} : { value }),
          at: item.at === 'top' ? 'top' : 'end',
        },
        facts: r.facts,
        assumed: r.assumed,
        duplicate: true,
        view: {
          kind: 'add_artifact',
          title,
          minutes: minutes ?? kind.minutes ?? 0,
          ...(deadline == null ? {} : { deadline }),
          ...((value ?? kind.price) === undefined
            ? {}
            : { value: value ?? kind.price }),
        },
      };
    },
    async make(hands, user, gesture, made) {
      const g = as(gesture, 'new_artifact');
      const typeId =
        g.typeId ?? (g.typeAs === undefined ? undefined : made.get(g.typeAs));
      const id = await hands.deliveries.create(
        user,
        {
          title: g.title,
          ...(typeId === undefined ? {} : { typeId }),
          ...(g.deadline === undefined ? {} : { deadline: g.deadline }),
          ...(g.minutes === undefined ? {} : { minutes: g.minutes }),
          ...(g.value === undefined ? {} : { value: g.value }),
        },
        g.at,
      );
      if (g.as !== undefined) made.set(g.as, id);
      return id;
    },
    line(drawing, draft, id) {
      const g = as(draft.gesture, 'new_artifact');
      // The tasks the plan writes into it, named on its line.
      const takes = drawing.drafts.flatMap((it) =>
        'new' in it.gesture &&
        it.gesture.new !== undefined &&
        g.as !== undefined &&
        it.gesture.new.artifactAs === g.as
          ? [it.gesture.new.title]
          : [],
      );
      return lineOf(draft, id, takes.length === 0 ? {} : { takes });
    },
  },
  {
    name: 'edit_artifact',
    domain: 'artifact',
    does: 'A delivery renamed, or given another deadline, time or value.',
    args: {
      ref: DELIVERY,
      title: true,
      deadline: true,
      minutes: true,
      value: true,
    },
    required: ['ref'],
    resolve(r, item) {
      const it = r.artifact(item.ref, 'ref')!;
      const { artifact } = it;
      const title = text(item.title);
      const deadline = deadlineOf(r, item.deadline);
      const minutes = intOf(item.minutes, 5);
      const value = intOf(item.value, 0);
      const edit = {
        ...(title === '' || title === artifact.title ? {} : { title }),
        ...(deadline === undefined ? {} : { deadline }),
        ...(minutes === undefined ? {} : { minutes }),
        ...(value === undefined ? {} : { value }),
      };
      if (Object.keys(edit).length === 0) {
        throw new Refusal(
          'edit_artifact needs what changes: title, deadline, minutes or value.',
        );
      }
      return {
        gesture: { do: 'edit_artifact', id: artifact.id, edit },
        facts: r.facts,
        assumed: r.assumed,
        duplicate: true,
        view: {
          kind: 'edit_artifact',
          title: edit.title ?? artifact.title,
          ...(edit.title === undefined ? {} : { was: artifact.title }),
          minutes: minutes ?? artifact.minutes ?? 0,
          ...(edit.deadline === undefined
            ? {}
            : {
                ...(edit.deadline === null ? {} : { deadline: edit.deadline }),
                ...(artifact.deadline === undefined
                  ? {}
                  : { wasDeadline: artifact.deadline }),
              }),
          ...(value === undefined ? {} : { value }),
        },
      };
    },
    async make(hands, user, gesture, _made, _trace, now) {
      const g = as(gesture, 'edit_artifact');
      await hands.deliveries.edit(user, g.id, g.edit, now);
      return g.id;
    },
    line: (_drawing, draft, id) => lineOf(draft, id),
  },
  {
    name: 'deliver',
    domain: 'artifact',
    does: 'A delivery marked delivered: its value counts towards the goals now.',
    args: { ref: DELIVERY },
    required: ['ref'],
    resolve(r, item) {
      const it = open(r.artifact(item.ref, 'ref')!);
      const { artifact } = it;
      // Delivering with work left is the person's call: the card shows it.
      const left = it.tasks.filter((task) => task.doneAt === undefined);
      return {
        gesture: { do: 'deliver', id: artifact.id },
        facts: r.facts,
        assumed: r.assumed,
        duplicate: true,
        view: {
          kind: 'deliver',
          title: artifact.title,
          minutes: artifact.minutes ?? 0,
          ...(artifact.value === undefined ? {} : { value: artifact.value }),
          ...(left.length === 0
            ? {}
            : { takes: left.map((task) => task.title) }),
        },
      };
    },
    async make(hands, user, gesture, _made, _trace, now) {
      const g = as(gesture, 'deliver');
      await hands.deliveries.edit(user, g.id, { done: true }, now);
      return g.id;
    },
    line: (_drawing, draft, id) => lineOf(draft, id),
  },
  {
    name: 'remove_artifact',
    domain: 'artifact',
    does: 'A delivery deleted, and the tasks waiting for it in Para depois with it.',
    args: { ref: DELIVERY },
    required: ['ref'],
    resolve(r, item) {
      const { artifact, tasks } = r.artifact(item.ref, 'ref')!;
      const going = tasks.filter(
        (task) => task.backlog && task.doneAt === undefined,
      );
      return {
        gesture: { do: 'remove_artifact', id: artifact.id, keepTasks: false },
        facts: r.facts,
        assumed: r.assumed,
        duplicate: true,
        view: {
          kind: 'remove_artifact',
          title: artifact.title,
          minutes: artifact.minutes ?? 0,
          ...(going.length === 0
            ? {}
            : { takes: going.map((task) => task.title) }),
        },
      };
    },
    async make(hands, user, gesture) {
      const g = as(gesture, 'remove_artifact');
      await hands.deliveries.remove(user, g.id, { keepTasks: g.keepTasks });
      return g.id;
    },
    line(_drawing, draft, id) {
      const g = as(draft.gesture, 'remove_artifact');
      return g.keepTasks
        ? lineOf({ ...draft, view: { ...draft.view!, takes: undefined } }, id)
        : lineOf(draft, id);
    },
  },
  {
    name: 'move_artifact',
    domain: 'artifact',
    does: 'A delivery moved in the queue of deliveries, after or before another.',
    args: {
      ref: DELIVERY,
      after: 'move_artifact: the delivery right above (p2).',
      before: 'move_artifact: the delivery right under (p2).',
    },
    required: ['ref'],
    resolve(r, item) {
      const it = open(r.artifact(item.ref, 'ref')!);
      const after =
        item.after === undefined ? undefined : r.artifact(item.after, 'after');
      const before =
        item.before === undefined
          ? undefined
          : r.artifact(item.before, 'before');
      for (const other of [after, before]) {
        if (other === undefined) continue;
        open(other);
        if (other.artifact.id === it.artifact.id) {
          throw new Refusal('A delivery cannot be placed next to itself.');
        }
      }
      if (after === undefined && before === undefined) {
        throw new Refusal('move_artifact needs after or before: a delivery.');
      }
      return {
        gesture: {
          do: 'move_artifact',
          id: it.artifact.id,
          ...(after === undefined ? {} : { after: after.artifact.id }),
          ...(before === undefined ? {} : { before: before.artifact.id }),
        },
        facts: r.facts,
        assumed: r.assumed,
        duplicate: true,
        view: {
          kind: 'move_artifact',
          title: it.artifact.title,
          minutes: it.artifact.minutes ?? 0,
          place: {
            ...(after === undefined ? {} : { after: after.artifact.title }),
            ...(before === undefined ? {} : { before: before.artifact.title }),
          },
        },
      };
    },
    async make(hands, user, gesture) {
      const g = as(gesture, 'move_artifact');
      // A place in the queue as the drag counts it: without the one moved.
      const queue = (await hands.artifacts.list(user)).filter(
        (it) => it.doneAt === undefined && it.id !== g.id,
      );
      const at = (id: string) => queue.findIndex((it) => it.id === id);
      const index =
        g.after !== undefined && at(g.after) >= 0
          ? at(g.after) + 1
          : g.before !== undefined && at(g.before) >= 0
            ? at(g.before)
            : queue.length;
      await hands.deliveries.move(user, g.id, index);
      return g.id;
    },
    line: (_drawing, draft, id) => lineOf(draft, id),
  },
  {
    name: 'new_kind',
    domain: 'artifact',
    does: 'A new kind in the catalogue, on a shelf, with how long one takes.',
    args: { as: true, name: true, shelf: true, minutes: true, price: true },
    required: ['name', 'shelf', 'minutes'],
    resolve(r, item) {
      const name = text(item.name);
      const shelf = text(item.shelf);
      const minutes = intOf(item.minutes, 5);
      if (name === '' || shelf === '' || minutes === undefined) {
        throw new Refusal(
          'new_kind needs name, shelf and minutes (how long one takes). Ask the person what they did not say.',
        );
      }
      const same = r.board.kinds.find((it) => sameTitle(it.type.name, name));
      if (same !== undefined) {
        throw new Refusal(
          `"${same.type.name}" is already a kind (${same.ref}). Use it.`,
        );
      }
      const price = intOf(item.price, 0);
      const as_ = declare(r, item.as, 'kind', name);
      return {
        gesture: {
          do: 'new_kind',
          ...(as_ === undefined ? {} : { as: as_ }),
          name: name.slice(0, 200),
          shelf: shelf.slice(0, 200),
          minutes,
          ...(price === undefined ? {} : { price }),
        },
        facts: r.facts,
        assumed: r.assumed,
        duplicate: true,
        view: {
          kind: 'add_kind',
          title: name,
          minutes,
          shelf,
          ...(price === undefined ? {} : { value: price }),
        },
      };
    },
    async make(hands, user, gesture, made) {
      const g = as(gesture, 'new_kind');
      const id = await hands.deliveries.addType(user, {
        name: g.name,
        minutes: g.minutes,
        category: g.shelf,
        ...(g.price === undefined ? {} : { price: g.price }),
      });
      if (g.as !== undefined) made.set(g.as, id);
      return id;
    },
    line: (_drawing, draft, id) => lineOf(draft, id),
  },
  {
    name: 'new_goal',
    domain: 'artifact',
    does: 'A goal: reais to bill by a day. It starts where the last goal ends (or today) and counts the deliveries delivered until then.',
    args: {
      target: 'Whole reais, as the person said.',
      deadline:
        'Its last day: a day word or YYYY-MM-DD (the end of next month when they said "by next month").',
    },
    required: ['target', 'deadline'],
    resolve(r, item) {
      const target = intOf(item.target, 1);
      if (target === undefined) {
        throw new Refusal(
          'new_goal needs target, the number the person said. Ask them.',
        );
      }
      const deadline = deadlineOf(r, item.deadline);
      if (deadline == null) {
        throw new Refusal(
          'new_goal needs deadline, the day it is to be reached by. Ask the person, offering the end of next week and of next month.',
        );
      }
      return {
        gesture: { do: 'new_goal', target, deadline },
        facts: r.facts,
        assumed: r.assumed,
        duplicate: true,
        view: {
          kind: 'add_goal',
          title: goalTitle('money', undefined),
          minutes: 0,
          goal: { kind: 'money', target, deadline },
        },
      };
    },
    async make(hands, user, gesture, _made, _trace, now) {
      const g = as(gesture, 'new_goal');
      return hands.deliveries.addGoal(
        user,
        { target: g.target, deadline: g.deadline },
        now,
      );
    },
    line: (_drawing, draft, id) => lineOf(draft, id),
  },
  {
    name: 'remove_goal',
    domain: 'artifact',
    does: 'A goal deleted; the deliveries stay.',
    args: { ref: 'The goal (g1).' },
    required: ['ref'],
    resolve(r, item) {
      const said = text(item.ref);
      const it = r.board.goal(said);
      if (it === undefined) {
        throw new Refusal(
          `No goal ${JSON.stringify(item.ref)}. Use a goal ref from the board (g1).`,
        );
      }
      const kind = r.board.kinds.find((k) => k.type.id === it.goal.typeId);
      return {
        gesture: { do: 'remove_goal', id: it.goal.id },
        facts: r.facts,
        assumed: r.assumed,
        duplicate: true,
        view: {
          kind: 'remove_goal',
          title: goalTitle(it.goal.kind, kind?.type.name),
          minutes: 0,
          goal: {
            kind: it.goal.kind,
            target: it.goal.target,
            deadline: it.goal.deadline,
          },
        },
      };
    },
    async make(hands, user, gesture) {
      const g = as(gesture, 'remove_goal');
      await hands.deliveries.removeGoal(user, g.id);
      return g.id;
    },
    line: (_drawing, draft, id) => lineOf(draft, id),
  },
];

/** The card's line for a change of Entregas: what resolving wrote down. */
function lineOf(
  draft: Draft,
  id: string,
  extra: Partial<PlanChange> = {},
): PlanChange {
  const view = draft.view!;
  const adds = view.kind === 'add_artifact' || view.kind === 'add_kind';
  const line: PlanChange = {
    ...view,
    ...(adds || view.kind === 'add_goal' ? {} : { id }),
    routine: false,
    ...extra,
  };
  if (line.takes === undefined) delete line.takes;
  return line;
}

/** A name [value] gives what this change makes, for later changes. */
function declare(
  r: Resolving,
  value: unknown,
  kind: 'artifact' | 'kind',
  title: string,
): string | undefined {
  const name = text(value);
  if (name === '') return undefined;
  if (r.declared.has(name) || r.board.title(name) !== undefined) {
    throw new Refusal(
      `"${name}" already names something: give this as another name.`,
    );
  }
  r.declared.set(name, { kind, title });
  return name;
}

/**
 * The kind [value] names: a ref (`k1`), one made earlier in the plan, or a
 * name as the person said it, matched loosely. Two kinds alike are a
 * question for the person, never a pick.
 */
function kindOf(
  r: Resolving,
  value: unknown,
): {
  ids: { typeId?: string; typeAs?: string };
  name?: string;
  minutes?: number;
  price?: number;
} {
  const said = text(value);
  if (said === '') return { ids: {} };
  const declared = r.declared.get(said);
  if (declared?.kind === 'kind') {
    return { ids: { typeAs: said }, name: declared.title };
  }
  const byRef = r.board.kind(said);
  const found =
    byRef === undefined
      ? r.board.kinds.filter((it) => sameTitle(it.type.name, said))
      : [byRef];
  if (found.length === 0) {
    throw new Refusal(
      `No kind "${said}" in the catalogue. Leave kind out for a one-off delivery, or add it with new_kind first if the person wants one.`,
    );
  }
  if (found.length > 1) {
    throw new Refusal(
      `${found.map((it) => `${it.ref} "${it.type.name}"`).join(' and ')} both match "${said}": ask the person which, with choices.`,
    );
  }
  const { type } = found[0];
  r.facts.push(`Achei o tipo ${type.name}`);
  return {
    ids: { typeId: type.id },
    name: type.name,
    minutes: type.minutes,
    price: type.price,
  };
}

/**
 * The deadline [value] says: a day word or YYYY-MM-DD, or `null` for
 * "none". Undefined when not said.
 */
function deadlineOf(r: Resolving, value: unknown): string | null | undefined {
  const said = text(value);
  if (said === '') return undefined;
  if (/^(none|nenhum|sem prazo)$/i.test(said)) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(said)) {
    if (Number.isNaN(Date.parse(`${said}T12:00:00Z`))) {
      throw new Refusal(`deadline ${said} is not a day.`);
    }
    if (said < r.board.today) {
      throw new Refusal(`${said} has already passed. Ask the person.`);
    }
    return said;
  }
  return r.day(said);
}

/** A delivery still open, refused when it was delivered. */
function open(it: BoardArtifact): BoardArtifact {
  if (it.artifact.doneAt !== undefined) {
    throw new Refusal(
      `${it.ref} "${it.artifact.title}" was already delivered.`,
    );
  }
  return it;
}

/** How a goal reads on its line: what it counts. */
function goalTitle(kind: GoalKind, typeName: string | undefined): string {
  return kind === 'money' ? 'Faturamento' : (typeName ?? 'Entregas');
}

function text(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

/** A whole number of at least [min], when one was given. */
function intOf(value: unknown, min: number): number | undefined {
  if (typeof value !== 'number' || !Number.isFinite(value)) return undefined;
  return Math.max(min, Math.round(value));
}
