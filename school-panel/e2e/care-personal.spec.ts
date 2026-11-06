import { expect, type Page, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

/** Seed: 6-A o'quvchisi (Umarova Jasmina), jarayondagi murojaat. */
const REQUEST = 'care-3';
const STUDENT = 'Umarova Jasmina';

type DbStudent = { studentCode: string; classId: string; lastName: string };

/** Demo bazasidan o'quvchi kodlari (qidiruv uchun noyob). */
async function codes(page: Page): Promise<{ eligible: DbStudent[]; grade1: DbStudent }> {
  return page.evaluate(() => {
    const db = JSON.parse(localStorage.getItem('parvoz-school:db:v1') ?? '{}') as { tables: { students: DbStudent[] } };
    const students = db.tables.students;
    return {
      eligible: students.filter((s) => s.classId === 'cls-7a').slice(0, 3),
      grade1: students.find((s) => s.classId === 'cls-1a') as DbStudent,
    };
  });
}

async function chooseTest(page: Page, title: string) {
  const dialog = page.getByRole('dialog');
  await dialog.getByTestId('assign-test').click();
  await page.getByRole('option', { name: title }).click();
}

test('murojaatdan shaxsiy so\'rov: o\'quvchi va murojaat bog\'langan, rozilik majburiy, tayinlashlarda «Alohida o\'quvchilar»', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'psixolog', 'Psixolog2026');
  await page.goto(url(`/care/requests/view?id=${REQUEST}`));

  await page.getByTestId('assign-personal').click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByRole('heading', { name: 'Shaxsiy soʻrov tayinlash' })).toBeVisible();

  // O'quvchi oldindan to'ldirilgan va qulflangan; maqsad tanlovi (sinf/parallel) yo'q.
  const locked = dialog.getByTestId('assign-locked-student');
  await expect(locked).toContainText(STUDENT);
  await expect(locked).toContainText('6-A');
  await expect(dialog.getByRole('tab')).toHaveCount(0);
  // Anonim emasligi aytilgan.
  await expect(dialog.getByText('Shaxsiy tayinlash anonim emas')).toBeVisible();

  await chooseTest(page, 'Mantiqiy fikrlash');
  await expect(dialog.getByText("Taklif qilinadi: 1 o'quvchi")).toBeVisible();

  // Rozilik belgilanmaguncha tayinlanmaydi.
  await dialog.getByTestId('assign-submit').click();
  await expect(dialog.getByText('Ota-onalar xabardorligini tasdiqlang')).toBeVisible();
  await expect(dialog).toBeVisible();

  await dialog.getByTestId('assign-consent').click();
  await dialog.getByTestId('assign-submit').click();
  await expect(dialog).toBeHidden();
  await expect(page.getByText('Test tayinlandi')).toBeVisible();

  // Tayinlashlar: faqat «Alohida o'quvchilar» (butun sinf emas); ism ko'rsatilmaydi.
  await page.goto(url('/assessments?tab=assignments'));
  const personal = page.getByTestId('personal-assignment');
  await expect(personal).toHaveCount(1);
  await expect(personal).toContainText('Alohida oʻquvchilar');
  await expect(personal).toContainText('1 oʻquvchi');
  await expect(page.locator('tbody')).not.toContainText(STUDENT);
  expect(errors).toEqual([]);
});

test('tayinlash oynasida «Alohida o\'quvchilar»: qidirish, 1..30, mos kelmagan sinf tanlanmaydi, olib tashlash', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'psixolog', 'Psixolog2026');
  const { eligible, grade1 } = await codes(page);
  await page.goto(url('/assessments?tab=assignments'));
  await page.getByRole('button', { name: 'Tayinlash' }).first().click();
  const dialog = page.getByRole('dialog');

  await dialog.getByTestId('assign-mode-students').click();
  // Test tanlanmaguncha o'quvchi qidirib bo'lmaydi (sinf parallellari test bo'yicha tekshiriladi).
  await expect(dialog.getByTestId('student-search')).toBeDisabled();
  await chooseTest(page, 'Mantiqiy fikrlash');
  const search = dialog.getByTestId('student-search');
  await expect(search).toBeEnabled();

  // Ikki o'quvchini qo'shamiz (kod bo'yicha qidiruv); fokus qidiruvga qaytadi.
  for (const student of eligible.slice(0, 2)) {
    await search.fill(student.studentCode);
    await dialog.getByRole('list', { name: 'Qidiruv natijalari' }).getByRole('button').first().click();
    await expect(search).toBeFocused();
  }
  const picked = dialog.getByTestId('picked-students');
  await expect(picked.getByRole('listitem')).toHaveCount(2);
  await expect(dialog.getByText('Tanlandi: 2 / 30')).toBeVisible();
  await expect(dialog.getByText("Taklif qilinadi: 2 o'quvchi")).toBeVisible();

  // 1-sinf o'quvchisi test parallellariga (3–11) mos emas — tanlab bo'lmaydi.
  await search.fill(grade1.studentCode);
  const result = dialog.getByRole('list', { name: 'Qidiruv natijalari' }).getByRole('button').first();
  await expect(result).toBeDisabled();
  await expect(result).toContainText('Sinfi mos emas');

  // Olib tashlash (aria-label bilan).
  await picked.getByRole('button', { name: /Olib tashlash/ }).first().click();
  await expect(picked.getByRole('listitem')).toHaveCount(1);
  await expect(search).toBeFocused();

  await dialog.getByTestId('assign-consent').click();
  await dialog.getByTestId('assign-submit').click();
  await expect(dialog).toBeHidden();
  await expect(page.getByTestId('personal-assignment')).toContainText('1 oʻquvchi');
  expect(errors).toEqual([]);
});

test('shaxsiy so\'rov tugmasi faqat psixologda; direktor murojaatni umuman ko\'ra olmaydi', async ({ page }) => {
  await login(page, 'psixolog', 'Psixolog2026');
  await page.goto(url(`/care/requests/view?id=${REQUEST}`));
  await expect(page.getByTestId('assign-personal')).toBeVisible();
  await page.getByRole('button', { name: 'Hisob menyusi' }).first().click();
  await page.getByRole('menuitem', { name: 'Chiqish' }).click();
  await page.waitForURL(/\/school\/login\/?/);
  await login(page, 'direktor', 'Direktor2026');
  await page.goto(url(`/care/requests/view?id=${REQUEST}`));
  await expect(page.getByTestId('assign-personal')).toHaveCount(0);
});
