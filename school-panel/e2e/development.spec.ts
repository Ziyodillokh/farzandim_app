import { expect, type Page, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

type StudentLite = { id: string; classId: string; archived: boolean; lastName: string; firstName: string };

async function students(page: Page): Promise<StudentLite[]> {
  return page.evaluate(() => {
    const raw = localStorage.getItem('parvoz-school:db:v1');
    const db = raw ? (JSON.parse(raw) as { tables: { students: StudentLite[] } }) : null;
    return db?.tables.students ?? [];
  });
}

async function firstOf(page: Page, classId: string): Promise<StudentLite> {
  const s = (await students(page)).find((x) => x.classId === classId && !x.archived);
  expect(s, classId).toBeTruthy();
  return s as StudentLite;
}

test('direktor: /development — faqat umumlashgan, hech bir o\'quvchi ismi yo\'q', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'direktor', 'Direktor2026');
  await page.goto(url('/development'));
  await expect(page.locator('main h1').first()).toHaveText('Rivojlanish');
  await expect(page.getByText('Shaxsiy natijalar faqat psixolog va sinf rahbariga ko\'rinadi', { exact: false })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Sinflar × sohalar' })).toBeVisible();
  await expect(page.getByRole('tab')).toHaveCount(0);

  const text = await page.locator('main').innerText();
  const names = (await students(page)).map((s) => `${s.lastName} ${s.firstName}`);
  expect(names.length).toBeGreaterThan(100);
  for (const name of names) expect(text.includes(name), name).toBe(false);
  expect(text).not.toMatch(/stu-\d+/);
  expect(errors).toEqual([]);
});

test('sinf rahbari: boshqa sinf (8-B) o\'quvchisining rivojlanish tabi — ruxsat yo\'q', async ({ page }) => {
  await login(page, 'sinf7a', 'Sinf2026');
  const other = await firstOf(page, 'cls-8b');
  await page.goto(url(`/students/view?id=${other.id}&tab=development`));
  await expect(page.locator('main')).toContainText(/ruxsat/i);
  await expect(page.getByRole('img', { name: 'Rivojlanish profili' })).toHaveCount(0);
});

test('sinf rahbari: o\'z sinfi o\'quvchisi — radar, hissiy holat faqat daraja, javoblar yo\'q', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'sinf7a', 'Sinf2026');
  const own = await firstOf(page, 'cls-7a');
  await page.goto(url(`/students/view?id=${own.id}&tab=development`));
  await expect(page.getByRole('tab', { name: 'Rivojlanish' })).toHaveAttribute('aria-selected', 'true');
  await expect(page.getByRole('img', { name: 'Rivojlanish profili' })).toBeVisible();
  await expect(page.getByText('IQ shkalasidagi kognitiv indeks').first()).toBeVisible();
  await expect(page.getByText('Javoblar va xom ballar faqat psixologga ko\'rinadi', { exact: false })).toBeVisible();
  await expect(page.getByRole('columnheader', { name: 'Javoblar' })).toHaveCount(0);
  expect(errors).toEqual([]);
});

test('psixolog: Maktab | Sinflar | E\'tibor ro\'yxati tablari URL bilan', async ({ page }) => {
  await login(page, 'psixolog', 'Psixolog2026');
  await page.goto(url('/development?tab=attention'));
  await expect(page.getByRole('tab', { name: 'E\'tibor ro\'yxati' })).toHaveAttribute('aria-selected', 'true');
  await expect(page.getByRole('heading', { name: 'E\'tibor ro\'yxati', level: 2 })).toBeVisible();
  await page.getByRole('tab', { name: 'Sinflar' }).click();
  await expect(page).toHaveURL(/[?&]tab=classes/);
  await expect(page.getByRole('heading', { name: 'Sinf natijalari' })).toBeVisible();
});
