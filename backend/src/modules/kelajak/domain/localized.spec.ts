import { parseL } from './localized';

describe('kelajak localized', () => {
  it('satr → {uz}; ru/en ixtiyoriy, bo\'sh satr tashlanadi', () => {
    expect(parseL('  Salom ', 'text', 10)).toEqual({ ok: true, value: { uz: 'Salom' } });
    expect(parseL({ uz: 'a', ru: '', en: 'b' }, 'text', 10)).toEqual({ ok: true, value: { uz: 'a', en: 'b' } });
  });

  it.each([
    [{ ru: 'x' }, /text\.uz/],
    [{ uz: '   ' }, /text\.uz/],
    [{ uz: 'a', ru: 5 }, /text\.ru/],
    [{ uz: 'x'.repeat(11) }, /10/],
    [['a'], /text/],
    [null, /text/],
  ])('noto\'g\'ri: %j', (value, error) => {
    const r = parseL(value, 'text', 10);
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toMatch(error);
  });
});
