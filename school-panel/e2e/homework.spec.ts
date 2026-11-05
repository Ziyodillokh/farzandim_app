import { expect, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

test('sinf rahbari: yozma vazifa beradi (tekshiruv xatolari bilan)', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'sinf7a', 'Sinf2026');
  await page.goto(url('/learning'));
  await page.getByRole('tab', { name: 'Topshiriqlar' }).click();
  await page.getByRole('button', { name: 'Topshiriq berish' }).click();

  const dialog = page.getByRole('dialog');
  await dialog.getByRole('radio', { name: 'Yozma vazifa' }).click();
  // Sarlavhasiz yuborib bo'lmaydi; vaqt 1–240 oralig'ida.
  await dialog.getByLabel(/Taxminiy vaqt/).fill('241');
  await dialog.getByRole('button', { name: 'Topshiriq berish' }).click();
  await expect(dialog.getByText('Majburiy maydon')).toBeVisible();
  await expect(dialog.getByText(/Vaqt 1 dan 240/).first()).toBeVisible();

  await dialog.getByLabel('Vazifa nomi').fill('Tabiat: kuzgi o\'zgarishlar kuzatuvi');
  await dialog.getByLabel(/Ko.rsatma/).fill('Daftarga 5 ta gap yozing va suratga oling.');
  await dialog.getByLabel(/Taxminiy vaqt/).fill('20');
  await dialog.getByRole('button', { name: 'Topshiriq berish' }).click();
  await expect(page.getByText('Topshiriq berildi')).toBeVisible();

  const row = page.getByRole('row').filter({ hasText: 'Tabiat: kuzgi' });
  await expect(row).toContainText('Yozma vazifa');
  await expect(row).toContainText('~20 daq');
  await expect(row).toContainText('/ 27 topshirdi');
  expect(errors).toEqual([]);
});

test('sinf rahbari: topshirilgan ishni ko\'radi, rasmlarni kattalashtiradi, qaytaradi va qabul qiladi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'sinf7a', 'Sinf2026');
  await page.goto(url('/learning'));
  await page.getByRole('tab', { name: 'Topshiriqlar' }).click();
  await page.getByRole('button', { name: /Topshiriqlar: Ona tili/ }).click();

  const sheet = page.getByRole('dialog').first();
  await expect(sheet.getByRole('heading', { name: /Mening Vatanim/ })).toBeVisible();
  const pendingBefore = Number(await sheet.getByText('Tekshirilmagan', { exact: true }).locator('xpath=following-sibling::dd').innerText());
  expect(pendingBefore).toBeGreaterThan(1);

  // Faqat «Yuborildi» holatidagilar; ≥ 2 rasmi borini tanlaymiz.
  await sheet.getByRole('button', { name: 'Yuborildi', exact: true }).click();
  const target = sheet.getByRole('row').filter({ hasText: /[23] ta rasm/ }).first();
  const studentName = (await target.getByRole('cell').first().innerText()).trim();
  await target.getByRole('button', { name: /Ochish/ }).click();

  const drawer = page.getByRole('dialog').last();
  await expect(drawer.getByRole('heading', { name: studentName })).toBeVisible();

  // Rasmni kattalashtirish va strelka bilan almashtirish; Esc yopadi.
  await drawer.getByRole('button', { name: /Rasmni kattalashtirish: 1/ }).click();
  const lightbox = page.getByRole('dialog').last();
  await expect(lightbox.getByRole('heading', { name: /1 \/ [23]-rasm/ })).toBeVisible();
  await page.keyboard.press('ArrowRight');
  await expect(lightbox.getByRole('heading', { name: /2 \/ [23]-rasm/ })).toBeVisible();
  await page.keyboard.press('ArrowLeft');
  await expect(lightbox.getByRole('heading', { name: /1 \/ [23]-rasm/ })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('heading', { name: /-rasm/ })).toHaveCount(0);

  // Izohsiz qaytarib bo'lmaydi.
  await drawer.getByRole('button', { name: 'Qaytarish' }).click();
  await expect(drawer.getByRole('alert')).toContainText('Qaytarish uchun izoh yozing');
  await expect(drawer.getByRole('button', { name: 'Qabul qilish' })).toBeEnabled();

  // Izoh bilan qaytarish — holat darhol yangilanadi.
  await drawer.getByRole('textbox', { name: 'Izoh', exact: true }).fill('Rasm xira, qayta suratga oling.');
  await drawer.getByRole('button', { name: 'Qaytarish' }).click();
  await expect(page.getByText('Ish qaytarildi')).toBeVisible();
  await expect(drawer.getByText('Qaytarildi', { exact: true })).toBeVisible();

  // Qabul qilish ham mumkin (qayta tekshirish) — tekshirilmaganlar soni kamayadi.
  await drawer.getByRole('button', { name: 'Qabul qilish' }).click();
  await expect(page.getByText('Ish qabul qilindi')).toBeVisible();
  await expect(drawer.getByText('Qabul qilindi', { exact: true })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(sheet.getByText('Tekshirilmagan', { exact: true }).locator('xpath=following-sibling::dd')).toHaveText(String(pendingBefore - 1));
  expect(errors).toEqual([]);
});

test('direktor: topshiriqlarni ko\'radi, lekin tekshira olmaydi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'direktor', 'Direktor2026');
  await page.goto(url('/learning'));
  await page.getByRole('tab', { name: 'Topshiriqlar' }).click();
  await page.getByRole('button', { name: /Topshiriqlar: Matematika: 34-mashq/ }).click();
  const sheet = page.getByRole('dialog').first();
  // Ikki sinf (7-A va 7-B) o'quvchilari.
  await expect(sheet.getByRole('cell', { name: '7-B' }).first()).toBeVisible();
  await sheet.getByRole('button', { name: 'Yuborildi', exact: true }).click();
  await sheet.getByRole('button', { name: /Ochish/ }).first().click();
  const drawer = page.getByRole('dialog').last();
  await expect(drawer.getByText(/tekshirish uchun ruxsatingiz yo.q/)).toBeVisible();
  await expect(drawer.getByRole('button', { name: 'Qabul qilish' })).toHaveCount(0);
  expect(errors).toEqual([]);
});
