import { expect, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

const DB_KEY = 'parvoz-school:db:v1';
const HOURS = '[data-testid="privacy-hours"]';

test('psixolog sozlamalarni saqlaydi: bola ko\'radigan ism, ish kunlari va vaqti banner va qayta yuklashda saqlanadi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'psixolog', 'Psixolog2026');

  // Menyudan sozlamalarga o'tish (Bola ovozi bo'limi ostida).
  await page.goto(url('/care'));
  await expect(page.locator(HOURS)).toContainText('Psixolog ish vaqti: Du–Ju, 08:30–16:30.');
  await page.getByRole('link', { name: 'Sozlamalar' }).first().click();
  await page.waitForURL(/\/school\/care\/settings\/?$/);
  await expect(page.locator('main h1').first()).toHaveText('Bola ovozi sozlamalari');
  await expect(page.getByText('Hammasi saqlangan')).toBeVisible();

  // Jonli ko'rinish: bola nimani ko'radi.
  const preview = page.getByTestId('care-settings-preview');
  await expect(preview).toContainText('Lola opa');
  await expect(preview).toContainText('Kamola opa');

  await page.locator('#care-settings-psychologistDisplayName').fill('Dilnoza opa');
  await page.locator('#care-settings-workEnd').fill('17:00');
  await page.getByRole('button', { name: 'Shanba', exact: true }).click();
  await page.locator('#care-settings-urgentSlaMinutes').fill('45');
  await page.locator('#care-settings-normalSlaHours').fill('12');
  await expect(page.getByText('Saqlanmagan oʻzgarishlar bor')).toBeVisible();
  await expect(preview).toContainText('Dilnoza opa');
  await expect(preview).toContainText('Du–Sh, 08:30–17:00');

  await page.getByRole('button', { name: 'Saqlash' }).click();
  await expect(page.getByText('Sozlamalar saqlandi')).toBeVisible();
  await expect(page.getByText('Hammasi saqlangan')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Saqlash' })).toBeFocused();

  // Qayta yuklash: qiymatlar saqlangan.
  await page.reload();
  await expect(page.locator('#care-settings-psychologistDisplayName')).toHaveValue('Dilnoza opa');
  await expect(page.locator('#care-settings-workEnd')).toHaveValue('17:00');
  await expect(page.locator('#care-settings-urgentSlaMinutes')).toHaveValue('45');
  await expect(page.locator('#care-settings-normalSlaHours')).toHaveValue('12');
  await expect(page.getByRole('button', { name: 'Shanba', exact: true })).toHaveAttribute('aria-pressed', 'true');

  // Banner endi sozlamadagi vaqtni ko'rsatadi (qattiq yozilgan matn emas).
  await page.goto(url('/care'));
  await expect(page.locator(HOURS)).toContainText('Psixolog ish vaqti: Du–Sh, 08:30–17:00.');
  expect(errors).toEqual([]);
});

test('noto\'g\'ri qiymatlar: xato xabari maydon yonida, fokus birinchi xatoli maydonga, saqlanmaydi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'psixolog', 'Psixolog2026');
  await page.goto(url('/care/settings'));
  await expect(page.getByText('Hammasi saqlangan')).toBeVisible();

  await page.locator('#care-settings-workStart').fill('18:00');
  await page.locator('#care-settings-urgentSlaMinutes').fill('5');
  await page.getByRole('button', { name: 'Saqlash' }).click();
  await expect(page.getByText('Tugash vaqti boshlanishdan keyin boʻlishi kerak').or(page.getByText("Tugash vaqti boshlanishdan keyin bo'lishi kerak"))).toBeVisible();
  await expect(page.getByText('Muddat 15 dan 1440 daqiqagacha boʻlishi kerak')).toBeVisible();
  await expect(page.locator('#care-settings-urgentSlaMinutes')).toHaveAttribute('aria-invalid', 'true');
  await expect(page.locator('#care-settings-workEnd')).toBeFocused();
  await expect(page.getByText('Sozlamalar saqlandi')).toHaveCount(0);

  // Tuzatilgach xato yo'qoladi va saqlanadi.
  await page.locator('#care-settings-workStart').fill('09:00');
  await page.locator('#care-settings-urgentSlaMinutes').fill('30');
  await page.getByRole('button', { name: 'Saqlash' }).click();
  await expect(page.getByText('Sozlamalar saqlandi')).toBeVisible();
  expect(errors).toEqual([]);
});

test('admin sozlamalarni faqat ko\'radi (tahrirlash tugmalari yo\'q); direktor tahrirlaydi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'admin', 'Admin2026');
  await page.goto(url('/care/settings'));
  await expect(page.getByText('Faqat koʻrish: sozlamalarni psixolog yoki direktor oʻzgartiradi.')).toBeVisible();
  await expect(page.locator('#care-settings-workEnd')).toBeDisabled();
  await expect(page.locator('#care-settings-urgentSlaMinutes')).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Saqlash' })).toHaveCount(0);

  await page.getByRole('button', { name: 'Hisob menyusi' }).first().click();
  await page.getByRole('menuitem', { name: 'Chiqish' }).click();
  await page.waitForURL(/\/school\/login\/?/);

  await login(page, 'direktor', 'Direktor2026');
  await page.goto(url('/care/settings'));
  await expect(page.locator('#care-settings-workEnd')).toBeEnabled();
  await expect(page.getByRole('button', { name: 'Saqlash' })).toBeVisible();
  expect(errors).toEqual([]);
});

test('sozlama saqlanmagan bo\'lsa banner "belgilanmagan" deydi, ish vaqti uydirilmaydi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'psixolog', 'Psixolog2026');
  await page.evaluate((key) => {
    const db = JSON.parse(localStorage.getItem(key) ?? '{}') as { tables: { careSettings: unknown } };
    db.tables.careSettings = null;
    localStorage.setItem(key, JSON.stringify(db));
  }, DB_KEY);
  await page.goto(url('/care'));
  await expect(page.locator(HOURS)).toHaveText('Psixolog ish vaqti hali belgilanmagan.');
  await page.goto(url('/care/settings'));
  await expect(page.getByText('Sozlamalar hali saqlanmagan — standart qiymatlar koʻrsatilgan.')).toBeVisible();
  expect(errors).toEqual([]);
});
