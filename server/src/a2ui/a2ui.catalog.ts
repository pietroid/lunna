import { ColorRole, ComponentName } from './a2ui.types';

/** A prop and what it accepts. */
interface PropSchema {
  /** A fixed set of values, when the prop is an enum. */
  values?: readonly string[];
  kind: 'string' | 'number' | 'boolean' | 'enum' | 'action';
  /** Shown to the model. Keep it to one line. */
  doc: string;
}

/** What a component takes. */
interface ComponentSchema {
  doc: string;
  props: Record<string, PropSchema>;
  children: boolean;
}

/** Colour roles, by meaning. The app owns the hex behind each one. */
export const COLOR_ROLES: readonly ColorRole[] = [
  'accent',
  'success',
  'info',
  'warning',
  'danger',
  'ink',
  'ink2',
  'ink3',
];

/** Type sizes, largest first. */
export const TEXT_VARIANTS = [
  'headline',
  'title',
  'body',
  'caption',
  'label',
] as const;

/** Button emphasis, highest first. */
export const BUTTON_VARIANTS = ['primary', 'secondary', 'tertiary'] as const;

/** Layout alignment along the main axis. */
export const MAIN_AXIS_ALIGNMENTS = [
  'start',
  'end',
  'center',
  'spaceBetween',
  'spaceAround',
  'spaceEvenly',
] as const;

/** Layout alignment across the main axis. */
export const CROSS_AXIS_ALIGNMENTS = [
  'start',
  'end',
  'center',
  'stretch',
] as const;

/** How an image fills its box. */
export const IMAGE_FITS = [
  'cover',
  'contain',
  'fill',
  'fitWidth',
  'fitHeight',
  'none',
] as const;

/** Gap sizes between children of a Column or Row. */
export const GAPS = ['none', 'tight', 'normal', 'loose'] as const;

/**
 * Every icon the app can draw, by name.
 *
 * The app maps each of these to a Phosphor glyph. A name that is not on this
 * list is rejected during validation rather than drawn as a question mark, so
 * the two lists have to stay in step: `app_ui`'s icon map is the other half.
 */
export const ICON_NAMES = [
  // time
  'calendar',
  'calendarPlus',
  'calendarCheck',
  'calendarX',
  'clock',
  'alarm',
  'timer',
  'hourglass',
  // status
  'check',
  'checkCircle',
  'x',
  'xCircle',
  'warning',
  'info',
  'question',
  'prohibit',
  'spinner',
  // work
  'target',
  'flag',
  'listChecks',
  'checkSquare',
  'note',
  'notebook',
  'file',
  'folder',
  'briefcase',
  'chartLine',
  'trophy',
  // objects
  'lightbulb',
  'sparkle',
  'star',
  'heart',
  'fire',
  'rocket',
  'bell',
  'bookmark',
  'gift',
  'coffee',
  'barbell',
  'moon',
  'sun',
  'cloud',
  // people and places
  'user',
  'users',
  'mapPin',
  'house',
  'globe',
  'envelope',
  'chat',
  'phone',
  'video',
  // commerce
  'shoppingCart',
  'currency',
  'creditCard',
  // controls
  'plus',
  'minus',
  'pencil',
  'trash',
  'link',
  'magnifyingGlass',
  'gear',
  'arrowRight',
  'arrowLeft',
  'arrowUp',
  'caretRight',
  'dotsThree',
] as const;

/** The component catalog. This is the contract the app renders. */
export const A2UI_CATALOG: Record<ComponentName, ComponentSchema> = {
  Column: {
    doc: 'Stacks children vertically. The usual root.',
    props: {
      mainAxisAlignment: {
        kind: 'enum',
        values: MAIN_AXIS_ALIGNMENTS,
        doc: 'Vertical distribution',
      },
      crossAxisAlignment: {
        kind: 'enum',
        values: CROSS_AXIS_ALIGNMENTS,
        doc: 'Horizontal alignment',
      },
      gap: {
        kind: 'enum',
        values: GAPS,
        doc: 'Space between children; defaults to normal',
      },
    },
    children: true,
  },
  Row: {
    doc: 'Lays children out horizontally. Keep to three or fewer.',
    props: {
      mainAxisAlignment: {
        kind: 'enum',
        values: MAIN_AXIS_ALIGNMENTS,
        doc: 'Horizontal distribution',
      },
      crossAxisAlignment: {
        kind: 'enum',
        values: CROSS_AXIS_ALIGNMENTS,
        doc: 'Vertical alignment',
      },
      gap: {
        kind: 'enum',
        values: GAPS,
        doc: 'Space between children; defaults to normal',
      },
    },
    children: true,
  },
  Spacer: {
    doc: 'Explicit empty space. Prefer a gap on the parent.',
    props: {
      width: { kind: 'number', doc: 'Width in logical pixels' },
      height: { kind: 'number', doc: 'Height in logical pixels' },
    },
    children: false,
  },
  Divider: {
    doc: 'A hairline rule between sections.',
    props: {},
    children: false,
  },
  Text: {
    doc: 'A run of text. Every string shown to the user is inside one.',
    props: {
      text: { kind: 'string', doc: 'Required. What to show' },
      variant: {
        kind: 'enum',
        values: TEXT_VARIANTS,
        doc: 'Type size; defaults to body',
      },
      color: {
        kind: 'enum',
        values: COLOR_ROLES,
        doc: 'Colour role; use on captions that carry status',
      },
    },
    children: false,
  },
  Icon: {
    doc: 'A glyph. Pair one with a heading or a list item to make it scannable.',
    props: {
      icon: { kind: 'enum', values: ICON_NAMES, doc: 'Required. Icon name' },
      size: { kind: 'number', doc: 'Size in logical pixels; defaults to 24' },
      color: { kind: 'enum', values: COLOR_ROLES, doc: 'Colour role' },
    },
    children: false,
  },
  Image: {
    doc: 'A remote image, by URL.',
    props: {
      src: { kind: 'string', doc: 'Required. Absolute https URL' },
      width: { kind: 'number', doc: 'Width in logical pixels' },
      height: { kind: 'number', doc: 'Height in logical pixels' },
      fit: { kind: 'enum', values: IMAGE_FITS, doc: 'How it fills its box' },
    },
    children: false,
  },
  Card: {
    doc: 'A padded surface grouping related content. Use for one result or one proposal.',
    props: {
      color: {
        kind: 'enum',
        values: COLOR_ROLES,
        doc: 'Tints the border and wash; use when the card carries a status',
      },
    },
    children: true,
  },
  Badge: {
    doc: 'A small pill for a status or a tag.',
    props: {
      text: { kind: 'string', doc: 'Required. Two or three words at most' },
      color: {
        kind: 'enum',
        values: COLOR_ROLES,
        doc: 'Colour role; defaults to accent',
      },
      icon: { kind: 'enum', values: ICON_NAMES, doc: 'Optional leading icon' },
    },
    children: false,
  },
  ListItem: {
    doc: 'One row of a list: icon, title, optional supporting line.',
    props: {
      icon: { kind: 'enum', values: ICON_NAMES, doc: 'Leading icon' },
      color: {
        kind: 'enum',
        values: COLOR_ROLES,
        doc: 'Colour role for the icon',
      },
      title: { kind: 'string', doc: 'Required. The line that is read first' },
      subtitle: { kind: 'string', doc: 'Optional supporting line' },
      action: { kind: 'action', doc: 'Makes the whole row tappable' },
    },
    children: false,
  },
  AppButton: {
    doc: 'A labelled action. One primary per message at most.',
    props: {
      text: { kind: 'string', doc: 'Required. Verb first, e.g. "Schedule it"' },
      variant: {
        kind: 'enum',
        values: BUTTON_VARIANTS,
        doc: 'Emphasis; defaults to secondary',
      },
      icon: { kind: 'enum', values: ICON_NAMES, doc: 'Optional leading icon' },
      color: {
        kind: 'enum',
        values: COLOR_ROLES,
        doc: 'Colour role; defaults to accent',
      },
      expand: { kind: 'boolean', doc: 'Stretch to the full width' },
      action: { kind: 'action', doc: 'Required. What tapping it does' },
    },
    children: false,
  },
  AppIconButton: {
    doc: 'An icon-only action, for a secondary affordance next to text.',
    props: {
      icon: { kind: 'enum', values: ICON_NAMES, doc: 'Required. Icon name' },
      size: { kind: 'number', doc: 'Size in logical pixels' },
      color: { kind: 'enum', values: COLOR_ROLES, doc: 'Colour role' },
      accessibilityLabel: {
        kind: 'string',
        doc: 'Required. What the button does, for screen readers',
      },
      action: { kind: 'action', doc: 'Required. What tapping it does' },
    },
    children: false,
  },
};

/** Every component name. */
export const COMPONENT_NAMES = Object.keys(A2UI_CATALOG) as ComponentName[];

/** Action types a model is allowed to emit. Anything else is dropped. */
export const MODEL_ACTION_TYPES = [
  'reply',
  'confirm',
  'openUrl',
  'dismiss',
  'thread',
] as const;

/** Thread operations a `thread` action may carry. */
export const THREAD_OPS = ['solve', 'reopen', 'rename', 'delete'] as const;

/**
 * The catalog, written out for the system prompt.
 *
 * Generated rather than hand-written so the prompt and the validator can never
 * drift: a prop added above shows up here on the next request.
 */
export function buildCatalogPrompt(): string {
  const lines: string[] = [
    '## Icons',
    '',
    'Every icon name, and the only ones that exist. One that is not here is',
    'dropped, taking its component with it.',
    '',
    ICON_NAMES.join(', '),
    '',
    '## Components',
    '',
  ];

  for (const name of COMPONENT_NAMES) {
    const schema = A2UI_CATALOG[name];
    lines.push(`### ${name}`);
    lines.push(schema.doc);

    for (const [prop, spec] of Object.entries(schema.props)) {
      // The icon list is long and appears on five components. Printed in full
      // each time it was more than a third of the system prompt, and a model
      // that has already read it once does not read it better the fifth time.
      const values =
        spec.values === ICON_NAMES
          ? 'icon name'
          : (spec.values?.join(' | ') ?? spec.kind);
      lines.push(`- ${prop} (${values}): ${spec.doc}`);
    }

    if (schema.children) {
      lines.push('- children (component[]): nested components');
    }
    lines.push('');
  }

  return lines.join('\n');
}

/** The action vocabulary, written out for the system prompt. */
export function buildActionPrompt(): string {
  return [
    '## Actions',
    '',
    'An action is an object on a component. Only these five exist:',
    '',
    '- {"type":"reply","text":"..."} sends that text as the user\'s next message.',
    '  This is how you offer a follow-up: the button text is what the user sees,',
    '  the action text is what they end up saying.',
    '- {"type":"confirm","text":"..."} is a reply that also authorises the change',
    "  you just described. It is the only way a tool that alters the user's data",
    '  ever runs. Put exactly one on a proposal, on the primary button, and make',
    '  its text restate the whole action. Never put one on a message that is not',
    '  proposing a specific change.',
    '- {"type":"openUrl","url":"https://..."} opens a link.',
    '- {"type":"dismiss"} closes the component without sending anything.',
    `- {"type":"thread","op":"${THREAD_OPS.join('|')}"} changes this thread.`,
    '  Use "solve" when the user\'s request is fully handled and nothing is left',
    '  to do. "rename" also takes a "title".',
    '',
    'Never invent another action type. {"type":"tool"} does not exist and a',
    'button carrying one is dropped along with the button, so the user taps',
    'nothing. Running a tool is not something you build into the tree: you call',
    'the tool yourself, in this same turn, and then write the sentence saying',
    'what you did. Never put a tool name, a call id or raw arguments in an',
    'action.',
    '',
    'A reply or confirm action has to stand on its own. Its text becomes the',
    'user\'s next message, and that message is all you get: "Agendar reunião com',
    'cliente amanhã, 19/09, das 09:00 às 15:00" works, "Sim" and "Pode agendar"',
    'do not.',
  ].join('\n');
}
