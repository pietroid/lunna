import { A2uiComponent } from './a2ui.types';

/**
 * The trees the server writes itself.
 *
 * Only what the model cannot be trusted to say: the turn where it never
 * answered, and the turn where a change to the user's data failed. Everything
 * else is the model's own reply, validated and drawn.
 *
 * There is no approval dialog here. A write is proposed inside an ordinary
 * reply, the model writes that proposal itself, and the user's tap is what
 * authorises the next turn to run it.
 */

/** Says the assistant is unreachable, without blaming the user. */
export function unavailableUi(): A2uiComponent {
  return {
    component: 'Column',
    gap: 'normal',
    children: [
      {
        component: 'ListItem',
        icon: 'cloud',
        color: 'warning',
        title: 'Não consegui me conectar agora',
        subtitle: 'Nada foi perdido. Tente de novo em instantes.',
      },
      {
        component: 'AppButton',
        text: 'Tentar de novo',
        variant: 'secondary',
        icon: 'arrowRight',
        action: { type: 'reply', text: 'Tenta de novo' },
      },
    ],
  };
}

/**
 * Says the model answered with nothing usable.
 *
 * Distinct from [unavailableUi]: the agent was reached and the tools may well
 * have run, so this offers to pick the turn back up rather than implying the
 * whole thing was lost.
 */
export function emptyReplyUi(): A2uiComponent {
  return {
    component: 'Column',
    gap: 'normal',
    children: [
      {
        component: 'ListItem',
        icon: 'question',
        color: 'warning',
        title: 'Me perdi na resposta',
        subtitle: 'Pode repetir? Se algo já foi feito, eu confiro para você.',
      },
      {
        component: 'AppButton',
        text: 'Tentar de novo',
        variant: 'secondary',
        icon: 'arrowRight',
        action: { type: 'reply', text: 'Tenta de novo' },
      },
    ],
  };
}

/** A plain sentence, for the cases that need nothing more. */
export function textUi(text: string): A2uiComponent {
  return { component: 'Text', text, variant: 'body' };
}

/**
 * Says a change the user asked for did not happen.
 *
 * The one tree that overrules the model. A failed write is exactly where a
 * model is most likely to write "pronto, agendei": the tool result says it
 * broke, but the turn has momentum and the sentence is already half written.
 * So the server stops asking. It names what was attempted, using the tool's own
 * summary, says why in words, and offers the retry.
 *
 * [summary] comes from the tool and is already in Portuguese. [reason] is the
 * raw error, which is English, technical, and never shown: it is mapped to one
 * of a few sentences a person can act on.
 */
export function writeFailedUi(summary: string, reason: string): A2uiComponent {
  return {
    component: 'Column',
    gap: 'normal',
    children: [
      {
        component: 'ListItem',
        icon: 'xCircle',
        color: 'danger',
        title: 'Não consegui fazer isso',
        subtitle: summary,
      },
      {
        component: 'Text',
        text: humanReason(reason),
        variant: 'caption',
        color: 'ink2',
      },
      {
        component: 'AppButton',
        text: 'Tentar de novo',
        variant: 'secondary',
        icon: 'arrowRight',
        action: { type: 'confirm', text: `Tenta de novo: ${summary}` },
      },
    ],
  };
}

/**
 * The failure, in a sentence the user can do something with.
 *
 * Deliberately short on detail. The full error is in the trace, under the id
 * the message carries; what belongs on screen is whether this is worth
 * retrying, and nothing about Google's API surface.
 */
function humanReason(reason: string): string {
  const text = reason.toLowerCase();

  if (
    text.includes('auth') ||
    text.includes('credential') ||
    text.includes('not configured')
  ) {
    return 'A conexão com sua agenda não está funcionando agora.';
  }
  if (text.includes('not found') || text.includes('404')) {
    return 'Não encontrei esse compromisso. Ele pode já ter sido alterado.';
  }
  if (
    text.includes('timeout') ||
    text.includes('etimedout') ||
    text.includes('econnreset')
  ) {
    return 'A agenda demorou demais para responder.';
  }
  if (
    text.includes('forbidden') ||
    text.includes('403') ||
    text.includes('permission')
  ) {
    return 'Essa conta não tem permissão para essa mudança.';
  }

  return 'A agenda recusou a operação. Nada foi alterado.';
}

/**
 * Whether a tree asks the user to authorise a change.
 *
 * The presence of a confirm action is what arms the next turn, so this is the
 * server's only way of knowing that the last thing it showed was a proposal.
 */
export function containsConfirm(component: A2uiComponent): boolean {
  if (component.action?.type === 'confirm') return true;
  return (component.children ?? []).some(containsConfirm);
}
