// Bank JSON'ining yaxlitligi (docs/KELAJAK-REJA.md §1): variantlar
// `answer_scales` bilan aynan bir xil, kategoriya nomi va sonlari
// `categories` / `statistics` bilan, yosh sonlari `statistics` bilan mos,
// `text`dan boshqa savolda `scoring` bor, ID'lar ketma-ket. Faqat
// ogohlantirish (bo'lim faylda bo'lmasa — tekshirilmaydi); har bir yozuvni
// parser alohida tekshiradi. Migratsiya generatori ogohlantirishda to'xtaydi.

type Raw = Record<string, unknown>;

const isPlainObject = (v: unknown): v is Raw => !!v && typeof v === 'object' && !Array.isArray(v);

const idOf = (q: Raw) => (typeof q.id === 'string' ? q.id : '?');

/** Kalit tartibidan qat'i nazar JSON tengligi (variantlar uchun yetarli). */
const sameJson = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

function countBy(items: readonly Raw[], key: string): Map<string, number> {
  return items.reduce((counts, q) => {
    const value = String(q[key]);
    return new Map(counts).set(value, (counts.get(value) ?? 0) + 1);
  }, new Map<string, number>());
}

/** `{kalit: son}` — fayldagi haqiqiy son bilan solishtirish. */
function countWarnings(label: string, declared: unknown, actual: ReadonlyMap<string, number>): string[] {
  if (!isPlainObject(declared)) return [];
  const keys = [...new Set([...Object.keys(declared), ...actual.keys()])].sort();
  return keys.flatMap((key) => {
    const expected = declared[key] ?? 0;
    const real = actual.get(key) ?? 0;
    return expected === real ? [] : [`${label}.${key}: e'lon qilingan ${String(expected)}, faylda ${real}`];
  });
}

/** Har savol variantlari `answer_scales[answer_type]` bilan aynan bir xil. */
function scaleWarnings(scales: unknown, items: readonly Raw[]): string[] {
  if (!isPlainObject(scales)) return [];
  return items.flatMap((q) => {
    const type = String(q.answer_type);
    if (type === 'text' || !Object.prototype.hasOwnProperty.call(scales, type)) return [];
    return sameJson(q.options, scales[type]) ? [] : [`${idOf(q)}: variantlar answer_scales.${type} bilan mos emas`];
  });
}

/** Kategoriya nomlari va sonlari: `categories[]` va `statistics.by_category`. */
function categoryWarnings(categories: unknown, statistics: unknown, items: readonly Raw[]): string[] {
  const actual = countBy(items, 'category_id');
  const list = Array.isArray(categories) ? categories.filter(isPlainObject) : [];
  const names = new Map(list.map((c) => [String(c.id), c.name]));
  const declaredCounts = Object.fromEntries(list.map((c) => [String(c.id), c.question_count]));
  return [
    ...items.flatMap((q) => {
      const name = names.get(String(q.category_id));
      return name === undefined || name === q.category ? [] : [`${idOf(q)}: kategoriya nomi categories bilan mos emas`];
    }),
    ...(list.length > 0 ? countWarnings('categories', declaredCounts, actual) : []),
    ...(isPlainObject(statistics) ? countWarnings('statistics.by_category', statistics.by_category, actual) : []),
  ];
}

function ageWarnings(statistics: unknown, items: readonly Raw[]): string[] {
  if (!isPlainObject(statistics)) return [];
  return countWarnings('statistics.by_age_group', statistics.by_age_group, countBy(items, 'age_group'));
}

/** `text`dan boshqa har savolda `scoring` bor. */
function scoringWarnings(items: readonly Raw[]): string[] {
  return items.flatMap((q) =>
    q.answer_type !== 'text' && !isPlainObject(q.scoring) ? [`${idOf(q)}: scoring yo'q`] : [],
  );
}

/** ID'lar bir prefiks bilan ketma-ket (har biri oldingisidan bitta ko'p) — birinchi uzilish. */
function sequenceWarnings(items: readonly Raw[]): string[] {
  const ids = items.map((q) => (typeof q.id === 'string' ? q.id : null));
  const parts = ids.map((id) => (id ? /^(.*?)(\d+)$/.exec(id) : null));
  const brokenAt = parts.findIndex((part, i) => {
    if (i === 0) return false;
    const prev = parts[i - 1];
    return !part || !prev || part[1] !== prev[1] || Number(part[2]) !== Number(prev[2]) + 1;
  });
  return brokenAt > 0 ? [`ID ketma-ketligi: ${ids[brokenAt - 1] ?? '?'} dan keyin ${ids[brokenAt] ?? '?'}`] : [];
}

export function bankIntegrityWarnings(bank: Raw, list: readonly unknown[]): string[] {
  const items = list.filter(isPlainObject);
  return [
    ...scaleWarnings(bank.answer_scales, items),
    ...categoryWarnings(bank.categories, bank.statistics, items),
    ...ageWarnings(bank.statistics, items),
    ...scoringWarnings(items),
    ...sequenceWarnings(items),
  ];
}
