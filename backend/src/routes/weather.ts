import { asc, eq } from "drizzle-orm";
import { Hono } from "hono";
import { db } from "../db";
import { planPoint } from "../db/schema";
import type { AppEnv } from "../lib/app-env";
import { validate } from "../lib/validation";
import { type Coordinates, FORECAST_DAYS, getForecast, getTypicalWeather } from "../lib/weather";
import { requireAuth } from "../middleware/require-auth";
import { tripIdParamSchema } from "../schemas/trip";
import { getMemberTrip } from "./trips";

const DAY_MS = 24 * 60 * 60 * 1000;
// Open-Meteo forecasts 16 days ahead in local time, which can be a day off from UTC
const FORECAST_WINDOW = { daysBefore: 1, daysAfter: FORECAST_DAYS } as const;

type Location = { place: string | null; latitude: number | null; longitude: number | null };

type DayLocation = Coordinates & { date: string; place: string | null };

const shiftDate = (date: string, days: number) =>
  new Date(Date.parse(date) + days * DAY_MS).toISOString().slice(0, 10);

const getUtcToday = () => new Date().toISOString().slice(0, 10);

const getForecastDates = (startDate: string, endDate: string) => {
  const today = getUtcToday();
  const first = shiftDate(today, -FORECAST_WINDOW.daysBefore);
  const last = shiftDate(today, FORECAST_WINDOW.daysAfter);
  const dates: string[] = [];
  for (let date = startDate > first ? startDate : first; date <= endDate && date <= last;) {
    dates.push(date);
    date = shiftDate(date, 1);
  }
  return dates;
};

const hasCoordinates = <Location extends { latitude: number | null; longitude: number | null }>(
  location: Location,
): location is Location & Coordinates => location.latitude !== null && location.longitude !== null;

export const weather = new Hono<AppEnv>()
  .use(requireAuth)
  .get("/:id/weather", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    const record = await getMemberTrip(id, c.get("user").id);
    const dates = getForecastDates(record.startDate, record.endDate);
    const forecastAvailableFrom = shiftDate(record.startDate, 1 - FORECAST_DAYS);
    const isUpcoming = record.startDate > getUtcToday();
    if (dates.length === 0 && !isUpcoming) {
      return c.json({ days: [], current: null, typical: null, forecastAvailableFrom });
    }
    const points = await db.query.planPoint.findMany({
      where: eq(planPoint.tripId, id),
      orderBy: [asc(planPoint.date), asc(planPoint.time), asc(planPoint.createdAt)],
    });
    const destination = {
      place: record.destinationName,
      latitude: record.destinationLatitude,
      longitude: record.destinationLongitude,
    };
    const toLocation = (point: (typeof points)[number] & Coordinates): Location => ({
      place: point.place ?? point.title,
      latitude: point.latitude,
      longitude: point.longitude,
    });

    /** The first plan point with a location that day, otherwise the trip destination. */
    const getDayLocation = (date: string): DayLocation | null => {
      const point = points.find(
        (candidate) => candidate.date === date && hasCoordinates(candidate),
      );
      const location = point && hasCoordinates(point) ? toLocation(point) : destination;
      return hasCoordinates(location) ? { ...location, date } : null;
    };

    /** Where the trip goes: the destination, otherwise the first place in the plan. */
    const getTripLocation = (): Location | null => {
      if (hasCoordinates(destination)) {
        return destination;
      }
      const point = points.find(hasCoordinates);
      return point && hasCoordinates(point) ? toLocation(point) : null;
    };

    const getTypical = async () => {
      const location = getTripLocation();
      if (dates.length > 0 || !location || !hasCoordinates(location)) {
        return null;
      }
      const typical = await getTypicalWeather(location, record.startDate, record.endDate);
      return typical ? { ...location, ...typical } : null;
    };

    const locations = dates.map(getDayLocation).filter((location) => location !== null);
    const [forecasts, typical] = await Promise.all([
      Promise.all(
        locations.map(async (location) => ({
          location,
          forecast: await getForecast(location),
        })),
      ),
      getTypical(),
    ]);
    const days = forecasts.flatMap(({ location, forecast }) => {
      const daily = forecast.daily.get(location.date);
      return daily ? [{ ...location, ...daily }] : [];
    });
    const today = forecasts.find(
      ({ location, forecast }) => forecast.current?.date === location.date,
    );
    const current = today?.forecast.current
      ? {
          ...today.location,
          temperature: today.forecast.current.temperature,
          weatherCode: today.forecast.current.weatherCode,
        }
      : null;
    return c.json({ days, current, typical, forecastAvailableFrom });
  });
