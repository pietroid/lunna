# Lunna

_Seu dia, no lugar._

Lunna is a personal day planner. Write down what needs doing and it gives
every block an hour, repacks the day when it changes (start, pause, extend,
finish, drag), repeats routines on their days, and reminds you at the right
moment.

- **App** (`app/`): Flutter, for iPhone, Android and the web.
- **Server** (`server/`): NestJS with Better Auth (Google sign-in) and
  Postgres on Neon through Drizzle.

Deployed to a Raspberry Pi as two Docker images pulled from GHCR.

- [SETUP.md](./SETUP.md): local development, Google OAuth, Neon, deployment.
- [AGENTS.md](./AGENTS.md): how the code is organised and the rules of the
  timeline.
