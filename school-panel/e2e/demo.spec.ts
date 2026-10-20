import { expect, type Page, test } from '@playwright/test';

import { login, trackErrors } from './helpers';

const BELL = /^Bildirishnomalar/;

async function openDemoPanel(page: Page) {
  await page.getByRole('button', { name: 'Demo', exact: true }).click();
  const panel = page.getByRole('dialog', { name: 'Demo boshqaruvi' });
  await expect(panel).toBeVisible();
  return panel;
}

test('topbardagi "Demo" tugmasi demo panelni ochadi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'direktor', 'Direktor2026');
  const panel = await openDemoPanel(page);
  await expect(panel.getByText('Rolni almashtirish')).toBeVisible();
  await expect(panel.getByText('Demo soati')).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(panel).toBeHidden();
  // Ctrl + Shift + D ham o'sha panelni ochadi.
  await page.keyboard.press('Control+Shift+D');
  await expect(page.getByRole('dialog', { name: 'Demo boshqaruvi' })).toBeVisible();
  expect(errors).toEqual([]);
});

test('rolni psixologga almashtirish — "Psixologik testlar" menyusi ko\'rinadi', async ({ page }) => {
  await login(page, 'direktor', 'Direktor2026');
  const nav = page.locator('aside');
  await expect(nav.getByRole('link', { name: 'Psixologik testlar' })).toHaveCount(0);
  const panel = await openDemoPanel(page);
  await panel.getByRole('button', { name: /Psixolog sifatida ko'rish/ }).click();
  await expect(panel).toBeHidden();
  await expect(nav.getByRole('link', { name: 'Psixologik testlar' })).toBeVisible();
  await expect(page.locator('main h1').first()).toBeVisible();
});

test('kirish nuqtasi navbatchi sifatida yangi tabda ochiladi, direktor tabi o\'z rolida qoladi', async ({ context, page }) => {
  await login(page, 'direktor', 'Direktor2026');
  const panel = await openDemoPanel(page);
  const [kiosk] = await Promise.all([
    context.waitForEvent('page'),
    panel.getByRole('button', { name: /Kirish nuqtasini ochish/ }).click(),
  ]);
  await expect(kiosk.getByLabel('P-1234')).toBeVisible();
  await expect(kiosk.getByText('navbatchi sifatida')).toBeVisible();
  await expect(kiosk).not.toHaveURL(/as=/);

  await page.reload();
  await expect(page.locator('aside')).toContainText('Direktor');
});

test('erta ketish so\'rovi qo\'ng\'iroqchada belgi chiqaradi, "Hammasini o\'qildi" tozalaydi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'admin', 'Admin2026');
  const bell = page.getByRole('button', { name: BELL });
  const markAll = page.getByRole('button', { name: 'Hammasini o\'qildi' });

  // Boshlang'ich (seed) o'qilmaganlarni tozalaymiz.
  await expect(bell).toHaveAccessibleName(/o'qilmagan/);
  await bell.click();
  await markAll.click();
  await expect(bell).toHaveAccessibleName('Bildirishnomalar');
  await page.keyboard.press('Escape');

  const panel = await openDemoPanel(page);
  await panel.getByRole('button', { name: 'Erta ketish so\'rovi' }).click();
  await page.keyboard.press('Escape');
  await expect(panel).toBeHidden();

  await expect(bell).toHaveAccessibleName(/o'qilmagan/);
  await bell.click();
  await expect(page.getByText('Erta ketish').first()).toBeVisible();
  await markAll.click();
  await expect(bell).toHaveAccessibleName('Bildirishnomalar');
  expect(errors).toEqual([]);
});
