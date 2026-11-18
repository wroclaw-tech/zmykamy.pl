import {
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  setSystemTime,
  spyOn,
  test,
} from "bun:test";
import { db } from "../db";
import { trip, user } from "../db/schema";
import app from "../index";
import { clearWeatherCache } from "../lib/weather";
import { createTrip, createUser, lisbon, request, type TestUser } from "./test-helpers";

const sintra = { latitude: 38.8, longitude: -9.39 };

beforeAll(() => {
  if (!process.env.DATABASE_URL?.endsWith("_test")) {
    throw new Error("Tests must run against the test database, run `bun run test`");
  }
});

/** Stubs Open-Meteo with 16 days from 2027-05-13; the max temperature is the rounded latitude. */
const mockOpenMeteo = () =>
  spyOn(globalThis, "fetch").mockImplementation((async (input: string | URL | Request) => {
    const url = new URL(String(input));
    if (url.hostname !== "api.open-meteo.com") {
      return new Response(null, { status: 404 });
    }
    const latitude = Number(url.searchParams.get("latitude"));
    const time = Array.from({ length: 16 }, (_, i) =>
      new Date(Date.UTC(2027, 4, 13 + i)).toISOString().slice(0, 10),
    );
    return Response.json({
      daily: {
        time,
        weather_code: time.map(() => 1),
        temperature_2m_max: time.map(() => Math.round(latitude)),
        temperature_2m_min: time.map(() => 12.5),
        precipitation_probability_max: time.map(() => null),
      },
    });
  }) as typeof fetch);

let fetchSpy: ReturnType<typeof mockOpenMeteo>;

beforeEach(async () => {
  setSystemTime(new Date("2027-05-13T10:00:00Z"));
  clearWeatherCache();
  fetchSpy = mockOpenMeteo();
  await db.delete(trip);
  await db.delete(user);
});

afterEach(() => {
  fetchSpy.mockRestore();
  setSystemTime();
});

const setup = async (body: unknown = lisbon) => {
  const kuba = await createUser("Kuba");
  const { id } = await createTrip(kuba, body);
  return { kuba, id };
};

const getWeather = async (as: TestUser, tripId: string) => {
  const response = await request(`/trips/${tripId}/weather`, as);
  return { status: response.status, body: (await response.json()) as { days: unknown[] } };
};

describe("trip weather", () => {
  test("requires membership", async () => {
    const { id } = await setup();
    const stranger = await createUser("Zuza");

    expect((await app.request(`/trips/${id}/weather`)).status).toBe(401);
    expect((await getWeather(stranger, id)).status).toBe(404);
  });

  test("forecasts the destination for days without located plan points", async () => {
    const { kuba, id } = await setup();

    const { status, body } = await getWeather(kuba, id);

    expect(status).toBe(200);
    expect(body.days.map((day) => (day as { date: string }).date)).toEqual([
      "2027-05-13",
      "2027-05-14",
      "2027-05-15",
      "2027-05-16",
      "2027-05-17",
      "2027-05-18",
    ]);
    expect(body.days[0]).toEqual({
      date: "2027-05-13",
      place: "Lizbona",
      latitude: 38.72,
      longitude: -9.14,
      weatherCode: 1,
      temperatureMax: 39,
      temperatureMin: 12.5,
      precipitationProbability: null,
    });
  });

  test("uses the first located plan point of the day", async () => {
    const { kuba, id } = await setup();
    const addPoint = (body: object) =>
      request(`/trips/${id}/plan/points`, kuba, {
        method: "POST",
        body: { date: "2027-05-14", title: "Punkt", ...body },
      });
    await addPoint({ time: "08:00", title: "Śniadanie" });
    await addPoint({ time: "11:00", place: "Pałac Pena", latitude: 38.79, longitude: -9.39 });
    await addPoint({ time: "09:12", place: "Sintra", ...sintra });

    const { body } = await getWeather(kuba, id);

    expect(body.days[1]).toMatchObject({ date: "2027-05-14", place: "Sintra", ...sintra });
  });

  test("shares one cached request between nearby places", async () => {
    const { kuba, id } = await setup();
    await request(`/trips/${id}/plan/points`, kuba, {
      method: "POST",
      body: {
        date: "2027-05-14",
        time: "09:00",
        title: "Rossio",
        latitude: 38.7214,
        longitude: -9.1405,
      },
    });

    await getWeather(kuba, id);
    await getWeather(kuba, id);

    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  test("skips days beyond the forecast and trips without a location", async () => {
    const later = await setup({ ...lisbon, startDate: "2027-06-10", endDate: "2027-06-12" });
    expect((await getWeather(later.kuba, later.id)).body.days).toEqual([]);

    const nowhere = await createTrip(later.kuba, { ...lisbon, destination: null });
    expect((await getWeather(later.kuba, nowhere.id)).body.days).toEqual([]);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  test("returns no days when Open-Meteo fails", async () => {
    const { kuba, id } = await setup();
    fetchSpy.mockResolvedValue(new Response(null, { status: 503 }));

    const { status, body } = await getWeather(kuba, id);

    expect(status).toBe(200);
    expect(body.days).toEqual([]);
  });
});
