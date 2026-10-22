import { buildFiguralRows, buildIqBankRows, readMixedForms, stableIqId } from '../../../../scripts/iq/build-bank-migration';
import { parseIqBank, parseIqItem } from './bank';
import { FORM_SIZE } from './levels';

const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>';
const item = (patch: Record<string, unknown> = {}) => ({
  externalId: 'iq-L1-001',
  level: 1,
  forms: ['L1A'],
  rule: 'count',
  b: -1.2,
  answer: 'C',
  gridSvg: svg,
  options: ['A', 'B', 'C', 'D', 'E', 'F'].map((key) => ({ key, svg })),
  ...patch,
});
const t = (s: string) => ({ uz: s, ru: `${s} ru`, en: `${s} en` });
const textItem = (patch: Record<string, unknown> = {}) => ({
  externalId: 'iq-L2-V01',
  level: 2,
  kind: 'VERBAL',
  forms: ['L2C'],
  rule: 'analogy',
  b: -0.5,
  answer: 'B',
  stem: t('Mushukcha — mushuk, kuchukcha — ?'),
  options: ['A', 'B', 'C', 'D'].map((key, i) => ({ key, text: t(`variant ${i}`) })),
  ...patch,
});

describe('IQ savollar banki', () => {
  it("to'g'ri savol o'tadi", () => {
    expect(parseIqItem(item()).ok).toBe(true);
  });

  it.each([
    ["javob variantlarda yo'q", { answer: 'G' }],
    ['5 ta variant', { options: ['A', 'B', 'C', 'D', 'E'].map((key) => ({ key, svg })) }],
    ['skriptli svg', { gridSvg: '<svg onload="x()"><script>alert(1)</script></svg>' }],
    ['tashqi havola', { gridSvg: '<svg><image href="https://x.y/a.png"/></svg>' }],
    ["noto'g'ri forma", { forms: ['L1E'] }],
    ['matnli tur rasmli id bilan', { kind: 'NUMERIC' }],
    ['b chegaradan tashqari', { b: 9 }],
  ])('rad etiladi: %s', (_name, patch) => {
    expect(parseIqItem(item(patch)).ok).toBe(false);
  });

  it("matnli savol o'tadi (variant 4..6, uch tilda)", () => {
    const parsed = parseIqItem(textItem());
    expect(parsed.ok && parsed.value).toMatchObject({ kind: 'VERBAL', stem: { uz: expect.any(String) } });
  });

  it.each([
    ["ruscha shart yo'q", { stem: { uz: 'a', en: 'b' } }],
    ['3 ta variant', { options: ['A', 'B', 'C'].map((key, i) => ({ key, text: t(`v${i}`) })) }],
    ['takror variant', { options: ['A', 'B', 'C', 'D'].map((key) => ({ key, text: t('bir xil') })) }],
    ['javob variantlarda yo\'q', { answer: 'E' }],
    ['matnli savolda rasm', { gridSvg: svg }],
    ["id turi mos emas", { externalId: 'iq-L2-N01' }],
    ["id darajasi mos emas", { externalId: 'iq-L3-V01' }],
    ["noma'lum tur", { kind: 'MEMORY' }],
    ['rasmli formada', { forms: ['L2A'] }],
    ['boshqa daraja formasida', { forms: ['L3C'] }],
  ])('matnli rad etiladi: %s', (_name, patch) => {
    expect(parseIqItem(textItem(patch)).ok).toBe(false);
  });

  it("aralash forma tarkibi: faqat mavjud rasmli savollar, C/D hamma darajada", () => {
    const fig = item({ forms: [] });
    expect(parseIqBank([fig], 1, { L1C: ['iq-L9-001'] }).errors).toEqual(expect.arrayContaining(['L1C: iq-L9-001 topilmadi']));
    expect(parseIqBank([textItem({ forms: [] })], 1, { L2C: ['iq-L2-V01'] }).errors).toEqual(
      expect.arrayContaining(['L2C: iq-L2-V01 rasmli emas']),
    );
    expect(parseIqBank([fig], 1, { L1A: ['iq-L1-001'] }).errors).toEqual(expect.arrayContaining(['aralash forma: L1A']));
  });

  it('haqiqiy rasmli bank: 216 savol, A/B har formada 20 ta, id barqaror', () => {
    const rows = buildFiguralRows();
    expect(rows).toHaveLength(216);
    const forms = new Map<string, number>();
    for (const r of rows) for (const f of r.forms) forms.set(f, (forms.get(f) ?? 0) + 1);
    expect(forms.size).toBe(10);
    expect([...forms.values()].every((n) => n === FORM_SIZE)).toBe(true);
    expect(rows[0].id).toBe(stableIqId(rows[0].externalId));
    // Anchor: qo'shni darajalar 3+3 umumiy savol.
    expect(rows.filter((r) => r.forms.length === 2)).toHaveLength(4 * 6);
  });

  it("to'liq bank: +120 matnli, C/D = 10 rasm + 4 son + 3 so'z + 3 mantiq, C ⊂ A, D ⊂ B", () => {
    const rows = buildIqBankRows();
    expect(rows).toHaveLength(216 + 120);
    const mixed = readMixedForms();
    for (const level of [1, 2, 3, 4, 5]) {
      for (const [form, source] of [['C', 'A'], ['D', 'B']]) {
        const items = rows.filter((r) => r.forms.includes(`L${level}${form}`));
        const count = (k: string) => items.filter((r) => r.kind === k).length;
        expect([items.length, count('FIGURAL'), count('NUMERIC'), count('VERBAL'), count('LOGIC')]).toEqual([FORM_SIZE, 10, 4, 3, 3]);
        expect(items.filter((r) => r.kind === 'FIGURAL').every((r) => r.forms.includes(`L${level}${source}`))).toBe(true);
        expect(mixed[`L${level}${form}`]).toHaveLength(10);
      }
    }
    // A/B tarkibi o'zgarmagan: to'liq bankdagi rasmli savollar formalaridan C/D olib tashlansa — asl bank.
    const classic = new Map(buildFiguralRows().map((r) => [r.externalId, r.forms]));
    for (const r of rows.filter((x) => x.kind === 'FIGURAL')) {
      expect(r.forms.filter((f) => /[AB]$/.test(f))).toEqual(classic.get(r.externalId));
    }
  });
});
