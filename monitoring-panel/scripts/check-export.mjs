#!/usr/bin/env node
/**
 * Statik eksport tekshiruvi (deploy'dan oldin):
 *  - yo'llarda `[ ] { } % ` va bo'shliq yo'q (server-deploy.sh curl tekshiruvi buzilmasin);
 *  - har marshrutda index.html bor;
 *  - har HTML'da noindex;
 *  - jami hajm < 8 MB.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';

const ROOT = resolve(process.cwd(), 'out');
const MAX_BYTES = 8 * 1024 * 1024;
const BAD = /[[\]{}% ]/;
// Manifestdagi barcha sahifalar + login, bosh sahifa va 404.
const ROUTE_PATHS = [...readFileSync(join(ROOT, '..', 'src/auth/route-manifest.ts'), 'utf8').matchAll(/\{\s*path:\s*'([^']+)',\s*perm:/g)].map((m) => m[1]);
const REQUIRED = ['index.html', 'login/index.html', '404.html', ...ROUTE_PATHS.map((p) => `${p.slice(1)}/index.html`)];
if (ROUTE_PATHS.length < 15) {
  console.error(`❌ check-export: manifestdan marshrutlar o'qilmadi (${ROUTE_PATHS.length})`);
  process.exit(1);
}

const files = [];
(function walk(dir) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) walk(full);
    else files.push(full);
  }
})(ROOT);

const errors = [];
let total = 0;
for (const file of files) {
  const rel = relative(ROOT, file);
  total += statSync(file).size;
  if (BAD.test(rel)) errors.push(`yaroqsiz belgi yo'lda: ${rel}`);
  if (rel.endsWith('.html') && !/<meta name="robots" content="noindex, nofollow"/.test(readFileSync(file, 'utf8'))) {
    errors.push(`noindex yo'q: ${rel}`);
  }
}
for (const required of REQUIRED) {
  if (!files.some((f) => relative(ROOT, f) === required)) errors.push(`topilmadi: ${required}`);
}
if (total > MAX_BYTES) errors.push(`hajm ${(total / 1024 / 1024).toFixed(2)} MB > 8 MB`);

if (errors.length) {
  console.error(`❌ check-export: ${errors.length} xato\n - ${errors.join('\n - ')}`);
  process.exit(1);
}
console.log(`✅ check-export: ${files.length} fayl, ${(total / 1024 / 1024).toFixed(2)} MB`);
