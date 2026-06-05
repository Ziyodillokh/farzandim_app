// Light mode refactor yordamchisi: AppColors GETTER ranglari ishlatilgan
// `const` widget/expression'lardan `const` keyword'ini olib tashlaydi.
// `AppColors.onPrimary` HAQIQIY const — uni o'z ichiga olgan const'lar
// buzilmaydi, shuning uchun ular tegmaydi (faqat getter ranglar).
//
// Algoritm: har `const` keyword'i topiladi; uning "boshqargan" ifodasi
// (balanslangan qavslar) AppColors getter rangini o'z ichiga olsa — `const`
// olib tashlanadi (qavs hisobida string/comment'lar e'tiborga olinadi).
//
// Ishga tushirish: node tool/fix_const_appcolors.js lib

const fs = require('fs');
const path = require('path');

const ROOT = 'lib';

// Getter ranglar (onPrimary EMAS — u const).
const GETTERS = [
  'background', 'backgroundTop', 'backgroundBottom', 'surface',
  'surfaceVariant', 'primary', 'primaryDark', 'primaryLight', 'secondary',
  'secondaryDark', 'textPrimary', 'textSecondary', 'textTertiary',
  'success', 'warning', 'error', 'info', 'border', 'divider',
];
const GETTER_RE = new RegExp('AppColors\\.(' + GETTERS.join('|') + ')\\b');

function listDart(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) listDart(p, out);
    else if (e.name.endsWith('.dart')) out.push(p);
  }
  return out;
}

const isWord = (c) => /[A-Za-z0-9_$]/.test(c);

// idx — `(` `[` yoki `{` pozitsiyasi. Balanslangan yopilishidan keyingi
// indeksni qaytaradi (string/comment'larni e'tiborsiz qoldirib).
function matchBracket(src, idx) {
  const n = src.length;
  const open = src[idx];
  const close = open === '(' ? ')' : open === '[' ? ']' : '}';
  let depth = 0;
  let i = idx;
  while (i < n) {
    const c = src[i];
    if (c === '/' && src[i + 1] === '/') { while (i < n && src[i] !== '\n') i++; continue; }
    if (c === '/' && src[i + 1] === '*') { i += 2; while (i < n && !(src[i] === '*' && src[i + 1] === '/')) i++; i += 2; continue; }
    if (c === '"' || c === "'") {
      const q = c;
      if (src[i + 1] === q && src[i + 2] === q) { i += 3; while (i < n && !(src[i] === q && src[i + 1] === q && src[i + 2] === q)) { if (src[i] === '\\') i++; i++; } i += 3; continue; }
      i++; while (i < n && src[i] !== q) { if (src[i] === '\\') i++; i++; } i++; continue;
    }
    if (c === open) depth++;
    else if (c === close) { depth--; if (depth === 0) return i + 1; }
    i++;
  }
  return idx;
}

// `const` keyword'idan keyingi ifodaning oxiri (constructor(...) / [...] /
// {...} / `VAR = expr;`).
function governedEnd(src, after) {
  const n = src.length;
  let i = after;
  while (i < n && /\s/.test(src[i])) i++;
  if (src[i] === '(' || src[i] === '[' || src[i] === '{') return matchBracket(src, i);
  // Type / identifier (generics bilan): Foo, Foo.named, Foo<Bar>
  while (i < n && /[A-Za-z0-9_.<>, ]/.test(src[i]) && src[i] !== '\n') i++;
  while (i < n && /\s/.test(src[i])) i++;
  if (src[i] === '(' || src[i] === '[' || src[i] === '{') return matchBracket(src, i);
  // `const TYPE name = expr;` — ';' gacha
  let s = after;
  while (s < n && src[s] !== ';' && src[s] !== '\n') s++;
  return s;
}

function process(src) {
  const n = src.length;
  const removals = [];
  let i = 0;
  while (i < n) {
    const c = src[i];
    if (c === '/' && src[i + 1] === '/') { while (i < n && src[i] !== '\n') i++; continue; }
    if (c === '/' && src[i + 1] === '*') { i += 2; while (i < n && !(src[i] === '*' && src[i + 1] === '/')) i++; i += 2; continue; }
    if (c === '"' || c === "'") {
      const q = c;
      if (src[i + 1] === q && src[i + 2] === q) { i += 3; while (i < n && !(src[i] === q && src[i + 1] === q && src[i + 2] === q)) { if (src[i] === '\\') i++; i++; } i += 3; continue; }
      i++; while (i < n && src[i] !== q) { if (src[i] === '\\') i++; i++; } i++; continue;
    }
    if (isWord(c)) {
      let j = i; while (j < n && isWord(src[j])) j++;
      const word = src.slice(i, j);
      const prev = i > 0 ? src[i - 1] : '';
      if (word === 'const' && !isWord(prev)) {
        const end = governedEnd(src, j);
        if (end > j) {
          const exprText = src.slice(j, end);
          if (GETTER_RE.test(exprText)) {
            // `const` + keyingi bo'sh joyni olib tashlaymiz.
            let k = j;
            while (k < n && /[ \t]/.test(src[k])) k++;
            removals.push([i, k]);
          }
        }
      }
      i = j; continue;
    }
    i++;
  }
  if (!removals.length) return null;
  // Orqadan oldinga qo'llaymiz.
  removals.sort((a, b) => b[0] - a[0]);
  let out = src;
  for (const [s, e] of removals) out = out.slice(0, s) + out.slice(e);
  return { out, count: removals.length };
}

let files = 0, total = 0;
for (const f of listDart(ROOT)) {
  const src = fs.readFileSync(f, 'utf8');
  const r = process(src);
  if (r) { fs.writeFileSync(f, r.out); files++; total += r.count; }
}
console.log(`Tuzatildi: ${files} fayl, ${total} ta const olib tashlandi.`);
