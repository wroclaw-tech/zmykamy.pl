import { MAX_AMOUNT } from "../schemas/expense";
import { ApiError } from "./errors";
import { convertAmount, getExchangeRate } from "./exchange-rates";

export type AmountInput = {
  amount: number;
  currency: string;
  date: string;
  exchangeRate: number | null;
};

type RateInfo = {
  exchangeRate: number;
  rateSource: "nbp" | "custom";
  rateDate: string | null;
  rateTable: "A" | "B" | "A/B" | null;
};

export const inTripCurrency = (amount: number) => ({
  amount,
  originalCurrency: null,
  originalAmount: null,
  exchangeRate: null,
  rateSource: null,
  rateDate: null,
  rateTable: null,
});

// Converts a foreign amount at the given rate and returns the expense columns to store
export const convertAtRate = (
  tripCurrency: string,
  amount: number,
  currency: string,
  rate: RateInfo,
) => {
  const converted = convertAmount(amount, currency, tripCurrency, rate.exchangeRate);
  if (converted <= 0) {
    throw new ApiError(400, "amount_too_small", "The converted amount must be positive");
  }
  if (converted > MAX_AMOUNT) {
    throw new ApiError(400, "amount_too_large", "The converted amount is too large");
  }
  return { amount: converted, originalCurrency: currency, originalAmount: amount, ...rate };
};

// Converts the entered amount to the trip's currency and returns the expense columns to store
export const resolveAmount = async (tripCurrency: string, input: AmountInput) => {
  if (input.currency === tripCurrency) {
    return inTripCurrency(input.amount);
  }
  if (input.exchangeRate !== null) {
    return convertAtRate(tripCurrency, input.amount, input.currency, {
      exchangeRate: input.exchangeRate,
      rateSource: "custom",
      rateDate: null,
      rateTable: null,
    });
  }
  const nbp = await getExchangeRate(input.currency, tripCurrency, input.date);
  return convertAtRate(tripCurrency, input.amount, input.currency, {
    exchangeRate: nbp.rate,
    rateSource: "nbp",
    rateDate: nbp.effectiveDate,
    rateTable: nbp.table,
  });
};
