import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mockNbp } from "../routes/test-helpers";
import { clearExchangeRateCache, convertAmount, getExchangeRate } from "./exchange-rates";

let fetchSpy: ReturnType<typeof mockNbp>;

beforeEach(() => {
  clearExchangeRateCache();
  fetchSpy = mockNbp();
});

afterEach(() => fetchSpy.mockRestore());

describe("getExchangeRate", () => {
  test("returns the NBP mid rate against PLN", async () => {
    expect(await getExchangeRate("EUR", "PLN", "2026-05-10")).toEqual({
      rate: 4.25,
      effectiveDate: "2026-05-08",
    });
    expect((await getExchangeRate("PLN", "EUR", "2026-05-10")).rate).toBeCloseTo(1 / 4.25);
  });

  test("crosses two foreign currencies through PLN", async () => {
    expect((await getExchangeRate("USD", "EUR", "2026-05-10")).rate).toBeCloseTo(4 / 4.25);
  });

  test("falls back to table B for exotic currencies", async () => {
    expect(await getExchangeRate("VND", "PLN", "2026-05-10")).toEqual({
      rate: 0.00016,
      effectiveDate: "2026-05-06",
    });
  });

  test("asks for the latest rate up to the payment day", async () => {
    await getExchangeRate("EUR", "PLN", "2026-05-10");
    expect(String(fetchSpy.mock.calls[0]![0])).toContain("/a/EUR/2026-04-30/2026-05-10/");
  });

  test("caches past days", async () => {
    await getExchangeRate("EUR", "PLN", "2026-05-10");
    await getExchangeRate("EUR", "PLN", "2026-05-10");
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  test("rejects currencies NBP does not publish", async () => {
    await expect(getExchangeRate("XAU", "PLN", "2026-05-10")).rejects.toMatchObject({
      code: "unsupported_currency",
    });
  });
});

describe("convertAmount", () => {
  test("converts between minor units", () => {
    expect(convertAmount(1000, "EUR", "PLN", 4.25)).toBe(4250);
  });

  test("accounts for currencies without minor units", () => {
    expect(convertAmount(10_000, "JPY", "PLN", 0.025)).toBe(25_000);
    expect(convertAmount(10_000, "PLN", "JPY", 40)).toBe(4000);
  });
});
