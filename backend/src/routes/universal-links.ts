import { Hono } from "hono";
import { ApiError } from "../lib/errors";
import { escapeHtml } from "../lib/html";
import { validate } from "../lib/validation";
import { inviteSlugParamSchema } from "../schemas/trip";
import { findInvitedTrip } from "./invites";

const BUNDLE_ID = "pl.zmykamy.app";

const renderInvitePage = (tripName: string | null) => `<!doctype html>
<html lang="pl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Zmykamy</title>
<style>body{font-family:-apple-system,system-ui,sans-serif;max-width:28rem;margin:4rem auto;padding:0 1.5rem;text-align:center}</style>
</head>
<body>
<h1>${tripName ? escapeHtml(tripName) : "Zaproszenie nie jest już ważne"}</h1>
<p>${
  tripName
    ? "Otwórz ten link na iPhonie z zainstalowaną aplikacją Zmykamy, żeby dołączyć do wyjazdu."
    : "Poproś organizatora o nowy link."
}</p>
</body>
</html>`;

export const universalLinks = new Hono()
  .get("/.well-known/apple-app-site-association", (c) =>
    c.json({
      applinks: {
        details: [
          {
            appIDs: [`${process.env.APPLE_TEAM_ID}.${BUNDLE_ID}`],
            components: [{ "/": "/j/*" }],
          },
        ],
      },
    }),
  )
  .get("/j/:slug", validate("param", inviteSlugParamSchema), async (c) => {
    try {
      const record = await findInvitedTrip(c.req.valid("param").slug);
      return c.html(renderInvitePage(record.name));
    } catch (error) {
      if (error instanceof ApiError && error.status === 404) {
        return c.html(renderInvitePage(null), 404);
      }
      throw error;
    }
  });
