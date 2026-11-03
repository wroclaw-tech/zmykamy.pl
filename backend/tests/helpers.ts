import app from "../src/index";
import { auth } from "../src/lib/auth";

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
