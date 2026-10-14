/** The Nest token the Better Auth instance is injected under. */
export const AUTH = Symbol('AUTH');

/** The signed-in person, as every controller reads them. */
export class AuthUser {
  declare id: string;
  declare email: string;
  declare name: string;
  declare image?: string;
  /** The IANA zone their day is measured in. */
  declare timeZone: string;
  /** When their working day starts, in minutes after midnight. */
  declare dayStart: number;
  /** When it ends, in minutes after midnight; 1440 is midnight. */
  declare dayEnd: number;
}
