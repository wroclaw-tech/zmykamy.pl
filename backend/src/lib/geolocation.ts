import { z } from "zod";
import { logger } from "./logger";

const GEOLOCATION_API_URL = "https://free.freeipapi.com/api/v1/json";
const GEOLOCATION_TIMEOUT_MS = 1500;

const geolocationResponseSchema = z.object({
  cityName: z.string().nullable(),
  countryCode: z.string().nullable(),
});

export type IpLocation = { city: string | null; countryCode: string | null };

const EMPTY_LOCATION: IpLocation = { city: null, countryCode: null };

export const getIpLocation = async (ipAddress: string | null | undefined): Promise<IpLocation> => {
  if (!ipAddress) {
    return EMPTY_LOCATION;
  }
  try {
    const response = await fetch(`${GEOLOCATION_API_URL}/${encodeURIComponent(ipAddress)}`, {
      signal: AbortSignal.timeout(GEOLOCATION_TIMEOUT_MS),
    });
    if (!response.ok) {
      logger.warn("IP geolocation failed", { status: response.status });
      return EMPTY_LOCATION;
    }
    const { cityName, countryCode } = geolocationResponseSchema.parse(await response.json());
    return { city: cityName || null, countryCode: countryCode || null };
  } catch (error) {
    logger.warn("IP geolocation failed", { error });
    return EMPTY_LOCATION;
  }
};
