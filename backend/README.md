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

`bun run db:up` also starts [Garage](https://garagehq.deuxfleurs.fr) as local S3 storage on `http://localhost:3900`; the `garage-init` container creates the `zmykamy` bucket and the access key from `.env.example`. If port `3900` is taken, set `S3_PORT` in `.env` and update the port in `S3_ENDPOINT`. In production the `S3_*` variables point at the shared Garage instance.

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

### Trips

All endpoints require authentication and are visible only to trip members; other users get `404`. Changing or deleting a trip requires the `organizer` role, participants get `403`.

- `GET /trips` - trips the user belongs to
- `POST /trips` - create a trip; the creator becomes its organizer. Returns `201` with the trip:
  - `name` - 1-60 characters
  - `destination` - `{ name, country, latitude, longitude }` (all but `name` nullable), or `null`
  - `startDate`, `endDate` - `YYYY-MM-DD`, `endDate` not before `startDate`
  - `currency` - ISO 4217 base currency, e.g. `PLN`
- `GET /trips/:id` - a single trip
- `PATCH /trips/:id` - update any of the `POST` fields, or `coverImageKey` (`null` removes the cover)
- `DELETE /trips/:id` - delete the trip with its cover, returns `204`
- `POST /trips/:id/cover/upload-url` - returns `{ uploadUrl, key }`; `PUT` the JPEG to `uploadUrl` with `Content-Type: image/jpeg` within 5 minutes, then `PATCH` the trip with `coverImageKey: key`

A trip is returned as `{ id, name, destination, startDate, endDate, currency, coverUrl, myRole, members: [{ userId, name, image, role, balance }] }`. `coverUrl` is a presigned link valid for an hour. `balance` is in minor units of the trip currency, positive when the member is owed money. Leaving the trip or removing a member with a non-zero balance returns `409 member_not_settled`.

### Expenses

All amounts are integers in minor units of the trip currency. Any member can add expenses; changing or deleting one requires being its author or an organizer.

- `GET /trips/:id/expenses` - `{ expenses }`, newest day first
- `POST /trips/:id/expenses` - `{ title, amount, date, icon?, paidBy, participants }`; the amount is split evenly between `participants` (member user ids), the remainder goes one unit at a time in user id order. Returns `201`
- `PATCH /trips/:id/expenses/:expenseId` - any of the `POST` fields; shares are recomputed when `amount` or `participants` change
- `DELETE /trips/:id/expenses/:expenseId` - returns `204`

An expense is returned as `{ id, title, amount, date, icon, paidBy: { userId, name }, shares: [{ userId, name, amount }], author, createdAt }`.

### Settlement

- `GET /trips/:id/settlement` - `{ balances, transfers, payments, naiveTransferCount }`. `transfers` is the fewest transfers that settle all balances (exact for up to 15 unsettled members); `paymentDetails` (`{ blikPhone, iban }` of the recipient) is only set on the viewer's own transfers. `naiveTransferCount` is how many transfers settling every expense separately would take
- `POST /trips/:id/settlement/payments` - `{ fromUserId, toUserId, amount }`; marks a transfer as paid and returns the updated settlement with `201`. Only the payer, the recipient or an organizer can record or undo a payment
- `DELETE /trips/:id/settlement/payments/:paymentId` - undoes a payment and returns the updated settlement

### Gallery

Photos and videos are uploaded straight to storage; the app makes the thumbnail (a JPEG) itself. Only trip members can list media, and the returned links are presigned for an hour.

- `POST /trips/:id/media/upload-url` - `{ kind, contentType }` (`photo` with `image/jpeg`, `video` with `video/mp4` or `video/quicktime`); returns `{ key, uploadUrl, thumbnailKey, thumbnailUploadUrl }`. `PUT` the file and its thumbnail within 5 minutes
- `POST /trips/:id/media` - `{ kind, contentType, key, thumbnailKey, width, height, durationSeconds?, takenAt }` once both files are uploaded; `takenAt` is an ISO date-time with offset. Returns `201`
- `GET /trips/:id/media` - `{ media }`, newest first, each `{ id, kind, url, thumbnailUrl, contentType, width, height, durationSeconds, takenAt, uploadedBy }`
- `DELETE /trips/:id/media/:mediaId` - the uploader or an organizer; deletes the files too, returns `204`

Deleting a trip also deletes its media files.

### Documents

Shared tickets, reservations and other documents, either a file (PDF, JPEG or PNG) or a link. Any member can add one; changing or deleting it requires being its author or an organizer.

- `POST /trips/:id/documents/upload-url` - `{ contentType }` (`application/pdf`, `image/jpeg`, `image/png`); returns `{ key, uploadUrl }`, `PUT` the file within 5 minutes
- `POST /trips/:id/documents` - `{ title, category, icon?, planPointId?, kind: "file", key, contentType }` or `{ title, category, icon?, planPointId?, kind: "link", url }`; `category` is `ticket`, `reservation` or `other`, `icon` defaults by category. Returns `201`
- `GET /trips/:id/documents` - `{ documents }`, oldest first
- `PATCH /trips/:id/documents/:documentId` - any of `title`, `category`, `icon`, `planPointId`, and `url` for links
- `DELETE /trips/:id/documents/:documentId` - deletes the file too, returns `204`

A document is returned as `{ id, title, category, icon, kind, url, fileUrl, contentType, planPointId, author, createdAt, updatedAt }`; `fileUrl` is presigned for an hour. Deleting a plan point detaches its documents.

### Notes

- `GET /trips/:id/notes` - `{ notes }`, pinned first, then recently updated
- `POST /trips/:id/notes` - `{ title, text?, pinned? }`; pinned notes are shown at the top of the trip. Returns `201`
- `PATCH /trips/:id/notes/:noteId` - any of the `POST` fields; the author or an organizer
- `DELETE /trips/:id/notes/:noteId` - the author or an organizer, returns `204`

A note is returned as `{ id, title, text, pinned, author, createdAt, updatedAt }`.

## Testing

```bash
bun run test:setup
bun run test
```

`test:setup` creates the `zmykamy_test` database from `.env.test` and migrates it; rerun it after adding migrations. Tests need the docker compose services running.

## Manual testing

Open `bruno/` as a collection in [Bruno](https://www.usebruno.com) (3.0+, the collection uses the OpenCollection YAML format). Run `auth/Sign in` and its returned token will be auto-added for future requests.

## Database

- `bun run db:generate` — generate a migration from schema changes
- `bun run db:migrate` — apply migrations
- `bun run db:studio` — open Drizzle Studio
- `bun run auth:generate` — regenerate the Better Auth schema after changing auth config or plugins
