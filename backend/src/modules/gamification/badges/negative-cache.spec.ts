import { NegativeCache } from './negative-cache';

describe('NegativeCache', () => {
  let now: number;
  const cache = (ttl = 1000, max = 3) => new NegativeCache(ttl, max, () => now);

  beforeEach(() => {
    now = 10_000;
  });

  it('TTL davomida "yo\'q" eslab qolinadi, undan keyin unutiladi', () => {
    const c = cache();
    c.add('a');
    expect(c.has('a')).toBe(true);
    now += 999;
    expect(c.has('a')).toBe(true);
    now += 1;
    expect(c.has('a')).toBe(false);
    expect(c.size).toBe(0);
  });

  it('boshqa kalitlar bir-biriga ta\'sir qilmaydi', () => {
    const c = cache();
    c.add('a');
    expect(c.has('b')).toBe(false);
  });

  it('qayta qo\'shish TTL ni yangilaydi', () => {
    const c = cache();
    c.add('a');
    now += 900;
    c.add('a');
    now += 900;
    expect(c.has('a')).toBe(true);
  });

  it('delete — darhol unutadi', () => {
    const c = cache();
    c.add('a');
    c.delete('a');
    expect(c.has('a')).toBe(false);
  });

  it('chegaradan oshganda avval muddati o\'tganlar, so\'ng eng eskilari chiqariladi', () => {
    const c = cache(1000, 3);
    c.add('a');
    now += 100;
    c.add('b');
    now += 100;
    c.add('c');
    now += 100;
    c.add('d'); // to'ldi, hech biri muddati o'tmagan → eng eskisi (a) chiqadi
    expect(c.size).toBe(3);
    expect(c.has('a')).toBe(false);
    expect(['b', 'c', 'd'].every((k) => c.has(k))).toBe(true);

    now += 900; // b, c muddati o'tdi (b: 200+1000 ≤ ...) — d yashaydi
    c.add('e');
    expect(c.size).toBeLessThanOrEqual(3);
    expect(c.has('e')).toBe(true);
    expect(c.has('d')).toBe(true);
  });

  it('o\'lchami hech qachon chegaradan oshmaydi', () => {
    const c = cache(1_000_000, 50);
    for (let i = 0; i < 500; i++) c.add(`k${i}`);
    expect(c.size).toBe(50);
    expect(c.has('k499')).toBe(true);
    expect(c.has('k0')).toBe(false);
  });
});
