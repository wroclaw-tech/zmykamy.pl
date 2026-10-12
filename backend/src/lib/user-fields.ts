import { z } from "zod";

export const THEME_PALETTES = [
  "ocean",
  "beach",
  "cities",
  "mountains",
  "tropics",
  "festivals",
] as const;

export const themePaletteSchema = z.enum(THEME_PALETTES);
export const termsVersionSchema = z.string().trim().min(1).max(32);
