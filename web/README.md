# web

nginx container for `https://zmykamy.pl`. It serves the landing page and the files iOS needs to open invite links (`/j/<slug>`) straight in the app.

- `/.well-known/apple-app-site-association` — generated on startup from `APPLE_TEAM_ID`; the container exits if it is not set
- `/j/*` — proxied to the backend, which renders the invite page for people without the app
- everything else — static files from `public/`

## Environment

- `APPLE_TEAM_ID` — Apple Developer team ID, e.g. `ABCDE12345`
- `BACKEND_URL` — backend origin without a trailing slash, e.g. `https://api.zmykamy.pl`

## Running locally

```bash
docker build -f Containerfile -t zmykamy-web .
docker run --rm -p 8080:80 -e APPLE_TEAM_ID=ABCDE12345 -e BACKEND_URL=http://host.docker.internal:3000 zmykamy-web
```

## Production

Deployed on Coolify with the `zmykamy.pl` domain; Coolify terminates TLS, the container listens on port 80. The AASA path must answer `200` without redirects. Apple's CDN caches the file, check what it sees with:

```bash
curl https://app-site-association.cdn-apple.com/a/v1/zmykamy.pl
```
