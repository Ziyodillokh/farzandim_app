import type { School } from '@/data/contracts';

/**
 * "Shu maktab uchun havola": maktab nomi, shahri va logosi URL fragmentiga
 * (`#b=...`) joylanadi — havolani ochgan istalgan brauzerda shu maktab ko'rinadi.
 * Fragment serverga yuborilmaydi (faqat brauzerda o'qiladi).
 */
export type Brand = Pick<School, 'name' | 'shortName' | 'city' | 'logo'>;

const PARAM = 'b';
const MAX_LOGO_IN_LINK = 60_000;

function toBase64Url(text: string): string {
  const bytes = new TextEncoder().encode(text);
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fromBase64Url(value: string): string {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((value.length + 3) % 4);
  const binary = atob(padded);
  const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

export function encodeBrand(brand: Brand): string {
  const logo = brand.logo && brand.logo.length <= MAX_LOGO_IN_LINK ? brand.logo : null;
  return toBase64Url(JSON.stringify({ n: brand.name, s: brand.shortName, c: brand.city, l: logo }));
}

export function decodeBrand(hash: string): Brand | null {
  // Juda uzun havola — e'tiborsiz (logo 60 KB gacha, matnlar qisqa).
  if (hash.length > MAX_LOGO_IN_LINK * 2) return null;
  const match = new RegExp(`[#&]${PARAM}=([^&]+)`).exec(hash);
  if (!match?.[1]) return null;
  try {
    const raw = JSON.parse(fromBase64Url(match[1])) as { n?: unknown; s?: unknown; c?: unknown; l?: unknown };
    if (typeof raw.n !== 'string' || raw.n.trim().length === 0 || raw.n.length > 100) return null;
    const logo =
      typeof raw.l === 'string' && raw.l.length <= MAX_LOGO_IN_LINK && /^data:image\/(png|jpeg|webp|svg\+xml);base64,[A-Za-z0-9+/=]+$/.test(raw.l)
        ? raw.l
        : null;
    return {
      name: raw.n.trim(),
      shortName: typeof raw.s === 'string' && raw.s.trim() ? raw.s.trim().slice(0, 12) : raw.n.trim().slice(0, 3).toUpperCase(),
      city: typeof raw.c === 'string' ? raw.c.trim().slice(0, 40) : '',
      logo,
    };
  } catch {
    return null;
  }
}

export function brandLink(origin: string, basePath: string, brand: Brand): string {
  return `${origin}${basePath}/login/#${PARAM}=${encodeBrand(brand)}`;
}

export const BRAND_PARAM = PARAM;
