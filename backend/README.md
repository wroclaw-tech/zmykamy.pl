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

Mobile clients authenticate with the `Authorization: Bearer <token>` header, using the token from the `set-auth-token` response header. Send `X-Device-Name` (e.g. `iPhone 16 Pro`) on sign-up and sign-in to name the session.

Errors are returned as `{ "error": { "code", "message" } }`; Better Auth endpoints under `/auth/*` return `{ "code", "message" }`.

- `GET /` — health check, returns `ok`

### Auth & user data

- `/auth/*` — Better Auth (e.g. `POST /auth/sign-up/email`, `POST /auth/sign-in/email`)
- `GET /auth/get-session` — the signed-in user and session
- `POST /auth/update-user` — update profile and settings; returns `{ "status": true }`:
  - `name` — nickname shown to other trip members (asked at sign-up)
  - `firstName`, `lastName` — or `null`
  - `phone` — international format, normalized to E.164 (e.g. `+48512345678`), or `null`
  - `blikPhone` — `+48` number for BLIK transfers, normalized to E.164, or `null`
  - `iban` — checksum-validated, stored without spaces in uppercase, or `null`
  - `themePalette` — `ocean`, `beach`, `cities`, `mountains`, `tropics`, `festivals` or `null`
  - `language` — `pl` (default), `en`
  - `defaultCurrency` — ISO 4217 code, default `PLN`
  - `dateFormat` — `dd.MM.yyyy` (default), `yyyy-MM-dd`, `dd/MM/yyyy`, `MM/dd/yyyy`
  - `weekStart` — `monday` (default), `sunday`
  - `termsVersion` — stamps `termsAcceptedAt`

### Security

- `POST /auth/change-email` — `{ newEmail }`; applied immediately while the email is unverified
- `POST /auth/change-password` — `{ currentPassword, newPassword, revokeOtherSessions? }`
- `GET /auth/list-accounts` — linked sign-in methods; the `credential` account's `updatedAt` is the last password change
- `GET /auth/list-sessions` — active sessions (`deviceName`, `city`, `countryCode`, `userAgent`, `ipAddress`, `token`, …); `city` (English name) and `countryCode` are looked up from the IP via [FreeIPAPI](https://freeipapi.com) at sign-in and are `null` when the lookup fails
- `POST /auth/revoke-session` — `{ token }`
- `POST /auth/revoke-other-sessions` — sign out all other devices
- `POST /auth/revoke-sessions` — sign out all devices, including the current one
- `POST /auth/delete-user` — `{ password }`; permanently deletes the account with its sessions and linked accounts. `password` can be omitted (e.g. for accounts without one) when the session was created within the last day

## Manual testing

Open `bruno/` as a collection in [Bruno](https://www.usebruno.com) (3.0+, the collection uses the OpenCollection YAML format). Run `auth/Sign in` and its returned token will be auto-added for future requests.

## Database

- `bun run db:generate` — generate a migration from schema changes
- `bun run db:migrate` — apply migrations
- `bun run db:studio` — open Drizzle Studio
- `bun run auth:generate` — regenerate the Better Auth schema after changing auth config or plugins
