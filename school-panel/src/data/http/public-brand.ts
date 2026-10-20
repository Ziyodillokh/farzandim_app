import type { School } from '@/data/contracts';
import { API_BASE } from '@/data/source';

/** Kirish sahifasi brendi — sessiyasiz `GET /school/public/brand`. */
export type PublicBrand = Pick<School, 'name' | 'shortName' | 'logo' | 'city' | 'academicYear'>;

/** Maktab topilmasa yoki tarmoq yo'q bo'lsa — `null` (brendsiz kirish sahifasi). */
export async function fetchPublicBrand(code: string): Promise<PublicBrand | null> {
  try {
    const res = await fetch(`${API_BASE}/school/public/brand?code=${encodeURIComponent(code)}`, {
      headers: { Accept: 'application/json' },
    });
    return res.ok ? ((await res.json()) as PublicBrand) : null;
  } catch {
    return null;
  }
}
