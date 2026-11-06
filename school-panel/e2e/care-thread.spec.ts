import { expect, type Page, test } from '@playwright/test';

import { login, trackErrors, url } from './helpers';

/** Seed: oddiy, ochilmagan, yangi murojaat (10-B). */
const NORMAL_NEW = 'care-2';
/** Seed: ochilgan, psixolog javob bergan, bolaning o'qilmagan xabari bor. */
const WITH_UNREAD = 'care-3';
/** Seed: shoshilinch, ochilmagan. */
const URGENT_NEW = 'care-1';
/** Seed: yopilgan (RESOLVED). */
const RESOLVED = 'care-5';
const PSYCHOLOGIST = 'Sobirova Lola Baxromovna';
const DEPUTY = 'Karimova Kamola Rustamovna';

const messages = (page: Page) => page.getByTestId('thread-message');

test('bolaga javob yozishmada ko\'rinadi; ichki eslatma bolaga ko\'rinadigan xabarlarda YO\'Q', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'psixolog', 'Psixolog2026');
  await page.goto(url(`/care/requests/view?id=${NORMAL_NEW}`));

  // Yozishma: bolaning murojaati. Ikki yozish oynasi aniq ajratilgan.
  await expect(page.getByRole('heading', { name: 'Bola bilan yozishma' })).toBeVisible();
  await expect(messages(page)).toHaveCount(1);
  await expect(messages(page).first()).toHaveAttribute('data-author', 'CHILD');
  const reply = page.getByTestId('reply-composer');
  const note = page.getByTestId('note-composer');
  await expect(reply).toContainText('Bolaga javob');
  await expect(reply).toContainText('Bola koʻradi');
  await expect(note).toContainText('Ichki eslatma');
  await expect(note).toContainText('Bola koʻrmaydi');
  await expect(reply).not.toContainText('Bola koʻrmaydi');

  // Javob yuborish.
  await page.getByLabel('Bolaga javob', { exact: true }).fill('Salom! Seni eshitaman, birga yechamiz.');
  await page.getByTestId('reply-send').click();
  await expect(page.getByText('Javob bolaga yuborildi')).toBeVisible();
  await expect(messages(page)).toHaveCount(2);
  const sent = messages(page).last();
  await expect(sent).toHaveAttribute('data-author', 'STAFF');
  await expect(sent).toContainText('Salom! Seni eshitaman, birga yechamiz.');
  await expect(sent).toContainText(PSYCHOLOGIST);
  await expect(sent).toContainText('Bolaga yuborilgan');
  await expect(page.getByLabel('Bolaga javob', { exact: true })).toHaveValue('');
  // Yuborgach fokus yozish maydonida qoladi — keyingi xabarni yozish davom etadi.
  await expect(page.getByLabel('Bolaga javob', { exact: true })).toBeFocused();

  // Ichki eslatma: tarixda "Bola koʻrmaydi" nishoni bilan; yozishmaga TUSHMAYDI.
  await page.locator('#care-note').fill('FAQAT-ICHKI: sinf rahbari bilan gaplashaman.');
  await page.getByTestId('note-add').click();
  await expect(page.getByText('Eslatma qoʻshildi').or(page.getByText("Eslatma qo'shildi"))).toBeVisible();
  const noteEntry = page.locator('[data-timeline="note"]').filter({ hasText: 'FAQAT-ICHKI' });
  await expect(noteEntry).toBeVisible();
  await expect(noteEntry).toContainText('Bola koʻrmaydi');
  await expect(messages(page)).toHaveCount(2);
  await expect(page.getByRole('log', { name: 'Bola bilan yozishma' })).not.toContainText('FAQAT-ICHKI');

  // Tarix: ochildi (kim) va birinchi javob; holat NEW → Jarayonda.
  await expect(page.locator('[data-timeline="opened"]')).toContainText(`Ochildi: ${PSYCHOLOGIST}`);
  await expect(page.locator('[data-timeline="replied"]')).toContainText('Bolaga birinchi javob yuborildi');
  await expect(page.locator('main h1').first().locator('..').getByText('Jarayonda')).toBeVisible();
  await expect(page.getByTestId('handler-badge')).toContainText(`Masʼul: ${PSYCHOLOGIST}`);

  // Klaviatura: Ctrl+Enter yuboradi.
  await page.getByLabel('Bolaga javob', { exact: true }).fill('Ertaga katta tanaffusda kela olasanmi?');
  await page.keyboard.press('Control+Enter');
  await expect(messages(page)).toHaveCount(3);
  await expect(messages(page).last()).toContainText('Ertaga katta tanaffusda');
  expect(errors).toEqual([]);
});

test('yopilgan murojaatga javob yozib bo\'lmaydi — sababi aytiladi; qayta ochilgach yoziladi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'psixolog', 'Psixolog2026');
  await page.goto(url(`/care/requests/view?id=${RESOLVED}`));
  const reply = page.getByTestId('reply-composer');
  await expect(reply).toContainText('Murojaat yopilgan');
  await expect(page.getByLabel('Bolaga javob', { exact: true })).toHaveCount(0);
  await expect(page.locator('[data-timeline="resolved"]')).toContainText('Murojaat yopildi');

  await page.getByRole('combobox', { name: 'Holat' }).click();
  await page.getByRole('option', { name: 'Jarayonda' }).click();
  await expect(page.getByLabel('Bolaga javob', { exact: true })).toBeVisible();
  expect(errors).toEqual([]);
});

test('murojaatlar qutisi: ochilmagan/ochilgan, o\'qilmagan bola xabari, mas\'ul; shoshilinch tepada; ochgach nishon yo\'qoladi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'psixolog', 'Psixolog2026');
  await page.goto(url('/care/requests'));
  const rows = page.locator('li[data-request]');
  await expect(rows.first()).toHaveAttribute('data-request', URGENT_NEW);
  await expect(rows.first().getByTestId('not-opened')).toContainText('Ochilmagan');

  await page.getByRole('tab', { name: /Jarayonda/ }).click();
  const unread = page.locator(`li[data-request="${WITH_UNREAD}"]`);
  await expect(unread.getByTestId('unread-from-child')).toContainText('1 ta yangi xabar');
  await expect(unread.getByTestId('opened')).toContainText('Ochilgan');
  await expect(unread).toContainText('Javob berilgan');
  await expect(unread.getByTestId('assigned-to')).toContainText(`Masʼul: ${PSYCHOLOGIST}`);

  // Ochish bola xabarini o'qilgan qiladi.
  await unread.getByRole('link').click();
  await expect(page.getByTestId('thread-message')).toHaveCount(3);
  await page.getByRole('link', { name: 'Murojaatlarga qaytish' }).click();
  await page.getByRole('tab', { name: /Jarayonda/ }).click();
  await expect(page.locator(`li[data-request="${WITH_UNREAD}"]`)).toBeVisible();
  await expect(page.locator(`li[data-request="${WITH_UNREAD}"]`).getByTestId('unread-from-child')).toHaveCount(0);
  expect(errors).toEqual([]);
});

test('muddatdan o\'tgan ochilmagan murojaat o\'rinbosarga o\'tadi: qutida, sarlavhada va tarixda ko\'rinadi', async ({ page }) => {
  const errors = trackErrors(page);
  await login(page, 'psixolog', 'Psixolog2026');

  // Demo soatini ish vaqti ichiga (10:00) qo'yamiz — shoshilinch muddat (60 daqiqa) o'tgan.
  // Bayram kunlari ish vaqti hisoblanmaydi (kuzgi ta'til 2–9 noyabr): test sanaga bog'liq bo'lmasin.
  await page.evaluate(() => {
    const db = JSON.parse(localStorage.getItem('parvoz-school:db:v1') ?? '{}') as { baseDate: string; tables: { holidays: unknown[] } };
    db.tables.holidays = [];
    localStorage.setItem('parvoz-school:db:v1', JSON.stringify(db));
    localStorage.setItem(
      'parvoz-school:clock',
      JSON.stringify({ mode: 'SCENARIO', speed: 1, scenarioDate: db.baseDate, scenarioStartMinute: 10 * 60, realStartedAt: Date.now(), epoch: Date.now() }),
    );
  });
  await page.goto(url('/care/requests'));
  const row = page.locator(`li[data-request="${URGENT_NEW}"]`);
  await expect(row.getByTestId('escalated')).toContainText('Oʻrinbosarga oʻtgan', { timeout: 15_000 });
  await expect(row.getByTestId('assigned-to')).toContainText(`Masʼul: ${DEPUTY}`);

  await row.getByRole('link').click();
  await expect(page.getByTestId('escalated-badge')).toContainText('Oʻrinbosarga oʻtgan');
  await expect(page.getByTestId('handler-badge')).toContainText(DEPUTY);
  await expect(page.locator('[data-timeline="escalated"]')).toContainText(`Oʻrinbosarga oʻtkazildi: ${DEPUTY}`);
  expect(errors).toEqual([]);
});

test('direktor murojaatlarni va yozishmani ko\'ra olmaydi', async ({ page }) => {
  await login(page, 'direktor', 'Direktor2026');
  await page.goto(url(`/care/requests/view?id=${NORMAL_NEW}`));
  await expect(page.locator('main h1').first()).toHaveText("Ruxsat yo'q");
  await expect(page.getByTestId('thread-message')).toHaveCount(0);
});
