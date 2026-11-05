import { expect, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

test('direktor: e\'lonni o\'quvchilarga ham ko\'rsatadi; ota-onalar auditoriyasida katak yo\'q', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'direktor', 'Direktor2026');

  // Seeddagi e'lonlarda belgi bor.
  await page.goto(url('/messages'));
  await expect(page.getByText('Oʻquvchilar ham koʻradi').first()).toBeVisible();

  await page.goto(url('/messages/new'));
  const checkbox = page.getByRole('checkbox', { name: /Parvoz Growth ilovasida/ });
  await expect(checkbox).toBeVisible();
  await expect(checkbox).not.toBeChecked();

  // Tanlangan ota-onalar — katak ko'rinmaydi; maktabga qaytsa — yana ko'rinadi.
  await page.getByRole('radio', { name: /Tanlangan ota-onalar/ }).click();
  await expect(checkbox).toHaveCount(0);
  await page.getByRole('radio', { name: /Butun maktab/ }).click();
  await expect(checkbox).toBeVisible();

  await page.getByLabel('Sarlavha').fill('Kitob ko\'rgazmasi');
  await page.getByLabel('Matn', { exact: true }).fill('Juma kuni kutubxonada kitob ko\'rgazmasi bo\'ladi.');
  await checkbox.check();
  await page.getByRole('button', { name: 'Yuborish' }).click();
  await expect(page).toHaveURL(/\/school\/messages\/?$/);

  const card = page.getByRole('button').filter({ hasText: 'Kitob ko\'rgazmasi' });
  await expect(card).toContainText('Oʻquvchilar ham koʻradi');
  expect(errors).toEqual([]);
});
