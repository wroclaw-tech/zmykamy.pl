import { z } from "zod";
import { ApiError } from "./errors";
import { logger } from "./logger";

const NBP_API_URL = "https://api.nbp.pl/api/exchangerates/rates";
const NBP_TIMEOUT_MS = 3000;
const BASE_CURRENCY = "PLN";
// Table A is published every business day, table B (exotic currencies) once a week
const LOOKBACK_DAYS = { a: 10, b: 21 } as const;
const DAY_MS = 24 * 60 * 60 * 1000;

const nbpResponseSchema = z.object({
  rates: z.array(z.object({ effectiveDate: z.iso.date(), mid: z.number().positive() })).min(1),
});

type NbpTable = "A" | "B";
type NbpRate = { mid: number; effectiveDate: string; table: NbpTable | null };

export type ExchangeRate = {
  rate: number;
  effectiveDate: string;
  table: NbpTable | "A/B" | null;
};

const cache = new Map<string, Promise<NbpRate | null>>();

const getWarsawToday = () =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Warsaw" }).format(new Date());

const shiftDate = (date: string, days: number) =>
  new Date(Date.parse(date) + days * DAY_MS).toISOString().slice(0, 10);

const fetchTableRate = async (table: "a" | "b", currency: string, date: string) => {
  const url = `${NBP_API_URL}/${table}/${currency}/${shiftDate(date, -LOOKBACK_DAYS[table])}/${date}/?format=json`;
  const response = await fetch(url, { signal: AbortSignal.timeout(NBP_TIMEOUT_MS) });
  if (response.status === 404) {
    return null;
  }
  if (!response.ok) {
    throw new Error(`NBP responded with ${response.status}`);
  }
  const { rates } = nbpResponseSchema.parse(await response.json());
  return { ...rates.at(-1)!, table: table === "a" ? ("A" as const) : ("B" as const) };
};

const fetchNbpRate = async (currency: string, date: string): Promise<NbpRate | null> =>
  (await fetchTableRate("a", currency, date)) ?? (await fetchTableRate("b", currency, date));

// Mid rate in PLN per unit, from the latest table published on or before the date.
// Today's table may not be out yet, so only past days are cached.
const getNbpRate = (currency: string, date: string) => {
  if (date >= getWarsawToday()) {
    return fetchNbpRate(currency, date);
  }
  const key = `${currency}:${date}`;
  let pending = cache.get(key);
  if (!pending) {
    pending = fetchNbpRate(currency, date);
    pending.catch(() => cache.delete(key));
    cache.set(key, pending);
  }
  return pending;
};

const getPlnRate = async (currency: string, date: string): Promise<NbpRate> => {
  if (currency === BASE_CURRENCY) {
    return { mid: 1, effectiveDate: date, table: null };
  }
  let rate: NbpRate | null;
  try {
    rate = await getNbpRate(currency, date);
  } catch (error) {
    logger.warn("NBP exchange rate request failed", { error, currency, date });
    throw new ApiError(502, "rate_unavailable", "Could not fetch the NBP exchange rate");
  }
  if (!rate) {
    throw new ApiError(422, "unsupported_currency", `NBP does not publish a rate for ${currency}`);
  }
  return rate;
};

// Rate converting one unit of `from` into `to`, using NBP mid rates for the given day
export const getExchangeRate = async (
  from: string,
  to: string,
  date: string,
): Promise<ExchangeRate> => {
  const today = getWarsawToday();
  const day = date > today ? today : date;
  if (from === to) {
    return { rate: 1, effectiveDate: day, table: null };
  }
  const [source, target] = await Promise.all([getPlnRate(from, day), getPlnRate(to, day)]);
  const effectiveDate =
    from === BASE_CURRENCY
      ? target.effectiveDate
      : to === BASE_CURRENCY || source.effectiveDate < target.effectiveDate
        ? source.effectiveDate
        : target.effectiveDate;
  const table =
    source.table && target.table && source.table !== target.table
      ? "A/B"
      : (source.table ?? target.table);
  return { rate: source.mid / target.mid, effectiveDate, table };
};

const getMinorUnitDigits = (currency: string) =>
  new Intl.NumberFormat("en", { style: "currency", currency }).resolvedOptions()
    .maximumFractionDigits ?? 2;

// Converts an amount in minor units of `from` to minor units of `to`
export const convertAmount = (amount: number, from: string, to: string, rate: number) =>
  Math.round(amount * rate * 10 ** (getMinorUnitDigits(to) - getMinorUnitDigits(from)));

export const clearExchangeRateCache = () => cache.clear();
