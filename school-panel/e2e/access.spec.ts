import { expect, type Page, test } from '@playwright/test';

import { access as uzAccess } from '../src/i18n/uz/access';
import { access as ruAccess } from '../src/i18n/ru/access';
import { common as uzCommon } from '../src/i18n/uz/common';
import { errors as uzErrors } from '../src/i18n/uz/errors';
import { collectConsole, findStudent, printCalls, readDb, stubPrint } from './access-helpers';
import { login, trackErrors, url } from './helpers';

const SCHOOL_NAME = 'Parvoz namunaviy maktabi';
const PASSWORD = /^[a-z2-9]{8}$/;

const openAccessTab = async (page: Page, studentId: string) => {
  await page.goto(url(`/students/view?id=${studentId}&tab=access`));
  await expect(page.getByRole('tab', { name: 'Kirish' })).toHaveAttribute('aria-selected', 'true');
};

/** Barcha saqlash joylari (localStorage, sessionStorage) matni — parol bu yerda bo'lmasligi kerak. */
const storageDump = (page: Page) =>
  page.evaluate(() => JSON.stringify({ local: { ...localStorage }, session: { ...sessionStorage }, href: location.href }));

test.describe('Kirish ma\'lumotlari', () => {
  test.use({ permissions: ['clipboard-read', 'clipboard-write'] });

  test('direktor: berish → bir martalik parol (nusxalash) → yopilgach hech qayerda yo\'q → tiklash (boshqa qurilmalardan chiqarish yoqilgan)', async ({ page }) => {
    const errors = trackErrors(page);
    const logs = collectConsole(page);
    await login(page, 'direktor', 'Direktor2026');
    const student = await findStudent(page, 'linkedNoCredentials');
    await openAccessTab(page, student.id);
    const main = page.getByRole('main');

    await expect(main.getByRole('heading', { name: uzAccess.credentials.title })).toBeVisible();
    await expect(main.getByText(uzAccess.credentials.none.title)).toBeVisible();
    await main.getByRole('button', { name: uzAccess.credentials.issue, exact: true }).click();

    // 1-qadam: tasdiqlash (login ixtiyoriy, fokus maydonda).
    const dialog = page.getByRole('dialog');
    await expect(dialog.getByRole('heading', { name: uzAccess.issueDialog.issueTitle })).toBeVisible();
    await expect(dialog.getByRole('textbox', { name: /Login/ })).toBeFocused();
    await dialog.getByRole('button', { name: uzAccess.issueDialog.submitIssue, exact: true }).click();

    // 2-qadam: bir martalik ochish.
    await expect(dialog.getByRole('heading', { name: uzAccess.reveal.title })).toBeVisible();
    await expect(dialog.getByRole('note')).toContainText(uzAccess.reveal.warning);
    const password = (await dialog.getByTestId('issued-password').innerText()).trim();
    const loginName = (await dialog.getByTestId('issued-login').innerText()).trim();
    expect(password).toMatch(PASSWORD);
    expect(loginName).toMatch(/^[a-z][a-z0-9._]{3,23}$/);
    await expect(dialog.getByRole('button', { name: uzAccess.reveal.copyPassword })).toBeFocused();

    await dialog.getByRole('button', { name: uzAccess.reveal.copyPassword }).click();
    await expect(page.getByText(uzCommon.copied)).toBeVisible();
    expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(password);
    await dialog.getByRole('button', { name: uzAccess.reveal.copyLogin }).click();
    expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(loginName);

    // Oyna tashqarisini bosish yopmaydi (bir martalik parol tasodifan yo'qolmasin); «Tayyor» yopadi.
    await page.mouse.click(5, 5);
    await expect(dialog).toBeVisible();
    await dialog.getByRole('button', { name: uzAccess.reveal.done, exact: true }).click();
    await expect(dialog).toBeHidden();

    // Parol hech qayerda: sahifa, URL, storage, konsol.
    await expect(page.locator('body')).not.toContainText(password);
    expect(await storageDump(page)).not.toContain(password);
    expect(logs.join('\n')).not.toContain(password);

    // Karta holati: login, kim bergan, vaqtinchalik parol.
    await expect(main.getByTestId('credentials-login')).toHaveText(loginName);
    await expect(main.getByText(uzAccess.credentials.passwordState.temporary, { exact: true })).toBeVisible();
    await expect(main.getByText(uzAccess.credentials.passwordState.temporaryHint)).toBeVisible();
    await expect(main.getByText(uzAccess.credentials.neverLoggedIn)).toBeVisible();

    // Tiklash: «boshqa qurilmalardan chiqarish» standart yoqilgan va tushuntirilgan.
    await main.getByRole('button', { name: uzAccess.credentials.reset, exact: true }).click();
    await expect(dialog.getByRole('heading', { name: uzAccess.issueDialog.resetTitle })).toBeVisible();
    const signOut = dialog.getByRole('switch', { name: uzAccess.issueDialog.signOut });
    await expect(signOut).toHaveAttribute('aria-checked', 'true');
    await expect(dialog.getByText(uzAccess.issueDialog.signOutHint)).toBeVisible();
    await signOut.click();
    await expect(signOut).toHaveAttribute('aria-checked', 'false');
    await signOut.click();
    await expect(signOut).toHaveAttribute('aria-checked', 'true');
    await dialog.getByRole('button', { name: uzAccess.issueDialog.submitReset, exact: true }).click();

    const resetPassword = (await dialog.getByTestId('issued-password').innerText()).trim();
    expect(resetPassword).toMatch(PASSWORD);
    expect(resetPassword).not.toBe(password);
    await expect(dialog.getByTestId('issued-login')).toHaveText(loginName);

    // Escape ham yopadi; parol yana yo'q.
    await page.keyboard.press('Escape');
    await expect(dialog).toBeHidden();
    await expect(main.getByRole('button', { name: uzAccess.credentials.reset, exact: true })).toBeFocused();
    await expect(page.locator('body')).not.toContainText(resetPassword);
    const dump = await storageDump(page);
    expect(dump).not.toContain(resetPassword);
    expect(dump).not.toContain(password);
    expect(logs.join('\n')).not.toContain(resetPassword);

    // Audit: parolsiz.
    const audit = (await readDb(page)).tables as unknown as { audit: Array<{ action: string; summary: string }> };
    expect(audit.audit.filter((a) => a.action.startsWith('student.credentials.')).map((a) => a.action)).toEqual(['student.credentials.issue', 'student.credentials.reset']);
    expect(JSON.stringify(audit.audit)).not.toContain(resetPassword);
    expect(errors).toEqual([]);
  });

  test('faqat klaviatura: Enter bilan ochiladi, matn kiritiladi, Enter bilan yuboriladi, Escape yopadi va fokus tugmaga qaytadi', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    const student = await findStudent(page, 'linkedNoCredentials');
    await openAccessTab(page, student.id);
    const issue = page.getByRole('main').getByRole('button', { name: uzAccess.credentials.issue, exact: true });
    await issue.focus();
    await page.keyboard.press('Enter');

    const dialog = page.getByRole('dialog');
    const field = dialog.getByRole('textbox', { name: /Login/ });
    await expect(field).toBeFocused();
    await page.keyboard.type('klaviatura.7');
    await page.keyboard.press('Enter');
    await expect(dialog.getByTestId('issued-login')).toHaveText('klaviatura.7');
    await expect(dialog.getByRole('button', { name: uzAccess.reveal.copyPassword })).toBeFocused();

    // Tab aylanasi dialog ichida qoladi (fokus ushlagichi): 4 ta tabdan keyin ham dialog ichida.
    for (let i = 0; i < 6; i++) await page.keyboard.press('Tab');
    expect(await dialog.evaluate((el) => el.contains(document.activeElement))).toBe(true);

    await page.keyboard.press('Escape');
    await expect(dialog).toBeHidden();
    // «Berish» tugmasi yo'qoldi (karta tafsilotga o'tdi) — fokus faol tab paneliga qaytadi, `body` ga tushmaydi.
    await expect(page.getByRole('tabpanel')).toBeFocused();
  });

  test('band login: maydonda xato, oyna ochiq qoladi; yaroqsiz format; keyin yangi login qabul qilinadi', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    const student = await findStudent(page, 'linkedNoCredentials');
    const taken = (await readDb(page)).tables.access.credentials[0]?.login ?? '';
    expect(taken).not.toBe('');
    await openAccessTab(page, student.id);
    await page.getByRole('main').getByRole('button', { name: uzAccess.credentials.issue, exact: true }).click();
    const dialog = page.getByRole('dialog');
    const field = dialog.getByRole('textbox', { name: /Login/ });
    const submit = dialog.getByRole('button', { name: uzAccess.issueDialog.submitIssue, exact: true });

    // Xato ikki joyda: ko'rinadigan matn (FormField) va ekran o'qish dasturi uchun darhol e'lon qilinadigan `alert`.
    const visibleError = dialog.locator('p.text-destructive');
    await field.fill('a b');
    await submit.click();
    await expect(visibleError).toHaveText(uzErrors.form.invalidLogin);
    await expect(dialog.getByRole('alert')).toHaveText(uzErrors.form.invalidLogin);
    await expect(field).toHaveAttribute('aria-invalid', 'true');

    await field.fill(taken.toUpperCase());
    await submit.click();
    await expect(visibleError).toHaveText(uzErrors.detail.LOGIN_TAKEN);
    await expect(dialog.getByRole('alert')).toHaveText(uzErrors.detail.LOGIN_TAKEN);
    await expect(dialog.getByRole('heading', { name: uzAccess.issueDialog.issueTitle })).toBeVisible();

    await field.fill('yangi.bola7');
    await expect(visibleError).toHaveCount(0);
    await expect(dialog.getByRole('alert')).toHaveCount(0);
    await submit.click();
    await expect(dialog.getByTestId('issued-login')).toHaveText('yangi.bola7');
  });

  test('chop etiladigan karta: login + parol + yo\'riqnoma; faqat karta chop etiladi; oyna yopilsa karta ham yo\'qoladi', async ({ page }) => {
    await stubPrint(page);
    await login(page, 'admin', 'Admin2026');
    const student = await findStudent(page, 'linkedNoCredentials');
    await openAccessTab(page, student.id);
    await page.getByRole('main').getByRole('button', { name: uzAccess.credentials.issue, exact: true }).click();
    const dialog = page.getByRole('dialog');
    await dialog.getByRole('button', { name: uzAccess.issueDialog.submitIssue, exact: true }).click();
    const password = (await dialog.getByTestId('issued-password').innerText()).trim();
    const loginName = (await dialog.getByTestId('issued-login').innerText()).trim();

    // Chop etish tugmasidan oldin karta DOM'da yo'q (parol ortiqcha joyda turmaydi).
    await expect(page.getByTestId('credential-print-card')).toHaveCount(0);
    await dialog.getByRole('button', { name: uzAccess.reveal.print }).click();
    await expect.poll(() => printCalls(page)).toBe(1);

    await page.emulateMedia({ media: 'print' });
    const card = page.getByTestId('credential-print-card');
    await expect(card).toBeVisible();
    await expect(card).toContainText(SCHOOL_NAME);
    await expect(card).toContainText(student.name);
    await expect(card).toContainText(loginName);
    await expect(card).toContainText(password);
    await expect(card).toContainText(uzAccess.card.step3);
    await expect(card).toContainText('Birinchi kirishda yangi parol oʻrnatasan');
    // Chop etishda boshqa hech narsa: sahifa, menyu, oyna.
    await expect(page.getByRole('main')).toBeHidden();
    await expect(page.locator('aside')).toBeHidden();
    await expect(dialog).toBeHidden();

    await page.emulateMedia({ media: 'screen' });
    await expect(card).toBeHidden();
    await expect(dialog).toBeVisible();

    // Chop etish oynasi yopilganda (afterprint) karta DOM'dan olinadi.
    await page.evaluate(() => window.dispatchEvent(new Event('afterprint')));
    await expect(page.getByTestId('credential-print-card')).toHaveCount(0);

    // Oyna yopilgach parol hech qayerda yo'q.
    await dialog.getByRole('button', { name: uzAccess.reveal.done, exact: true }).click();
    await expect(page.locator('body')).not.toContainText(password);
  });

  test('ulanmagan o\'quvchi: sababi tushuntiriladi (ota-ona avval ulashi kerak), berish tugmasi yo\'q; taklif kodi bor', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    const student = await findStudent(page, 'unlinked');
    await openAccessTab(page, student.id);
    const main = page.getByRole('main');
    const note = main.getByTestId('credentials-not-linked');
    await expect(note).toContainText(uzAccess.credentials.notLinked.title);
    await expect(note).toContainText('ota-ona');
    await expect(main.getByRole('button', { name: uzAccess.credentials.issue })).toHaveCount(0);
    await expect(main.getByRole('button', { name: uzAccess.credentials.reset })).toHaveCount(0);
    await expect(main.getByRole('button', { name: uzAccess.invite.create })).toBeVisible();
  });

  test('NOT_LINKED (oyna ochiq turganda boshqa xodim ulanishni uzdi): toast, oyna yopiladi, karta «ulanmagan» holatida', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    const student = await findStudent(page, 'linkedNoCredentials');
    await openAccessTab(page, student.id);
    const main = page.getByRole('main');
    await main.getByRole('button', { name: uzAccess.credentials.issue, exact: true }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toBeVisible();

    // Boshqa tab (bir xil brauzer): shu o'quvchining ulanishi uziladi — `storage` hodisasi bu tabdagi bazani yangilaydi.
    const other = await page.context().newPage();
    await other.goto(url('/dashboard'));
    await expect(other.locator('main h1').first()).toBeVisible();
    await other.evaluate((id) => {
      const key = 'parvoz-school:db:v1';
      const db = JSON.parse(localStorage.getItem(key) ?? '{}') as { tables: { access: { linkedStudentIds: string[] } } };
      db.tables.access.linkedStudentIds = db.tables.access.linkedStudentIds.filter((x) => x !== id);
      localStorage.setItem(key, JSON.stringify(db));
    }, student.id);
    // Yozuvchi tab hodisa yetkazilguncha ochiq turadi (darhol yopilsa brauzer `storage` hodisasini yuborib ulgurmasligi mumkin).
    // Modal ochiq: `main` aria-hidden — shuning uchun rol bo'yicha emas, test id bo'yicha izlanadi.
    await expect(page.getByTestId('credentials-not-linked')).toBeVisible();
    await other.close();

    await dialog.getByRole('button', { name: uzAccess.issueDialog.submitIssue, exact: true }).click();
    await expect(page.getByText(uzErrors.detail.NOT_LINKED).first()).toBeVisible();
    await expect(dialog).toBeHidden();
    await expect(main.getByTestId('credentials-not-linked')).toBeVisible();
    await expect(main.getByRole('button', { name: uzAccess.credentials.issue })).toHaveCount(0);
  });
});

test.describe('Taklif kodi', () => {
  test('sinf rahbari: kod yaratadi (3+3, muddat sanog\'i, ikki o\'rin), chop etish ko\'rinishi, tasdiq bilan yangilaydi; kirish ma\'lumotlari kartasi yo\'q', async ({ page }) => {
    await stubPrint(page);
    const errors = trackErrors(page);
    await login(page, 'sinf7a', 'Sinf2026');
    const student = await findStudent(page, 'linkedNoCredentials', 'cls-7a');
    await openAccessTab(page, student.id);
    const main = page.getByRole('main');

    await expect(main.getByRole('heading', { name: uzAccess.invite.title })).toBeVisible();
    // Sinf rahbarida `students.manage` yo'q — kirish ma'lumotlari kartasi ham, tiklash so'rovlari ham ko'rinmaydi.
    await expect(main.getByRole('heading', { name: uzAccess.credentials.title })).toHaveCount(0);
    await expect(main.getByTestId('recovery-card')).toHaveCount(0);

    await expect(main.getByText(uzAccess.invite.none.title)).toBeVisible();
    await main.getByRole('button', { name: uzAccess.invite.create }).click();
    const code = main.getByTestId('invite-code');
    await expect(code).toHaveText(/^\d{3} \d{3}$/);
    const first = (await code.innerText()).trim();
    await expect(main.getByTestId('invite-expiry')).toContainText(/(23 soat \d{1,2} daq|24 soat) qoldi/);
    const slots = main.getByRole('list', { name: uzAccess.invite.slotsLabel });
    await expect(slots.getByRole('listitem')).toHaveCount(2);
    await expect(slots).toContainText(`${uzAccess.invite.slot.student}: ${uzAccess.invite.slotState.pending}`);
    await expect(slots).toContainText(`${uzAccess.invite.slot.parent}: ${uzAccess.invite.slotState.pending}`);
    // Ekran o'qish dasturi uchun raqamlar alohida o'qiladi.
    const spoken = [...first.replace(' ', '')].join(' ');
    await expect(main.locator('.sr-only').filter({ hasText: spoken.slice(0, 5) })).toHaveCount(1);

    // Chop etish ko'rinishi.
    await main.getByRole('button', { name: uzAccess.invite.print }).click();
    await expect.poll(() => printCalls(page)).toBe(1);
    await page.emulateMedia({ media: 'print' });
    const card = page.getByTestId('invite-print-card');
    await expect(card).toBeVisible();
    await expect(card).toContainText(SCHOOL_NAME);
    await expect(card).toContainText(first);
    await expect(card).toContainText(student.name);
    await expect(card).toContainText(uzAccess.inviteCard.childTitle);
    await expect(card).toContainText(uzAccess.inviteCard.parentText);
    await expect(page.getByRole('main')).toBeHidden();
    await page.emulateMedia({ media: 'screen' });
    await expect(card).toBeHidden();
    await page.evaluate(() => window.dispatchEvent(new Event('afterprint')));
    await expect(page.getByTestId('invite-print-card')).toHaveCount(0);

    // Yangilash: avval bekor qilish (kod o'zgarmaydi), keyin tasdiq (yangi kod).
    const regenerate = main.getByRole('button', { name: uzAccess.invite.regenerate });
    await regenerate.click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toContainText(uzAccess.invite.confirmText);
    await dialog.getByRole('button', { name: 'Bekor qilish' }).click();
    await expect(dialog).toBeHidden();
    await expect(regenerate).toBeFocused();
    await expect(code).toHaveText(first);

    await regenerate.click();
    await dialog.getByRole('button', { name: uzAccess.invite.confirm, exact: true }).click();
    await expect(dialog).toBeHidden();
    await expect(code).not.toHaveText(first);
    await expect(code).toHaveText(/^\d{3} \d{3}$/);

    // Baza: bitta faol kod (oldingisi yopilgan), audit kodni o'zini yozmaydi.
    const db = await readDb(page);
    const mine = db.tables.access.inviteCodes.filter((c) => c.studentId === student.id);
    expect(mine).toHaveLength(2);
    expect(mine.filter((c) => c.closedAt === null)).toHaveLength(1);
    expect(errors).toEqual([]);
  });

  test('sinf rahbari boshqa sinf o\'quvchisining kartasida ham kod ololmaydi (ruxsat yo\'q)', async ({ page }) => {
    await login(page, 'sinf7a', 'Sinf2026');
    const student = await findStudent(page, 'unlinked', 'cls-8b');
    await page.goto(url(`/students/view?id=${student.id}&tab=access`));
    // O'quvchi kartasi o'zi doiradan tashqari — xato holati, kod tugmasi yo'q.
    await expect(page.getByRole('button', { name: uzAccess.invite.create })).toHaveCount(0);
    await expect(page.getByRole('main')).toContainText(uzErrors.FORBIDDEN);
  });

  test('tekshiruv kutayotgan o\'quvchi: kodda «Oʻquvchi: foydalanildi»', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    const { tables } = await readDb(page);
    const review = tables.access.linkRequests.find((r) => r.kind === 'REVIEW');
    expect(review).toBeTruthy();
    await openAccessTab(page, review?.studentId ?? '');
    const slots = page.getByRole('main').getByRole('list', { name: uzAccess.invite.slotsLabel });
    await expect(slots).toContainText(`${uzAccess.invite.slot.student}: ${uzAccess.invite.slotState.used}`);
  });
});

test.describe('Parol tiklash so\'rovlari', () => {
  test('rad etish: tasdiq oynasi, so\'rov yo\'qoladi, parol/login o\'zgarmaydi', async ({ page }) => {
    const errors = trackErrors(page);
    await login(page, 'admin', 'Admin2026');
    const student = await findStudent(page, 'openRecovery');
    const before = (await readDb(page)).tables.access.credentials.find((c) => c.studentId === student.id);
    await openAccessTab(page, student.id);
    const main = page.getByRole('main');
    const card = main.getByTestId('recovery-card');
    await expect(card).toBeVisible();
    await expect(card.getByRole('heading', { name: new RegExp(uzAccess.recovery.title) })).toBeVisible();
    await expect(card.getByTestId('recovery-request')).toHaveCount(1);
    await expect(card.getByTestId('recovery-request')).toContainText(/Soʻrov: .+/);

    await card.getByRole('button', { name: uzAccess.recovery.reject, exact: true }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog.getByRole('heading', { name: uzAccess.recovery.rejectTitle })).toBeVisible();
    await expect(dialog).toContainText(uzAccess.recovery.rejectText);
    await dialog.getByRole('button', { name: uzAccess.recovery.reject, exact: true }).click();

    await expect(page.getByText(uzAccess.recovery.rejected).first()).toBeVisible();
    await expect(card).toHaveCount(0);
    const after = (await readDb(page)).tables.access;
    expect(after.recoveryRequests.find((r) => r.studentId === student.id)?.status).toBe('REJECTED');
    expect(after.credentials.find((c) => c.studentId === student.id)).toEqual(before);
    expect(errors).toEqual([]);
  });

  test('«Parolni tiklash»: tiklash oynasi ochiladi, bajarilgach so\'rov hal bo\'ladi (RESTORED)', async ({ page }) => {
    await login(page, 'direktor', 'Direktor2026');
    // Direktorda ham `students.manage` bor, lekin bildirishnoma faqat sinf rahbari/adminga — kartada ko'rinadi.
    const student = await findStudent(page, 'openRecovery');
    await openAccessTab(page, student.id);
    const main = page.getByRole('main');
    const card = main.getByTestId('recovery-card');
    await card.getByRole('button', { name: uzAccess.recovery.reset, exact: true }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog.getByRole('heading', { name: uzAccess.issueDialog.resetTitle })).toBeVisible();
    await dialog.getByRole('button', { name: uzAccess.issueDialog.submitReset, exact: true }).click();
    await expect(dialog.getByTestId('issued-password')).toHaveText(PASSWORD);
    await dialog.getByRole('button', { name: uzAccess.reveal.done, exact: true }).click();
    await expect(card).toHaveCount(0);
    expect((await readDb(page)).tables.access.recoveryRequests.find((r) => r.studentId === student.id)?.status).toBe('RESTORED');
  });
});

test.describe('Chuqur havola', () => {
  test('/students?search=… qidiruvni oldindan to\'ldiradi (parol tiklash bildirishnomasidan o\'tish)', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    const student = await findStudent(page, 'openRecovery');
    await page.goto(url(`/students?search=${encodeURIComponent(student.name)}`));
    await expect(page.getByRole('textbox', { name: 'Qidirish' })).toHaveValue(student.name);
    await expect(page.getByRole('main').getByText(student.name, { exact: true }).first()).toBeVisible();
  });
});

test.describe('Rollar va til', () => {
  test('psixolog «Kirish» tabini ko\'rmaydi; ?tab=access profilga qaytadi', async ({ page }) => {
    await login(page, 'psixolog', 'Psixolog2026');
    const { tables } = await readDb(page);
    const id = tables.students[0]?.id ?? '';
    await page.goto(url(`/students/view?id=${id}&tab=access`));
    await expect(page.getByRole('tab', { name: 'Profil' })).toHaveAttribute('aria-selected', 'true');
    await expect(page.getByRole('tab', { name: 'Kirish' })).toHaveCount(0);
  });

  test('ruscha interfeys: sarlavhalar, tugmalar va kod kartasi tarjima qilingan', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    const student = await findStudent(page, 'linkedNoCredentials');
    await openAccessTab(page, student.id);
    await page.getByRole('button', { name: 'RU', exact: true }).click();
    const main = page.getByRole('main');
    await expect(page.getByRole('tab', { name: 'Вход' })).toHaveAttribute('aria-selected', 'true');
    await expect(main.getByRole('heading', { name: ruAccess.credentials.title })).toBeVisible();
    await expect(main.getByRole('heading', { name: ruAccess.invite.title })).toBeVisible();
    await main.getByRole('button', { name: ruAccess.invite.create }).click();
    await expect(main.getByTestId('invite-expiry')).toContainText(/Осталось (23 ч \d{1,2} мин|24 ч)/);
    await expect(main.getByRole('list', { name: ruAccess.invite.slotsLabel })).toContainText(`${ruAccess.invite.slot.parent}: ${ruAccess.invite.slotState.pending}`);
    await main.getByRole('button', { name: ruAccess.credentials.issue, exact: true }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog.getByRole('heading', { name: ruAccess.issueDialog.issueTitle })).toBeVisible();
    await dialog.getByRole('button', { name: ruAccess.issueDialog.submitIssue, exact: true }).click();
    await expect(dialog.getByRole('heading', { name: ruAccess.reveal.title })).toBeVisible();
    await expect(dialog.getByRole('note')).toContainText(ruAccess.reveal.warning);
  });
});

test.describe('390px', () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test('«Kirish» tabi ekranga sig\'adi: tiklash so\'rovi, taklif kodi va kirish ma\'lumotlari', async ({ page }) => {
    await login(page, 'admin', 'Admin2026');
    const student = await findStudent(page, 'openRecovery');
    await openAccessTab(page, student.id);
    const main = page.getByRole('main');
    const recovery = main.getByTestId('recovery-card');
    await expect(recovery).toBeVisible();
    await main.getByRole('button', { name: uzAccess.invite.create }).click();
    await expect(main.getByTestId('invite-code')).toBeVisible();
    await expect(main.getByTestId('credentials-details')).toBeVisible();
    for (const name of [uzAccess.recovery.reject, uzAccess.recovery.reset]) {
      const box = await recovery.getByRole('button', { name, exact: true }).boundingBox();
      expect(box, name).not.toBeNull();
      expect((box?.x ?? 0) + (box?.width ?? 0), name).toBeLessThanOrEqual(390);
    }
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
  });
});
