import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { expect, type Page } from '@playwright/test';

export const BASE = '/school';

/** basePath + oxirida `/` (statik eksport, trailingSlash). */
export function url(path: string): string {
  const [p, q] = path.split('?');
  const clean = p === '/' ? '/' : `${p}/`;
  return `${BASE}${clean}${q ? `?${q}` : ''}`;
}

/** Konsol xatolari va ushlanmagan istisnolarni yig'adi. */
export function trackErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(`${page.url()} → ${msg.text()}`);
  });
  page.on('pageerror', (err) => errors.push(`${page.url()} → ${err.message}`));
  return errors;
}

export async function login(page: Page, username: string, password: string): Promise<void> {
  await page.goto(url('/login'));
  await page.locator('#username').fill(username);
  await page.locator('#password').fill(password);
  await page.locator('button[type="submit"]').click();
  await page.waitForURL(/\/school\/dashboard\/?$/);
  await expect(page.locator('main h1').first()).toBeVisible();
}

export type RouteInfo = { path: string; perm: string; external: boolean };

/**
 * Marshrutlar manifestidan yo'l va ruxsatlarni o'qiydi (manifest lucide ikonlarini
 * import qiladi — Node'da yuklamaslik uchun matn sifatida tahlil qilinadi).
 */
export function readRoutes(): RouteInfo[] {
  const text = readFileSync(resolve(__dirname, '../src/auth/route-manifest.ts'), 'utf8');
  const routes: RouteInfo[] = [];
  for (const m of text.matchAll(/\{\s*path:\s*'([^']+)',\s*perm:\s*'([^']+)'([^}]*)\}/g)) {
    routes.push({ path: m[1] ?? '', perm: m[2] ?? '', external: /external:\s*true/.test(m[3] ?? '') });
  }
  return routes;
}
