import { Action, ArgName, ARGS } from './action';
import { ARTIFACTS } from './artifacts';
import { QUEUE } from './queue';

export * from './action';

/**
 * Everything the agent can do, one entry per control, by domain. The `do`
 * enum, the changes' schema, how each change is read, made and drawn: all
 * of it is read from here. Adding a control is adding an entry.
 */
export const ACTIONS: readonly Action[] = [...QUEUE, ...ARTIFACTS];

const BY_NAME = new Map(ACTIONS.map((it) => [it.name, it]));

/** The action named [name], when there is one. */
export function actionOf(name: unknown): Action | undefined {
  return typeof name === 'string' ? BY_NAME.get(name) : undefined;
}

/**
 * How a change is written in the `answer` tool:
 * - `flat`: one object with every argument optional, the server refusing the
 *   ones a verb does not take;
 * - `variants`: one object per verb (`anyOf`), each with only its own
 *   arguments, so a wrong argument cannot be written at all.
 */
export type SchemaShape = 'flat' | 'variants';

export const SCHEMA_SHAPES: readonly SchemaShape[] = ['flat', 'variants'];

/** The shape a deployment uses when `AGENT_SCHEMA` says none: `flat` scored 37/39 to `variants`' 34/39 (pass^2) on the eval. */
export const DEFAULT_SHAPE: SchemaShape = 'flat';

/** The schema of a plan's changes, in [shape], for [actions]. */
export function changesSchema(
  shape: SchemaShape,
  actions: readonly Action[] = ACTIONS,
): Record<string, unknown> {
  return {
    type: 'array',
    minItems: 1,
    maxItems: 12,
    items: shape === 'flat' ? flat(actions) : variants(actions),
  };
}

/** One object, every argument of every action, in [ARGS]' order. */
function flat(actions: readonly Action[]): Record<string, unknown> {
  const properties: Record<string, unknown> = {
    do: { type: 'string', enum: actions.map((it) => it.name) },
  };
  for (const name of Object.keys(ARGS) as ArgName[]) {
    const users = actions.filter((it) => it.args[name] !== undefined);
    if (users.length === 0) continue;
    // A description of its own is said beside the shared one, by verb.
    const own = users.filter((it) => typeof it.args[name] === 'string');
    const base = ARGS[name] as { description?: string };
    properties[name] =
      own.length === 0
        ? ARGS[name]
        : {
            ...ARGS[name],
            description: [
              ...(own.length === users.length ? [] : [base.description]),
              ...own.map((it) => `${it.name}: ${String(it.args[name])}`),
            ].join(' '),
          };
  }
  return {
    type: 'object',
    properties,
    required: ['do'],
    additionalProperties: false,
  };
}

/** One object per action, each with only its own arguments. */
function variants(actions: readonly Action[]): Record<string, unknown> {
  return {
    anyOf: actions.map((action) => {
      const properties: Record<string, unknown> = {
        do: { type: 'string', enum: [action.name] },
      };
      for (const name of Object.keys(ARGS) as ArgName[]) {
        const arg = action.args[name];
        if (arg === undefined) continue;
        properties[name] =
          arg === true ? ARGS[name] : { ...ARGS[name], description: arg };
      }
      return {
        type: 'object',
        description: action.does,
        properties,
        required: ['do', ...(action.required ?? [])],
        additionalProperties: false,
      };
    }),
  };
}
