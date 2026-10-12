import type { Gender, Staff } from '@/data/contracts';
import { withBase } from './base-path';

/**
 * Xodim portretlari: `public/avatars/f-NN.svg` (ayollar) va `m-NN.svg` (erkaklar),
 * DiceBear Notionists (CC0). Har xodimga jinsiga mos, iloji boricha noyob portret
 * deterministik tarzda biriktiriladi (RNG'siz — seed determinizmi buzilmaydi).
 */
export const PORTRAIT_POOL = { FEMALE: 36, MALE: 24 } as const;

/** Demo hisoblar — eng yaxshi portretlar (login kartochkalarida ko'rinadi). */
export const PINNED_PORTRAITS: Readonly<Record<string, string>> = {
  'stf-director': 'f-01',
  'stf-homeroom-7a': 'f-02',
  'stf-psychologist': 'f-03',
  'stf-admin': 'm-01',
  'stf-duty': 'm-02',
};

const FEMALE_SUFFIX = /(ovna|evna|qizi)$/i;
const MALE_SUFFIX = /(ovich|evich|o['ʻ’`]?g['ʻ’`]?li)$/i;
const FEMALE_SURNAME = /^\S+(ova|eva|ina|aya)\s/i;
const PORTRAIT_KEY = /^[fm]-\d{2}$/;

/** O'zbek F.I.Sh. bo'yicha jins: otasining ismi qo'shimchasi, bo'lmasa familiya. */
export function inferStaffGender(fullName: string): Gender {
  const name = fullName.trim();
  if (FEMALE_SUFFIX.test(name)) return 'FEMALE';
  if (MALE_SUFFIX.test(name)) return 'MALE';
  return FEMALE_SURNAME.test(name) ? 'FEMALE' : 'MALE';
}

function poolKeys(gender: Gender): string[] {
  const prefix = gender === 'FEMALE' ? 'f' : 'm';
  return Array.from({ length: PORTRAIT_POOL[gender] }, (_, i) => `${prefix}-${String(i + 1).padStart(2, '0')}`);
}

/** Eng kam ishlatilgan portret (teng bo'lsa — eng kichik raqam). */
export function assignPortrait(existing: ReadonlyArray<{ portrait?: string }>, fullName: string): string {
  const keys = poolKeys(inferStaffGender(fullName));
  const used = new Map(keys.map((k) => [k, 0]));
  for (const s of existing) {
    const n = s.portrait ? used.get(s.portrait) : undefined;
    if (n !== undefined && s.portrait) used.set(s.portrait, n + 1);
  }
  let best = keys[0] ?? 'f-01';
  let bestCount = Number.POSITIVE_INFINITY;
  for (const k of keys) {
    const n = used.get(k) ?? 0;
    if (n < bestCount) {
      best = k;
      bestCount = n;
    }
  }
  return best;
}

/** Portreti yo'q xodimlarga tartib bo'yicha portret beradi (demo hisoblar — biriktirilgan). */
export function assignAllPortraits<T extends Pick<Staff, 'id' | 'fullName' | 'portrait'>>(staff: readonly T[]): T[] {
  const pinned = staff.map((s) => {
    const key = PINNED_PORTRAITS[s.id];
    return key ? { ...s, portrait: key } : s;
  });
  const taken: Array<{ portrait?: string }> = pinned.filter((s) => s.portrait);
  return pinned.map((s) => {
    if (s.portrait) return s;
    const next = { ...s, portrait: assignPortrait(taken, s.fullName) };
    taken.push(next);
    return next;
  });
}

export function portraitUrl(key: string): string | null {
  return PORTRAIT_KEY.test(key) ? withBase(`/avatars/${key}.svg`) : null;
}

/** Ko'rsatiladigan rasm: yuklangan foto → portret → null (bosh harflar). */
export function staffAvatarSrc(s: { photo?: string | null; portrait?: string | null }): string | null {
  if (s.photo) return s.photo;
  return s.portrait ? portraitUrl(s.portrait) : null;
}

/** "Yusupova Nodira Azimovna" → "Nodira Yusupova". */
export function shortName(fullName: string): string {
  const [last, first] = fullName.trim().split(/\s+/);
  return first ? `${first} ${last}` : (last ?? '');
}
