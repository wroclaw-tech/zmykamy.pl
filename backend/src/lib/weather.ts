import { z } from "zod";
import { logger } from "./logger";

const OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast";
const OPEN_METEO_TIMEOUT_MS = 3000;
const FORECAST_DAYS = 16;
const CACHE_TTL_MS = 60 * 60 * 1000;
// Two decimal places is about 1 km, close enough to share forecasts between nearby places
const COORDINATE_DECIMALS = 2;
const DAILY_VARIABLES = [
  "weather_code",
  "temperature_2m_max",
  "temperature_2m_min",
  "precipitation_probability_max",
] as const;

const nullableNumbers = z.array(z.number().nullable());

const openMeteoResponseSchema = z.object({
  daily: z.object({
    time: z.array(z.iso.date()),
    weather_code: nullableNumbers,
    temperature_2m_max: nullableNumbers,
    temperature_2m_min: nullableNumbers,
    precipitation_probability_max: nullableNumbers,
  }),
});

export type Coordinates = { latitude: number; longitude: number };

export type DailyForecast = {
  weatherCode: number;
  temperatureMax: number;
  temperatureMin: number;
  precipitationProbability: number | null;
};

type CacheEntry = { expiresAt: number; pending: Promise<Map<string, DailyForecast>> };

const cache = new Map<string, CacheEntry>();

const roundCoordinate = (value: number) => value.toFixed(COORDINATE_DECIMALS);

const toForecastsByDate = (daily: z.infer<typeof openMeteoResponseSchema>["daily"]) => {
  const forecasts = new Map<string, DailyForecast>();
  daily.time.forEach((date, i) => {
    const weatherCode = daily.weather_code[i];
    const temperatureMax = daily.temperature_2m_max[i];
    const temperatureMin = daily.temperature_2m_min[i];
    if (weatherCode == null || temperatureMax == null || temperatureMin == null) {
      return;
    }
    forecasts.set(date, {
      weatherCode,
      temperatureMax,
      temperatureMin,
      precipitationProbability: daily.precipitation_probability_max[i] ?? null,
    });
  });
  return forecasts;
};

const fetchForecast = async (latitude: string, longitude: string) => {
  const params = new URLSearchParams({
    latitude,
    longitude,
    daily: DAILY_VARIABLES.join(","),
    timezone: "auto",
    forecast_days: String(FORECAST_DAYS),
  });
  const response = await fetch(`${OPEN_METEO_URL}?${params}`, {
    signal: AbortSignal.timeout(OPEN_METEO_TIMEOUT_MS),
  });
  if (!response.ok) {
    throw new Error(`Open-Meteo responded with ${response.status}`);
  }
  return toForecastsByDate(openMeteoResponseSchema.parse(await response.json()).daily);
};

/**
 * Daily forecasts for the next 16 days keyed by local date at the location, cached for an hour.
 * Resolves to an empty map when Open-Meteo is unavailable, since weather is only a hint.
 */
export const getDailyForecasts = async ({ latitude, longitude }: Coordinates) => {
  const roundedLatitude = roundCoordinate(latitude);
  const roundedLongitude = roundCoordinate(longitude);
  const key = `${roundedLatitude},${roundedLongitude}`;
  let entry = cache.get(key);
  if (!entry || entry.expiresAt <= Date.now()) {
    const pending = fetchForecast(roundedLatitude, roundedLongitude);
    pending.catch(() => cache.delete(key));
    entry = { expiresAt: Date.now() + CACHE_TTL_MS, pending };
    cache.set(key, entry);
  }
  try {
    return await entry.pending;
  } catch (error) {
    logger.warn("Open-Meteo forecast request failed", { error, key });
    return new Map<string, DailyForecast>();
  }
};

export const clearWeatherCache = () => cache.clear();
