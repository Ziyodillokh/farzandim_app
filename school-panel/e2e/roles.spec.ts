import { expect, type Page, test } from '@playwright/test';

import { DEMO_ACCOUNTS } from '../src/auth/demo-accounts';
import { type Permission, roleHas } from '../src/auth/permissions';
import { login, readRoutes, trackErrors, url } from './helpers';

const ROUTES = readRoutes();

const FORBIDDEN = "Ruxsat yo'q";

/** Tafsilot sahifalari uchun haqiqiy identifikatorlar (7-A — sinf rahbari doirasida). */
async function detailQueries(page: Page): Promise<Record<string, string>> {
  const studentId = await page.evaluate(() => {
    const raw = localStorage.getItem('parvoz-school:db:v1');
    const db = raw ? (JSON.parse(raw) as { tables: { students: Array<{ id: string; classId: string }> } }) : null;
    return db?.tables.students.find((s) => s.classId === 'cls-7a')?.id ?? 'stu-1';
  });
  return {
    '/students/view': `id=${studentId}`,
    '/classes/view': 'id=cls-7a',
    '/attendance/class': 'id=cls-7a',
    '/care/requests/view': 'id=care-1',
    '/reports/print': 'month=2026-09',
    '/assessments/view': 'id=tpl-logic',
  };
}

test('manifestdan marshrutlar o\'qildi', () => {
  expect(ROUTES.length).toBeGreaterThan(30);
});

for (const account of DEMO_ACCOUNTS) {
  test(`${account.username}: har sahifa ochiladi yoki "ruxsat yo'q" ko'rsatadi, konsol xatosiz`, async ({ page }) => {
    const errors = trackErrors(page);
    await login(page, account.username, account.password);
    const queries = await detailQueries(page);

    for (const route of ROUTES) {
      if (route.external) continue;
      const query = queries[route.path];
      await page.goto(url(query ? `${route.path}?${query}` : route.path));
      const heading = page.locator('main h1').first();
      await expect(heading, route.path).toBeVisible();
      if (roleHas(account.role, route.perm as Permission)) {
        await expect(heading, route.path).not.toHaveText(FORBIDDEN);
      } else {
        await expect(heading, route.path).toHaveText(FORBIDDEN);
      }
    }
    expect(errors).toEqual([]);
  });
}
