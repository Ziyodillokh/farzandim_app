import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { expect, type Page } from '@playwright/test';

export const BASE = '/monitoring';
export const FORBIDDEN = "Ruxsat yo'q";

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
  await page.waitForURL(/\/monitoring\/dashboard\/?$/);
  await expect(page.locator('main h1').first()).toBeVisible();
}

export type RouteInfo = { path: string; perm: string };

/** Manifestdan yo'l va ruxsatlar (lucide ikonlari Node'da yuklanmasin — matn sifatida). */
export function readRoutes(): RouteInfo[] {
  const text = readFileSync(resolve(__dirname, '../src/auth/route-manifest.ts'), 'utf8');
  return [...text.matchAll(/\{\s*path:\s*'([^']+)',\s*perm:\s*'([^']+)'/g)].map((m) => ({ path: m[1] ?? '', perm: m[2] ?? '' }));
}
