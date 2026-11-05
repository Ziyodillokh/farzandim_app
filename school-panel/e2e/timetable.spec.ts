import { expect, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

/** 7-A (1-smena): shanba kuni 5-dars — bu katak jadvalning chekkasida, nusxalashdan keyin ham bor. */
const EMPTY_CELL = '[data-cell="6:5"]';

test('sinf rahbari: dars jadvalini tahrirlaydi, nusxalaydi, saqlaydi; chiqishda ogohlantiriladi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'sinf7a', 'Sinf2026');
  await page.goto(url('/timetable'));

  const grid = page.getByRole('grid');
  await expect(grid).toBeVisible();
  await expect(page.getByText('Hammasi saqlangan')).toBeVisible();

  // Klaviatura: strelka bilan qo'shni katakka o'tadi.
  await page.locator('[data-cell="1:1"]').focus();
  await page.keyboard.press('ArrowRight');
  await expect(page.locator('[data-cell="2:1"]')).toBeFocused();
  await page.keyboard.press('ArrowDown');
  await expect(page.locator('[data-cell="2:2"]')).toBeFocused();

  // Dushanbani boshqa kunlarga nusxalash: Chorshanba 1-dars Dushanbanikidek bo'ladi.
  const mondayFirst = (await page.locator('[data-cell="1:1"]').getAttribute('aria-label')) ?? '';
  const mondayContent = mondayFirst.slice(mondayFirst.indexOf('): ') + 3);
  await page.getByRole('button', { name: 'Kunni nusxalash' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Nusxalash' }).click();
  await expect(page.locator('[data-cell="3:1"]')).toHaveAttribute('aria-label', new RegExp(`${mondayContent.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`));

  // «Boshqa…» fan + xona.
  await page.locator(EMPTY_CELL).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('combobox', { name: 'Fan' }).click();
  await page.getByRole('option', { name: /Boshqa/ }).click();
  await dialog.getByLabel('Fan nomi').fill('Shaxmat toʻgaragi');
  await dialog.getByLabel(/Xona/).fill('Kab. 12');
  await dialog.getByRole('button', { name: /Qo.llash/ }).click();
  await expect(page.locator(EMPTY_CELL)).toContainText('Shaxmat');
  await expect(page.getByText(/Saqlanmagan o.zgarishlar bor/)).toBeVisible();

  // Menyu orqali chiqish — tasdiq so'raladi; «Bekor qilish» sahifada qoldiradi.
  await page.getByRole('link', { name: 'Sinflar', exact: true }).click();
  const leave = page.getByRole('dialog');
  await expect(leave.getByRole('heading', { name: /Saqlanmagan/ })).toBeVisible();
  await leave.getByRole('button', { name: 'Bekor qilish' }).click();
  await expect(page).toHaveURL(/\/school\/timetable\/?$/);
  await expect(page.locator(EMPTY_CELL)).toContainText('Shaxmat');

  // Saqlash va qayta yuklaganda saqlanib qolishi.
  await page.getByRole('button', { name: 'Saqlash' }).click();
  await expect(page.getByText('Dars jadvali saqlandi')).toBeVisible();
  await expect(page.getByText('Hammasi saqlangan')).toBeVisible();
  await page.reload();
  await expect(page.locator(EMPTY_CELL)).toContainText('Shaxmat');
  await expect(page.locator('[data-cell="3:1"]')).toContainText(mondayContent.split(',')[0] ?? '');
  expect(errors).toEqual([]);
});

test('direktor: har qanday sinfni tanlaydi; o\'zgarmagan jadvalda chiqish ogohlantirmaydi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'direktor', 'Direktor2026');
  await page.goto(url('/timetable'));
  await expect(page.getByRole('grid')).toBeVisible();
  await page.getByRole('combobox', { name: 'Sinf' }).click();
  await page.getByRole('option', { name: '9-B' }).click();
  await expect(page.getByRole('grid')).toHaveAttribute('aria-label', /9-B/);
  await page.getByRole('link', { name: 'Sinflar', exact: true }).click();
  await expect(page).toHaveURL(/\/school\/classes\/?$/);
  expect(errors).toEqual([]);
});
