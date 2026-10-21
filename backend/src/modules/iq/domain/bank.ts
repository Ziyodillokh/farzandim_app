// IQ savollar banki JSON'i (prisma/data/iq/items.json, scripts/iq/generator.py)
// — tekshiruv. Migratsiya va kelajakdagi import shu qoidadan o'tadi.

import { IQ_LEVELS, IqLevel, OPTION_KEYS } from './levels';

export interface IqItemData {
  externalId: string;
  level: IqLevel;
  forms: string[];
  rule: string;
  b: number;
  answer: string;
  gridSvg: string;
  options: Array<{ key: string; svg: string }>;
}

const EXTERNAL_ID = /^iq-L[1-5]-\d{3}$/;
const FORM = /^L[1-5][AB]$/;
const SVG = /^<svg [^>]*>[\s\S]*<\/svg>$/;
/** SVG ichida faol kontent bo'lmasin (klient WebView emas, lekin baribir). */
const UNSAFE_SVG = /<script|on\w+=|javascript:|<foreignObject|xlink:href|href=/i;

type Parsed = { ok: true; value: IqItemData } | { ok: false; error: string };

function svgError(svg: unknown): string | null {
  if (typeof svg !== 'string' || !SVG.test(svg)) return 'svg emas';
  return UNSAFE_SVG.test(svg) ? 'xavfli svg' : null;
}

export function parseIqItem(raw: unknown): Parsed {
  if (typeof raw !== 'object' || raw === null) return { ok: false, error: 'obyekt emas' };
  const r = raw as Record<string, unknown>;
  if (typeof r.externalId !== 'string' || !EXTERNAL_ID.test(r.externalId)) return { ok: false, error: 'externalId' };
  if (!IQ_LEVELS.includes(r.level as IqLevel)) return { ok: false, error: 'level' };
  if (!Array.isArray(r.forms) || !r.forms.every((f) => typeof f === 'string' && FORM.test(f))) {
    return { ok: false, error: 'forms' };
  }
  if (typeof r.b !== 'number' || !Number.isFinite(r.b) || Math.abs(r.b) > 6) return { ok: false, error: 'b' };
  if (typeof r.rule !== 'string' || r.rule.length === 0) return { ok: false, error: 'rule' };
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
  if (typeof r.answer !== 'string' || !OPTION_KEYS.includes(r.answer)) return { ok: false, error: 'answer' };
  return {
    ok: true,
    value: {
      externalId: r.externalId,
      level: r.level as IqLevel,
      forms: r.forms as string[],
      rule: r.rule,
      b: r.b,
      answer: r.answer,
      gridSvg: r.gridSvg as string,
      options: options as Array<{ key: string; svg: string }>,
    },
  };
}

/** Butun bank: xatolar ro'yxati + har forma aniq `FORM_SIZE` savol. */
export function parseIqBank(raw: unknown, formSize: number): { items: IqItemData[]; errors: string[] } {
  if (!Array.isArray(raw)) return { items: [], errors: ['massiv emas'] };
  const items: IqItemData[] = [];
  const errors: string[] = [];
  const seen = new Set<string>();
  raw.forEach((r, i) => {
    const parsed = parseIqItem(r);
    if (!parsed.ok) return errors.push(`[${i}]: ${parsed.error}`);
    if (seen.has(parsed.value.externalId)) return errors.push(`${parsed.value.externalId}: dublikat`);
    seen.add(parsed.value.externalId);
    items.push(parsed.value);
  });
  const forms = new Map<string, number>();
  for (const it of items) for (const f of it.forms) forms.set(f, (forms.get(f) ?? 0) + 1);
  for (const level of IQ_LEVELS) {
    for (const f of [`L${level}A`, `L${level}B`]) {
      if (forms.get(f) !== formSize) errors.push(`${f}: ${forms.get(f) ?? 0} savol (${formSize} kerak)`);
    }
  }
  return { items, errors };
}
