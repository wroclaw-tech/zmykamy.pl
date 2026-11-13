import { spyOn } from "bun:test";
import app from "../index";
import { auth } from "../lib/auth";

export const lisbon = {
  name: "Lizbona",
  destination: { name: "Lizbona", country: "Portugalia", latitude: 38.72, longitude: -9.14 },
  startDate: "2027-05-12",
  endDate: "2027-05-18",
  currency: "EUR",
};

export type TestUser = { id: string; headers: Record<string, string> };

export const createUser = async (name: string): Promise<TestUser> => {
  const { token, user: created } = await auth.api.signUpEmail({
    body: { name, email: `${name.toLowerCase()}@example.com`, password: "password123" },
  });
  return {
    id: created.id,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
  };
};

export const request = (
  path: string,
  as: TestUser,
  init: { method?: string; body?: unknown } = {},
) =>
  app.request(path, {
    method: init.method ?? "GET",
    headers: as.headers,
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });

export const createTrip = async (as: TestUser, body: unknown = lisbon) => {
  const response = await request("/trips", as, { method: "POST", body });
  return (await response.json()) as { id: string };
};

const nbpRates: Record<string, { table: "a" | "b"; mid: number; effectiveDate: string }> = {
  EUR: { table: "a", mid: 4.25, effectiveDate: "2026-05-08" },
  USD: { table: "a", mid: 4, effectiveDate: "2026-05-08" },
  VND: { table: "b", mid: 0.00016, effectiveDate: "2026-05-06" },
};

// Stubs the NBP API with fixed mid rates
export const mockNbp = (overrides: Partial<typeof nbpRates> = {}) =>
  spyOn(globalThis, "fetch").mockImplementation((async (input: string | URL | Request) => {
    const [table, code] = String(input).split("/rates/")[1]!.split("/");
    const rate = { ...nbpRates, ...overrides }[code!];
    if (!rate || rate.table !== table) {
      return new Response("404 NotFound - Not Found - Brak danych", { status: 404 });
    }
    return Response.json({ rates: [{ effectiveDate: rate.effectiveDate, mid: rate.mid }] });
  }) as typeof fetch);
