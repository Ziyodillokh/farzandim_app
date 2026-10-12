import { expect, test } from '@playwright/test';

import { encodeBrand } from '../src/lib/brand-link';
import { login, url } from './helpers';

test('"Shu maktab uchun havola" yangi brauzerda maktab nomini ko\'rsatadi', async ({ browser }) => {
  const context = await browser.newContext();
  const page = await context.newPage();
  const brand = { name: 'Toshkent shahar 25-maktab', shortName: '25M', city: 'Toshkent', logo: null };
  await page.goto(`${url('/login')}#b=${encodeBrand(brand)}`);
  await expect(page.getByText(brand.name).first()).toBeVisible();
  // Fragment tozalanadi, nom saqlanadi — kirgandan keyin ham shu maktab.
  await expect(page).not.toHaveURL(/#b=/);
  await login(page, 'direktor', 'Direktor2026');
  await expect(page.locator('aside')).toContainText(brand.name.slice(0, 20));
  await context.close();
});
