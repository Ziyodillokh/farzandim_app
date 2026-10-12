import { expect, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

/**
 * Psixologik testlar: kutubxona → "Mantiqiy fikrlash" → 7-A ga tayinlash →
 * demo simulyatsiya → natijalar jadvalida qatorlar bor.
 */
test('psixolog: shablonni 7-A ga tayinlaydi, simulyatsiya natijalari ko\'rinadi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'psixolog', 'Psixolog2026');

  // Kutubxona
  await page.goto(url('/assessments'));
  await expect(page.locator('main h1').first()).toHaveText('Psixologik testlar');
  const card = page.getByTestId('test-card-tpl-logic');
  await expect(card).toBeVisible();

  // tpl-logic sahifasi
  await card.getByRole('link', { name: 'Mantiqiy fikrlash' }).click();
  await page.waitForURL(/\/assessments\/view\/?\?id=tpl-logic/);
  await expect(page.locator('main h1').first()).toContainText('Mantiqiy fikrlash');
  await expect(page.getByText('IQ shkalasidagi kognitiv indeks').first()).toBeVisible();

  // Tayinlash oynasi (test oldindan tanlangan)
  await page.getByTestId('view-assign').click();
  const dialog = page.getByRole('dialog');
  await expect(dialog).toBeVisible();
  await expect(dialog.getByTestId('assign-test')).toContainText('Mantiqiy fikrlash');
  await dialog.getByRole('checkbox', { name: '7-A' }).click();
  await dialog.getByTestId('assign-consent').click();
  await dialog.getByTestId('assign-submit').click();
  await expect(dialog).toBeHidden();
  await expect(page.getByText('Test tayinlandi')).toBeVisible();

  // Tayinlashlar: yangi qator (faqat 7-A) — demo simulyatsiya
  await page.getByRole('tab', { name: 'Tayinlashlar' }).click();
  const row = page
    .locator('tbody tr')
    .filter({ hasText: 'Mantiqiy fikrlash' })
    .filter({ hasNotText: '7-B' });
  await expect(row).toHaveCount(1);
  await row.locator('[data-testid^="simulate-"]').click();
  await expect(page.getByText(/Demo: \d+ ta natija qo'shildi/)).toBeVisible();
  await expect(row.getByText(/^[1-9]\d* \/ \d+$/)).toBeVisible();

  // Natijalar: jadvalda qatorlar bor
  await page.goto(url('/assessments?tab=results&test=tpl-logic'));
  await expect(page.getByTestId('results-test')).toContainText('Mantiqiy fikrlash');
  const firstLink = page.locator('tbody tr').first().getByRole('link');
  await expect(firstLink).toHaveAttribute('href', /\/students\/view\/?\?id=.+&tab=development/);
  expect(await page.locator('tbody tr a[href*="tab=development"]').count()).toBeGreaterThan(0);

  expect(errors).toEqual([]);
});
