import { afterEach, beforeAll, beforeEach, describe, expect, mock, spyOn, test } from "bun:test";
import { eq } from "drizzle-orm";
import { db } from "../db";
import { trip, tripEmailInvite, user } from "../db/schema";
import { type Email, mailer } from "../lib/email";
import { createTrip, createUser, lisbon, request, type TestUser } from "./test-helpers";

type EmailInvite = {
  id: string;
  email: string;
  status: "sent" | "joined";
  sentAt: string;
  joinedAt: string | null;
};

type SendResult = {
  invites: EmailInvite[];
  alreadyMembers: string[];
  alreadyInvited: string[];
  failed: string[];
};

type PendingInvite = {
  id: string;
  code: string;
  trip: { id: string; name: string; startDate: string; endDate: string };
  inviterName: string | null;
};

beforeAll(() => {
  if (!process.env.DATABASE_URL?.endsWith("_test")) {
    throw new Error("Tests must run against the test database, run `bun run test`");
  }
});

let sent: Email[];

beforeEach(async () => {
  await db.delete(trip);
  await db.delete(user);
  sent = [];
  spyOn(mailer, "send").mockImplementation(async (email) => {
    sent.push(email);
  });
});

afterEach(() => {
  mock.restore();
});

const send = (tripId: string, emails: string[], as: TestUser) =>
  request(`/trips/${tripId}/email-invites`, as, { method: "POST", body: { emails } });

const sendOk = async (tripId: string, emails: string[], as: TestUser) => {
  const response = await send(tripId, emails, as);
  expect(response.status).toBe(201);
  return (await response.json()) as SendResult;
};

const list = async (tripId: string, as: TestUser) =>
  (await (await request(`/trips/${tripId}/email-invites`, as)).json()) as EmailInvite[];

const resend = (tripId: string, inviteId: string, as: TestUser) =>
  request(`/trips/${tripId}/email-invites/${inviteId}/resend`, as, { method: "POST" });

const pending = async (as: TestUser) =>
  (await (await request("/email-invites", as)).json()) as PendingInvite[];

const moveSentAtBack = (inviteId: string) =>
  db
    .update(tripEmailInvite)
    .set({ sentAt: new Date(Date.now() - 60 * 60 * 1000) })
    .where(eq(tripEmailInvite.id, inviteId));

const guests = (count: number, prefix = "guest") =>
  Array.from({ length: count }, (_, index) => `${prefix}${index}@example.com`);

const setupTrip = async () => {
  const kuba = await createUser("Kuba");
  const { id } = await createTrip(kuba);
  return { kuba, id };
};

describe("sending", () => {
  test("e-mails each address the trip details and the invite link", async () => {
    const { kuba, id } = await setupTrip();
    const { url } = (await (await request(`/trips/${id}/invite`, kuba)).json()) as { url: string };

    const result = await sendOk(id, ["Tomek@Example.com", "zuza@example.com"], kuba);

    expect(result.invites).toEqual([
      expect.objectContaining({ email: "tomek@example.com", status: "sent", joinedAt: null }),
      expect.objectContaining({ email: "zuza@example.com", status: "sent", joinedAt: null }),
    ]);
    expect(sent.map((email) => email.to)).toEqual(["tomek@example.com", "zuza@example.com"]);
    expect(sent[0]!.subject).toBe("Kuba zaprasza Cię na wyjazd „Lizbona”");
    expect(sent[0]!.text).toContain("12–18 maja 2027");
    expect(sent[0]!.text).toContain(url);
    expect(sent[0]!.html).toContain(`href="${url}"`);
    expect(await list(id, kuba)).toHaveLength(2);
  });

  test("dedupes addresses and skips members and pending invitations", async () => {
    const { kuba, id } = await setupTrip();
    await sendOk(id, ["tomek@example.com"], kuba);
    sent = [];

    const result = await sendOk(
      id,
      ["zuza@example.com", " ZUZA@example.com", "kuba@example.com", "tomek@example.com"],
      kuba,
    );

    expect(result.invites.map((invite) => invite.email)).toEqual(["zuza@example.com"]);
    expect(result.alreadyMembers).toEqual(["kuba@example.com"]);
    expect(result.alreadyInvited).toEqual(["tomek@example.com"]);
    expect(sent.map((email) => email.to)).toEqual(["zuza@example.com"]);
  });

  test("rejects invalid addresses and too many at once", async () => {
    const { kuba, id } = await setupTrip();

    expect((await send(id, ["not-an-email"], kuba)).status).toBe(400);
    expect((await send(id, [], kuba)).status).toBe(400);
    expect((await send(id, guests(11), kuba)).status).toBe(400);
    expect(sent).toHaveLength(0);
  });

  test("reports addresses that could not be sent and does not keep them", async () => {
    const { kuba, id } = await setupTrip();
    spyOn(mailer, "send").mockImplementation(async (email) => {
      if (email.to === "bounce@example.com") {
        throw new Error("Resend responded with 422");
      }
    });

    const result = await sendOk(id, ["bounce@example.com", "tomek@example.com"], kuba);

    expect(result.failed).toEqual(["bounce@example.com"]);
    expect(result.invites.map((invite) => invite.email)).toEqual(["tomek@example.com"]);
    expect((await list(id, kuba)).map((invite) => invite.email)).toEqual(["tomek@example.com"]);
  });

  test("escapes user-provided values in the html", async () => {
    const kuba = await createUser("Kuba");
    await db.update(user).set({ name: `<b>Kuba</b> & "Ola"` }).where(eq(user.id, kuba.id));
    const { id } = await createTrip(kuba, { ...lisbon, name: "<script>alert(1)</script>" });

    await sendOk(id, ["tomek@example.com"], kuba);

    const { html, text } = sent[0]!;
    expect(html).not.toContain("<script>");
    expect(html).not.toContain("<b>Kuba</b>");
    expect(html).toContain("&#60;script&#62;alert(1)&#60;/script&#62;");
    expect(html).toContain("&#60;b&#62;Kuba&#60;/b&#62; &#38; &#34;Ola&#34;");
    expect(text).toContain("<script>alert(1)</script>");
  });
});

describe("permissions", () => {
  test("only the organizer can send, list, resend and cancel", async () => {
    const { kuba, id } = await setupTrip();
    const ola = await createUser("Ola");
    const { code } = (await (await request(`/trips/${id}/invite`, kuba)).json()) as {
      code: string;
    };
    await request(`/invites/${code}/join`, ola, { method: "POST" });
    const [invite] = (await sendOk(id, ["tomek@example.com"], kuba)).invites;

    expect((await send(id, ["zuza@example.com"], ola)).status).toBe(403);
    expect((await request(`/trips/${id}/email-invites`, ola)).status).toBe(403);
    expect((await resend(id, invite!.id, ola)).status).toBe(403);
    expect(
      (await request(`/trips/${id}/email-invites/${invite!.id}`, ola, { method: "DELETE" })).status,
    ).toBe(403);
  });

  test("hides the trip from outsiders", async () => {
    const { id } = await setupTrip();
    const outsider = await createUser("Zuza");

    expect((await send(id, ["tomek@example.com"], outsider)).status).toBe(404);
  });
});

describe("limits", () => {
  test("caps e-mails per trip", async () => {
    const { kuba, id } = await setupTrip();
    await sendOk(id, guests(10, "a"), kuba);
    await sendOk(id, guests(10, "b"), kuba);
    await sendOk(id, guests(10, "c"), kuba);
    sent = [];

    const response = await send(id, ["one-more@example.com"], kuba);

    expect(response.status).toBe(429);
    expect(await response.json()).toMatchObject({ error: { code: "rate_limited" } });
    expect(Number(response.headers.get("Retry-After"))).toBeGreaterThan(0);
    expect(sent).toHaveLength(0);
  });

  test("caps e-mails per user across trips", async () => {
    const kuba = await createUser("Kuba");
    for (const prefix of ["a", "b", "c", "d", "e"]) {
      const { id } = await createTrip(kuba);
      await sendOk(id, guests(10, prefix), kuba);
    }
    const { id } = await createTrip(kuba);

    expect((await send(id, ["one-more@example.com"], kuba)).status).toBe(429);
  });
});

describe("resending", () => {
  test("waits for the cooldown", async () => {
    const { kuba, id } = await setupTrip();
    const [invite] = (await sendOk(id, ["tomek@example.com"], kuba)).invites;

    const response = await resend(id, invite!.id, kuba);

    expect(response.status).toBe(429);
    expect(Number(response.headers.get("Retry-After"))).toBeGreaterThan(14 * 60);
    expect(sent).toHaveLength(1);
  });

  test("sends the e-mail again after the cooldown", async () => {
    const { kuba, id } = await setupTrip();
    const [invite] = (await sendOk(id, ["tomek@example.com"], kuba)).invites;
    await moveSentAtBack(invite!.id);

    const response = await resend(id, invite!.id, kuba);

    expect(response.status).toBe(200);
    const resent = (await response.json()) as EmailInvite;
    expect(resent).toMatchObject({ id: invite!.id, status: "sent" });
    expect(Date.parse(resent.sentAt)).toBeGreaterThan(Date.now() - 60_000);
    expect(sent.map((email) => email.to)).toEqual(["tomek@example.com", "tomek@example.com"]);
  });

  test("keeps the cooldown untouched when sending fails", async () => {
    const { kuba, id } = await setupTrip();
    const [invite] = (await sendOk(id, ["tomek@example.com"], kuba)).invites;
    await moveSentAtBack(invite!.id);
    spyOn(mailer, "send").mockRejectedValue(new Error("Resend responded with 500"));

    expect((await resend(id, invite!.id, kuba)).status).toBe(502);
    mock.restore();
    spyOn(mailer, "send").mockResolvedValue();
    expect((await resend(id, invite!.id, kuba)).status).toBe(200);
  });

  test("is not possible once the person joined", async () => {
    const { kuba, id } = await setupTrip();
    const ola = await createUser("Ola");
    const [invite] = (await sendOk(id, ["ola@example.com"], kuba)).invites;
    const [mine] = await pending(ola);
    await request(`/invites/${mine!.code}/join`, ola, { method: "POST" });
    await moveSentAtBack(invite!.id);

    const response = await resend(id, invite!.id, kuba);

    expect(response.status).toBe(409);
    expect(await response.json()).toMatchObject({ error: { code: "email_invite_joined" } });
  });
});

describe("cancelling", () => {
  test("removes the invitation for the organizer and the invitee", async () => {
    const { kuba, id } = await setupTrip();
    const ola = await createUser("Ola");
    const [invite] = (await sendOk(id, ["ola@example.com"], kuba)).invites;

    const response = await request(`/trips/${id}/email-invites/${invite!.id}`, kuba, {
      method: "DELETE",
    });

    expect(response.status).toBe(204);
    expect(await list(id, kuba)).toEqual([]);
    expect(await pending(ola)).toEqual([]);
  });

  test("reports a missing invitation", async () => {
    const { kuba, id } = await setupTrip();

    const response = await request(`/trips/${id}/email-invites/${crypto.randomUUID()}`, kuba, {
      method: "DELETE",
    });

    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({ error: { code: "email_invite_not_found" } });
  });
});

describe("in-app invitations", () => {
  test("shows pending invitations to the account with that e-mail", async () => {
    const { kuba, id } = await setupTrip();
    const ola = await createUser("Ola");
    const zuza = await createUser("Zuza");
    await sendOk(id, ["OLA@example.com"], kuba);

    const [invite] = await pending(ola);

    expect(invite).toMatchObject({
      code: expect.stringMatching(/^LIZ-[A-Z2-9]{8}$/),
      trip: { id, name: "Lizbona", startDate: "2027-05-12", endDate: "2027-05-18" },
      inviterName: "Kuba",
    });
    expect(await pending(zuza)).toEqual([]);
  });

  test("shows invitations sent before the account was created", async () => {
    const { kuba, id } = await setupTrip();
    await sendOk(id, ["tomek@example.com"], kuba);

    const tomek = await createUser("Tomek");

    expect((await pending(tomek)).map((invite) => invite.trip.id)).toEqual([id]);
  });

  test("requires authentication", async () => {
    const response = await request("/email-invites", { id: "", headers: {} });

    expect(response.status).toBe(401);
  });
});

describe("joining", () => {
  test("marks the invitation as joined and hides it from the invitee", async () => {
    const { kuba, id } = await setupTrip();
    const ola = await createUser("Ola");
    await sendOk(id, ["ola@example.com"], kuba);
    const [mine] = await pending(ola);

    const joined = await request(`/invites/${mine!.code}/join`, ola, { method: "POST" });

    expect(joined.status).toBe(200);
    expect(await list(id, kuba)).toEqual([
      expect.objectContaining({
        email: "ola@example.com",
        status: "joined",
        joinedAt: expect.any(String),
      }),
    ]);
    expect(await pending(ola)).toEqual([]);
  });

  test("lets the organizer invite again someone who joined and left", async () => {
    const { kuba, id } = await setupTrip();
    const ola = await createUser("Ola");
    await sendOk(id, ["ola@example.com"], kuba);
    const [mine] = await pending(ola);
    await request(`/invites/${mine!.code}/join`, ola, { method: "POST" });
    await request(`/trips/${id}/members/me`, ola, { method: "DELETE" });

    const result = await sendOk(id, ["ola@example.com"], kuba);

    expect(result.invites).toEqual([expect.objectContaining({ status: "sent" })]);
    expect(await pending(ola)).toHaveLength(1);
  });
});
