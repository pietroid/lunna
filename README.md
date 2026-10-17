# Lunna

_Seu dia, no lugar._

Lunna is a personal day planner. Write down what needs doing and it gives
every block an hour, repacks the day when it changes (start, pause, extend,
finish, drag), repeats routines on their days, and reminds you at the right
moment.

- **App** (`app/`): Flutter, for iPhone, Android and the web, built as two
  brands from one codebase: **Lunna** (light) and **Focus** (dark).
- **Server** (`server/`): NestJS with Better Auth (Google sign-in) and
  Postgres on Neon through Drizzle.

Deployed to a Raspberry Pi as Docker images pulled from GHCR: one backend
and a web image per brand.

- [SETUP.md](./SETUP.md): local development, Google OAuth, Neon, deployment.
- [MIGRATION.md](./MIGRATION.md): moving to two brands on one backend.
- [AGENTS.md](./AGENTS.md): how the code is organised and the rules of the
  timeline.
- [product/](./product): research RFCs and one record per delivered feature.
- [.tool/](./.tool): internal tools (open and comment on those docs, mockup
  prints).
