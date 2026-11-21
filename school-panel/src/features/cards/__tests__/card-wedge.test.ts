import { describe, expect, it } from 'vitest';

import { normalizeReaderUid } from '@/data/schemas/cards';
import { createWedgeParser, WEDGE_IDLE_MS, wedgeToken, type WedgeToken } from '../card-wedge';

const key = (code: string, key = '') => wedgeToken({ code, key, ctrlKey: false, metaKey: false, altKey: false });
const codeOf = (ch: string) => (/\d/.test(ch) ? `Digit${ch}` : ch === '-' ? 'Minus' : `Key${ch.toUpperCase()}`);
const ENTER = key('Enter', 'Enter');

/** O'qigich yoki odam yozishini taqlid qiladi: `gap` ms oraliq bilan, oxirida (bo'lsa) Enter. */
function type(text: string, { gap, enter = true, start = 1_000 }: { gap: number; enter?: boolean; start?: number }) {
  const cards: string[] = [];
  const parser = createWedgeParser((uid) => cards.push(uid));
  let at = start;
  const tokens: WedgeToken[] = [...text].map((ch) => key(codeOf(ch)));
  for (const token of tokens) {
    parser.key(token, at);
    at += gap;
  }
  const swallowed = enter ? parser.key(ENTER, at - gap + 5) : parser.idle(at + WEDGE_IDLE_MS);
  return { cards, swallowed };
}

describe('USB o\'qigich raqami', () => {
  it('hex o\'zgarmaydi, o\'nlik hex\'ga o\'giriladi', () => {
    expect(normalizeReaderUid('04:de:5f:1e:ac:c0:40')).toBe('04DE5F1EACC040');
    expect(normalizeReaderUid('A1B2C3D4')).toBe('A1B2C3D4');
    expect(normalizeReaderUid('0012345678')).toBe('00BC614E');
    expect(normalizeReaderUid('4294967295')).toBe('FFFFFFFF');
    expect(normalizeReaderUid('1234567890123456')).toBe('0462D53C8ABAC0');
  });

  it('noto\'g\'ri raqamlar rad etiladi', () => {
    expect(normalizeReaderUid('4294967296')).toBeNull();
    expect(normalizeReaderUid('1234')).toBeNull();
    expect(normalizeReaderUid('P-1234')).toBeNull();
    expect(normalizeReaderUid('')).toBeNull();
  });
});

describe('USB o\'qigich oqimi', () => {
  it('tez yozilgan raqam + Enter — karta, Enter yutiladi', () => {
    expect(type('0012345678', { gap: 8 })).toEqual({ cards: ['00BC614E'], swallowed: true });
    expect(type('04de5f1eacc040', { gap: 12 })).toEqual({ cards: ['04DE5F1EACC040'], swallowed: true });
  });

  it('Enter\'siz o\'qigich — kutishdan keyin karta', () => {
    expect(type('A1B2C3D4', { gap: 10, enter: false })).toEqual({ cards: ['A1B2C3D4'], swallowed: true });
  });

  it('odam sekin yozsa — karta emas, Enter o\'tadi', () => {
    expect(type('0012345678', { gap: 120 })).toEqual({ cards: [], swallowed: false });
  });

  it('shtrix-kod skaneri "P-1234" — karta emas', () => {
    expect(type('P-1234', { gap: 8 })).toEqual({ cards: [], swallowed: false });
  });

  it('rus klaviaturasida ham harflar e.code bo\'yicha olinadi', () => {
    expect(wedgeToken({ code: 'KeyA', key: 'ф', ctrlKey: false, metaKey: false, altKey: false })).toEqual({ kind: 'char', ch: 'A' });
    expect(wedgeToken({ code: 'Numpad7', key: '7', ctrlKey: false, metaKey: false, altKey: false })).toEqual({ kind: 'char', ch: '7' });
    expect(wedgeToken({ code: 'ShiftLeft', key: 'Shift', ctrlKey: false, metaKey: false, altKey: false })).toEqual({ kind: 'ignore' });
    expect(wedgeToken({ code: 'KeyC', key: 'c', ctrlKey: true, metaKey: false, altKey: false })).toEqual({ kind: 'reset' });
  });

  it('odam yozgan raqamdan keyin kelgan karta alohida o\'qiladi', () => {
    const cards: string[] = [];
    const parser = createWedgeParser((uid) => cards.push(uid));
    parser.key(key('Digit1'), 0);
    parser.key(key('Digit2'), 300);
    let at = 900;
    for (const ch of 'A1B2C3D4') {
      parser.key(key(codeOf(ch)), at);
      at += 6;
    }
    expect(parser.key(ENTER, at)).toBe(true);
    expect(cards).toEqual(['A1B2C3D4']);
  });
});
