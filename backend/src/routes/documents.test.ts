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

type DocumentResponse = {
  id: string;
  title: string;
  category: string;
  icon: string;
  kind: string;
  url: string | null;
  fileUrl: string | null;
  planPointId: string | null;
  author: { userId: string } | null;
};

type NoteResponse = { id: string; title: string; text: string; pinned: boolean };

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

const json = async <T>(response: Response) => (await response.json()) as T;

const uploadPdf = async (as: TestUser, tripId: string) => {
  const { key, uploadUrl } = await json<{ key: string; uploadUrl: string }>(
    await request(`/trips/${tripId}/documents/upload-url`, as, {
      method: "POST",
      body: { contentType: "application/pdf" },
    }),
  );
  await fetch(uploadUrl, {
    method: "PUT",
    body: "%PDF",
    headers: { "Content-Type": "application/pdf" },
  });
  return key;
};

const addLink = (as: TestUser, tripId: string, body: Record<string, unknown> = {}) =>
  request(`/trips/${tripId}/documents`, as, {
    method: "POST",
    body: {
      title: "Mieszkanie w Alfamie",
      category: "reservation",
      kind: "link",
      url: "https://example.com/booking/123",
      ...body,
    },
  });

const addNote = (as: TestUser, tripId: string, body: Record<string, unknown> = {}) =>
  request(`/trips/${tripId}/notes`, as, {
    method: "POST",
    body: { title: "Kod do drzwi", text: "4821#", ...body },
  });

describe("documents and notes access", () => {
  test("requires authentication", async () => {
    const { id } = await setup();
    const responses = await Promise.all([
      app.request(`/trips/${id}/documents`),
      app.request(`/trips/${id}/notes`),
    ]);
    expect(responses.map((response) => response.status)).toEqual([401, 401]);
  });

  test("hides documents and notes from non-members", async () => {
    const { id } = await setup();
    const stranger = await createUser("Bartek");
    const responses = await Promise.all([
      request(`/trips/${id}/documents`, stranger),
      request(`/trips/${id}/notes`, stranger),
      addLink(stranger, id),
      addNote(stranger, id),
    ]);
    expect(responses.map((response) => response.status)).toEqual([404, 404, 404, 404]);
  });
});

describe("documents", () => {
  test("adds an uploaded PDF with a default icon", async () => {
    const { ola, id } = await setup();
    const key = await uploadPdf(ola, id);
    const response = await request(`/trips/${id}/documents`, ola, {
      method: "POST",
      body: {
        title: "Karty pokładowe WAW → LIS",
        category: "ticket",
        kind: "file",
        key,
        contentType: "application/pdf",
      },
    });

    expect(response.status).toBe(201);
    const document = await json<DocumentResponse>(response);
    expect(document).toMatchObject({
      category: "ticket",
      icon: "confirmation_number",
      kind: "file",
      url: null,
      planPointId: null,
      author: { userId: ola.id },
    });
    expect(await (await fetch(document.fileUrl!)).text()).toBe("%PDF");
  });

  test("adds a link attached to a plan point", async () => {
    const { kuba, id } = await setup();
    const point = await json<{ id: string }>(
      await request(`/trips/${id}/plan/points`, kuba, {
        method: "POST",
        body: { date: "2027-05-14", time: "18:00", title: "Zameldowanie" },
      }),
    );
    const response = await addLink(kuba, id, { planPointId: point.id, icon: "key" });

    expect(response.status).toBe(201);
    expect(await json<DocumentResponse>(response)).toMatchObject({
      kind: "link",
      icon: "key",
      url: "https://example.com/booking/123",
      fileUrl: null,
      planPointId: point.id,
    });

    await request(`/trips/${id}/plan/points/${point.id}`, kuba, { method: "DELETE" });
    const { documents } = await json<{ documents: DocumentResponse[] }>(
      await request(`/trips/${id}/documents`, kuba),
    );
    expect(documents[0]?.planPointId).toBeNull();
  });

  test("rejects files from elsewhere, other trips' points and non-http links", async () => {
    const { kuba, id } = await setup();
    const { id: otherTrip } = await createTrip(kuba);
    const otherPoint = await json<{ id: string }>(
      await request(`/trips/${otherTrip}/plan/points`, kuba, {
        method: "POST",
        body: { date: "2027-05-14", time: "18:00", title: "Gdzie indziej" },
      }),
    );
    const responses = await Promise.all([
      request(`/trips/${id}/documents`, kuba, {
        method: "POST",
        body: {
          title: "Bilet",
          category: "ticket",
          kind: "file",
          key: `trips/${otherTrip}/documents/x.pdf`,
          contentType: "application/pdf",
        },
      }),
      addLink(kuba, id, { planPointId: otherPoint.id }),
      addLink(kuba, id, { url: "javascript:alert(1)" }),
    ]);
    expect(responses.map((response) => response.status)).toEqual([400, 400, 400]);
  });

  test("lets only the author or an organizer change or delete a document", async () => {
    const { kuba, ola, zuza, id } = await setup();
    const key = await uploadPdf(ola, id);
    const document = await json<DocumentResponse>(
      await request(`/trips/${id}/documents`, ola, {
        method: "POST",
        body: {
          title: "Ubezpieczenie",
          category: "other",
          kind: "file",
          key,
          contentType: "application/pdf",
        },
      }),
    );

    const byZuza = await request(`/trips/${id}/documents/${document.id}`, zuza, {
      method: "PATCH",
      body: { title: "Moje" },
    });
    const byOrganizer = await request(`/trips/${id}/documents/${document.id}`, kuba, {
      method: "PATCH",
      body: { title: "Ubezpieczenie podróżne" },
    });
    const deleted = await request(`/trips/${id}/documents/${document.id}`, ola, {
      method: "DELETE",
    });

    expect([byZuza.status, byOrganizer.status, deleted.status]).toEqual([403, 200, 204]);
    expect((await json<DocumentResponse>(byOrganizer)).title).toBe("Ubezpieczenie podróżne");
    expect(await fileExists(key)).toBe(false);
  });

  test("deletes document files together with the trip", async () => {
    const { kuba, id } = await setup();
    const key = await uploadPdf(kuba, id);
    await request(`/trips/${id}/documents`, kuba, {
      method: "POST",
      body: {
        title: "Bilet",
        category: "ticket",
        kind: "file",
        key,
        contentType: "application/pdf",
      },
    });
    await request(`/trips/${id}`, kuba, { method: "DELETE" });
    expect(await fileExists(key)).toBe(false);
  });
});

describe("notes", () => {
  test("lists pinned notes first", async () => {
    const { kuba, ola, id } = await setup();
    await addNote(ola, id, { title: "Numer do gospodarza", text: "+351 912 345 678" });
    await addNote(kuba, id, { title: "Wi-Fi", text: "sardynki2027", pinned: true });
    await addNote(ola, id, { title: "Pamiątki" });

    const { notes } = await json<{ notes: NoteResponse[] }>(
      await request(`/trips/${id}/notes`, kuba),
    );
    expect(notes.map((note) => [note.title, note.pinned])).toEqual([
      ["Wi-Fi", true],
      ["Pamiątki", false],
      ["Numer do gospodarza", false],
    ]);
  });

  test("updates only the given fields", async () => {
    const { ola, id } = await setup();
    const note = await json<NoteResponse>(await addNote(ola, id, { pinned: true }));
    const response = await request(`/trips/${id}/notes/${note.id}`, ola, {
      method: "PATCH",
      body: { title: "Kod do klatki" },
    });
    expect(await json<NoteResponse>(response)).toMatchObject({
      title: "Kod do klatki",
      text: "4821#",
      pinned: true,
    });
  });

  test("lets only the author or an organizer change or delete a note", async () => {
    const { kuba, ola, zuza, id } = await setup();
    const note = await json<NoteResponse>(await addNote(ola, id));

    const byZuza = await request(`/trips/${id}/notes/${note.id}`, zuza, {
      method: "PATCH",
      body: { pinned: true },
    });
    const byOrganizer = await request(`/trips/${id}/notes/${note.id}`, kuba, {
      method: "PATCH",
      body: { pinned: true },
    });
    const deleted = await request(`/trips/${id}/notes/${note.id}`, ola, { method: "DELETE" });

    expect([byZuza.status, byOrganizer.status, deleted.status]).toEqual([403, 200, 204]);
  });
});
