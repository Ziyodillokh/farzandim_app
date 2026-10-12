import { expect, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

/** Ssenariy soati: dushanba 08:00 — 1-smena boshlangan, kiosk ishlaydi. */
const SCENARIO = { mode: 'SCENARIO', speed: 1, scenarioDate: '2026-10-12', scenarioStartMinute: 8 * 60, realStartedAt: 0, epoch: 7 };

test('kiosk: navbatchi shaxsiy kod bilan belgilaydi, noma\'lum kod rad etiladi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'navbatchi', 'Navbatchi2026');
  const codes = await page.evaluate((clock) => {
    localStorage.setItem('parvoz-school:clock', JSON.stringify({ ...clock, realStartedAt: Date.now() }));
    const raw = localStorage.getItem('parvoz-school:db:v1');
    const db = raw ? (JSON.parse(raw) as { tables: { students: Array<{ studentCode: string; classId: string; archived: boolean }> } }) : null;
    const students = db?.tables.students ?? [];
    const used = new Set(students.map((s) => s.studentCode));
    const known = students.find((s) => !s.archived && s.classId === 'cls-9a')?.studentCode ?? '';
    const unknown = ['P-0000', 'P-0001', 'P-0002', 'P-0003'].find((c) => !used.has(c)) ?? 'P-0004';
    return { known, unknown };
  }, SCENARIO);
  expect(codes.known).toMatch(/^P-\d{4}$/);

  await page.goto(url('/kiosk'));
  const input = page.getByLabel('P-1234');
  await input.fill(codes.known.slice(2));
  const result = page.getByRole('alertdialog');
  await expect(result).toContainText(/Xush kelibsiz|Kechikdingiz|Allaqachon/);
  await result.click();
  await expect(result).toBeHidden();

  await input.fill(codes.unknown.slice(2));
  await expect(result).toContainText('Kod topilmadi');
  expect(errors).toEqual([]);
});
