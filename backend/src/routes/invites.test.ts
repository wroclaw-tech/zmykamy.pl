import { beforeAll, beforeEach, describe, expect, test } from "bun:test";
import { db } from "../db";
import { trip, user } from "../db/schema";
import app from "../index";
import { createTrip, createUser, request, type TestUser } from "./test-helpers";

type Invite = { code: string; url: string };

beforeAll(() => {
  if (!process.env.DATABASE_URL?.endsWith("_test")) {
    throw new Error("Tests must run against the test database, run `bun run test`");
  }
});

beforeEach(async () => {
  await db.delete(trip);
  await db.delete(user);
});

const getInvite = async (tripId: string, as: TestUser) =>
  (await (await request(`/trips/${tripId}/invite`, as)).json()) as Invite;

const join = (code: string, as: TestUser) =>
  request(`/invites/${code}/join`, as, { method: "POST" });

const setupTrip = async () => {
  const kuba = await createUser("Kuba");
  const ola = await createUser("Ola");
  const { id } = await createTrip(kuba);
  return { kuba, ola, id, invite: await getInvite(id, kuba) };
};

describe("invite link", () => {
  test("has a readable prefix and an unguessable code", async () => {
    const { invite } = await setupTrip();

    expect(invite.code).toMatch(/^LIZ-[A-Z2-9]{8}$/);
    expect(invite.url.endsWith(`/j/${invite.code}`)).toBe(true);
  });

  test("stays the same until regenerated", async () => {
    const { kuba, id, invite } = await setupTrip();

    expect(await getInvite(id, kuba)).toEqual(invite);
  });

  test("is visible to every member but hidden from outsiders", async () => {
    const { ola, id, invite } = await setupTrip();
    const outsider = await createUser("Zuza");
    await join(invite.code, ola);

    expect(await getInvite(id, ola)).toEqual(invite);
    expect((await request(`/trips/${id}/invite`, outsider)).status).toBe(404);
  });

  test("can be regenerated only by the organizer", async () => {
    const { kuba, ola, id, invite } = await setupTrip();
    await join(invite.code, ola);

    const denied = await request(`/trips/${id}/invite/regenerate`, ola, { method: "POST" });
    expect(denied.status).toBe(403);

    const regenerated = (await (
      await request(`/trips/${id}/invite/regenerate`, kuba, { method: "POST" })
    ).json()) as Invite;
    expect(regenerated.code).not.toBe(invite.code);
    expect(await getInvite(id, kuba)).toEqual(regenerated);
  });

  test("stops working once regenerated", async () => {
    const { kuba, ola, id, invite } = await setupTrip();
    await request(`/trips/${id}/invite/regenerate`, kuba, { method: "POST" });

    expect((await join(invite.code, ola)).status).toBe(404);
    expect((await request(`/invites/${invite.code}`, ola)).status).toBe(404);
  });
});

describe("invite preview", () => {
  test("is public and exposes only the basics", async () => {
    const { invite } = await setupTrip();

    const response = await app.request(`/invites/${invite.code}`);

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      tripId: expect.any(String),
      name: "Lizbona",
      destination: { name: "Lizbona", country: "Portugalia" },
      startDate: "2027-05-12",
      endDate: "2027-05-18",
      organizerName: "Kuba",
      memberCount: 1,
    });
  });

  test("ignores the cosmetic prefix and letter case", async () => {
    const { invite } = await setupTrip();
    const randomPart = invite.code.split("-")[1]!;

    const response = await app.request(`/invites/xyz-${randomPart.toLowerCase()}`);

    expect(response.status).toBe(200);
  });

  test("rejects an unknown code", async () => {
    const response = await app.request("/invites/LIZ-AAAAAAAA");

    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({ error: { code: "invite_not_found" } });
  });
});

describe("joining", () => {
  test("requires authentication", async () => {
    const { invite } = await setupTrip();

    const response = await app.request(`/invites/${invite.code}/join`, { method: "POST" });

    expect(response.status).toBe(401);
  });

  test("adds the user as a participant", async () => {
    const { ola, invite } = await setupTrip();

    const response = await join(invite.code, ola);

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      myRole: "participant",
      members: [
        { name: "Kuba", role: "organizer" },
        { name: "Ola", role: "participant" },
      ],
    });
  });

  test("is idempotent for existing members", async () => {
    const { kuba, ola, invite } = await setupTrip();
    await join(invite.code, ola);

    const again = await join(invite.code, ola);
    const organizer = await join(invite.code, kuba);

    expect(again.status).toBe(200);
    expect(await organizer.json()).toMatchObject({ myRole: "organizer" });
    expect(await db.query.tripMember.findMany()).toHaveLength(2);
  });

  test("lets a removed member rejoin with the same link", async () => {
    const { kuba, ola, id, invite } = await setupTrip();
    await join(invite.code, ola);
    await request(`/trips/${id}/members/${ola.id}`, kuba, { method: "DELETE" });

    expect((await join(invite.code, ola)).status).toBe(200);
  });
});

describe("leaving and removing", () => {
  test("lets a participant leave", async () => {
    const { ola, id, invite } = await setupTrip();
    await join(invite.code, ola);

    const response = await request(`/trips/${id}/members/me`, ola, { method: "DELETE" });

    expect(response.status).toBe(204);
    expect((await request(`/trips/${id}`, ola)).status).toBe(404);
  });

  test("does not let the organizer leave", async () => {
    const { kuba, id } = await setupTrip();

    const response = await request(`/trips/${id}/members/me`, kuba, { method: "DELETE" });

    expect(response.status).toBe(409);
    expect(await response.json()).toMatchObject({ error: { code: "organizer_cannot_leave" } });
  });

  test("lets the organizer remove a participant", async () => {
    const { kuba, ola, id, invite } = await setupTrip();
    await join(invite.code, ola);

    const response = await request(`/trips/${id}/members/${ola.id}`, kuba, { method: "DELETE" });

    expect(response.status).toBe(204);
    expect(await db.query.tripMember.findMany()).toHaveLength(1);
  });

  test("does not let participants remove anyone", async () => {
    const { kuba, ola, id, invite } = await setupTrip();
    await join(invite.code, ola);

    const response = await request(`/trips/${id}/members/${kuba.id}`, ola, { method: "DELETE" });

    expect(response.status).toBe(403);
  });

  test("does not let the organizer remove themselves", async () => {
    const { kuba, id } = await setupTrip();

    const response = await request(`/trips/${id}/members/${kuba.id}`, kuba, { method: "DELETE" });

    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ error: { code: "cannot_remove_self" } });
  });

  test("reports a missing member", async () => {
    const { kuba, ola, id } = await setupTrip();

    const response = await request(`/trips/${id}/members/${ola.id}`, kuba, { method: "DELETE" });

    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({ error: { code: "member_not_found" } });
  });
});

describe("team balances", () => {
  test("starts every member at zero", async () => {
    const { kuba, ola, id, invite } = await setupTrip();
    await join(invite.code, ola);

    const response = await request(`/trips/${id}`, kuba);
    const { members } = (await response.json()) as { members: { balance: number }[] };

    expect(members.map((member) => member.balance)).toEqual([0, 0]);
  });
});

describe("universal links", () => {
  test("serves the app site association", async () => {
    const response = await app.request("/.well-known/apple-app-site-association");

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      applinks: { details: [{ components: [{ "/": "/j/*" }] }] },
    });
  });

  test("serves a fallback page for a valid invite", async () => {
    const { invite } = await setupTrip();

    const response = await app.request(`/j/${invite.code}`);

    expect(response.status).toBe(200);
    expect(await response.text()).toContain("Lizbona");
  });

  test("serves an expired page for an unknown invite", async () => {
    const response = await app.request("/j/LIZ-AAAAAAAA");

    expect(response.status).toBe(404);
    expect(await response.text()).toContain("nie jest już ważne");
  });
});
