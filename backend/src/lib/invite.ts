const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 8;
const PREFIX_LENGTH = 3;
const FALLBACK_PREFIX = "ZMY";
const UNBIASED_BYTE_LIMIT = 256 - (256 % CODE_ALPHABET.length);

export const generateInviteCode = () => {
  let code = "";
  while (code.length < CODE_LENGTH) {
    for (const byte of crypto.getRandomValues(new Uint8Array(CODE_LENGTH))) {
      if (byte < UNBIASED_BYTE_LIMIT && code.length < CODE_LENGTH) {
        code += CODE_ALPHABET[byte % CODE_ALPHABET.length];
      }
    }
  }
  return code;
};

export const getInvitePrefix = (label: string) => {
  const letters = label
    .replaceAll("ł", "l")
    .replaceAll("Ł", "L")
    .normalize("NFD")
    .replace(/[^a-zA-Z]/g, "")
    .toUpperCase();
  return letters.slice(0, PREFIX_LENGTH) || FALLBACK_PREFIX;
};

export const toInviteSlug = (label: string, code: string) => `${getInvitePrefix(label)}-${code}`;

export const parseInviteCode = (slug: string) => slug.split("-").at(-1)!.toUpperCase();

export const toInviteUrl = (label: string, code: string) =>
  `${process.env.INVITE_BASE_URL ?? process.env.BETTER_AUTH_URL}/j/${toInviteSlug(label, code)}`;
