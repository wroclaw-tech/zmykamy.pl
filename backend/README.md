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

Errors are returned as `{ "error": { "code", "message" } }`; validation errors also carry `issues`.

- `GET /` — health check, returns `ok`

### Auth

- `/auth/*` — Better Auth (e.g. `POST /auth/sign-up/email`, `POST /auth/sign-in/email`, `GET /auth/get-session`)

`POST /auth/sign-up/email` also accepts `themePalette` and `termsVersion`

### Profile

- `GET /profile` — the signed-in user
- `PATCH /profile` — update `name`, `themePalette` (`ocean`, `beach`, `cities`, `mountains`, `tropics`, `festivals`) or `termsVersion`

## Manual testing

Open `bruno/` as a collection in [Bruno](https://www.usebruno.com) and select the `local` environment. Run `auth/Sign up` or `auth/Sign in` first — it stores the bearer token used by every other request.

## Database

- `bun run db:generate` — generate a migration from schema changes
- `bun run db:migrate` — apply migrations
- `bun run db:studio` — open Drizzle Studio
- `bun run auth:generate` — regenerate the Better Auth schema after changing auth config or plugins
