import { expect, test } from '@playwright/test';

import { FORBIDDEN, login, trackErrors, url } from './helpers';

test('kirmagan foydalanuvchi login sahifasiga yo\'naltiriladi', async ({ page }) => {
  await page.goto(url('/dashboard'));
  await page.waitForURL(/\/monitoring\/login\/?/);
  await expect(page.locator('#username')).toBeVisible();
});

test('noto\'g\'ri parol — xato xabari', async ({ page }) => {
  await page.goto(url('/login'));
  await page.locator('#username').fill('respublika');
  await page.locator('#password').fill('notogri');
  await page.locator('button[type="submit"]').click();
  await expect(page.getByText("Login yoki parol noto'g'ri")).toBeVisible();
});

test('respublika: xaritadan hududni bosish — hudud profili', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'respublika', 'Respublika2026');
  await page.getByRole('button', { name: /^Samarqand viloyati:/ }).first().click();
  await page.waitForURL(/\/regions\/view\/\?id=UZ-SA/);
  await expect(page.locator('main h1').first()).toHaveText('Samarqand viloyati');
  await expect(page.getByText("Respublikadagi o'rni")).toBeVisible();
  expect(errors).toEqual([]);
});

test('viloyat hisobi boshqa hudud profilini ocholmaydi', async ({ page }) => {
  await login(page, 'samarqand', 'Samarqand2026');
  await expect(page.locator('main h1').first()).toContainText('Samarqand viloyati');
  await page.goto(url('/regions/view?id=UZ-TK'));
  await expect(page.locator('main h1').first()).toHaveText(FORBIDDEN);
  await page.goto(url('/reports/print?id=UZ'));
  await expect(page.locator('main h1').first()).toHaveText(FORBIDDEN);
  await page.goto(url('/regions/view?id=UZ-SA'));
  await expect(page.locator('main h1').first()).toHaveText('Samarqand viloyati');
});

test('davr filtri barcha sahifalarda saqlanadi', async ({ page }) => {
  await login(page, 'respublika', 'Respublika2026');
  await page.getByRole('combobox', { name: 'Davr' }).first().click();
  await page.getByRole('option', { name: "O'tgan o'quv yili" }).click();
  await expect(page.locator('main').getByText(/2025\/2026 o'quv yili/).first()).toBeVisible();
  await page.goto(url('/regions/view?id=UZ-BU'));
  await expect(page.locator('main').getByText(/2025\/2026 o'quv yili/).first()).toBeVisible();
});

test('til almashtirish: rus tilida sarlavha', async ({ page }) => {
  await login(page, 'respublika', 'Respublika2026');
  await page.getByRole('button', { name: 'RU', exact: true }).click();
  await expect(page.locator('main h1').first()).toHaveText('Обзор');
});

test('taqdimot rejimi: slaydlar almashadi, chiqish — dashboard', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'respublika', 'Respublika2026');
  await page.goto(url('/present'));
  await expect(page.getByText('1 / 10')).toBeVisible();
  await page.keyboard.press(' ');
  await page.keyboard.press('ArrowRight');
  await expect(page.getByText('2 / 10')).toBeVisible();
  await expect(page.locator('main h2')).toHaveText("Asosiy ko'rsatkichlar");
  await page.keyboard.press('ArrowLeft');
  await page.keyboard.press('ArrowLeft');
  await expect(page.getByText('10 / 10')).toBeVisible();
  await page.getByRole('button', { name: 'Taqdimotdan chiqish' }).click();
  await page.waitForURL(/\/monitoring\/dashboard\/?$/);
  expect(errors).toEqual([]);
});

test('hisobotlar: CSV yuklab olinadi, chop etish sahifasi ochiladi', async ({ page }) => {
  await login(page, 'respublika', 'Respublika2026');
  await page.goto(url('/reports'));
  const [download] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'CSV yuklab olish' }).first().click()]);
  expect(download.suggestedFilename()).toMatch(/^parvoz-monitoring-DEMO_indicators_respublika_/);
  const text = await (await download.createReadStream()).toArray();
  const csv = Buffer.concat(text).toString('utf8');
  expect(csv.split('\r\n').length).toBe(15);
  await page.getByRole('link', { name: 'Hisobotni ochish' }).click();
  await page.waitForURL(/\/reports\/print\/\?id=UZ/);
  await expect(page.locator('main h1').first()).toHaveText('Respublika hisoboti');
});
