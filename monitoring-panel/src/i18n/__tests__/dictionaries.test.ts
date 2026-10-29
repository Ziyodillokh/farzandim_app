import { describe, expect, it } from 'vitest';

import { ru } from '../ru';
import { uz } from '../uz';

type Tree = { [key: string]: string | Tree };

function flatten(tree: Tree, prefix = ''): Array<[string, string]> {
  return Object.entries(tree).flatMap(([k, v]) => (typeof v === 'string' ? [[`${prefix}${k}`, v] as [string, string]] : flatten(v, `${prefix}${k}.`)));
}

const UZ = flatten(uz as unknown as Tree);
const RU = new Map(flatten(ru as unknown as Tree));
const placeholders = (s: string) => [...s.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort();

/** Bolalar haqida stigma yoki tashxis ohangidagi so'zlar — panelda bo'lmasligi kerak. */
const BANNED = [
  /tashxis qo'yil/i,
  /\bkasal/i,
  /aqli past/i,
  /aqliy zaif/i,
  /depressiya/i,
  /nuqsonli/i,
  /muammoli bola/i,
  /xavfli bola/i,
  /zaif bola/i,
  /диагноз постав/i,
  /\bбольн/i,
  /умственно отстал/i,
  /депресс/i,
  /проблемн\w* ребён/i,
  /трудн\w* ребён/i,
];

describe('lug\'atlar', () => {
  it('uz va ru kalitlari bir xil', () => {
    expect([...RU.keys()].sort()).toEqual(UZ.map(([k]) => k).sort());
  });

  it('o\'zgaruvchilar ({...}) har ikki tilda bir xil', () => {
    for (const [key, text] of UZ) expect(placeholders(RU.get(key) ?? ''), key).toEqual(placeholders(text));
  });

  it('bo\'sh matn yo\'q', () => {
    for (const [key, text] of UZ) expect(text.trim(), key).not.toBe('');
    for (const [key, text] of RU) expect(text.trim(), key).not.toBe('');
  });

  it('stigma yoki tashxis so\'zlari ishlatilmaydi', () => {
    for (const [key, text] of [...UZ, ...RU]) {
      for (const re of BANNED) expect(re.test(text), `${key}: "${text}"`).toBe(false);
    }
  });

  it('o\'zbekcha matnda noto\'g\'ri tutuq belgisi yo\'q (o` yoki o‘ aralashmasin)', () => {
    for (const [key, text] of UZ) expect(/[`‘]/.test(text), key).toBe(false);
  });
});
