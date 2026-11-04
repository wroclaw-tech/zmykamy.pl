# zmykamy.pl

Mobile app for planning group trips.

- `backend/` — Bun + Hono API with Better Auth and Postgres
- `ios/` — SwiftUI app
- `docs/` — product docs

## Running locally

### Backend

Requires [Bun](https://bun.sh) and Docker.

```bash
cd backend
bun install
cp .env.example .env
bun run db:up
bun run db:migrate
bun run dev
```

The API listens on `http://localhost:3000`. See [`backend/README.md`](backend/README.md) for endpoints and details.

### iOS app

Open `ios/zmykamy.pl.xcodeproj` in Xcode and run the `zmykamy.pl` scheme on an iOS Simulator.

Debug builds talk to the local backend at `http://localhost:3000`, so start it first. To use the production API (`https://api.zmykamy.pl`) instead:

1. **Product → Scheme → Edit Scheme…** (`⌘ <`)
2. Select **Run** → **Arguments**
3. Under **Environment Variables** enable the `ZMYKAMY_API_URL` checkbox, then run the app

Uncheck it to switch back to the local backend. `localhost` only reaches your Mac from the Simulator, so enable the variable when running on a physical device. Release builds always use the production API.
