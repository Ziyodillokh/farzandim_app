/**
 * Hududlar (14) — ISO 3166-2 kodi, SOATO, bola ilovasidagi `Child.region`
 * kaliti (slug) va nomlar. Tartib — rasmiy statistika (SOATO) tartibi.
 */
export const REGION_IDS = [
  'UZ-QR',
  'UZ-AN',
  'UZ-BU',
  'UZ-JI',
  'UZ-QA',
  'UZ-NW',
  'UZ-NG',
  'UZ-SA',
  'UZ-SU',
  'UZ-SI',
  'UZ-TO',
  'UZ-FA',
  'UZ-XO',
  'UZ-TK',
] as const;

export type RegionId = (typeof REGION_IDS)[number];

export type RegionRef = {
  id: RegionId;
  soato: string;
  /** Bola ilovasi `Child.region` tarjima kaliti (uzbekistan_regions.dart). */
  slug: string;
  nameUz: string;
  nameRu: string;
  shortUz: string;
  shortRu: string;
};

export const REGIONS: readonly RegionRef[] = [
  { id: 'UZ-QR', soato: '1735', slug: 'karakalpakstan', nameUz: "Qoraqalpog'iston Respublikasi", nameRu: 'Республика Каракалпакстан', shortUz: "Qoraqalpog'iston", shortRu: 'Каракалпакстан' },
  { id: 'UZ-AN', soato: '1703', slug: 'andijan', nameUz: 'Andijon viloyati', nameRu: 'Андижанская область', shortUz: 'Andijon', shortRu: 'Андижан' },
  { id: 'UZ-BU', soato: '1706', slug: 'bukhara', nameUz: 'Buxoro viloyati', nameRu: 'Бухарская область', shortUz: 'Buxoro', shortRu: 'Бухара' },
  { id: 'UZ-JI', soato: '1708', slug: 'jizzakh', nameUz: 'Jizzax viloyati', nameRu: 'Джизакская область', shortUz: 'Jizzax', shortRu: 'Джизак' },
  { id: 'UZ-QA', soato: '1710', slug: 'kashkadarya', nameUz: 'Qashqadaryo viloyati', nameRu: 'Кашкадарьинская область', shortUz: 'Qashqadaryo', shortRu: 'Кашкадарья' },
  { id: 'UZ-NW', soato: '1712', slug: 'navoi', nameUz: 'Navoiy viloyati', nameRu: 'Навоийская область', shortUz: 'Navoiy', shortRu: 'Навои' },
  { id: 'UZ-NG', soato: '1714', slug: 'namangan', nameUz: 'Namangan viloyati', nameRu: 'Наманганская область', shortUz: 'Namangan', shortRu: 'Наманган' },
  { id: 'UZ-SA', soato: '1718', slug: 'samarkand', nameUz: 'Samarqand viloyati', nameRu: 'Самаркандская область', shortUz: 'Samarqand', shortRu: 'Самарканд' },
  { id: 'UZ-SU', soato: '1722', slug: 'surkhandarya', nameUz: 'Surxondaryo viloyati', nameRu: 'Сурхандарьинская область', shortUz: 'Surxondaryo', shortRu: 'Сурхандарья' },
  { id: 'UZ-SI', soato: '1724', slug: 'sirdarya', nameUz: 'Sirdaryo viloyati', nameRu: 'Сырдарьинская область', shortUz: 'Sirdaryo', shortRu: 'Сырдарья' },
  { id: 'UZ-TO', soato: '1727', slug: 'tashkent', nameUz: 'Toshkent viloyati', nameRu: 'Ташкентская область', shortUz: 'Toshkent vil.', shortRu: 'Ташкентская обл.' },
  { id: 'UZ-FA', soato: '1730', slug: 'fergana', nameUz: "Farg'ona viloyati", nameRu: 'Ферганская область', shortUz: "Farg'ona", shortRu: 'Фергана' },
  { id: 'UZ-XO', soato: '1733', slug: 'khorezm', nameUz: 'Xorazm viloyati', nameRu: 'Хорезмская область', shortUz: 'Xorazm', shortRu: 'Хорезм' },
  { id: 'UZ-TK', soato: '1726', slug: 'tashkentCity', nameUz: 'Toshkent shahri', nameRu: 'город Ташкент', shortUz: 'Toshkent sh.', shortRu: 'г. Ташкент' },
];

const BY_ID = new Map(REGIONS.map((r) => [r.id, r]));

export function regionRef(id: RegionId): RegionRef {
  const ref = BY_ID.get(id);
  if (!ref) throw new Error(`Noma'lum hudud: ${id}`);
  return ref;
}

export function isRegionId(value: unknown): value is RegionId {
  return typeof value === 'string' && BY_ID.has(value as RegionId);
}

export function regionName(id: RegionId, locale: 'uz' | 'ru', short = false): string {
  const r = regionRef(id);
  if (locale === 'ru') return short ? r.shortRu : r.nameRu;
  return short ? r.shortUz : r.nameUz;
}
