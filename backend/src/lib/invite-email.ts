import { escapeHtml } from "./html";

type InviteEmail = {
  tripName: string;
  startDate: string;
  endDate: string;
  inviterName: string;
  url: string;
};

const dateRangeFormat = new Intl.DateTimeFormat("pl-PL", {
  day: "numeric",
  month: "long",
  year: "numeric",
  timeZone: "UTC",
});

const formatDateRange = (startDate: string, endDate: string) =>
  dateRangeFormat.formatRange(new Date(startDate), new Date(endDate));

export const renderInviteEmail = ({
  tripName,
  startDate,
  endDate,
  inviterName,
  url,
}: InviteEmail) => {
  const dates = formatDateRange(startDate, endDate);
  const subject = `${inviterName} zaprasza Cię na wyjazd „${tripName}”`;
  const text = [
    `${inviterName} zaprasza Cię na wyjazd „${tripName}” (${dates}).`,
    "",
    "Dołącz do ekipy w aplikacji Zmykamy:",
    url,
    "",
    "Jeśli nie spodziewasz się tego zaproszenia, po prostu zignoruj tę wiadomość.",
  ].join("\n");
  const html = `<!doctype html>
<html lang="pl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(subject)}</title>
</head>
<body style="margin:0;padding:0;background:#f5f2eb;font-family:-apple-system,system-ui,'Segoe UI',Helvetica,Arial,sans-serif;color:#1c1c1e">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f5f2eb;padding:32px 16px">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:26px;padding:32px 28px">
<tr><td>
<p style="margin:0 0 8px;font-size:13px;font-weight:600;letter-spacing:0.3px;color:#6c6c70">ZAPROSZENIE DO WYJAZDU</p>
<h1 style="margin:0 0 8px;font-size:26px;line-height:1.2;color:#1c1c1e">${escapeHtml(tripName)}</h1>
<p style="margin:0 0 24px;font-size:15px;color:#6c6c70">${escapeHtml(dates)}</p>
<p style="margin:0 0 24px;font-size:16px;line-height:1.5">${escapeHtml(inviterName)} zaprasza Cię do ekipy w aplikacji Zmykamy.</p>
<a href="${escapeHtml(url)}" style="display:inline-block;background:#1a4da8;color:#ffffff;text-decoration:none;font-size:16px;font-weight:600;padding:14px 28px;border-radius:100px">Dołącz do wyjazdu</a>
<p style="margin:24px 0 0;font-size:13px;line-height:1.5;color:#6c6c70">Jeśli przycisk nie działa, otwórz ten link:<br><a href="${escapeHtml(url)}" style="color:#1a4da8;word-break:break-all">${escapeHtml(url)}</a></p>
</td></tr>
</table>
<p style="margin:16px 0 0;font-size:12px;color:#6c6c70">Jeśli nie spodziewasz się tego zaproszenia, po prostu zignoruj tę wiadomość.</p>
</td></tr>
</table>
</body>
</html>`;
  return { subject, html, text };
};
