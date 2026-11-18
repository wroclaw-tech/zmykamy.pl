import { asc, eq } from "drizzle-orm";
import { Hono } from "hono";
import { db } from "../db";
import { planPoint } from "../db/schema";
import type { AppEnv } from "../lib/app-env";
import { validate } from "../lib/validation";
import { type Coordinates, getDailyForecasts } from "../lib/weather";
import { requireAuth } from "../middleware/require-auth";
import { tripIdParamSchema } from "../schemas/trip";
import { getMemberTrip } from "./trips";

const DAY_MS = 24 * 60 * 60 * 1000;
// Open-Meteo forecasts 16 days ahead in local time, which can be a day off from UTC
const FORECAST_WINDOW = { daysBefore: 1, daysAfter: 16 } as const;

type DayLocation = Coordinates & { date: string; place: string | null };

const shiftDate = (date: string, days: number) =>
  new Date(Date.parse(date) + days * DAY_MS).toISOString().slice(0, 10);

const getForecastDates = (startDate: string, endDate: string) => {
  const today = new Date().toISOString().slice(0, 10);
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
    if (dates.length === 0) {
      return c.json({ days: [] });
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

    /** The first plan point with a location that day, otherwise the trip destination. */
    const getDayLocation = (date: string): DayLocation | null => {
      const point = points.find(
        (candidate) => candidate.date === date && hasCoordinates(candidate),
      );
      const location = point
        ? {
            place: point.place ?? point.title,
            latitude: point.latitude,
            longitude: point.longitude,
          }
        : destination;
      return hasCoordinates(location) ? { ...location, date } : null;
    };

    const locations = dates.map(getDayLocation).filter((location) => location !== null);
    const days = await Promise.all(
      locations.map(async ({ date, place, latitude, longitude }) => {
        const forecast = (await getDailyForecasts({ latitude, longitude })).get(date);
        return forecast ? { date, place, latitude, longitude, ...forecast } : null;
      }),
    );
    return c.json({ days: days.filter((day) => day !== null) });
  });
