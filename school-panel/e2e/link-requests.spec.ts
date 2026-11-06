import { expect, test } from '@playwright/test';

import { access as uzAccess } from '../src/i18n/uz/access';
import { linkRequests as ruLink } from '../src/i18n/ru/linkRequests';
import { linkRequests as uzLink } from '../src/i18n/uz/linkRequests';
import { notifications as uzNotifications } from '../src/i18n/uz/notifications';
import { readDb } from './access-helpers';
import { login, trackErrors, url } from './helpers';

const PAGE = '/students/link-requests';
const REQUESTS_URL = /\/students\/link-requests\/?$/;

const navLink = (page: import('@playwright/test').Page) => page.locator('aside').getByRole('link', { name: /Ulanish soʻrovlari/ });

test.describe('Ulanish soʻrovlari', () => {
  test('admin: tekshiruv va tuzatish bo\'limlari, nishon; tasdiqlash o\'quvchini bola profiliga ulaydi (kirish ma\'lumotlari endi mumkin)', async ({ page }) => {
    const errors = trackErrors(page);
    await login(page, 'admin', 'Admin2026');
    await page.goto(url(PAGE));
    const main = page.getByRole('main');
    await expect(main.getByRole('heading', { name: uzLink.title, level: 1 })).toBeVisible();
    await expect(main).toContainText(uzLink.privacy);

    const review = main.getByRole('region', { name: uzLink.listLabel }).getByRole('region', { name: new RegExp(uzLink.review.title) });
    await expect(review.getByTestId('link-request')).toHaveCount(3);
    const correction = main.getByRole('region', { name: new RegExp(uzLink.correction.title) });
    await expect(correction.getByTestId('link-request')).toHaveCount(2);
    // Menyu: faol bo'lim faqat «Ulanish so'rovlari» (O'quvchilar emas) va ochiq so'rovlar soni.
    await expect(navLink(page)).toHaveAttribute('href', /\/students\/link-requests\/?$/);
    await expect(navLink(page)).toContainText('5');
    await expect(navLink(page)).toHaveAccessibleName(/Ochiq soʻrovlar: 5/);
    await expect(page.locator('aside').getByRole('link', { name: "O'quvchilar", exact: true })).not.toHaveClass(/from-primary/);

    // Har bir tekshiruv: o'quvchi, sinf, vaqt, ota-ona kodi holati.
    const first = review.getByTestId('link-request').first();
    await expect(first.getByRole('link')).toHaveAttribute('href', /\/students\/view\/?\?id=/);
    await expect(first).toContainText(/Soʻrov: .+ · \d{2}\.\d{2}\.\d{4}, \d{2}:\d{2}/);
    await expect(first).toContainText(/Ota-ona kodi: (kiritilgan|kiritilmagan)/);
    const studentName = (await first.getByRole('link').innerText()).trim();
    const studentId = new URL((await first.getByRole('link').getAttribute('href')) ?? '', 'http://x').searchParams.get('id') ?? '';
    expect(studentId).not.toBe('');
    expect((await readDb(page)).tables.access.linkedStudentIds).not.toContain(studentId);

    // Tasdiqlash — tasdiq oynasi (oqibati tushuntiriladi), bekor qilsa hech narsa o'zgarmaydi.
    await first.getByRole('button', { name: uzLink.review.confirm, exact: true }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog.getByRole('heading', { name: uzLink.review.confirmTitle })).toBeVisible();
    await expect(dialog).toContainText(studentName);
    await dialog.getByRole('button', { name: 'Bekor qilish' }).click();
    await expect(dialog).toBeHidden();
    await expect(review.getByTestId('link-request')).toHaveCount(3);
    await expect(first.getByRole('button', { name: uzLink.review.confirm, exact: true })).toBeFocused();

    await first.getByRole('button', { name: uzLink.review.confirm, exact: true }).click();
    await dialog.getByRole('button', { name: uzLink.review.confirm, exact: true }).click();
    await expect(page.getByText(uzLink.toast.confirmed).first()).toBeVisible();
    await expect(review.getByTestId('link-request')).toHaveCount(2);
    await expect(page.getByRole('region', { name: uzLink.listLabel })).toBeFocused();
    await expect(navLink(page)).toHaveAccessibleName(/Ochiq soʻrovlar: 4/);
    expect((await readDb(page)).tables.access.linkedStudentIds).toContain(studentId);

    // Endi o'quvchi bola profiliga ulangan: kirish ma'lumotlarini berish mumkin.
    await page.goto(url(`/students/view?id=${studentId}&tab=access`));
    await expect(page.getByRole('main').getByRole('button', { name: uzAccess.credentials.issue, exact: true })).toBeVisible();
    expect(errors).toEqual([]);
  });

  test('rad etish: tasdiq oynasi, so\'rov yo\'qoladi, o\'quvchi ulanmaydi, kodda o\'quvchi o\'rni bo\'shaydi', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    await page.goto(url(PAGE));
    const main = page.getByRole('main');
    const review = main.getByRole('region', { name: new RegExp(uzLink.review.title) });
    const item = review.getByTestId('link-request').first();
    const studentId = new URL((await item.getByRole('link').getAttribute('href')) ?? '', 'http://x').searchParams.get('id') ?? '';

    await item.getByRole('button', { name: uzLink.review.reject, exact: true }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog.getByRole('heading', { name: uzLink.review.rejectTitle })).toBeVisible();
    await expect(dialog).toContainText('Kod oʻrni boʻshaydi');
    await dialog.getByRole('button', { name: uzLink.review.reject, exact: true }).click();

    await expect(page.getByText(uzLink.toast.rejected).first()).toBeVisible();
    await expect(review.getByTestId('link-request')).toHaveCount(2);
    const db = await readDb(page);
    expect(db.tables.access.linkedStudentIds).not.toContain(studentId);
    expect(db.tables.access.linkRequests.find((r) => r.studentId === studentId)?.status).toBe('REJECTED');

    // O'quvchi kartasida kod o'rni yana bo'sh.
    await page.goto(url(`/students/view?id=${studentId}&tab=access`));
    await expect(page.getByRole('main').getByRole('list', { name: uzAccess.invite.slotsLabel })).toContainText(
      `${uzAccess.invite.slot.student}: ${uzAccess.invite.slotState.pending}`,
    );
  });

  test('tuzatish: bolaning izohi ko\'rinadi; «Ulanishni uzish» ulanishni uzadi, «Ulanishni saqlash» saqlaydi', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    await page.goto(url(PAGE));
    const main = page.getByRole('main');
    const correction = main.getByRole('region', { name: new RegExp(uzLink.correction.title) });
    const items = correction.getByTestId('link-request');
    await expect(items).toHaveCount(2);
    await expect(items.first().getByTestId('link-request-note')).not.toBeEmpty();
    await expect(items.first()).toContainText(uzLink.correction.note);
    await expect(items.first()).toContainText(uzLink.correction.reason.WRONG_SCHOOL_OR_CLASS);

    const idOf = async (n: number) => new URL((await items.nth(n).getByRole('link').getAttribute('href')) ?? '', 'http://x').searchParams.get('id') ?? '';
    const keepId = await idOf(0);
    const unlinkId = await idOf(1);

    await items.nth(0).getByRole('button', { name: uzLink.correction.keep, exact: true }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog.getByRole('heading', { name: uzLink.correction.keepTitle })).toBeVisible();
    await dialog.getByRole('button', { name: uzLink.correction.keep, exact: true }).click();
    await expect(page.getByText(uzLink.toast.kept).first()).toBeVisible();
    await expect(items).toHaveCount(1);

    await items.nth(0).getByRole('button', { name: uzLink.correction.unlink, exact: true }).click();
    await expect(dialog.getByRole('heading', { name: uzLink.correction.unlinkTitle })).toBeVisible();
    await dialog.getByRole('button', { name: uzLink.correction.unlink, exact: true }).click();
    await expect(page.getByText(uzLink.toast.unlinked).first()).toBeVisible();
    await expect(correction).toHaveCount(0);

    const linked = (await readDb(page)).tables.access.linkedStudentIds;
    expect(linked).toContain(keepId);
    expect(linked).not.toContain(unlinkId);
    // Tuzatishlar hal bo'ldi, 3 ta tekshiruv qoldi.
    await expect(navLink(page)).toHaveAccessibleName(/Ochiq soʻrovlar: 3/);

    // Uzilgan o'quvchiga kirish ma'lumotlari endi berilmaydi.
    await page.goto(url(`/students/view?id=${unlinkId}&tab=access`));
    await expect(page.getByTestId('credentials-not-linked')).toBeVisible();
  });

  test('hammasi hal qilinsa: bo\'sh holat va nishonsiz menyu', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    await page.goto(url(PAGE));
    const main = page.getByRole('main');
    const items = main.getByTestId('link-request');
    await expect(items).toHaveCount(5);
    // Tekshiruv — «Tasdiqlash», tuzatish — «Ulanishni saqlash» (ikkalasi ham ijobiy qaror).
    const positive = new RegExp(`^(${uzLink.review.confirm}|${uzLink.correction.keep})$`);
    for (let left = 5; left > 0; left--) {
      await items.first().getByRole('button', { name: positive }).click();
      await page.getByRole('dialog').getByRole('button', { name: positive }).click();
      await expect(items).toHaveCount(left - 1);
    }
    await expect(main.getByText(uzLink.empty.title)).toBeVisible();
    await expect(main.getByText(uzLink.empty.text)).toBeVisible();
    await expect(navLink(page)).toHaveAccessibleName('Ulanish soʻrovlari');
  });

  test('sinf rahbari: faqat o\'z sinfi (7-A) so\'rovlari; menyuda bor', async ({ page }) => {
    await login(page, 'sinf7a', 'Sinf2026');
    await expect(navLink(page)).toBeVisible();
    await page.goto(url(PAGE));
    const items = page.getByRole('main').getByTestId('link-request');
    await expect(items.first()).toBeVisible();
    const count = await items.count();
    expect(count).toBeGreaterThanOrEqual(2);
    expect(count).toBeLessThan(5);
    for (let i = 0; i < count; i++) await expect(items.nth(i).getByText('7-A', { exact: true })).toBeVisible();
    await expect(navLink(page)).toHaveAccessibleName(new RegExp(`Ochiq soʻrovlar: ${count}`));
  });

  test('psixolog va navbatchi: menyuda yo\'q, sahifa — «Ruxsat yo\'q»', async ({ page }) => {
    await login(page, 'psixolog', 'Psixolog2026');
    await expect(navLink(page)).toHaveCount(0);
    await page.goto(url(PAGE));
    await expect(page.locator('main h1').first()).toHaveText("Ruxsat yo'q");
  });

  test('ruscha interfeys', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    await page.goto(url(PAGE));
    await page.getByRole('button', { name: 'RU', exact: true }).click();
    const main = page.getByRole('main');
    await expect(main.getByRole('heading', { name: ruLink.title, level: 1 })).toBeVisible();
    await expect(main).toContainText(ruLink.privacy);
    await expect(main.getByRole('button', { name: ruLink.review.confirm, exact: true }).first()).toBeVisible();
    await expect(main.getByRole('button', { name: ruLink.correction.unlink, exact: true }).first()).toBeVisible();
    await expect(main).toContainText(ruLink.correction.note);
    await expect(page.locator('aside').getByRole('link', { name: new RegExp(ruLink.title) })).toBeVisible();
  });

  test.describe('390px', () => {
    test.use({ viewport: { width: 390, height: 844 } });

    test('ro\'yxat ekranga sig\'adi, amal tugmalari ko\'rinadi', async ({ page }) => {
      await login(page, 'admin', 'Admin2026');
      await page.goto(url(PAGE));
      const item = page.getByRole('main').getByTestId('link-request').first();
      await expect(item).toBeVisible();
      for (const name of [uzLink.review.confirm, uzLink.review.reject]) {
        const box = await item.getByRole('button', { name, exact: true }).boundingBox();
        expect(box, name).not.toBeNull();
        expect((box?.x ?? 0) + (box?.width ?? 0), name).toBeLessThanOrEqual(390);
      }
      expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
    });
  });
});

test.describe('Bildirishnomadan o\'tish', () => {
  test('sinf rahbari: «ulanishi tekshiruvni kutmoqda» → Ulanish so\'rovlari', async ({ page }) => {
    await login(page, 'sinf7a', 'Sinf2026');
    await page.getByRole('button', { name: /^Bildirishnomalar/ }).click();
    const popover = page.getByRole('dialog');
    const item = popover.getByRole('button', { name: /maktabga ulanishi tekshiruvni kutmoqda/ }).first();
    await expect(item).toBeVisible();
    await expect(item).toContainText(uzNotifications.category.LINK_REVIEW);
    await item.click();
    await expect(page).toHaveURL(REQUESTS_URL);
    await expect(page.getByRole('main').getByRole('heading', { name: uzLink.title, level: 1 })).toBeVisible();
  });

  test('admin: «kirish parolini tiklashni so\'radi» → o\'quvchi kartasi, «Kirish» tabi, so\'rov ko\'rinadi', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    await page.getByRole('button', { name: /^Bildirishnomalar/ }).click();
    const item = page.getByRole('dialog').getByRole('button', { name: /kirish parolini tiklashni soʻradi/ }).first();
    await expect(item).toContainText(uzNotifications.category.CHILD_RECOVERY_REQUEST);
    await item.click();
    await expect(page).toHaveURL(/\/students\/view\/?\?id=.+&tab=access/);
    await expect(page.getByRole('tab', { name: 'Kirish' })).toHaveAttribute('aria-selected', 'true');
    await expect(page.getByTestId('recovery-card')).toBeVisible();
  });
});
