import { ACTIONS, ARGS, changesSchema } from '.';
import { QUEUE } from './queue';

/**
 * The changes' schema as `agent.prompt.ts` wrote it by hand before the
 * registry: the registry's flat shape of the queue's verbs must be it, byte
 * for byte (save what a new task now says of its delivery).
 */
const TODAY = {
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
      ref: {
        type: 'string',
        description: 'The existing card it moves.',
      },
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
      after: { type: 'string', description: 'place: the card right above.' },
      before: {
        type: 'string',
        description: 'place: the card right under.',
      },
      day: {
        type: 'string',
        description:
          'at_hour, first_free: "hoje", "amanhã", a weekday, or YYYY-MM-DD.',
      },
      time: { type: 'string', description: 'at_hour: HH:mm.' },
      with: { type: 'string', description: 'swap: the other task.' },
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

type Obj = Record<string, unknown>;

describe('the registry', () => {
  it('writes the queue’s verbs flat exactly as the prompt did before it', () => {
    const flat = changesSchema('flat', QUEUE) as { items: Obj };
    const props = flat.items.properties as Obj;
    const fresh = JSON.parse(JSON.stringify(props.new)) as {
      properties: Obj;
    };
    delete fresh.properties.artifact;
    // Added since, with the light days: the schema before it, plus this.
    const { rest_day: restDay, ...before } = props;
    expect(restDay).toEqual({
      type: 'boolean',
      description:
        'Only after the person confirmed a delivery’s task on a day off or a light day.',
    });

    expect(
      JSON.stringify({
        ...flat,
        items: { ...flat.items, properties: { ...before, new: fresh } },
      }),
    ).toBe(JSON.stringify(TODAY));
  });

  it('names every verb once, each with arguments that exist', () => {
    const names = ACTIONS.map((it) => it.name);
    expect(new Set(names).size).toBe(names.length);
    for (const action of ACTIONS) {
      for (const arg of Object.keys(action.args))
        expect(ARGS).toHaveProperty(arg);
      for (const arg of action.required ?? []) {
        expect(action.args).toHaveProperty(arg);
      }
    }
  });

  it('gives each verb only its own arguments in the variants shape', () => {
    const { items } = changesSchema('variants') as { items: { anyOf: Obj[] } };

    expect(items.anyOf).toHaveLength(ACTIONS.length);
    const deliver = items.anyOf.find(
      (it) =>
        ((it.properties as Obj).do as { enum: string[] }).enum[0] === 'deliver',
    )!;
    expect(Object.keys(deliver.properties as Obj)).toEqual(['do', 'ref']);
    expect(deliver.required).toEqual(['do', 'ref']);
    expect(deliver.additionalProperties).toBe(false);
    expect((deliver.properties as { ref: Obj }).ref.description).toBe(
      'The delivery (p1).',
    );
    // No `oneOf` and no `$ref`: what tool schemas reliably take.
    expect(JSON.stringify(items)).not.toMatch(/oneOf|\$ref/);
  });

  it('says beside a shared argument what each verb that differs means by it', () => {
    const { items } = changesSchema('flat') as { items: { properties: Obj } };
    const ref = items.properties.ref as { description: string };

    expect(ref.description).toContain('The existing card it moves.');
    expect(ref.description).toContain('deliver: The delivery (p1).');
    expect(ref.description).toContain('remove_goal: The goal (g1).');
  });
});
