import { Injectable } from '@nestjs/common';
import {
  A2UI_CATALOG,
  COLOR_ROLES,
  COMPONENT_NAMES,
  ICON_NAMES,
  MODEL_ACTION_TYPES,
  THREAD_OPS,
} from './a2ui.catalog';
import {
  A2uiAction,
  A2uiComponent,
  A2uiIssue,
  A2uiValidationResult,
  ComponentName,
} from './a2ui.types';

/** What the validator is allowed to accept for this particular tree. */
export interface ValidationOptions {
  /**
   * Tool names to scrub out of user-facing strings. Supplied by the agent, so
   * a new tool is covered without editing this file.
   */
  toolNames?: string[];
}

/** Shown when nothing usable survived. */
export const FALLBACK_TEXT =
  'Não consegui montar essa resposta direito. Pode pedir de novo?';

/** Props every component may carry, regardless of its schema. */
const UNIVERSAL_PROPS = new Set(['component', 'children', 'action']);

/** Markdown noise a model adds out of habit. */
const MARKDOWN_NOISE = /[`*_#>]/g;

/** Anything that reads as machine output rather than speech. */
const MACHINE_WORDS =
  /\b(tool[_ ]call|function[_ ]call|tool_call_id|a2ui|json|payload|schema|endpoint|api call)\b/gi;

/**
 * Checks, repairs and scrubs a tree before it is stored or sent.
 *
 * Two jobs, and the second matters more. Structural validation stops the app
 * crashing on a component it cannot draw. Scrubbing stops the user reading a
 * tool name, an id, or a JSON fragment: a model that has just called a tool is
 * apt to narrate it, and a validator that only checked shape would happily
 * pass that straight through.
 *
 * A bad node is dropped rather than failing the whole tree, so one malformed
 * button does not cost the user the sentence above it.
 */
@Injectable()
export class A2uiValidationService {
  validate(
    value: unknown,
    options: ValidationOptions = {},
  ): A2uiValidationResult {
    const issues: A2uiIssue[] = [];
    const component = this._node(value, 'root', options, issues);

    if (component === undefined) {
      issues.push({
        path: 'root',
        severity: 'reject',
        message: 'Nothing renderable survived validation',
      });

      return {
        component: { component: 'Text', text: FALLBACK_TEXT, variant: 'body' },
        issues,
        clean: false,
      };
    }

    return { component, issues, clean: issues.length === 0 };
  }

  /** Every string a user would read, for logging and previews. */
  collectText(component: A2uiComponent): string[] {
    const found: string[] = [];

    const walk = (node: A2uiComponent): void => {
      for (const key of ['text', 'title', 'subtitle']) {
        const value = node[key];
        if (typeof value === 'string' && value.trim() !== '') found.push(value);
      }
      for (const child of node.children ?? []) walk(child);
    };

    walk(component);
    return found;
  }

  private _node(
    value: unknown,
    path: string,
    options: ValidationOptions,
    issues: A2uiIssue[],
  ): A2uiComponent | undefined {
    if (value === null || typeof value !== 'object' || Array.isArray(value)) {
      issues.push({
        path,
        severity: 'reject',
        message: 'Not a component object',
      });
      return undefined;
    }

    const raw = value as Record<string, unknown>;
    const name = raw.component;

    if (
      typeof name !== 'string' ||
      !COMPONENT_NAMES.includes(name as ComponentName)
    ) {
      issues.push({
        path,
        severity: 'reject',
        message: `Unknown component "${String(name)}"`,
      });
      return undefined;
    }

    const componentName = name as ComponentName;
    const schema = A2UI_CATALOG[componentName];
    const node: A2uiComponent = { component: componentName };

    for (const [key, entry] of Object.entries(raw)) {
      if (UNIVERSAL_PROPS.has(key)) continue;

      const spec = schema.props[key];
      if (spec === undefined) {
        issues.push({
          path,
          severity: 'repair',
          message: `Dropped unsupported prop "${key}" on ${componentName}`,
        });
        continue;
      }

      const cleaned = this._prop(
        componentName,
        key,
        entry,
        path,
        options,
        issues,
      );
      if (cleaned !== undefined) node[key] = cleaned;
    }

    if (schema.children) {
      const children: A2uiComponent[] = [];
      const rawChildren = Array.isArray(raw.children) ? raw.children : [];

      rawChildren.forEach((child, index) => {
        const built = this._node(
          child,
          `${path}.children[${index}]`,
          options,
          issues,
        );
        if (built !== undefined) children.push(built);
      });

      if (children.length === 0) {
        issues.push({
          path,
          severity: 'reject',
          message: `Dropped empty ${componentName}`,
        });
        return undefined;
      }

      node.children = children;
    }

    if (raw.action !== undefined) {
      const action = this._action(raw.action, path, options, issues);
      if (action !== undefined) node.action = action;
    }

    return this._requireProps(node, path, issues);
  }

  private _prop(
    component: ComponentName,
    key: string,
    value: unknown,
    path: string,
    options: ValidationOptions,
    issues: A2uiIssue[],
  ): unknown {
    const spec = A2UI_CATALOG[component].props[key];

    switch (spec.kind) {
      case 'string': {
        if (typeof value !== 'string') {
          issues.push({
            path,
            severity: 'repair',
            message: `Dropped non-string "${key}" on ${component}`,
          });
          return undefined;
        }
        return this._scrub(value, `${path}.${key}`, options, issues);
      }
      case 'number': {
        const parsed = typeof value === 'number' ? value : Number(value);
        if (!Number.isFinite(parsed)) {
          issues.push({
            path,
            severity: 'repair',
            message: `Dropped non-numeric "${key}" on ${component}`,
          });
          return undefined;
        }
        return parsed;
      }
      case 'boolean':
        return value === true;
      case 'enum': {
        if (typeof value === 'string' && spec.values?.includes(value))
          return value;
        issues.push({
          path,
          severity: 'repair',
          message: `Dropped invalid ${key} "${String(value)}" on ${component}`,
        });
        return undefined;
      }
      case 'action':
        return this._action(value, path, options, issues);
    }
  }

  /**
   * Makes one user-facing string safe to read.
   *
   * Returns undefined when nothing worth showing is left, which drops the node
   * rather than leaving a blank line where a sentence should be.
   */
  private _scrub(
    value: string,
    path: string,
    options: ValidationOptions,
    issues: A2uiIssue[],
  ): string | undefined {
    const original = value;
    let text = value.trim();

    if (this._looksLikeData(text)) {
      issues.push({
        path,
        severity: 'reject',
        message: 'Dropped a string that was raw data rather than prose',
      });
      return undefined;
    }

    for (const tool of options.toolNames ?? []) {
      if (text.includes(tool)) {
        text = text.split(tool).join('that').replace(/\s+/g, ' ');
        issues.push({
          path,
          severity: 'repair',
          message: `Scrubbed tool name "${tool}" from user-facing text`,
        });
      }
    }

    if (MACHINE_WORDS.test(text)) {
      MACHINE_WORDS.lastIndex = 0;
      issues.push({
        path,
        severity: 'repair',
        message: 'User-facing text mentioned machine internals',
      });
      text = text.replace(MACHINE_WORDS, '').replace(/\s{2,}/g, ' ');
    }
    MACHINE_WORDS.lastIndex = 0;

    if (MARKDOWN_NOISE.test(text)) {
      text = text.replace(MARKDOWN_NOISE, '');
      issues.push({
        path,
        severity: 'repair',
        message: 'Stripped markdown from user-facing text',
      });
    }

    text = text
      .replace(/\s+\./g, '.')
      .replace(/\s{2,}/g, ' ')
      .trim();

    if (text === '') {
      issues.push({
        path,
        severity: 'reject',
        message: `Dropped a string that scrubbed to nothing: "${original.slice(0, 60)}"`,
      });
      return undefined;
    }

    return text;
  }

  /** Whether a string is a payload wearing a sentence's clothes. */
  private _looksLikeData(text: string): boolean {
    if (/^[[{]/.test(text) && /[\]}]$/.test(text)) return true;
    if (/^"?[a-z_]+"?\s*:\s*[{["]/.test(text)) return true;
    // An ISO timestamp is fine inside a sentence, but a bare pair of them is a
    // busy interval the model forgot to put into words.
    if (
      /^\d{4}-\d{2}-\d{2}T[\d:.]+Z?\s*(-|to|,)\s*\d{4}-\d{2}-\d{2}T/.test(text)
    ) {
      return true;
    }
    return false;
  }

  private _action(
    value: unknown,
    path: string,
    options: ValidationOptions,
    issues: A2uiIssue[],
  ): A2uiAction | undefined {
    if (value === null || typeof value !== 'object') {
      issues.push({
        path,
        severity: 'repair',
        message: 'Dropped a non-object action',
      });
      return undefined;
    }

    const raw = value as Record<string, unknown>;
    const type = raw.type;

    if (
      typeof type !== 'string' ||
      !MODEL_ACTION_TYPES.includes(type as never)
    ) {
      issues.push({
        path,
        severity: 'repair',
        message: `Dropped unknown action type "${String(type)}"`,
      });
      return undefined;
    }

    switch (type) {
      case 'reply':
      case 'confirm': {
        const text = typeof raw.text === 'string' ? raw.text.trim() : '';
        if (text === '') {
          issues.push({
            path,
            severity: 'repair',
            message: `${type} action has no text`,
          });
          return undefined;
        }
        // A confirm is what authorises a write on the next turn, so it has to
        // say enough to stand as the user's whole message. "Sim" arriving alone
        // would authorise a turn that no longer knows what it is agreeing to.
        if (type === 'confirm' && text.length < 8) {
          issues.push({
            path,
            severity: 'repair',
            message: `Dropped a confirm too vague to stand alone: "${text}"`,
          });
          return undefined;
        }
        return { type, text };
      }
      case 'openUrl': {
        const url = typeof raw.url === 'string' ? raw.url.trim() : '';
        if (!/^https?:\/\//.test(url)) {
          issues.push({
            path,
            severity: 'repair',
            message: `Dropped openUrl with unusable url "${url}"`,
          });
          return undefined;
        }
        return { type: 'openUrl', url };
      }
      case 'dismiss':
        return { type: 'dismiss' };
      case 'thread': {
        const op = raw.op;
        if (typeof op !== 'string' || !THREAD_OPS.includes(op as never)) {
          issues.push({
            path,
            severity: 'repair',
            message: `Dropped thread action with unknown op "${String(op)}"`,
          });
          return undefined;
        }
        const title =
          typeof raw.title === 'string' ? raw.title.trim() : undefined;
        if (op === 'rename' && (title === undefined || title === '')) {
          issues.push({
            path,
            severity: 'repair',
            message: 'Dropped a rename with no title',
          });
          return undefined;
        }
        return { type: 'thread', op: op as never, title };
      }
      default:
        return undefined;
    }
  }

  /** Drops a node that lost a prop it cannot be drawn without. */
  private _requireProps(
    node: A2uiComponent,
    path: string,
    issues: A2uiIssue[],
  ): A2uiComponent | undefined {
    const missing = (prop: string): boolean =>
      node[prop] === undefined || node[prop] === '';

    const drop = (reason: string): undefined => {
      issues.push({ path, severity: 'reject', message: reason });
      return undefined;
    };

    switch (node.component) {
      case 'Text':
        if (missing('text')) return drop('Dropped a Text with no text');
        break;
      case 'Badge':
        if (missing('text')) return drop('Dropped a Badge with no text');
        break;
      case 'ListItem':
        if (missing('title')) return drop('Dropped a ListItem with no title');
        break;
      case 'Icon':
        if (missing('icon')) return drop('Dropped an Icon with no icon');
        break;
      case 'Image':
        if (missing('src')) return drop('Dropped an Image with no src');
        break;
      case 'AppButton':
        if (missing('text')) return drop('Dropped an AppButton with no label');
        if (node.action === undefined) {
          return drop('Dropped an AppButton with no action');
        }
        break;
      case 'AppIconButton':
        if (missing('icon'))
          return drop('Dropped an AppIconButton with no icon');
        if (node.action === undefined) {
          return drop('Dropped an AppIconButton with no action');
        }
        if (missing('accessibilityLabel')) {
          node.accessibilityLabel = 'Action';
          issues.push({
            path,
            severity: 'repair',
            message: 'AppIconButton had no accessibility label',
          });
        }
        break;
      default:
        break;
    }

    // An icon name outside the catalog would draw as a question mark, so it is
    // cheaper to lose the icon than to show a broken one.
    for (const key of ['icon']) {
      const value = node[key];
      if (typeof value === 'string' && !ICON_NAMES.includes(value as never)) {
        issues.push({
          path,
          severity: 'repair',
          message: `Dropped unknown icon "${value}"`,
        });
        delete node[key];
        if (node.component === 'Icon' || node.component === 'AppIconButton') {
          return drop(`Dropped ${node.component} with unknown icon "${value}"`);
        }
      }
    }

    const color = node.color;
    if (typeof color === 'string' && !COLOR_ROLES.includes(color as never)) {
      issues.push({
        path,
        severity: 'repair',
        message: `Dropped unknown colour "${color}"`,
      });
      delete node.color;
    }

    return node;
  }
}
