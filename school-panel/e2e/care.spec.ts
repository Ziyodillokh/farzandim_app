import { expect, type Page, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

/** Seed'dagi shoshilinch, hali protokolsiz murojaat. */
const URGENT_REQUEST = 'care-1';
const SAFETY_TEXT = 'Xavfsizlik signali: psixolog shoshilinch protokolni ishga tushirdi';

async function logout(page: Page): Promise<void> {
  await page.getByRole('button', { name: 'Hisob menyusi' }).first().click();
  await page.getByRole('menuitem', { name: 'Chiqish' }).click();
  await page.waitForURL(/\/school\/login\/?/);
}

function safetyAlert(page: Page) {
  return page.locator('[data-alert="SAFETY_SIGNAL"]');
}

test('psixolog himoya protokolini ishga tushiradi → direktor va navbatchi xavfsizlik signalini ko\'radi', async ({ page }) => {
  const errors = trackErrors(page);

  // 1) Psixolog: shoshilinch murojaat → himoya protokoli.
  await login(page, 'psixolog', 'Psixolog2026');
  await page.goto(url(`/care/requests/view?id=${URGENT_REQUEST}`));
  await page.getByRole('button', { name: 'Himoya protokolini ishga tushirish' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Ishga tushirish' }).click();
  await expect(page.getByText('Himoya protokoli ishga tushirildi').first()).toBeVisible();
  await expect(page.getByText('Himoya protokoli faol').first()).toBeVisible();
  // Psixologning o'zida signal yo'q (u yuboruvchi).
  await page.goto(url('/dashboard'));
  await expect(page.locator('main h1').first()).toContainText(/Xayrli/);
  await expect(safetyAlert(page)).toHaveCount(0);
  await logout(page);

  // 2) Direktor: bosh sahifada ismsiz signal, havola — /care.
  await login(page, 'direktor', 'Direktor2026');
  const director = safetyAlert(page);
  await expect(director).toBeVisible();
  await expect(director).toContainText(SAFETY_TEXT);
  await expect(director).not.toContainText(/masxara|8-B/i);
  await expect(director.getByRole('link')).toHaveAttribute('href', /\/care\/?$/);
  await director.getByRole('link').click();
  await page.waitForURL(/\/school\/care\/?$/);
  await expect(page.locator('main h1').first()).toHaveText('Bola ovozi');
  await logout(page);

  // 3) Navbatchi: o'sha signal, havola — /attendance.
  await login(page, 'navbatchi', 'Navbatchi2026');
  const duty = safetyAlert(page);
  await expect(duty).toBeVisible();
  await expect(duty.getByRole('link')).toHaveAttribute('href', /\/attendance\/?$/);

  expect(errors).toEqual([]);
});

test('direktor /care sahifasida so\'rovnomalar ro\'yxati va psixolog ish maydonini ko\'radi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'direktor', 'Direktor2026');
  await page.goto(url('/care'));
  await expect(page.getByRole('heading', { name: 'O\'tkazilgan so\'rovnomalar' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Psixolog ish maydoni' })).toBeVisible();
  await expect(page.getByText('Psixologik testlar').first()).toBeVisible();
  await expect(page.locator('main h1')).toHaveCount(1);
  expect(errors).toEqual([]);
});
