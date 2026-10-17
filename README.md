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

By default the app talks to `https://api-zmykamy.b.solvro.pl`. To use the local backend instead, set an environment variable on the scheme:

1. **Product → Scheme → Edit Scheme…** (`⌘ <`)
2. Select **Run** → **Arguments**
3. Under **Environment Variables** click **+** and add `ZMYKAMY_API_URL` = `http://localhost:3000`
4. Make sure the checkbox next to it is enabled, then run the app

Uncheck the variable to switch back to the production API. `localhost` only reaches your Mac from the Simulator, not from a physical device.
