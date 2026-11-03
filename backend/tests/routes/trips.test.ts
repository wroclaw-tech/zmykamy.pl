import { beforeAll, beforeEach, describe, expect, test } from "bun:test";
import { db } from "../../src/db";
import { trip, tripMember, user } from "../../src/db/schema";
import app from "../../src/index";
import { createTrip, createUser, lisbon, request } from "../helpers";

beforeAll(() => {
  if (!process.env.DATABASE_URL?.endsWith("_test")) {
    throw new Error("Tests must run against the test database, run `bun run test`");
  }
});

beforeEach(async () => {
  await db.delete(trip);
  await db.delete(user);
});

describe("trips", () => {
  test("requires authentication", async () => {
    const response = await app.request("/trips");
    expect(response.status).toBe(401);
  });

  test("makes the creator the only organizer", async () => {
    const kuba = await createUser("Kuba");
    const response = await request("/trips", kuba, { method: "POST", body: lisbon });

    expect(response.status).toBe(201);
    expect(await response.json()).toMatchObject({
      name: "Lizbona",
      destination: lisbon.destination,
      startDate: "2027-05-12",
      endDate: "2027-05-18",
      currency: "EUR",
      coverUrl: null,
      myRole: "organizer",
      members: [{ userId: kuba.id, name: "Kuba", role: "organizer" }],
    });
  });

  test("lists only trips the user belongs to", async () => {
    const kuba = await createUser("Kuba");
    const ola = await createUser("Ola");
    await createTrip(kuba);
    await createTrip(ola, { ...lisbon, name: "Berlin" });

    const response = await request("/trips", kuba);
    const trips = (await response.json()) as { name: string }[];

    expect(trips.map((listed) => listed.name)).toEqual(["Lizbona"]);
  });

  test("hides trips from non-members", async () => {
    const kuba = await createUser("Kuba");
    const ola = await createUser("Ola");
    const { id } = await createTrip(kuba);

    const responses = await Promise.all([
      request(`/trips/${id}`, ola),
      request(`/trips/${id}`, ola, { method: "PATCH", body: { name: "Moja" } }),
      request(`/trips/${id}`, ola, { method: "DELETE" }),
      request(`/trips/${id}/cover/upload-url`, ola, { method: "POST" }),
    ]);

    expect(responses.map((response) => response.status)).toEqual([404, 404, 404, 404]);
  });

  test("lets participants read but not manage the trip", async () => {
    const kuba = await createUser("Kuba");
    const ola = await createUser("Ola");
    const { id } = await createTrip(kuba);
    await db.insert(tripMember).values({ tripId: id, userId: ola.id, role: "participant" });

    const read = await request(`/trips/${id}`, ola);
    expect(read.status).toBe(200);
    expect(await read.json()).toMatchObject({ myRole: "participant" });

    const responses = await Promise.all([
      request(`/trips/${id}`, ola, { method: "PATCH", body: { name: "Moja" } }),
      request(`/trips/${id}`, ola, { method: "DELETE" }),
      request(`/trips/${id}/cover/upload-url`, ola, { method: "POST" }),
    ]);
    expect(responses.map((response) => response.status)).toEqual([403, 403, 403]);
  });

  test("lets the organizer update and delete the trip", async () => {
    const kuba = await createUser("Kuba");
    const { id } = await createTrip(kuba);

    const updated = await request(`/trips/${id}`, kuba, {
      method: "PATCH",
      body: { name: "Sylwek w Lizbonie", destination: null },
    });
    expect(await updated.json()).toMatchObject({ name: "Sylwek w Lizbonie", destination: null });

    const deleted = await request(`/trips/${id}`, kuba, { method: "DELETE" });
    expect(deleted.status).toBe(204);
    expect((await request(`/trips/${id}`, kuba)).status).toBe(404);
  });

  test("rejects an end date before the start date", async () => {
    const kuba = await createUser("Kuba");
    const created = await request("/trips", kuba, {
      method: "POST",
      body: { ...lisbon, startDate: "2027-05-18", endDate: "2027-05-12" },
    });
    expect(created.status).toBe(400);

    const { id } = await createTrip(kuba);
    const updated = await request(`/trips/${id}`, kuba, {
      method: "PATCH",
      body: { startDate: "2027-06-01" },
    });
    expect(updated.status).toBe(400);
    expect(await updated.json()).toMatchObject({ error: { code: "invalid_date_range" } });
  });

  test("rejects an unsupported currency", async () => {
    const kuba = await createUser("Kuba");
    const response = await request("/trips", kuba, {
      method: "POST",
      body: { ...lisbon, currency: "XYZ1" },
    });
    expect(response.status).toBe(400);
  });

  test("sets a cover uploaded through the presigned url", async () => {
    const kuba = await createUser("Kuba");
    const { id } = await createTrip(kuba);

    const uploadResponse = await request(`/trips/${id}/cover/upload-url`, kuba, {
      method: "POST",
    });
    const { uploadUrl, key } = (await uploadResponse.json()) as { uploadUrl: string; key: string };
    const upload = await fetch(uploadUrl, {
      method: "PUT",
      body: "jpeg",
      headers: { "Content-Type": "image/jpeg" },
    });
    expect(upload.status).toBe(200);

    const updated = await request(`/trips/${id}`, kuba, {
      method: "PATCH",
      body: { coverImageKey: key },
    });
    const { coverUrl } = (await updated.json()) as { coverUrl: string };
    expect(await (await fetch(coverUrl)).text()).toBe("jpeg");

    await request(`/trips/${id}`, kuba, { method: "DELETE" });
  });

  test("rejects a cover key that was not uploaded for the trip", async () => {
    const kuba = await createUser("Kuba");
    const { id } = await createTrip(kuba);

    const response = await request(`/trips/${id}`, kuba, {
      method: "PATCH",
      body: { coverImageKey: `trips/${crypto.randomUUID()}/cover/other.jpg` },
    });
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ error: { code: "invalid_cover_key" } });
  });
});
