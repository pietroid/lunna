import { Injectable } from '@nestjs/common';
import { A2uiComponent } from './a2ui.types';

/** What the parser made of a raw model reply. */
export interface ParseResult {
  /** The tree, when one could be recovered. */
  component?: A2uiComponent;
  /**
   * How it was recovered. Logged on every turn, because a run of `salvaged` or
   * `wrapped` is the first sign a model or a prompt change has regressed, long
   * before anyone notices the UI looks plainer.
   */
  strategy: 'direct' | 'fenced' | 'salvaged' | 'wrapped' | 'failed';
  /** What went wrong, when the strategy was not `direct`. */
  detail?: string;
}

/** Fenced blocks, with or without a language tag. */
const FENCE = /```(?:json|JSON)?\s*([\s\S]*?)```/;

/**
 * Turns whatever the model said into a component tree.
 *
 * Models wrap JSON in fences, apologise before it, and trail a sentence after
 * it. Rather than fail the turn on any of that, the parser works down a ladder
 * of increasingly forgiving strategies and reports which rung it landed on.
 */
@Injectable()
export class A2uiParserService {
  parse(raw: string): ParseResult {
    const trimmed = raw.trim();

    if (trimmed === '') {
      return { strategy: 'failed', detail: 'The model returned nothing' };
    }

    const direct = this._readTree(trimmed);
    if (direct !== undefined) return { component: direct, strategy: 'direct' };

    const fenced = FENCE.exec(trimmed);
    if (fenced !== null) {
      const tree = this._readTree(fenced[1].trim());
      if (tree !== undefined) {
        return {
          component: tree,
          strategy: 'fenced',
          detail: 'The reply was wrapped in a code fence',
        };
      }
    }

    const salvaged = this._salvage(trimmed);
    if (salvaged !== undefined) {
      return {
        component: salvaged,
        strategy: 'salvaged',
        detail: 'JSON was embedded in surrounding prose',
      };
    }

    // The model answered in plain prose. That is a format miss, not a failed
    // turn: the sentence it wrote is still the right answer, so it is wrapped
    // rather than thrown away.
    if (!trimmed.startsWith('{')) {
      return {
        component: { component: 'Text', text: trimmed, variant: 'body' },
        strategy: 'wrapped',
        detail: 'The model replied in prose instead of A2UI',
      };
    }

    return { strategy: 'failed', detail: 'The reply was not parseable JSON' };
  }

  /** Reads `{"a2ui": ...}`, or a bare tree, out of one JSON string. */
  private _readTree(candidate: string): A2uiComponent | undefined {
    let parsed: unknown;
    try {
      parsed = JSON.parse(candidate);
    } catch {
      return undefined;
    }

    if (parsed === null || typeof parsed !== 'object') return undefined;
    const object = parsed as Record<string, unknown>;

    const wrapped = object.a2ui;
    if (wrapped !== null && typeof wrapped === 'object') {
      return wrapped as A2uiComponent;
    }

    // Some models drop the wrapper and return the root component directly.
    if (typeof object.component === 'string') return object as A2uiComponent;

    return undefined;
  }

  /**
   * Pulls the first balanced JSON object out of a longer string.
   *
   * Scans rather than regexes, so a brace inside a string value does not end
   * the object early.
   */
  private _salvage(text: string): A2uiComponent | undefined {
    const start = text.indexOf('{');
    if (start === -1) return undefined;

    let depth = 0;
    let inString = false;
    let escaped = false;

    for (let i = start; i < text.length; i++) {
      const char = text[i];

      if (escaped) {
        escaped = false;
        continue;
      }
      if (char === '\\') {
        escaped = true;
        continue;
      }
      if (char === '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (char === '{') depth++;
      if (char === '}') {
        depth--;
        if (depth === 0) {
          return this._readTree(text.slice(start, i + 1));
        }
      }
    }

    return undefined;
  }
}
