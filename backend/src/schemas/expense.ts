import { z } from "zod";
import { PLAN_ICONS } from "../db/schema";
import { roundRate } from "../lib/exchange-rates";
import { currencySchema } from "./user";

export const MAX_AMOUNT = 100_000_000;

const amountSchema = z.int().positive().max(MAX_AMOUNT);

const userIdSchema = z.string().min(1);

const exchangeRateSchema = z
  .number()
  .positive()
  .max(1_000_000)
  .refine((rate) => roundRate(rate) === rate, "At most 6 decimal places");

export const expenseParamSchema = z.object({ id: z.uuid(), expenseId: z.uuid() });

export const paymentParamSchema = z.object({ id: z.uuid(), paymentId: z.uuid() });

export const exchangeRateQuerySchema = z.object({
  currency: currencySchema,
  date: z.iso.date().optional(),
});

// `amount` is in `currency` (the trip's currency when omitted on create). Without
// `exchangeRate` the NBP mid rate from the expense date is used.
export const createExpenseSchema = z.object({
  title: z.string().trim().min(1).max(120),
  amount: amountSchema,
  currency: currencySchema.optional(),
  exchangeRate: exchangeRateSchema.optional(),
  date: z.iso.date(),
  icon: z.enum(PLAN_ICONS).default("savings"),
  paidBy: userIdSchema,
  participants: z.array(userIdSchema).min(1).max(100),
});

export const updateExpenseSchema = createExpenseSchema
  .extend({ exchangeRate: exchangeRateSchema.nullable() })
  .partial()
  .refine((body) => Object.keys(body).length > 0, "At least one field is required");

export const createPaymentSchema = z
  .object({ fromUserId: userIdSchema, toUserId: userIdSchema, amount: amountSchema })
  .refine((body) => body.fromUserId !== body.toUserId, {
    message: "fromUserId and toUserId must differ",
    path: ["toUserId"],
  });
