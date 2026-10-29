import { expect, test } from '@playwright/test';

import { DEMO_ACCOUNTS } from '../src/auth/demo-accounts';
import { type Permission, roleHas } from '../src/auth/permissions';
import { FORBIDDEN, login, readRoutes, trackErrors, url } from './helpers';

const ROUTES = readRoutes();

test('manifestdan marshrutlar o\'qildi', () => {
  expect(ROUTES.length).toBe(15);
});

for (const account of DEMO_ACCOUNTS) {
  test(`${account.username}: har sahifa ochiladi yoki "ruxsat yo'q", konsol xatosiz`, async ({ page }) => {
    const errors = trackErrors(page);
    await login(page, account.username, account.password);
    const own = account.regionId ?? 'UZ-SA';
    const queries: Record<string, string> = { '/regions/view': `id=${own}`, '/reports/print': `id=${account.regionId ?? 'UZ'}` };

    for (const route of ROUTES) {
      const query = queries[route.path];
      await page.goto(url(query ? `${route.path}?${query}` : route.path));
      const heading = page.locator('main h1').first();
      await expect(heading, route.path).toBeAttached();
      if (roleHas(account.role, route.perm as Permission)) {
        await expect(heading, route.path).not.toHaveText(FORBIDDEN);
      } else {
        await expect(heading, route.path).toHaveText(FORBIDDEN);
      }
    }
    expect(errors).toEqual([]);
  });
}
