import { logger } from "./logger";

export type Email = { to: string; subject: string; html: string; text: string };

const RESEND_API_URL = "https://api.resend.com/emails";
const RESEND_TIMEOUT_MS = 10_000;
const DEFAULT_FROM = "Zmykamy <zaproszenia@zmykamy.pl>";

const sendWithResend = async (apiKey: string, email: Email) => {
  const response = await fetch(RESEND_API_URL, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: process.env.EMAIL_FROM || DEFAULT_FROM,
      to: [email.to],
      subject: email.subject,
      html: email.html,
      text: email.text,
    }),
    signal: AbortSignal.timeout(RESEND_TIMEOUT_MS),
  });
  if (!response.ok) {
    throw new Error(`Resend responded with ${response.status}: ${await response.text()}`);
  }
};

export const mailer = {
  send: async (email: Email) => {
    const apiKey = process.env.RESEND_API_KEY;
    if (!apiKey) {
      logger.info("RESEND_API_KEY is not set, logging the e-mail instead of sending it", {
        to: email.to,
        subject: email.subject,
        text: email.text,
      });
      return;
    }
    await sendWithResend(apiKey, email);
  },
};
