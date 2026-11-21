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
  await expect(page.getByText(/NFC karta|Kartani o'qigichga tegizing/)).toBeVisible();
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
  await expect(page.getByText(/^\d{5} \d{5}$/).first()).toBeVisible();
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

test('karta partiyasi: raqam berish va ketma-ket biriktirish (USB o\'qigich)', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'direktor', 'Direktor2026');
  await page.goto(url('/cards'));
  await page.getByRole('tab', { name: 'Partiya (chop etish)' }).click();

  // Demo'da kartasi yo'qolgan o'quvchilar bor — ularga raqam beriladi.
  await page.getByRole('button', { name: 'Raqam berish' }).click();
  const reserve = page.getByRole('dialog');
  await reserve.getByText('Hammasini tanlash').click();
  await reserve.getByRole('button', { name: 'Raqam berish' }).click();
  await expect(reserve).toBeHidden();
  await expect(page.getByText(/Chop etish navbatida: \d+ ta/)).toBeVisible();
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/cards-batch.png` });

  await page.getByRole('button', { name: 'Ketma-ket biriktirish' }).click();
  const station = page.getByRole('dialog');
  const current = station.getByTestId('station-current');
  const number = (await current.locator('p.font-mono').innerText()).trim();
  expect(number).toMatch(/^\d{5} \d{5}$/);
  await expect(station.getByText(/0 \/ \d+ bog'landi/)).toBeVisible();

  await page.evaluate(() => {
    const fire = (key: string, code: string) => window.dispatchEvent(new KeyboardEvent('keydown', { key, code, bubbles: true, cancelable: true }));
    for (const ch of 'A1B2C3D4') fire(ch, /\d/.test(ch) ? `Digit${ch}` : `Key${ch}`);
    fire('Enter', 'Enter');
  });
  await expect(station.getByRole('status')).toContainText(`karta ${number} bog'landi`);
  await expect(station.getByText(/1 \/ \d+ bog'landi/)).toBeVisible();
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/cards-batch-station.png` });
  expect(errors).toEqual([]);
});
