/**
 * One action, as the app sends it back.
 *
 * The app does not interpret actions: it posts whatever the component carried
 * and renders whatever comes back. That keeps the decision about what an
 * action means on the server, where the catalog lives.
 */
export class ActionDto {
  /** The action object, verbatim from the rendered component. */
  action?: {
    type?: string;
    /** `reply` and `confirm` */
    text?: string;
    /** `thread` */
    op?: string;
    title?: string;
  };
}
