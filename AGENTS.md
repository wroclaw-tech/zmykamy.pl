# zmykamy.pl

Monorepo for a mobile app for planning group trips.

- `backend/` — Bun + Hono API (see `backend/CLAUDE.md`)
- `ios/` — SwiftUI iOS app (see `ios/AGENTS.md`)
- `web/` — nginx container for zmykamy.pl (landing page, universal links)
- `docs/` — product docs

## Git

### Commits

Use Conventional Commits with the monorepo package as the scope:

```
<type>(<scope>): <short description>
```

- Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `perf`, `style`, `ci`, `build`
- Scopes: `backend`, `ios`, `web`, `docs`; omit the scope for changes spanning the whole repo
- Description in lowercase, imperative mood, no trailing period

Examples:

```
feat(ios): add trip list screen
fix(backend): handle expired sessions
chore(backend): add docker compose with postgres
docs: update concept
chore: reorganize files
```

Keep commits small and focused on one change. Don't mix changes from different packages in one commit.

### Branches

Never commit directly to `main`. Work on a branch named `<type>/<short-description>` (e.g. `feat/backend-auth`) and open a pull request.
