// IQ savollar banki JSON'i — tekshiruv. Migratsiya va kelajakdagi import shu
// qoidadan o'tadi. Ikki tur:
//   FIGURAL — rasmli matritsa (prisma/data/iq/items.json, generator.py), 6 svg variant;
//   NUMERIC / VERBAL / LOGIC — matnli (text_items.json, text_items.py), shart va
//   variantlar uch tilda, 4–6 variant.

import { CLASSIC_FORMS, IQ_FORMS, IQ_LEVELS, IqLevel, OPTION_KEYS } from './levels';

export const IQ_ITEM_KINDS = ['FIGURAL', 'NUMERIC', 'VERBAL', 'LOGIC'] as const;
export type IqItemKind = (typeof IQ_ITEM_KINDS)[number];
export type TextKind = Exclude<IqItemKind, 'FIGURAL'>;

export const IQ_LOCALES = ['uz', 'ru', 'en'] as const;
export type LocalizedText = Record<(typeof IQ_LOCALES)[number], string>;

interface IqItemBase {
  externalId: string;
  level: IqLevel;
  forms: string[];
  rule: string;
  b: number;
  answer: string;
}

export interface IqFiguralItem extends IqItemBase {
  kind: 'FIGURAL';
  gridSvg: string;
  options: Array<{ key: string; svg: string }>;
}

export interface IqTextItem extends IqItemBase {
  kind: TextKind;
  stem: LocalizedText;
  options: Array<{ key: string; text: LocalizedText }>;
}

export type IqItemData = IqFiguralItem | IqTextItem;

const FIGURAL_ID = /^iq-L[1-5]-\d{3}$/;
const TEXT_ID: Readonly<Record<TextKind, RegExp>> = {
  NUMERIC: /^iq-L[1-5]-N\d{2}$/,
  VERBAL: /^iq-L[1-5]-V\d{2}$/,
  LOGIC: /^iq-L[1-5]-G\d{2}$/,
};
const FORM = /^L[1-5][A-D]$/;
const SVG = /^<svg [^>]*>[\s\S]*<\/svg>$/;
/** SVG ichida faol kontent bo'lmasin (klient WebView emas, lekin baribir). */
const UNSAFE_SVG = /<script|on\w+=|javascript:|<foreignObject|xlink:href|href=/i;
const MIN_TEXT_OPTIONS = 4;
const MAX_TEXT_LENGTH = 400;

type Failed = { ok: false; error: string };
type Parsed = { ok: true; value: IqItemData } | Failed;
type Base = { ok: true; value: IqItemBase } | Failed;

function svgError(svg: unknown): string | null {
  if (typeof svg !== 'string' || !SVG.test(svg)) return 'svg emas';
  return UNSAFE_SVG.test(svg) ? 'xavfli svg' : null;
}

function localized(value: unknown): LocalizedText | null {
  if (typeof value !== 'object' || value === null) return null;
  const v = value as Record<string, unknown>;
  const ok = IQ_LOCALES.every((l) => {
    const s = v[l];
    return typeof s === 'string' && s.trim().length > 0 && s.length <= MAX_TEXT_LENGTH;
  });
  return ok ? { uz: v.uz as string, ru: v.ru as string, en: v.en as string } : null;
}

function parseBase(r: Record<string, unknown>, idPattern: RegExp): Base {
  if (typeof r.externalId !== 'string' || !idPattern.test(r.externalId)) return { ok: false, error: 'externalId' };
  if (!IQ_LEVELS.includes(r.level as IqLevel)) return { ok: false, error: 'level' };
  if (!r.externalId.startsWith(`iq-L${r.level as number}-`)) return { ok: false, error: 'externalId darajasi' };
  if (!Array.isArray(r.forms) || !r.forms.every((f) => typeof f === 'string' && FORM.test(f))) {
    return { ok: false, error: 'forms' };
  }
  if (typeof r.b !== 'number' || !Number.isFinite(r.b) || Math.abs(r.b) > 6) return { ok: false, error: 'b' };
  if (typeof r.rule !== 'string' || r.rule.length === 0) return { ok: false, error: 'rule' };
  if (typeof r.answer !== 'string') return { ok: false, error: 'answer' };
  const { externalId, level, forms, rule, b, answer } = r as unknown as IqItemBase;
  return { ok: true, value: { externalId, level, forms, rule, b, answer } };
}

function parseFigural(r: Record<string, unknown>): Parsed {
  const base = parseBase(r, FIGURAL_ID);
  if (!base.ok) return base;
  const gridError = svgError(r.gridSvg);
  if (gridError) return { ok: false, error: `gridSvg: ${gridError}` };
  const options = r.options;
  if (!Array.isArray(options) || options.length !== OPTION_KEYS.length) return { ok: false, error: 'options soni' };
  for (const [i, o] of options.entries()) {
    const opt = o as Record<string, unknown>;
    if (opt?.key !== OPTION_KEYS[i]) return { ok: false, error: `options[${i}].key` };
    const e = svgError(opt.svg);
    if (e) return { ok: false, error: `options[${i}]: ${e}` };
  }
  if (!OPTION_KEYS.includes(base.value.answer)) return { ok: false, error: 'answer' };
  return {
    ok: true,
    value: {
      ...base.value,
      kind: 'FIGURAL',
      gridSvg: r.gridSvg as string,
      options: (options as Array<{ key: string; svg: string }>).map(({ key, svg }) => ({ key, svg })),
    },
  };
}

function parseText(r: Record<string, unknown>, kind: TextKind): Parsed {
  const base = parseBase(r, TEXT_ID[kind]);
  if (!base.ok) return base;
  if (r.gridSvg !== undefined && r.gridSvg !== null) return { ok: false, error: 'matnli savolda gridSvg' };
  // Matnli savol faqat o'z darajasining aralash formasida (A/B — rasmli).
  if (!base.value.forms.every((f) => f.startsWith(`L${base.value.level}`) && !CLASSIC_FORMS.some((c) => f.endsWith(c)))) {
    return { ok: false, error: 'matnli savol formasi' };
  }
  const stem = localized(r.stem);
  if (!stem) return { ok: false, error: 'stem' };
  const raw = r.options;
  if (!Array.isArray(raw) || raw.length < MIN_TEXT_OPTIONS || raw.length > OPTION_KEYS.length) {
    return { ok: false, error: 'options soni' };
  }
  const options: IqTextItem['options'] = [];
  for (const [i, o] of raw.entries()) {
    const opt = o as Record<string, unknown>;
    if (opt?.key !== OPTION_KEYS[i]) return { ok: false, error: `options[${i}].key` };
    const text = localized(opt.text);
    if (!text) return { ok: false, error: `options[${i}].text` };
    options.push({ key: OPTION_KEYS[i], text });
  }
  for (const l of IQ_LOCALES) {
    if (new Set(options.map((o) => o.text[l])).size !== options.length) return { ok: false, error: `options takror (${l})` };
  }
  if (!options.some((o) => o.key === base.value.answer)) return { ok: false, error: 'answer' };
  return { ok: true, value: { ...base.value, kind, stem, options } };
}

export function parseIqItem(raw: unknown): Parsed {
  if (typeof raw !== 'object' || raw === null) return { ok: false, error: 'obyekt emas' };
  const r = raw as Record<string, unknown>;
  const kind = r.kind ?? 'FIGURAL';
  if (!IQ_ITEM_KINDS.includes(kind as IqItemKind)) return { ok: false, error: 'kind' };
  return kind === 'FIGURAL' ? parseFigural(r) : parseText(r, kind as TextKind);
}

/** Aralash formalardagi rasmli savollar: forma → externalId'lar (mixed_forms.json). */
export type MixedFormsMap = Readonly<Record<string, readonly string[]>>;

/** Rasmli savollarga aralash formalarni qo'shadi (yangi obyektlar; manba o'zgarmaydi). */
export function withMixedForms(items: readonly IqItemData[], mixed: MixedFormsMap): IqItemData[] {
  const extra = new Map<string, string[]>();
  for (const [form, ids] of Object.entries(mixed)) {
    for (const id of ids) extra.set(id, [...(extra.get(id) ?? []), form]);
  }
  return items.map((it) => {
    const add = (extra.get(it.externalId) ?? []).filter((f) => !it.forms.includes(f));
    return add.length ? { ...it, forms: [...it.forms, ...add] } : it;
  });
}

function mixedErrors(items: readonly IqItemData[], mixed: MixedFormsMap): string[] {
  const byId = new Map(items.map((it) => [it.externalId, it]));
  return Object.entries(mixed).flatMap(([form, ids]) => [
    ...(FORM.test(form) && !CLASSIC_FORMS.some((f) => form.endsWith(f)) ? [] : [`aralash forma: ${form}`]),
    ...ids.flatMap((id) => {
      const it = byId.get(id);
      if (!it) return [`${form}: ${id} topilmadi`];
      return it.kind === 'FIGURAL' ? [] : [`${form}: ${id} rasmli emas`];
    }),
  ]);
}

/**
 * Butun bank: xatolar ro'yxati + har forma aniq `formSize` savol. A/B har doim
 * shart; biror C/D forma bo'lsa — hamma darajada C va D ham shart.
 */
export function parseIqBank(
  raw: unknown,
  formSize: number,
  mixed: MixedFormsMap = {},
): { items: IqItemData[]; errors: string[] } {
  if (!Array.isArray(raw)) return { items: [], errors: ['massiv emas'] };
  const parsed: IqItemData[] = [];
  const errors: string[] = [];
  const seen = new Set<string>();
  raw.forEach((r, i) => {
    const p = parseIqItem(r);
    if (!p.ok) return errors.push(`[${i}]: ${p.error}`);
    if (seen.has(p.value.externalId)) return errors.push(`${p.value.externalId}: dublikat`);
    seen.add(p.value.externalId);
    parsed.push(p.value);
  });
  errors.push(...mixedErrors(parsed, mixed));
  const items = withMixedForms(parsed, mixed);
  const forms = new Map<string, number>();
  for (const it of items) for (const f of it.forms) forms.set(f, (forms.get(f) ?? 0) + 1);
  const hasMixed = [...forms.keys()].some((f) => !CLASSIC_FORMS.some((c) => f.endsWith(c)));
  const required = IQ_LEVELS.flatMap((level) => (hasMixed ? IQ_FORMS : CLASSIC_FORMS).map((f) => `L${level}${f}`));
  for (const f of required) {
    if (forms.get(f) !== formSize) errors.push(`${f}: ${forms.get(f) ?? 0} savol (${formSize} kerak)`);
  }
  return { items, errors };
}
