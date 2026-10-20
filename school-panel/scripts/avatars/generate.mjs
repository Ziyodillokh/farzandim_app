#!/usr/bin/env node
/**
 * Xodim portretlari — DiceBear "Notionists" (dizayn: Zoish, CC0 1.0; kod: MIT).
 * Oq-qora chiziqli, katta yoshdagi odamlar — professional panel uchun.
 * Faqat dev vaqtida ishlaydi; natija `public/avatars/*.svg` sifatida commit qilinadi (runtime JS yo'q).
 *
 *   node scripts/avatars/generate.mjs --candidates [--count 54]   # tanlash uchun contact sheet
 *   node scripts/avatars/generate.mjs --write                      # pool.json → public/avatars/
 */
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { createAvatar } from '@dicebear/core';
import * as notionists from '@dicebear/notionists';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const POOL_FILE = join(ROOT, 'scripts/avatars/pool.json');
const OUT_DIR = join(ROOT, 'public/avatars');
const MAX_BYTES = 18_000;

const v = (...n) => n.map((i) => `variant${String(i).padStart(2, '0')}`);

const COMMON = {
  size: 160,
  radius: 0,
  backgroundType: ['gradientLinear'],
  backgroundRotation: [150, 210],
  // Faqat ko'k / havorang / moviy (binafsha yo'q)
  backgroundColor: ['dbeafe', 'bfdbfe', 'e0f2fe', 'bae6fd', 'cffafe', 'dce8ff'],
  bodyIconProbability: 0,
  gestureProbability: 0,
  glassesProbability: 24,
  glasses: v(3, 8, 11), // faqat tiniq ko'zoynaklar (quyosh ko'zoynaklari yo'q)
  body: v(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 16, 17, 19, 20, 21, 23, 25), // naqsh/chaqmoqsiz
};
// Soch variantlari contact sheet'dan saralangan (shlyapa, ro'mol, panklar va bolalarcha bantlar yo'q).
const FEMALE = { ...COMMON, beardProbability: 0, hair: v(2, 4, 8, 10, 23, 28, 36, 37, 39, 41, 45, 48, 57, 58, 61) };
const MALE = {
  ...COMMON,
  beardProbability: 28,
  hair: v(1, 3, 5, 6, 7, 9, 11, 12, 13, 15, 16, 17, 18, 19, 20, 21, 22, 24, 25, 26, 27, 30, 31, 32, 33, 34, 35, 38, 40, 44, 49, 52, 53, 54, 55, 56, 60),
};

function render(seed, gender) {
  const svg = createAvatar(notionists, { seed, ...(gender === 'f' ? FEMALE : MALE) }).toString();
  return svg.replace(/<metadata[\s\S]*?<\/metadata>/g, '').replace(/\s{2,}/g, ' ');
}

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 ? process.argv[i + 1] : fallback;
}

if (process.argv.includes('--candidates')) {
  const count = Number(arg('count', '54'));
  const dir = join(ROOT, 'test-results/avatars');
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  const cells = [];
  for (const g of ['f', 'm']) {
    for (let i = 1; i <= (g === 'f' ? count : Math.round(count * 0.67)); i++) {
      const seed = `${g}-${i}`;
      writeFileSync(join(dir, `${seed}.svg`), render(seed, g));
      cells.push(`<figure><img src="${seed}.svg"><figcaption>${seed}</figcaption></figure>`);
    }
  }
  writeFileSync(
    join(dir, 'index.html'),
    `<!doctype html><meta charset="utf-8"><style>body{margin:12px;font:12px system-ui;display:grid;grid-template-columns:repeat(12,1fr);gap:8px}img{width:100%;border-radius:16px}figure{margin:0;text-align:center}</style>${cells.join('')}`,
  );
  console.log(`candidates → ${dir}/index.html`);
} else if (process.argv.includes('--write')) {
  const pool = JSON.parse(readFileSync(POOL_FILE, 'utf8'));
  rmSync(OUT_DIR, { recursive: true, force: true });
  mkdirSync(OUT_DIR, { recursive: true });
  let total = 0;
  for (const [g, seeds] of [['f', pool.female], ['m', pool.male]]) {
    seeds.forEach((seed, i) => {
      const svg = render(seed, g);
      if (svg.length > MAX_BYTES) throw new Error(`${seed}: ${svg.length} B > ${MAX_BYTES}`);
      writeFileSync(join(OUT_DIR, `${g}-${String(i + 1).padStart(2, '0')}.svg`), svg);
      total += svg.length;
    });
  }
  console.log(`wrote ${pool.female.length + pool.male.length} avatars, ${(total / 1024).toFixed(0)} KB → public/avatars`);
} else {
  console.log('usage: --candidates [--count N] | --write');
}
