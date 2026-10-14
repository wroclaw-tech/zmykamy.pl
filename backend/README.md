# backend

Hono + Better Auth + Drizzle on Bun, backed by Postgres.

## Setup

```bash
bun install
cp .env.example .env
bun run db:up
bun run db:migrate
bun run dev
```

The API listens on `http://localhost:3000` locally and on `https://api.zmykamy.pl` in production. `BETTER_AUTH_URL` must match the public URL of the environment.

If port `5432` is taken, set `POSTGRES_PORT` in `.env` and update the port in `DATABASE_URL`.

## Endpoints

Mobile clients authenticate with the `Authorization: Bearer <token>` header, using the token from the `set-auth-token` response header.

Errors are returned as `{ "error": { "code", "message" } }`; Better Auth endpoints under `/auth/*` return `{ "code", "message" }`.

- `GET /` — health check, returns `ok`

### Auth & user data

- `/auth/*` — Better Auth (e.g. `POST /auth/sign-up/email`, `POST /auth/sign-in/email`)
- `GET /auth/get-session` — the signed-in user and session
- `POST /auth/update-user` — update `name`, `themePalette` (`ocean`, `beach`, `cities`, `mountains`, `tropics`, `festivals` or `null`) or `termsVersion` (stamps `termsAcceptedAt`); returns `{ "status": true }`

## Manual testing

Open `bruno/` as a collection in [Bruno](https://www.usebruno.com) (3.0+, the collection uses the OpenCollection YAML format). Run `auth/Sign in` and its returned token will be auto-added for future requests.

## Database

- `bun run db:generate` — generate a migration from schema changes
- `bun run db:migrate` — apply migrations
- `bun run db:studio` — open Drizzle Studio
- `bun run auth:generate` — regenerate the Better Auth schema after changing auth config or plugins
