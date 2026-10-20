import { expect, type Page, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

/** Ssenariy soati: dushanba 08:00 — 1-smena boshlangan (sinf ro'yxati belgilash rejimida). */
const SCENARIO = { mode: 'SCENARIO', speed: 1, scenarioDate: '2026-10-12', scenarioStartMinute: 8 * 60, realStartedAt: 0, epoch: 21 };

type StudentInfo = { id: string; name: string; guardianName: string };

/** 7-A dagi ota-onasi bor birinchi o'quvchi (sinf rahbari doirasida). */
async function student7a(page: Page): Promise<StudentInfo> {
  const info = await page.evaluate(() => {
    const raw = localStorage.getItem('parvoz-school:db:v1');
    type Db = { tables: { students: Array<{ id: string; classId: string; archived: boolean; lastName: string; firstName: string; guardianIds: string[] }>; guardians: Array<{ id: string; fullName: string }> } };
    const db = raw ? (JSON.parse(raw) as Db) : null;
    const s = db?.tables.students.find((x) => x.classId === 'cls-7a' && !x.archived && x.guardianIds.length > 0);
    const g = db?.tables.guardians.find((x) => x.id === s?.guardianIds[0]);
    return s && g ? { id: s.id, name: `${s.lastName} ${s.firstName}`, guardianName: g.fullName } : null;
  });
  expect(info).not.toBeNull();
  return info as StudentInfo;
}

const tabNames = (page: Page) => page.getByRole('tab').allInnerTexts();

test('sinf rahbari: 5 ta tab, ?tab= bilan ochiladi va URL bilan almashadi; eslatma qo\'shiladi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'sinf7a', 'Sinf2026');
  const s = await student7a(page);

  await page.goto(url(`/students/view?id=${s.id}&tab=history`));
  await expect(page.getByRole('tab')).toHaveCount(5);
  expect((await tabNames(page)).map((x) => x.trim())).toEqual(['Profil', 'Davomat', 'Rivojlanish', 'Tarix', 'Eslatmalar']);
  await expect(page.getByRole('tab', { name: 'Tarix' })).toHaveAttribute('aria-selected', 'true');
  await expect(page.getByRole('heading', { name: 'Tarix', level: 2 })).toBeVisible();

  await page.getByRole('tab', { name: 'Eslatmalar' }).click();
  await expect(page).toHaveURL(/[?&]tab=notes/);
  const note = `E2E eslatma ${Date.now()}`;
  await page.getByLabel('Yangi eslatma').fill(note);
  await page.locator('form').filter({ has: page.getByLabel('Yangi eslatma') }).getByRole('button', { name: 'Saqlash' }).click();
  await expect(page.getByText(note)).toBeVisible();

  await page.getByRole('tab', { name: 'Davomat' }).click();
  await expect(page).toHaveURL(/[?&]tab=attendance/);
  await page.getByRole('tab', { name: 'Profil' }).click();
  await expect(page).not.toHaveURL(/[?&]tab=/);
  expect(errors).toEqual([]);
});

test('psixolog: profil va rivojlanish; ruxsatsiz ?tab=history profilga qaytadi', async ({ page }) => {
  await login(page, 'psixolog', 'Psixolog2026');
  const s = await student7a(page);
  await page.goto(url(`/students/view?id=${s.id}&tab=history`));
  await expect(page.getByRole('tab')).toHaveCount(2);
  expect((await tabNames(page)).map((x) => x.trim())).toEqual(['Profil', 'Rivojlanish']);
  await expect(page.getByRole('tab', { name: 'Profil' })).toHaveAttribute('aria-selected', 'true');
  await expect(page.getByRole('main').getByRole('button', { name: 'Erta ketish', exact: true })).toHaveCount(0);
});

test('direktor: rivojlanish tabi yo\'q, erta ketish tugmasi yo\'q, istisno bor', async ({ page }) => {
  await login(page, 'direktor', 'Direktor2026');
  const s = await student7a(page);
  await page.goto(url(`/students/view?id=${s.id}`));
  await expect(page.getByRole('tab')).toHaveCount(4);
  expect((await tabNames(page)).map((x) => x.trim())).toEqual(['Profil', 'Davomat', 'Tarix', 'Eslatmalar']);
  const main = page.getByRole('main');
  await expect(main.getByRole('button', { name: 'School Mode istisnosi' })).toBeVisible();
  await expect(main.getByRole('button', { name: 'Erta ketish', exact: true })).toHaveCount(0);
});

test('sarlavha amallari: erta ketish va istisno oynalari o\'quvchi tanlangan holda ochiladi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'sinf7a', 'Sinf2026');
  const s = await student7a(page);
  await page.goto(url(`/students/view?id=${s.id}`));
  const main = page.getByRole('main');

  await main.getByRole('button', { name: 'Erta ketish', exact: true }).click();
  let dialog = page.getByRole('dialog');
  await expect(dialog).toContainText('Erta ketish so\'rovi');
  await expect(dialog).toContainText(s.name);
  await expect(dialog.getByPlaceholder('Ism yoki kod bo\'yicha qidiring…')).toHaveCount(0);
  await page.keyboard.press('Escape');
  await expect(dialog).toBeHidden();

  await main.getByRole('button', { name: 'School Mode istisnosi' }).click();
  dialog = page.getByRole('dialog');
  await expect(dialog).toContainText(s.name);
  await expect(dialog.getByRole('listbox')).toHaveCount(0);
  await page.keyboard.press('Escape');
  expect(errors).toEqual([]);
});

test('ota-onaga xabar: ?guardianId= auditoriyani tanlangan ota-onalar bilan to\'ldiradi', async ({ page }) => {
  await login(page, 'sinf7a', 'Sinf2026');
  const s = await student7a(page);
  await page.goto(url(`/students/view?id=${s.id}`));
  await page.getByRole('main').getByRole('link', { name: 'Ota-onaga xabar' }).click();
  await expect(page).toHaveURL(/\/messages\/new\/?\?guardianId=/);
  await expect(page.getByRole('radio', { name: /Tanlangan ota-onalar/ })).toHaveAttribute('aria-checked', 'true');
  await expect(page.getByRole('main')).toContainText(s.guardianName);
});

test('/messages/new?classId=cls-7a — auditoriya: 7-A sinfi', async ({ page }) => {
  await login(page, 'direktor', 'Direktor2026');
  await page.goto(url('/messages/new?classId=cls-7a'));
  await expect(page.getByRole('radio', { name: /^Sinflar/ })).toHaveAttribute('aria-checked', 'true');
  await expect(page.getByRole('button', { name: '7-A', exact: true })).toHaveAttribute('aria-pressed', 'true');
  await expect(page.getByRole('button', { name: '8-B', exact: true })).toHaveAttribute('aria-pressed', 'false');
});

test('/students?new=1 yaratish oynasini ochadi (classId bilan sinf tanlangan)', async ({ page }) => {
  await login(page, 'direktor', 'Direktor2026');
  await page.goto(url('/students?new=1'));
  await expect(page.getByRole('dialog')).toContainText('Yangi o\'quvchi');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toBeHidden();
  await expect(page).not.toHaveURL(/new=1/);

  await page.goto(url('/students?new=1&classId=cls-7a'));
  const dialog = page.getByRole('dialog');
  await expect(dialog).toContainText('Yangi o\'quvchi');
  await expect(dialog.getByRole('combobox').first()).toContainText('7-A');
});

test.describe('390px', () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test('sinf ro\'yxati: belgilash tugmalari ekranga sig\'adi, holat 3-katakda', async ({ page }) => {
    await login(page, 'sinf7a', 'Sinf2026');
    await page.evaluate((clock) => localStorage.setItem('parvoz-school:clock', JSON.stringify({ ...clock, realStartedAt: Date.now() })), SCENARIO);
    await page.goto(url('/attendance/class?id=cls-7a'));
    const row = page.getByRole('row').filter({ hasText: /P-\d{4}/ }).first();
    await expect(row).toBeVisible();
    for (const name of ['Keldi', 'Kechikdi', 'Kelmadi', 'Sababli']) {
      const button = row.getByRole('button', { name, exact: true });
      await expect(button).toBeVisible();
      const box = await button.boundingBox();
      expect(box, name).not.toBeNull();
      expect((box?.x ?? 0) + (box?.width ?? 0), name).toBeLessThanOrEqual(390);
      expect(box?.width ?? 0, name).toBeGreaterThanOrEqual(34);
    }
    await expect(row.getByRole('cell').nth(2)).toBeVisible();
    const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(scrollWidth).toBeLessThanOrEqual(390);
  });
});
