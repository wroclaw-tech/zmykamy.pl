import { beforeAll, beforeEach, describe, expect, test } from "bun:test";
import { db } from "../db";
import { trip, tripMember, user } from "../db/schema";
import app from "../index";
import { createTrip, createUser, request, type TestUser } from "./test-helpers";

beforeAll(() => {
  if (!process.env.DATABASE_URL?.endsWith("_test")) {
    throw new Error("Tests must run against the test database, run `bun run test`");
  }
});

beforeEach(async () => {
  await db.delete(trip);
  await db.delete(user);
});

const train = { date: "2027-05-14", time: "09:12", title: "Pociąg do Sintry", icon: "train" };

const setup = async () => {
  const kuba = await createUser("Kuba");
  const ola = await createUser("Ola");
  const { id } = await createTrip(kuba);
  await db.insert(tripMember).values({ tripId: id, userId: ola.id, role: "participant" });
  return { kuba, ola, id };
};

const addPoint = async (as: TestUser, tripId: string, body: unknown = train) => {
  const response = await request(`/trips/${tripId}/plan/points`, as, { method: "POST", body });
  return (await response.json()) as { id: string };
};

const addInfo = async (as: TestUser, tripId: string, body: unknown = { title: "Nocleg" }) => {
  const response = await request(`/trips/${tripId}/plan/info`, as, { method: "POST", body });
  return (await response.json()) as { id: string };
};

describe("plan access", () => {
  test("requires authentication", async () => {
    const { id } = await setup();
    const response = await app.request(`/trips/${id}/plan`);
    expect(response.status).toBe(401);
  });

  test("hides the plan from non-members", async () => {
    const { id } = await setup();
    const stranger = await createUser("Zuza");

    const responses = await Promise.all([
      request(`/trips/${id}/plan`, stranger),
      request(`/trips/${id}/plan/points`, stranger, { method: "POST", body: train }),
      request(`/trips/${id}/plan/info`, stranger, { method: "POST", body: { title: "Nocleg" } }),
    ]);

    expect(responses.map((response) => response.status)).toEqual([404, 404, 404]);
  });
});

describe("plan points", () => {
  test("creates a point authored by the member", async () => {
    const { ola, id } = await setup();
    const response = await request(`/trips/${id}/plan/points`, ola, {
      method: "POST",
      body: { ...train, description: "Dworzec Rossio", place: "Rossio" },
    });

    expect(response.status).toBe(201);
    expect(await response.json()).toMatchObject({
      date: "2027-05-14",
      time: "09:12",
      title: "Pociąg do Sintry",
      description: "Dworzec Rossio",
      place: "Rossio",
      icon: "train",
      author: { userId: ola.id, name: "Ola" },
    });
  });

  test("defaults the icon and leaves optional fields empty", async () => {
    const { kuba, id } = await setup();
    const response = await request(`/trips/${id}/plan/points`, kuba, {
      method: "POST",
      body: { date: "2027-05-12", time: "10:00", title: "Spacer" },
    });

    expect(await response.json()).toMatchObject({
      icon: "location_on",
      description: null,
      place: null,
    });
  });

  test("rejects invalid input", async () => {
    const { kuba, id } = await setup();
    const bodies = [
      { ...train, title: "  " },
      { ...train, time: "25:00" },
      { ...train, icon: "rocket" },
      { ...train, date: "14.05.2027" },
    ];

    const responses = await Promise.all(
      bodies.map((body) => request(`/trips/${id}/plan/points`, kuba, { method: "POST", body })),
    );

    expect(responses.map((response) => response.status)).toEqual([400, 400, 400, 400]);
  });

  test("rejects dates outside the trip", async () => {
    const { kuba, id } = await setup();
    const point = await addPoint(kuba, id);

    const responses = await Promise.all([
      request(`/trips/${id}/plan/points`, kuba, {
        method: "POST",
        body: { ...train, date: "2027-05-19" },
      }),
      request(`/trips/${id}/plan/points/${point.id}`, kuba, {
        method: "PATCH",
        body: { date: "2027-05-11" },
      }),
    ]);

    expect(responses.map((response) => response.status)).toEqual([400, 400]);
    expect(await responses[0]!.json()).toMatchObject({ error: { code: "date_out_of_range" } });
  });

  test("lists the plan ordered by date and time", async () => {
    const { kuba, id } = await setup();
    await addPoint(kuba, id, { ...train, title: "Kolacja", time: "20:00" });
    await addPoint(kuba, id, { ...train, title: "Pociąg", time: "09:12" });
    await addPoint(kuba, id, { ...train, title: "Przylot", date: "2027-05-12", time: "10:05" });

    const response = await request(`/trips/${id}/plan`, kuba);
    const { points } = (await response.json()) as { points: { title: string }[] };

    expect(points.map((point) => point.title)).toEqual(["Przylot", "Pociąg", "Kolacja"]);
  });

  test("lets the author and organizers edit and delete", async () => {
    const { kuba, ola, id } = await setup();
    const own = await addPoint(ola, id);

    const edited = await request(`/trips/${id}/plan/points/${own.id}`, ola, {
      method: "PATCH",
      body: { title: "Pociąg IC", time: "09:30" },
    });
    expect(await edited.json()).toMatchObject({ title: "Pociąg IC", time: "09:30" });

    const byOrganizer = await request(`/trips/${id}/plan/points/${own.id}`, kuba, {
      method: "PATCH",
      body: { place: "Rossio" },
    });
    expect(byOrganizer.status).toBe(200);

    const removed = await request(`/trips/${id}/plan/points/${own.id}`, ola, { method: "DELETE" });
    expect(removed.status).toBe(204);
  });

  test("does not let participants change points they did not add", async () => {
    const { kuba, ola, id } = await setup();
    const point = await addPoint(kuba, id);

    const responses = await Promise.all([
      request(`/trips/${id}/plan/points/${point.id}`, ola, {
        method: "PATCH",
        body: { title: "Moje" },
      }),
      request(`/trips/${id}/plan/points/${point.id}`, ola, { method: "DELETE" }),
    ]);

    expect(responses.map((response) => response.status)).toEqual([403, 403]);
  });

  test("returns 404 for a point of another trip", async () => {
    const { kuba, id } = await setup();
    const other = await createTrip(kuba);
    const point = await addPoint(kuba, other.id);

    const response = await request(`/trips/${id}/plan/points/${point.id}`, kuba, {
      method: "DELETE",
    });

    expect(response.status).toBe(404);
  });

  test("keeps the point when its author leaves the trip", async () => {
    const { kuba, ola, id } = await setup();
    const point = await addPoint(ola, id);
    await request(`/trips/${id}/members/me`, ola, { method: "DELETE" });

    const response = await request(`/trips/${id}/plan`, kuba);
    const { points } = (await response.json()) as { points: { id: string; author: unknown }[] };

    expect(points).toMatchObject([{ id: point.id, author: { userId: ola.id, name: "Ola" } }]);
  });
});

describe("trip info", () => {
  test("creates, edits and deletes a card", async () => {
    const { ola, id } = await setup();
    const created = await request(`/trips/${id}/plan/info`, ola, {
      method: "POST",
      body: { title: "Nocleg", text: "Alfama", icon: "bed" },
    });
    expect(created.status).toBe(201);
    const card = (await created.json()) as { id: string };
    expect(card).toMatchObject({ title: "Nocleg", text: "Alfama", icon: "bed" });

    const edited = await request(`/trips/${id}/plan/info/${card.id}`, ola, {
      method: "PATCH",
      body: { text: "Rua dos Remédios 4" },
    });
    expect(await edited.json()).toMatchObject({ title: "Nocleg", text: "Rua dos Remédios 4" });

    const removed = await request(`/trips/${id}/plan/info/${card.id}`, ola, { method: "DELETE" });
    expect(removed.status).toBe(204);
  });

  test("defaults the icon and the text", async () => {
    const { kuba, id } = await setup();
    const card = await addInfo(kuba, id);
    expect(card).toMatchObject({ icon: "info", text: "" });
  });

  test("does not let participants change cards they did not add", async () => {
    const { kuba, ola, id } = await setup();
    const card = await addInfo(kuba, id);

    const responses = await Promise.all([
      request(`/trips/${id}/plan/info/${card.id}`, ola, { method: "PATCH", body: { title: "X" } }),
      request(`/trips/${id}/plan/info/${card.id}`, ola, { method: "DELETE" }),
    ]);

    expect(responses.map((response) => response.status)).toEqual([403, 403]);
  });

  test("returns points and cards in one plan response", async () => {
    const { kuba, id } = await setup();
    await addPoint(kuba, id);
    await addInfo(kuba, id, { title: "Nocleg" });
    await addInfo(kuba, id, { title: "Dojazd" });

    const response = await request(`/trips/${id}/plan`, kuba);
    const plan = (await response.json()) as { points: unknown[]; info: { title: string }[] };

    expect(plan.points).toHaveLength(1);
    expect(plan.info.map((card) => card.title)).toEqual(["Nocleg", "Dojazd"]);
  });
});

describe("changing trip dates", () => {
  test("is rejected while points would fall outside the new range", async () => {
    const { kuba, id } = await setup();
    await addPoint(kuba, id, { ...train, date: "2027-05-18" });

    const response = await request(`/trips/${id}`, kuba, {
      method: "PATCH",
      body: { endDate: "2027-05-17" },
    });

    expect(response.status).toBe(409);
    expect(await response.json()).toMatchObject({ error: { code: "plan_points_out_of_range" } });
  });

  test("is allowed when every point stays inside", async () => {
    const { kuba, id } = await setup();
    await addPoint(kuba, id, { ...train, date: "2027-05-14" });

    const response = await request(`/trips/${id}`, kuba, {
      method: "PATCH",
      body: { startDate: "2027-05-13", endDate: "2027-05-20" },
    });

    expect(response.status).toBe(200);
  });
});
