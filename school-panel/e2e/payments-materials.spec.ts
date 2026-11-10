import { expect, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

test('admin: to\'lov kartasi bosilsa ro\'yxat filtrlanadi; sinf filtri va «Eslatma qo\'shish» bor', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'admin', 'Admin2026');
  await page.goto(url('/reminders/payments'));

  const prepaid = page.getByRole('button', { name: /Oldindan to.laganlar/ });
  await prepaid.click();
  await expect(prepaid).toHaveAttribute('aria-pressed', 'true');
  await expect(page.getByRole('tab', { name: /Oldindan to.lagan/ })).toHaveAttribute('aria-selected', 'true');
  // Yana bosilsa — hammasi.
  await prepaid.click();
  await expect(page.getByRole('tab', { name: 'Barchasi' })).toHaveAttribute('aria-selected', 'true');

  await page.getByRole('button', { name: /Eslatma qo.shish/ }).click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByText('Yangi to\'lov eslatmasi')).toBeVisible();
  await expect(dialog.getByRole('radio', { name: 'Butun sinf' }).or(dialog.getByRole('button', { name: 'Butun sinf' }))).toBeVisible();
  await page.keyboard.press('Escape');
  expect(errors).toEqual([]);
});

test('sinf rahbari: o\'z sinfi to\'lovlarini faqat ko\'radi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'sinf7a', 'Sinf2026');
  await page.goto(url('/reminders/payments'));
  await expect(page.getByText(/Faqat o.z sinfingiz/)).toBeVisible();
  await expect(page.getByRole('button', { name: /Eslatma qo.shish/ })).toHaveCount(0);
  await expect(page.getByRole('checkbox')).toHaveCount(0);
  expect(errors).toEqual([]);
});

test('admin: taklif varaqalari sahifasi QR va kodlarni ko\'rsatadi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'admin', 'Admin2026');
  await page.goto(url('/parents'));
  await page.getByRole('link', { name: 'Taklif varaqalari' }).click();
  await expect(page.getByRole('heading', { name: 'Taklif varaqalari' })).toBeVisible();
  await expect(page.getByRole('button', { name: /Chop etish/ })).toBeVisible();
  expect(errors).toEqual([]);
});

test('direktor: maktab materialini qo\'shadi va u katalogda birinchi turadi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'direktor', 'Direktor2026');
  await page.goto(url('/learning'));
  await page.getByRole('tab', { name: 'Materiallar' }).click();
  await page.getByRole('button', { name: /Material qo.shish/ }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByLabel('Sarlavha').fill('Kasrlarni qo\'shish');
  await dialog.getByRole('button', { name: '7', exact: true }).click();
  await dialog.getByLabel('Matn').fill('Avval umumiy maxrajni toping, keyin suratlarni qo\'shing.');
  await dialog.getByLabel(/Havola/).fill('http://example.com');
  await dialog.getByRole('button', { name: 'Qo\'shish' }).click();
  await expect(dialog.getByText(/https:\/\//)).toBeVisible();
  await dialog.getByLabel(/Havola/).fill('https://www.youtube.com/watch?v=x1');
  await dialog.getByRole('button', { name: 'Qo\'shish' }).click();
  await expect(page.getByText('Kasrlarni qo\'shish').first()).toBeVisible();
  await expect(page.getByText('youtube.com').first()).toBeVisible();
  expect(errors).toEqual([]);
});
