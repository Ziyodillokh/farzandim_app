#!/usr/bin/env node
/**
 * `out/` ni prod nginx kabi xizmat qiladi: `/school/...` → out/...,
 * `try_files $uri $uri.html $uri/ =404` (index.html), 404 → out/404.html.
 * Foydalanish: `npm run start` (PORT=4401).
 */
import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize, resolve } from 'node:path';

const ROOT = resolve(process.cwd(), 'out');
const BASE = '/school';
const PORT = Number(process.env.PORT ?? 4401);
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8',
  '.woff2': 'font/woff2',
  '.webmanifest': 'application/manifest+json',
};

function resolveFile(urlPath) {
  const safe = normalize(decodeURIComponent(urlPath)).replace(/^(\.\.[/\\])+/, '');
  const candidates = [join(ROOT, safe), join(ROOT, `${safe}.html`), join(ROOT, safe, 'index.html')];
  return candidates.find((p) => p.startsWith(ROOT) && existsSync(p) && statSync(p).isFile());
}

createServer((req, res) => {
  const url = new URL(req.url ?? '/', 'http://localhost');
  if (url.pathname === '/' || url.pathname === BASE) {
    res.writeHead(301, { Location: `${BASE}/` });
    res.end();
    return;
  }
  if (!url.pathname.startsWith(`${BASE}/`)) {
    res.writeHead(404).end('not found');
    return;
  }
  const file = resolveFile(url.pathname.slice(BASE.length) || '/');
  if (!file) {
    const notFound = join(ROOT, '404.html');
    res.writeHead(404, { 'Content-Type': TYPES['.html'] });
    if (existsSync(notFound)) createReadStream(notFound).pipe(res);
    else res.end('not found');
    return;
  }
  res.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream' });
  createReadStream(file).pipe(res);
}).listen(PORT, () => {
  console.log(`Parvoz School: http://localhost:${PORT}${BASE}/`);
});
