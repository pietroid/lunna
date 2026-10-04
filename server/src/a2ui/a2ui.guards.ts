import { formatRange, Interval } from '../time/work-hours';
import { Zone } from '../time/zone';
import { A2uiComponent } from './a2ui.types';

/**
 * The one question the timeline still asks.
 *
 * Everything else a drag used to ask about — how long is this, may I book it,
 * that hour is taken, shall I take it off the calendar — was the screen
 * asking the user to do arithmetic it could do itself. All of it is gone. A
 * card has an hour because everything has an hour, and dragging one changes
 * which hour, which needs no permission.
 *
 * What is left is the only drag that destroys something: putting a card at
 * the top of the day while something else is already running. That one has a
 * real answer only the user has, so it is the only one asked.
 */

/** The button that closes a guard and changes nothing. */
function cancelButton(): A2uiComponent {
  return {
    component: 'AppButton',
    text: 'Cancelar',
    variant: 'tertiary',
    expand: true,
    action: { type: 'dismiss' },
  };
}

/**
 * Asks what happens to the thing that was already running.
 *
 * Both answers move the dragged card to now. They differ in what becomes of
 * what it displaced: finished, or further down the day.
 */
export function startNowGuard(
  eventId: string,
  index: number,
  current: { title: string; interval: Interval },
  zone: Zone,
): A2uiComponent {
  return {
    component: 'Column',
    gap: 'normal',
    children: [
      {
        component: 'ListItem',
        icon: 'alarm',
        title: 'Começar agora?',
        subtitle: `${current.title} está rodando, ${formatRange(current.interval, zone)}.`,
      },
      {
        component: 'AppButton',
        text: 'Concluir o atual',
        variant: 'primary',
        icon: 'check',
        expand: true,
        action: {
          type: 'timing',
          eventId,
          index,
          decision: 'solve_current',
        },
      },
      {
        component: 'AppButton',
        text: 'Deixar para depois',
        variant: 'secondary',
        expand: true,
        action: {
          type: 'timing',
          eventId,
          index,
          decision: 'postpone_current',
        },
      },
      cancelButton(),
    ],
  };
}

/**
 * Says the calendar has not kept up, and offers to try again.
 *
 * The one thing the user ever learns about the queue behind the timeline.
 * Everything they did is done and on screen; what failed is the copy of it
 * that lives on Google, which is worth knowing about and never worth undoing
 * their work over. So this says what is out of step and gives them the
 * button, rather than rolling the day back to a state they did not ask for.
 */
export function syncFailedUi(title: string): A2uiComponent {
  return {
    component: 'Column',
    gap: 'normal',
    children: [
      {
        component: 'ListItem',
        icon: 'cloud',
        color: 'warning',
        title: 'Sua agenda não acompanhou',
        subtitle: `"${title}" está no Focus, mas não no Google Agenda.`,
      },
      {
        component: 'Text',
        text: 'O seu dia continua como você deixou. É só a cópia no Google que ficou para trás.',
        variant: 'caption',
        color: 'ink2',
      },
      {
        component: 'AppButton',
        text: 'Tentar de novo',
        variant: 'primary',
        icon: 'arrowRight',
        expand: true,
        action: { type: 'sync' },
      },
      {
        component: 'AppButton',
        text: 'Agora não',
        variant: 'tertiary',
        expand: true,
        action: { type: 'dismiss' },
      },
    ],
  };
}
