import { expect, type Page, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

/** Ssenariy soati: dushanba 08:00 — 1-smena boshlangan, kiosk ishlaydi. */
/** 07:05 — 1-smena ochiq, demo simulyatori hali hech kimni «keldi» qilmagan. */
const EARLY_MINUTE = 7 * 60 + 5;
const SCENARIO = { mode: 'SCENARIO', speed: 1, scenarioDate: '2026-10-12', scenarioStartMinute: 8 * 60, realStartedAt: 0, epoch: 7 };

const EARLY = { ...SCENARIO, scenarioStartMinute: EARLY_MINUTE };

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

test('kiosk orqali kirish ikkinchi tabdagi sinf ro\'yxatida darhol ko\'rinadi', async ({ context, page }) => {
  await login(page, 'navbatchi', 'Navbatchi2026');
  // 07:00 — hali hech kim kelmagan, o'quvchi "kutilmoqda".
  const student = await page.evaluate((clock) => {
    localStorage.setItem('parvoz-school:clock', JSON.stringify({ ...clock, scenarioStartMinute: 7 * 60, epoch: 11, realStartedAt: Date.now() }));
    const raw = localStorage.getItem('parvoz-school:db:v1');
    const db = raw ? (JSON.parse(raw) as { tables: { students: Array<{ studentCode: string; classId: string; archived: boolean; lastName: string; firstName: string }> } }) : null;
    const s = db?.tables.students.find((x) => !x.archived && x.classId === 'cls-9a');
    return s ? { code: s.studentCode, name: `${s.lastName} ${s.firstName}` } : null;
  }, SCENARIO);
  expect(student).not.toBeNull();
  if (!student) return;

  const board = await context.newPage();
  await board.goto(url('/attendance/class?id=cls-9a'));
  const row = board.getByRole('row').filter({ hasText: student.name });
  await expect(row).toBeVisible();
  // Ustunlar: №, o'quvchi, holat, kirish, … (oxirida "Keldi" tugmasi ham bor — faqat holat katagi).
  const status = row.getByRole('cell').nth(2);
  await expect(status).not.toContainText('Keldi');

  await page.goto(url('/kiosk'));
  await page.getByLabel('P-1234').fill(student.code.slice(2));
  await expect(page.getByRole('alertdialog')).toContainText('Xush kelibsiz');
  await expect(status).toContainText('Keldi', { timeout: 5_000 });
  await expect(row.getByRole('cell').nth(3)).toContainText(/\d{2}:\d{2}/);
});

test('kiosk: USB o\'qigich (klaviatura rejimi) kartani to\'g\'ridan-to\'g\'ri qayd etadi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'navbatchi', 'Navbatchi2026');
  const uid = await page.evaluate((clock) => {
    localStorage.setItem('parvoz-school:clock', JSON.stringify({ ...clock, realStartedAt: Date.now() }));
    const raw = localStorage.getItem('parvoz-school:db:v1');
    type Db = {
      tables: {
        cards: Array<{ uid: string; kind: string; status: string; studentId: string }>;
        students: Array<{ id: string; classId: string; archived: boolean }>;
        attendance: Array<{ studentId: string; date: string; inAt: string | null }>;
      };
    };
    const db = raw ? (JSON.parse(raw) as Db) : null;
    const inClass = new Set((db?.tables.students ?? []).filter((s) => !s.archived && s.classId === 'cls-9a').map((s) => s.id));
    // Bugun hali kelmagan o'quvchi (kelgan bo'lsa, tegish endi «chiqdi» bo'ladi).
    const arrived = new Set((db?.tables.attendance ?? []).filter((r) => r.date === clock.scenarioDate && r.inAt).map((r) => r.studentId));
    return db?.tables.cards.find((c) => c.kind === 'UID' && c.status === 'ACTIVE' && inClass.has(c.studentId) && !arrived.has(c.studentId))?.uid ?? '';
  }, EARLY);
  expect(uid).toMatch(/^[0-9A-F]{14}$/);

  await page.goto(url('/kiosk'));
  await expect(page.getByText('Kartani o\'qigichga tegizing')).toBeVisible();
  const input = page.getByLabel('P-1234');
  await expect(input).toBeFocused();

  // O'qigich: belgilar bir zumda va Enter — kod maydoniga yuborilmaydi, karta sifatida o'tadi.
  await readerTap(page, uid);
  const result = page.getByRole('alertdialog');
  await expect(result).toContainText(/Xush kelibsiz|Kechikdingiz|Allaqachon/);
  await expect(result).not.toContainText('Kod topilmadi');
  await result.click();
  await expect(result).toBeHidden();
  await expect(input).toHaveValue('');

  // Ro'yxatda yo'q karta (o'nlik ko'rinishda) — "Karta tanilmadi".
  await readerTap(page, '0012345678');
  await expect(result).toContainText('Karta tanilmadi');
  await result.click();
  await expect(result).toBeHidden();

  // Sekin o'qigich (karta sifatida tanilmagan): kod maydoni raqamni kod deb yubormaydi.
  await input.focus();
  await page.keyboard.type('0012345678', { delay: 120 });
  await page.keyboard.press('Enter');
  await page.waitForTimeout(600);
  await expect(result).toBeHidden();
  await expect(input).toHaveValue('');
  expect(errors).toEqual([]);
});

/**
 * USB o'qigichni taqlid qiladi: tugmalar bir zumda (CI sekin bo'lsa ham) va oxirida Enter.
 * Sintetik hodisalar maydonga yozilmaydi — faqat sahifadagi o'qigich ushlagichi ko'radi.
 */
async function readerTap(page: Page, text: string): Promise<void> {
  await page.evaluate((chars) => {
    const target = document.activeElement ?? document.body;
    const fire = (key: string, code: string) => target.dispatchEvent(new KeyboardEvent('keydown', { key, code, bubbles: true, cancelable: true }));
    for (const ch of chars) fire(ch, /\d/.test(ch) ? `Digit${ch}` : `Key${ch.toUpperCase()}`);
    fire('Enter', 'Enter');
  }, text);
}
