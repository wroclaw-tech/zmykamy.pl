import { z } from "zod";

const DEVICE_NAME_HEADER = "x-device-name";

const deviceNameSchema = z.string().trim().min(1).max(60);

export const getDeviceName = (headers: Headers | undefined) => {
  const result = deviceNameSchema.safeParse(headers?.get(DEVICE_NAME_HEADER));
  return result.success ? result.data : null;
};
