import { expect, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

test('noto\'g\'ri parol xato ko\'rsatadi, to\'g\'risi bosh sahifaga olib kiradi', async ({ page }) => {
  const errors = trackErrors(page);
  await page.goto(url('/login'));
  await page.locator('#username').fill('direktor');
  await page.locator('#password').fill('noto-g-ri');
  await page.locator('button[type="submit"]').click();
  await expect(page).toHaveURL(/\/login\/?$/);
  await expect(page.locator('[role="alert"], .text-destructive').first()).toBeVisible();

  await login(page, 'direktor', 'Direktor2026');
  await expect(page.getByRole('heading', { level: 1 }).first()).toContainText(/Xayrli/);
  expect(errors).toEqual([]);
});

test('kirmagan foydalanuvchi himoyalangan sahifadan loginga qaytariladi', async ({ page }) => {
  await page.goto(url('/students'));
  await page.waitForURL(/\/school\/login\/?/);
});

test('til almashtirish: rus tilida menyu', async ({ page }) => {
  await login(page, 'admin', 'Admin2026');
  await page.getByRole('button', { name: /^RU$/ }).first().click();
  await expect(page.locator('aside')).toContainText('Главная');
  await page.reload();
  await expect(page.locator('aside')).toContainText('Главная');
});
