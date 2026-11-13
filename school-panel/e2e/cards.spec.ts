import { expect, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

/** Ssenariy soati: dushanba 07:45 — 1-smena boshlanishidan oldin, kirish ochiq. */
const SCENARIO = { mode: 'SCENARIO', speed: 1, scenarioDate: '2026-10-12', scenarioStartMinute: 7 * 60 + 45, realStartedAt: 0, epoch: 21 };
const SHOTS = process.env.SHOTS_DIR;

test('kiosk: demo karta tegishi kirishni qayd etadi va NFC qatori ko\'rinadi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'navbatchi', 'Navbatchi2026');
  await page.evaluate((clock) => localStorage.setItem('parvoz-school:clock', JSON.stringify({ ...clock, realStartedAt: Date.now() })), SCENARIO);

  await page.goto(url('/kiosk'));
  await expect(page.getByText(/NFC karta|Bu qurilmada NFC yo'q/)).toBeVisible();
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/kiosk-nfc.png` });
  await page.getByRole('button', { name: 'Demo: karta tegizish' }).click();

  const result = page.getByRole('alertdialog');
  await expect(result).toContainText(/Xush kelibsiz|Kechikdingiz|Allaqachon/);
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/kiosk-card-result.png` });
  expect(errors).toEqual([]);
});

test('kartalar: ro\'yxat, qo\'lda biriktirish va tegishlar jurnali', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'direktor', 'Direktor2026');
  await page.goto(url('/cards'));
  await expect(page.getByRole('heading', { name: 'NFC kartalar' })).toBeVisible();
  await expect(page.getByText('K-000001')).toBeVisible();
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/cards-list.png` });

  await page.getByRole('button', { name: 'Karta biriktirish' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByPlaceholder("Ism yoki kod bo'yicha qidiring…").fill('Ali');
  await dialog.locator('button').filter({ hasText: 'Ali' }).first().click();
  await dialog.getByLabel('Karta seriya raqami (UID)').fill('04:aa:bb:cc:dd:ee:77');
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/cards-assign.png` });
  await dialog.getByRole('button', { name: 'Biriktirish' }).click();
  await expect(page.getByText(/biriktirildi/)).toBeVisible();

  await page.getByRole('tab', { name: 'Tegishlar' }).click();
  await expect(page.getByText(/Tegishlar hali yo'q|Kirdi|Takroriy/).first()).toBeVisible();
  expect(errors).toEqual([]);
});
