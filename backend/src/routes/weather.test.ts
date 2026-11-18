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

const getDates = (start: string, end: string) => {
  const dates: string[] = [];
  for (let date = start; date <= end;) {
    dates.push(date);
    date = new Date(Date.parse(date) + 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  }
  return dates;
};

const respondWithForecast = (url: URL) => {
  const latitude = Number(url.searchParams.get("latitude"));
  const time = getDates("2027-05-13", "2027-05-28");
  return Response.json({
    current: { time: "2027-05-13T11:00", temperature_2m: 24.3, weather_code: 0 },
    daily: {
      time,
      weather_code: time.map(() => 1),
      temperature_2m_max: time.map(() => Math.round(latitude)),
      temperature_2m_min: time.map(() => 12.5),
      precipitation_probability_max: time.map(() => null),
    },
  });
};

/** Past years get warmer the closer they are: 2026 has 25°, 2022 has 21°. */
const respondWithArchive = (url: URL) => {
  const time = getDates(
    url.searchParams.get("start_date") ?? "",
    url.searchParams.get("end_date") ?? "",
  );
  const yearsAgo = 2027 - Number(time[0]?.slice(0, 4));
  return Response.json({
    daily: {
      time,
      weather_code: time.map((_, i) => (i % 3 === 2 ? 61 : 0)),
      temperature_2m_max: time.map(() => 26 - yearsAgo),
      temperature_2m_min: time.map(() => 14),
    },
  });
};

/**
 * Stubs Open-Meteo: forecasts for 16 days from 2027-05-13 where the max temperature is the
 * rounded latitude, and an archive of past years.
 */
const mockOpenMeteo = () =>
  spyOn(globalThis, "fetch").mockImplementation((async (input: string | URL | Request) => {
    const url = new URL(String(input));
    if (url.hostname === "api.open-meteo.com") {
      return respondWithForecast(url);
    }
    if (url.hostname === "archive-api.open-meteo.com") {
      return respondWithArchive(url);
    }
    return new Response(null, { status: 404 });
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
  return {
    status: response.status,
    body: (await response.json()) as {
      days: unknown[];
      current: unknown;
      typical: unknown;
      forecastAvailableFrom: string;
    },
  };
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

  test("reports the current weather at today's place", async () => {
    const { kuba, id } = await setup();

    const { body } = await getWeather(kuba, id);

    expect(body.current).toEqual({
      date: "2027-05-13",
      place: "Lizbona",
      latitude: 38.72,
      longitude: -9.14,
      temperature: 24.3,
      weatherCode: 0,
    });
    expect(body.typical).toBeNull();
  });

  test("describes the usual weather for trips beyond the forecast", async () => {
    const { kuba, id } = await setup({ ...lisbon, startDate: "2027-06-10", endDate: "2027-06-12" });

    const { body } = await getWeather(kuba, id);

    expect(body.days).toEqual([]);
    expect(body.current).toBeNull();
    expect(body.typical).toEqual({
      place: "Lizbona",
      latitude: 38.72,
      longitude: -9.14,
      weatherCode: 0,
      temperatureMax: 23,
      temperatureMin: 14,
    });
    expect(body.forecastAvailableFrom).toBe("2027-05-26");
    expect(fetchSpy).toHaveBeenCalledTimes(5);
  });

  test("describes the usual weather for the days past the forecast", async () => {
    const { kuba, id } = await setup({ ...lisbon, startDate: "2027-05-26", endDate: "2027-06-01" });

    const { body } = await getWeather(kuba, id);

    expect(body.days).toHaveLength(3);
    const urls = fetchSpy.mock.calls.map(([input]) => new URL(String(input)));
    expect(urls.map((url) => url.searchParams.get("start_date")).filter(Boolean)).toContain(
      "2026-05-29",
    );
    expect(body.typical).toMatchObject({ place: "Lizbona", weatherCode: 0 });
  });

  test("averages the usual weather over at most two weeks of a long trip", async () => {
    const { kuba, id } = await setup({ ...lisbon, startDate: "2027-07-01", endDate: "2027-08-30" });

    await getWeather(kuba, id);

    const urls = fetchSpy.mock.calls.map(([input]) => new URL(String(input)));
    expect(urls.map((url) => url.searchParams.get("end_date"))).toContain("2026-07-14");
  });

  test("skips trips without a location and finished trips", async () => {
    const { kuba } = await setup();
    const nowhere = await createTrip(kuba, { ...lisbon, destination: null });
    const past = await createTrip(kuba, {
      ...lisbon,
      startDate: "2027-04-01",
      endDate: "2027-04-05",
    });

    expect((await getWeather(kuba, nowhere.id)).body).toMatchObject({
      days: [],
      current: null,
      typical: null,
    });
    expect((await getWeather(kuba, past.id)).body).toMatchObject({
      days: [],
      current: null,
      typical: null,
    });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  test("returns no days when Open-Meteo fails", async () => {
    const { kuba, id } = await setup();
    fetchSpy.mockResolvedValue(new Response(null, { status: 503 }));

    const { status, body } = await getWeather(kuba, id);

    expect(status).toBe(200);
    expect(body).toMatchObject({ days: [], current: null });
  });
});
