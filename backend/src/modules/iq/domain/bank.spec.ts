import { buildIqBankRows, stableIqId } from '../../../../scripts/iq/build-bank-migration';
import { parseIqItem } from './bank';
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

describe('IQ savollar banki', () => {
  it("to'g'ri savol o'tadi", () => {
    expect(parseIqItem(item()).ok).toBe(true);
  });

  it.each([
    ["javob variantlarda yo'q", { answer: 'G' }],
    ['5 ta variant', { options: ['A', 'B', 'C', 'D', 'E'].map((key) => ({ key, svg })) }],
    ['skriptli svg', { gridSvg: '<svg onload="x()"><script>alert(1)</script></svg>' }],
    ['tashqi havola', { gridSvg: '<svg><image href="https://x.y/a.png"/></svg>' }],
    ["noto'g'ri forma", { forms: ['L1C'] }],
    ['b chegaradan tashqari', { b: 9 }],
  ])('rad etiladi: %s', (_name, patch) => {
    expect(parseIqItem(item(patch)).ok).toBe(false);
  });

  it('haqiqiy bank: 216 savol, har formada 20 ta, id barqaror', () => {
    const rows = buildIqBankRows();
    expect(rows).toHaveLength(216);
    const forms = new Map<string, number>();
    for (const r of rows) for (const f of r.forms) forms.set(f, (forms.get(f) ?? 0) + 1);
    expect(forms.size).toBe(10);
    expect([...forms.values()].every((n) => n === FORM_SIZE)).toBe(true);
    expect(rows[0].id).toBe(stableIqId(rows[0].externalId));
    // Anchor: qo'shni darajalar 3+3 umumiy savol.
    expect(rows.filter((r) => r.forms.length === 2)).toHaveLength(4 * 6);
  });
});
