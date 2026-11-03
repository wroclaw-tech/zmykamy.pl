import { beforeAll, beforeEach, describe, expect, test } from "bun:test";
import { db } from "../db";
import { trip, tripMember, user } from "../db/schema";
import app from "../index";
import { fileExists } from "../lib/storage";
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

type UploadTarget = {
  key: string;
  uploadUrl: string;
  thumbnailKey: string;
  thumbnailUploadUrl: string;
};

type MediaResponse = {
  id: string;
  kind: string;
  url: string;
  thumbnailUrl: string;
  takenAt: string;
  uploadedBy: { userId: string } | null;
};

const setup = async () => {
  const kuba = await createUser("Kuba");
  const ola = await createUser("Ola");
  const zuza = await createUser("Zuza");
  const { id } = await createTrip(kuba);
  await db.insert(tripMember).values([
    { tripId: id, userId: ola.id, role: "participant" },
    { tripId: id, userId: zuza.id, role: "participant" },
  ]);
  return { kuba, ola, zuza, id };
};

const getUploadTarget = async (as: TestUser, tripId: string, body: unknown) => {
  const response = await request(`/trips/${tripId}/media/upload-url`, as, {
    method: "POST",
    body,
  });
  return (await response.json()) as UploadTarget;
};

const put = (url: string, body: string, contentType: string) =>
  fetch(url, { method: "PUT", body, headers: { "Content-Type": contentType } });

const uploadPhoto = async (as: TestUser, tripId: string, takenAt = "2027-05-14T10:00:00+01:00") => {
  const target = await getUploadTarget(as, tripId, { kind: "photo", contentType: "image/jpeg" });
  await put(target.uploadUrl, "photo", "image/jpeg");
  await put(target.thumbnailUploadUrl, "thumb", "image/jpeg");
  const response = await request(`/trips/${tripId}/media`, as, {
    method: "POST",
    body: {
      kind: "photo",
      contentType: "image/jpeg",
      key: target.key,
      thumbnailKey: target.thumbnailKey,
      width: 4032,
      height: 3024,
      takenAt,
    },
  });
  return { response, target };
};

describe("gallery access", () => {
  test("requires authentication", async () => {
    const { id } = await setup();
    expect((await app.request(`/trips/${id}/media`)).status).toBe(401);
  });

  test("hides the gallery from non-members", async () => {
    const { id } = await setup();
    const stranger = await createUser("Bartek");
    const responses = await Promise.all([
      request(`/trips/${id}/media`, stranger),
      request(`/trips/${id}/media/upload-url`, stranger, {
        method: "POST",
        body: { kind: "photo", contentType: "image/jpeg" },
      }),
    ]);
    expect(responses.map((response) => response.status)).toEqual([404, 404]);
  });
});

describe("gallery", () => {
  test("uploads a photo with its thumbnail through presigned urls", async () => {
    const { ola, id } = await setup();
    const { response, target } = await uploadPhoto(ola, id);

    expect(response.status).toBe(201);
    const body = (await response.json()) as MediaResponse;
    expect(body).toMatchObject({ kind: "photo", uploadedBy: { userId: ola.id } });
    expect(new Date(body.takenAt).toISOString()).toBe("2027-05-14T09:00:00.000Z");
    expect(await (await fetch(body.url)).text()).toBe("photo");
    expect(await (await fetch(body.thumbnailUrl)).text()).toBe("thumb");
    expect(target.key).toStartWith(`trips/${id}/media/`);
    expect(target.key).toEndWith(".jpg");
  });

  test("uses the video extension for videos", async () => {
    const { kuba, id } = await setup();
    const target = await getUploadTarget(kuba, id, {
      kind: "video",
      contentType: "video/quicktime",
    });
    expect(target.key).toEndWith(".mov");
    expect(target.thumbnailKey).toEndWith("-thumb.jpg");
  });

  test("rejects a content type that does not match the kind", async () => {
    const { kuba, id } = await setup();
    const response = await request(`/trips/${id}/media/upload-url`, kuba, {
      method: "POST",
      body: { kind: "photo", contentType: "video/mp4" },
    });
    expect(response.status).toBe(400);
  });

  test("rejects media that was not uploaded for the trip", async () => {
    const { kuba, id } = await setup();
    const target = await getUploadTarget(kuba, id, { kind: "photo", contentType: "image/jpeg" });
    const response = await request(`/trips/${id}/media`, kuba, {
      method: "POST",
      body: {
        kind: "photo",
        contentType: "image/jpeg",
        key: target.key,
        thumbnailKey: `trips/${crypto.randomUUID()}/media/other-thumb.jpg`,
        width: 10,
        height: 10,
        takenAt: "2027-05-14T10:00:00Z",
      },
    });
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ error: { code: "invalid_media_key" } });
  });

  test("lists media newest first", async () => {
    const { kuba, id } = await setup();
    await uploadPhoto(kuba, id, "2027-05-13T10:00:00Z");
    await uploadPhoto(kuba, id, "2027-05-15T10:00:00Z");
    const { media } = (await (await request(`/trips/${id}/media`, kuba)).json()) as {
      media: MediaResponse[];
    };
    expect(media.map((item) => item.takenAt.slice(0, 10))).toEqual(["2027-05-15", "2027-05-13"]);
  });

  test("lets only the uploader or an organizer delete media", async () => {
    const { kuba, ola, zuza, id } = await setup();
    const { response, target } = await uploadPhoto(ola, id);
    const { id: mediaId } = (await response.json()) as MediaResponse;

    const byZuza = await request(`/trips/${id}/media/${mediaId}`, zuza, { method: "DELETE" });
    const byOrganizer = await request(`/trips/${id}/media/${mediaId}`, kuba, { method: "DELETE" });

    expect([byZuza.status, byOrganizer.status]).toEqual([403, 204]);
    expect(await fileExists(target.key)).toBe(false);
    expect(await fileExists(target.thumbnailKey)).toBe(false);
  });

  test("deletes the files together with the trip", async () => {
    const { kuba, id } = await setup();
    const { target } = await uploadPhoto(kuba, id);
    await request(`/trips/${id}`, kuba, { method: "DELETE" });
    expect(await fileExists(target.key)).toBe(false);
  });
});
