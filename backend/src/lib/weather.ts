import { z } from "zod";
import { logger } from "./logger";

const OPEN_METEO_FORECAST_URL = "https://api.open-meteo.com/v1/forecast";
const OPEN_METEO_ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive";
const OPEN_METEO_TIMEOUT_MS = 3000;
export const FORECAST_DAYS = 16;
const FORECAST_TTL_MS = 30 * 60 * 1000;
const TYPICAL_WEATHER_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const TYPICAL_WEATHER_YEARS = 5;
const TYPICAL_WEATHER_MAX_DAYS = 14;
const DAY_MS = 24 * 60 * 60 * 1000;
// Two decimal places is about 1 km, close enough to share forecasts between nearby places
const COORDINATE_DECIMALS = 2;
const DAILY_VARIABLES = ["weather_code", "temperature_2m_max", "temperature_2m_min"] as const;

const nullableNumbers = z.array(z.number().nullable());

const dailySchema = z.object({
  time: z.array(z.iso.date()),
  weather_code: nullableNumbers,
  temperature_2m_max: nullableNumbers,
  temperature_2m_min: nullableNumbers,
});

const forecastResponseSchema = z.object({
  current: z
    .object({
      time: z.string(),
      temperature_2m: z.number().nullable(),
      weather_code: z.number().nullable(),
    })
    .optional(),
  daily: dailySchema.extend({ precipitation_probability_max: nullableNumbers }),
});

const archiveResponseSchema = z.object({ daily: dailySchema });

export type Coordinates = { latitude: number; longitude: number };

type DailyWeather = { weatherCode: number; temperatureMax: number; temperatureMin: number };

export type DailyForecast = DailyWeather & { precipitationProbability: number | null };

export type CurrentWeather = { date: string; temperature: number; weatherCode: number };

export type Forecast = { daily: Map<string, DailyForecast>; current: CurrentWeather | null };

export type TypicalWeather = DailyWeather;

type CacheEntry = { expiresAt: number; pending: Promise<unknown> };

const cache = new Map<string, CacheEntry>();

const getCached = <Value>(key: string, ttlMs: number, load: () => Promise<Value>) => {
  let entry = cache.get(key);
  if (!entry || entry.expiresAt <= Date.now()) {
    const pending = load();
    pending.catch(() => cache.delete(key));
    entry = { expiresAt: Date.now() + ttlMs, pending };
    cache.set(key, entry);
  }
  return entry.pending as Promise<Value>;
};

const toQueryCoordinates = ({ latitude, longitude }: Coordinates) => ({
  latitude: latitude.toFixed(COORDINATE_DECIMALS),
  longitude: longitude.toFixed(COORDINATE_DECIMALS),
});

const fetchOpenMeteo = async (url: string, params: Record<string, string>) => {
  const response = await fetch(`${url}?${new URLSearchParams(params)}`, {
    signal: AbortSignal.timeout(OPEN_METEO_TIMEOUT_MS),
  });
  if (!response.ok) {
    throw new Error(`Open-Meteo responded with ${response.status}`);
  }
  return response.json();
};

const toDailyWeather = (daily: z.infer<typeof dailySchema>, i: number): DailyWeather | null => {
  const weatherCode = daily.weather_code[i];
  const temperatureMax = daily.temperature_2m_max[i];
  const temperatureMin = daily.temperature_2m_min[i];
  if (weatherCode == null || temperatureMax == null || temperatureMin == null) {
    return null;
  }
  return { weatherCode, temperatureMax, temperatureMin };
};

const toCurrentWeather = (
  current: z.infer<typeof forecastResponseSchema>["current"],
): CurrentWeather | null => {
  const temperature = current?.temperature_2m;
  const weatherCode = current?.weather_code;
  if (!current || temperature == null || weatherCode == null) {
    return null;
  }
  return { date: current.time.slice(0, 10), temperature, weatherCode };
};

const fetchForecast = async (coordinates: Coordinates): Promise<Forecast> => {
  const json = await fetchOpenMeteo(OPEN_METEO_FORECAST_URL, {
    ...toQueryCoordinates(coordinates),
    current: "temperature_2m,weather_code",
    daily: [...DAILY_VARIABLES, "precipitation_probability_max"].join(","),
    timezone: "auto",
    forecast_days: String(FORECAST_DAYS),
  });
  const { current, daily } = forecastResponseSchema.parse(json);
  const forecasts = new Map<string, DailyForecast>();
  daily.time.forEach((date, i) => {
    const weather = toDailyWeather(daily, i);
    if (weather) {
      forecasts.set(date, {
        ...weather,
        precipitationProbability: daily.precipitation_probability_max[i] ?? null,
      });
    }
  });
  return { daily: forecasts, current: toCurrentWeather(current) };
};

const EMPTY_FORECAST: Forecast = { daily: new Map(), current: null };

/**
 * Current weather and daily forecasts for the next 16 days, keyed by local date at the location.
 * Resolves to an empty forecast when Open-Meteo is unavailable, since weather is only a hint.
 */
export const getForecast = async (coordinates: Coordinates) => {
  const { latitude, longitude } = toQueryCoordinates(coordinates);
  const key = `forecast:${latitude},${longitude}`;
  try {
    return await getCached(key, FORECAST_TTL_MS, () => fetchForecast(coordinates));
  } catch (error) {
    logger.warn("Open-Meteo forecast request failed", { error, key });
    return EMPTY_FORECAST;
  }
};

const shiftYears = (date: string, years: number) => {
  const shifted = new Date(`${date}T00:00:00Z`);
  shifted.setUTCFullYear(shifted.getUTCFullYear() - years);
  return shifted.toISOString().slice(0, 10);
};

const shiftDays = (date: string, days: number) =>
  new Date(Date.parse(date) + days * DAY_MS).toISOString().slice(0, 10);

const getMostCommon = (values: number[]) => {
  const counts = new Map<number, number>();
  for (const value of values) {
    counts.set(value, (counts.get(value) ?? 0) + 1);
  }
  return [...counts].reduce((best, entry) => (entry[1] > best[1] ? entry : best))[0];
};

const getAverage = (values: number[]) =>
  values.reduce((sum, value) => sum + value, 0) / values.length;

const fetchTypicalWeather = async (
  coordinates: Coordinates,
  startDate: string,
  endDate: string,
): Promise<TypicalWeather | null> => {
  const responses = await Promise.all(
    Array.from({ length: TYPICAL_WEATHER_YEARS }, async (_, i) => {
      const json = await fetchOpenMeteo(OPEN_METEO_ARCHIVE_URL, {
        ...toQueryCoordinates(coordinates),
        start_date: shiftYears(startDate, i + 1),
        end_date: shiftYears(endDate, i + 1),
        daily: DAILY_VARIABLES.join(","),
        timezone: "auto",
      });
      return archiveResponseSchema.parse(json).daily;
    }),
  );
  const days = responses.flatMap((daily) =>
    daily.time.map((_, i) => toDailyWeather(daily, i)).filter((day) => day !== null),
  );
  if (days.length === 0) {
    return null;
  }
  return {
    weatherCode: getMostCommon(days.map((day) => day.weatherCode)),
    temperatureMax: getAverage(days.map((day) => day.temperatureMax)),
    temperatureMin: getAverage(days.map((day) => day.temperatureMin)),
  };
};

/**
 * Weather usually seen on these dates, averaged over the same days of the past five years.
 * Long trips are cut to their first two weeks. Resolves to null when Open-Meteo is unavailable.
 */
export const getTypicalWeather = async (
  coordinates: Coordinates,
  startDate: string,
  endDate: string,
) => {
  const lastDate = shiftDays(startDate, TYPICAL_WEATHER_MAX_DAYS - 1);
  const end = endDate < lastDate ? endDate : lastDate;
  const { latitude, longitude } = toQueryCoordinates(coordinates);
  const key = `typical:${latitude},${longitude}:${startDate}:${end}`;
  try {
    return await getCached(key, TYPICAL_WEATHER_TTL_MS, () =>
      fetchTypicalWeather(coordinates, startDate, end),
    );
  } catch (error) {
    logger.warn("Open-Meteo archive request failed", { error, key });
    return null;
  }
};

export const clearWeatherCache = () => cache.clear();
