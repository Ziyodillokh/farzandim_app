#!/usr/bin/env node
/**
 * Vizual QA: demo hisob bilan kirib, sahifalarni suratga oladi (yorug'/qorong'i, bir necha kenglik).
 *
 *   node scripts/shots.mjs [--base http://127.0.0.1:4400] [--users direktor,sinf7a]
 *     [--themes light,dark] [--widths 1440,390] [--routes /dashboard,/students|all]
 *     [--out test-results/shots] [--full] [--locale uz|ru]
 *
 * Natija: <out>/<theme>/<width>/<user>__<route>.png va <out>/index.html (contact sheet).
 * Ruxsat yo'q sahifalar saqlanmaydi.
 */
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium } from '@playwright/test';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const PASSWORDS = { direktor: 'Direktor2026', admin: 'Admin2026', sinf7a: 'Sinf2026', psixolog: 'Psixolog2026', navbatchi: 'Navbatchi2026' };
const FORBIDDEN = /Ruxsat yo'q|Нет доступа/;
const HEIGHT = { 1440: 900, 1024: 768, 390: 844 };

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 && process.argv[i + 1] && !process.argv[i + 1].startsWith('--') ? process.argv[i + 1] : fallback;
}
const flag = (name) => process.argv.includes(`--${name}`);

const base = arg('base', 'http://127.0.0.1:4400').replace(/\/$/, '');
const users = arg('users', 'direktor').split(',');
const themes = arg('themes', 'light,dark').split(',');
const widths = arg('widths', '1440,390').split(',').map(Number);
const out = resolve(ROOT, arg('out', 'test-results/shots'));
const full = flag('full');
const locale = arg('locale', 'uz');

function manifestRoutes() {
  const text = readFileSync(join(ROOT, 'src/auth/route-manifest.ts'), 'utf8');
  return [...text.matchAll(/\{\s*path:\s*'([^']+)',\s*perm:\s*'[^']+'([^}]*)\}/g)]
    .filter((m) => !/external:\s*true/.test(m[2] ?? ''))
    .map((m) => m[1]);
}
const routeArg = arg('routes', 'all');
const routes = routeArg === 'all' ? manifestRoutes() : routeArg.split(',');

const url = (path) => {
  const [p, q] = path.split('?');
  return `${base}/school${p === '/' ? '/' : `${p}/`}${q ? `?${q}` : ''}`;
};

async function detailQuery(page, path) {
  const ids = await page.evaluate(() => {
    const raw = localStorage.getItem('parvoz-school:db:v1');
    const t = raw ? JSON.parse(raw).tables : null;
    return { student: t?.students.find((s) => s.classId === 'cls-7a')?.id ?? 'stu-1', care: t?.careRequests[0]?.id ?? 'care-1' };
  });
  const map = {
    '/students/view': `id=${ids.student}`,
    '/classes/view': 'id=cls-7a',
    '/attendance/class': 'id=cls-7a',
    '/care/requests/view': `id=${ids.care}`,
    '/reports/print': 'month=2026-09',
    '/assessments/view': 'id=tpl-logic',
  };
  return map[path];
}

const browser = await chromium.launch();
const saved = [];
const errors = [];
for (const theme of themes) {
  for (const width of widths) {
    for (const user of users) {
      const context = await browser.newContext({ viewport: { width, height: HEIGHT[width] ?? 900 }, deviceScaleFactor: 1 });
      await context.addInitScript(
        ([t, l]) => {
          try {
            localStorage.setItem('theme', t);
            localStorage.setItem('parvoz-school:locale', JSON.stringify(l));
          } catch {
            /* ignore */
          }
        },
        [theme, locale],
      );
      const page = await context.newPage();
      page.on('console', (m) => m.type() === 'error' && errors.push(`${user} ${page.url()} → ${m.text().slice(0, 200)}`));
      page.on('pageerror', (e) => errors.push(`${user} ${page.url()} → ${String(e).slice(0, 200)}`));
      const dir = join(out, theme, String(width));
      mkdirSync(dir, { recursive: true });

      await page.goto(url('/login'), { waitUntil: 'networkidle', timeout: 120_000 });
      await page.waitForTimeout(600);
      const loginShot = join(dir, `${user}__login.png`);
      await page.screenshot({ path: loginShot, fullPage: full });
      saved.push(loginShot);
      await page.locator('#username').fill(user);
      await page.locator('#password').fill(PASSWORDS[user] ?? '');
      await page.locator('button[type="submit"]').click();
      await page.waitForURL(/\/dashboard\/?$/, { timeout: 120_000 });

      for (const route of routes) {
        const query = await detailQuery(page, route);
        await page.goto(url(query ? `${route}?${query}` : route), { timeout: 120_000 });
        await page.locator('main h1').first().waitFor({ timeout: 60_000 }).catch(() => undefined);
        await page.waitForTimeout(1200);
        const heading = (await page.locator('main h1').first().textContent().catch(() => '')) ?? '';
        if (FORBIDDEN.test(heading)) continue;
        const file = join(dir, `${user}__${route.replace(/^\//, '').replace(/\//g, '_') || 'root'}.png`);
        await page.screenshot({ path: file, fullPage: full });
        saved.push(file);
      }
      await context.close();
    }
  }
}
await browser.close();

const cards = saved
  .map((f) => relative(out, f))
  .map((f) => `<figure><img src="${f}" loading="lazy"><figcaption>${f}</figcaption></figure>`)
  .join('\n');
writeFileSync(
  join(out, 'index.html'),
  `<!doctype html><meta charset="utf-8"><title>shots</title><style>body{font:13px system-ui;margin:16px;display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:16px}img{width:100%;border:1px solid #ddd}figure{margin:0}</style>${cards}`,
);
console.log(`saved ${saved.length} shots → ${relative(ROOT, out)}`);
if (errors.length) console.log(`console errors (${errors.length}):\n${[...new Set(errors)].slice(0, 20).join('\n')}`);
