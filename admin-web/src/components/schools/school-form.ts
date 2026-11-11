// Admin → Maktablar: forma mantig'i (React'siz, `tsx --test` bilan tekshiriladi).
// Qoidalar backend `admin-schools.input.ts` bilan bir xil — server xatosi
// faqat poyga holatida (masalan, kod shu orada band bo'lsa) chiqadi.

import type { CreateSchoolPayload } from '@/lib/api/admin.api';

export const SCHOOL_CODE_PATTERN = /^[a-z0-9-]{2,40}$/;
export const STAFF_USERNAME_PATTERN = /^[a-z0-9._-]{3,32}$/;
export const DEFAULT_DIRECTOR_USERNAME = 'direktor';
export const SCHOOL_PANEL_URL = 'https://farzandimedu.uz/maktab/';

export const LIMITS = {
  name: 100,
  shortName: 12,
  city: 40,
  fullName: 80,
} as const;

const LATIN: Record<string, string> = {
  а: 'a',
  б: 'b',
  в: 'v',
  г: 'g',
  д: 'd',
  е: 'e',
  ё: 'yo',
  ж: 'j',
  з: 'z',
  и: 'i',
  й: 'y',
  к: 'k',
  л: 'l',
  м: 'm',
  н: 'n',
  о: 'o',
  п: 'p',
  р: 'r',
  с: 's',
  т: 't',
  у: 'u',
  ф: 'f',
  х: 'x',
  ц: 's',
  ч: 'ch',
  ш: 'sh',
  щ: 'sh',
  ъ: '',
  ы: 'i',
  ь: '',
  э: 'e',
  ю: 'yu',
  я: 'ya',
  ў: 'o',
  қ: 'q',
  ғ: 'g',
  ҳ: 'h',
};

/** Nomdan maktab kodi taklifi: «24-maktab, Chilonzor» → «24-maktab-chilonzor». */
export function suggestSchoolCode(name: string): string {
  const latin = name
    .toLowerCase()
    .split('')
    .map((ch) => LATIN[ch] ?? ch)
    .join('')
    // Oʻ, gʻ, ' va ʼ belgilari kodda tushib qoladi (o'quvchi → oquvchi).
    .replace(/[ʻʼ'`‘’]/g, '');
  return latin
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40)
    .replace(/-+$/g, '');
}

export interface SchoolFormValues {
  name: string;
  shortName: string;
  city: string;
  code: string;
  directorName: string;
  directorUsername: string;
}

export type SchoolFormErrors = Partial<Record<keyof SchoolFormValues, string>>;

export const emptySchoolForm = (): SchoolFormValues => ({
  name: '',
  shortName: '',
  city: '',
  code: '',
  directorName: '',
  directorUsername: DEFAULT_DIRECTOR_USERNAME,
});

const required = (value: string, label: string, max: number): string | undefined => {
  const v = value.trim();
  if (!v) return `${label} kiritilmagan`;
  if (v.length > max) return `${label} ${max} belgidan oshmasin`;
  return undefined;
};

export function usernameError(value: string): string | undefined {
  return STAFF_USERNAME_PATTERN.test(value.trim().toLowerCase())
    ? undefined
    : 'Login: 3–32 belgi, faqat a-z, 0-9, ".", "_", "-"';
}

export function validateSchoolForm(form: SchoolFormValues): SchoolFormErrors {
  const errors: SchoolFormErrors = {
    name: required(form.name, 'Maktab nomi', LIMITS.name),
    city: required(form.city, 'Shahar / tuman', LIMITS.city),
    shortName:
      form.shortName.trim().length > LIMITS.shortName ? `Qisqa nom ${LIMITS.shortName} belgidan oshmasin` : undefined,
    code: SCHOOL_CODE_PATTERN.test(form.code.trim().toLowerCase())
      ? undefined
      : 'Maktab kodi: 2–40 belgi, faqat a-z, 0-9 va "-"',
    directorName: required(form.directorName, 'Direktor F.I.Sh.', LIMITS.fullName),
    directorUsername: usernameError(form.directorUsername),
  };
  return Object.fromEntries(Object.entries(errors).filter(([, v]) => v)) as SchoolFormErrors;
}

export const hasErrors = (errors: object): boolean => Object.keys(errors).length > 0;

export function toCreatePayload(form: SchoolFormValues): CreateSchoolPayload {
  const shortName = form.shortName.trim();
  return {
    code: form.code.trim().toLowerCase(),
    name: form.name.trim(),
    ...(shortName && { shortName }),
    city: form.city.trim(),
    director: {
      fullName: form.directorName.trim(),
      username: form.directorUsername.trim().toLowerCase(),
    },
  };
}

/** Direktorga yuboriladigan matn (nusxa olish uchun). */
export function credentialsText(c: {
  schoolName?: string;
  schoolCode: string;
  username: string;
  temporaryPassword: string;
}): string {
  return [
    c.schoolName ? `Parvoz maktab paneli — ${c.schoolName}` : 'Parvoz maktab paneli',
    `Manzil: ${SCHOOL_PANEL_URL}`,
    `Maktab kodi: ${c.schoolCode}`,
    `Login: ${c.username}`,
    `Vaqtinchalik parol: ${c.temporaryPassword}`,
    'Birinchi kirishda yangi parol o‘rnatiladi.',
  ].join('\n');
}
