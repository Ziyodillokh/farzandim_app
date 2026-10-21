// Matn siyosati (docs/KELAJAK-REJA.md §3): kasb bo'yicha qat'iy hukm yo'q,
// taqiqlangan iboralar hech bir matnda uchramaydi, bolaga signal xabarlarida
// raqam yo'q, ota-onaga "bu tashxis emas". Barcha ko'rsatish matnlari
// tekshiriladi: texts.ts, kategoriya nomlari va Career Lab faoliyatlari.

import { CAREER_LAB_LABELS } from './career-lab';
import { GROWTH_KEYS, KELAJAK_CATEGORIES, KELAJAK_TEST_TYPES, RIASEC_CODES, SCORED_CATEGORY_IDS } from './catalog';
import { KELAJAK_LANGS, L } from './localized';
import {
  DISCLAIMERS,
  GROWTH_TEXTS,
  NEXT_TEXTS,
  RIASEC_TEXTS,
  STRENGTH_TEXTS,
  SUPPORT_CHILD_TEXTS,
  SUPPORT_PARENT_TEXTS,
  TEST_TEXTS,
} from './texts';

interface Entry {
  path: string;
  text: L;
}

const isL = (v: unknown): v is L =>
  !!v && typeof v === 'object' && !Array.isArray(v) && typeof (v as { uz?: unknown }).uz === 'string';

/** Ichma-ich tuzilmadagi barcha `L` matnlari (yo'li bilan). */
function collect(value: unknown, path: string): Entry[] {
  if (isL(value)) return [{ path, text: value }];
  if (Array.isArray(value)) return value.flatMap((v, i) => collect(v, `${path}[${i}]`));
  if (value && typeof value === 'object') {
    return Object.entries(value).flatMap(([k, v]) => collect(v, `${path}.${k}`));
  }
  return [];
}

const ALL_TEXTS: Entry[] = [
  ...collect(TEST_TEXTS, 'TEST_TEXTS'),
  ...collect(RIASEC_TEXTS, 'RIASEC_TEXTS'),
  ...collect(STRENGTH_TEXTS, 'STRENGTH_TEXTS'),
  ...collect(GROWTH_TEXTS, 'GROWTH_TEXTS'),
  ...collect(SUPPORT_CHILD_TEXTS, 'SUPPORT_CHILD_TEXTS'),
  ...collect(SUPPORT_PARENT_TEXTS, 'SUPPORT_PARENT_TEXTS'),
  ...collect(NEXT_TEXTS, 'NEXT_TEXTS'),
  ...collect(DISCLAIMERS, 'DISCLAIMERS'),
  ...collect(KELAJAK_CATEGORIES.map((c) => c.name), 'KELAJAK_CATEGORIES'),
  ...collect(CAREER_LAB_LABELS, 'CAREER_LAB_LABELS'),
];

/** Apostrof variantlari (' ‘ ’ ʼ `) bitta belgiga keltiriladi. */
const normalize = (s: string) => s.toLowerCase().replace(/[‘’ʼʻ`´]/g, '\'');

const FORBIDDEN = [
  'bo\'lishing kerak',
  'mos ekansan',
  'должен стать',
  'тебе нужно стать',
  'you should become',
  'you must become',
  '100%',
];

/** "tashxis" faqat inkor bilan: keyingi 3 so'z ichida "emas". */
const AFFIRMATIVE_DIAGNOSIS = /tashxis(?![a-z']*(?:\s+[^\s.,;:!?]+){0,3}?\s+emas\b)/;

function violations(text: string): string[] {
  const t = normalize(text);
  return [
    ...FORBIDDEN.filter((phrase) => t.includes(phrase)),
    ...(AFFIRMATIVE_DIAGNOSIS.test(t) ? ['tashxis (ijobiy ma\'noda)'] : []),
  ];
}

const strings = (entries: readonly Entry[]) =>
  entries.flatMap(({ path, text }) =>
    KELAJAK_LANGS.flatMap((lang) => (text[lang] === undefined ? [] : [{ path: `${path}.${lang}`, value: text[lang]! }])),
  );

describe('kelajak matn siyosati', () => {
  it('tekshiruvchi o\'zi ishlaydi', () => {
    expect(violations('Sen dasturchi bo‘lishing kerak')).toEqual(['bo\'lishing kerak']);
    expect(violations('Senga bu kasb 100% mos')).toEqual(['100%']);
    expect(violations('You should become an engineer')).toEqual(['you should become']);
    expect(violations('Ты должен стать врачом')).toEqual(['должен стать']);
    expect(violations('Tashxis: xavotir')).toEqual(['tashxis (ijobiy ma\'noda)']);
    expect(violations('Bu tashxis emas.')).toEqual([]);
    expect(violations('Savollar tashxis vositasi emas')).toEqual([]);
    expect(violations('Bu tibbiy tashxis qo‘yish vositasi emas')).toEqual([]);
  });

  it('matnlar topildi (bo\'sh tekshiruv emas)', () => {
    expect(ALL_TEXTS.length).toBeGreaterThan(100);
  });

  it('hech bir matnda taqiqlangan ibora yo\'q', () => {
    const found = strings(ALL_TEXTS).flatMap(({ path, value }) =>
      violations(value).map((v) => `${path}: ${v}`),
    );
    expect(found).toEqual([]);
  });

  it('har matn uch tilda (uz/ru/en), bo\'sh emas', () => {
    const missing = ALL_TEXTS.flatMap(({ path, text }) =>
      KELAJAK_LANGS.filter((lang) => !text[lang]?.trim()).map((lang) => `${path}.${lang}`),
    );
    expect(missing).toEqual([]);
  });

  it('bolaga signal xabari: raqamsiz, ishonchli kattalar; xavfda SOS tugmasi', () => {
    for (const [level, text] of Object.entries(SUPPORT_CHILD_TEXTS)) {
      for (const lang of KELAJAK_LANGS) expect(text[lang]).not.toMatch(/\d/);
      expect(normalize(text.uz)).toMatch(/ishonchli katta/);
      if (level !== 'none') {
        for (const lang of KELAJAK_LANGS) expect(text[lang]).toMatch(/SOS/);
      }
    }
  });

  it('ota-onaga: xotirjam ohang, "bu tashxis emas"', () => {
    for (const text of Object.values(SUPPORT_PARENT_TEXTS)) {
      expect(text.uz).toMatch(/tashxis emas/);
      expect(text.ru).toMatch(/не диагноз/);
      expect(text.en).toMatch(/not a diagnosis/);
    }
    expect(Object.keys(SUPPORT_PARENT_TEXTS)).toEqual(['watch', 'support']);
  });

  it('qamrov: har test turi, ballanadigan kategoriya va RIASEC kodi uchun matn bor', () => {
    expect(Object.keys(TEST_TEXTS)).toEqual([...KELAJAK_TEST_TYPES]);
    expect(Object.keys(STRENGTH_TEXTS).sort()).toEqual([...SCORED_CATEGORY_IDS].sort());
    expect(Object.keys(GROWTH_TEXTS).sort()).toEqual([...GROWTH_KEYS].sort());
    expect(Object.keys(RIASEC_TEXTS)).toEqual([...RIASEC_CODES]);
    for (const code of RIASEC_CODES) expect(RIASEC_TEXTS[code].suggestions.length).toBeGreaterThanOrEqual(3);
  });

  it('savollar soni matnlarda yo\'q — faqat KELAJAK_TESTS\'da', () => {
    for (const { title, description } of Object.values(TEST_TEXTS)) {
      for (const lang of KELAJAK_LANGS) {
        expect(title[lang]).not.toMatch(/\d/);
        expect(description[lang]).not.toMatch(/\d/);
      }
    }
  });

  it('ochiq fikr va farovonlik testi: bola nimani kim ko\'rishini biladi; yordam uchun ishonchli katta va SOS', () => {
    const voice = TEST_TEXTS.voice.description;
    expect(normalize(voice.uz)).toMatch(/ota-onang ko'rmaydi/);
    expect(normalize(voice.uz)).toMatch(/ishonchli katta/);
    for (const lang of KELAJAK_LANGS) expect(voice[lang]).toMatch(/SOS/);
    expect(voice.ru).toMatch(/Родители не видят/);
    expect(voice.en).toMatch(/parents do not see/);
    expect(normalize(TEST_TEXTS.wellbeing.description.uz)).toMatch(/umumiy xulosa/);
  });

  it('o\'rin to\'ldiruvchilar faqat {activity} va faqat Career Lab tavsiyasida', () => {
    const placeholders = strings(ALL_TEXTS).filter(({ value }) => /[{}]/.test(value));
    expect(placeholders.every(({ path, value }) => path.startsWith('NEXT_TEXTS.career_lab') && /^[^{}]*\{activity\}[^{}]*$/.test(value))).toBe(true);
  });
});
