// Maktab paneli S4: Smart Reminder — ro'yxat (kelgusi / o'tgan, ko'rsatkichlar,
// filtr), yaratish / tahrirlash / to'xtatish / o'chirish, validatsiya, audit.

import { toLocalDateTime } from '../../src/school/comms/comms-time';
import { resetDb } from './db';
import { addFamily, classesAudience, createClass, SCHOOL, schoolCall } from './school-comms-fixtures';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createTestApp, TestApp } from './test-app';

const DAY_MS = 24 * 60 * 60 * 1000;

describe('School comms: Smart Reminder (S4)', () => {
  let t: TestApp;
  let schoolId: string;
  let cls7a: string;
  let director: LoggedIn;
  let call: ReturnType<typeof schoolCall>;

  const input = (over: Record<string, unknown> = {}) => ({
    kind: 'EXAM',
    title: 'Chorak imtihoni',
    body: 'Jadval ilovada.',
    audience: SCHOOL,
    sendAt: '2099-05-01T09:00',
    repeat: 'NONE',
    ...over,
  });

  beforeAll(async () => {
    t = await createTestApp();
    call = schoolCall(t.app);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    schoolId = (await createSchool(t.prisma)).school.id;
    cls7a = (await createClass(t.prisma, schoolId, 7, 'A')).id;
    await addFamily(t.prisma, schoolId, cls7a);
    director = await login(t.app, 'direktor');
  });

  afterAll(() => t.close());

  it('yaratish / tahrirlash / to\'xtatish / o\'chirish — validatsiya va audit', async () => {
    expect((await call(director, 'POST', '/comms/reminders', input({ sendAt: '2020-01-01T09:00' }))).json())
      .toMatchObject({ code: 'VALIDATION', message: 'sendAt: errors.form.invalidDate' });
    expect((await call(director, 'POST', '/comms/reminders', input({ sendAt: '01.05.2099' }))).json())
      .toMatchObject({ message: 'sendAt: errors.form.invalidDate' });
    expect((await call(director, 'POST', '/comms/reminders', input({ body: 'x'.repeat(501) }))).json())
      .toMatchObject({ message: 'body: errors.form.tooLong' });
    expect((await call(director, 'POST', '/comms/reminders', input({ audience: classesAudience('ghost') }))).json())
      .toMatchObject({ code: 'VALIDATION', message: 'audience.classIds' });

    const created = await call(director, 'POST', '/comms/reminders', input());
    expect(created.statusCode).toBe(201);
    const r = created.json();
    expect(r).toMatchObject({ sendAt: '2099-05-01T09:00:00', active: true, repeat: 'NONE', byStaffId: director.me.staff.id });

    // O'tib ketgan eslatma: vaqtini o'zgartirmay tahrirlash mumkin (panel daqiqagacha qaytaradi).
    const past = new Date(Date.now() - DAY_MS);
    await t.prisma.schoolReminder.update({ where: { id: r.id }, data: { sendAt: past } });
    const unchanged = toLocalDateTime(past).slice(0, 16);
    expect((await call(director, 'PUT', `/comms/reminders/${r.id}`, input({ title: 'Yangi nom', sendAt: unchanged }))).json())
      .toMatchObject({ title: 'Yangi nom', sendAt: `${unchanged}:00` });
    expect((await call(director, 'PUT', `/comms/reminders/${r.id}`, input({ sendAt: '2020-02-02T10:00' }))).statusCode).toBe(400);

    const off = await call(director, 'PATCH', `/comms/reminders/${r.id}/active`, { active: false });
    expect(off.json()).toMatchObject({ active: false });
    expect((await call(director, 'PATCH', `/comms/reminders/${r.id}/active`, {})).json()).toMatchObject({ message: 'active: errors.form.required' });
    expect((await call(director, 'DELETE', `/comms/reminders/${r.id}`)).statusCode).toBe(204);
    expect((await call(director, 'DELETE', `/comms/reminders/${r.id}`)).statusCode).toBe(404);

    const audits = await t.prisma.schoolAuditLog.findMany({ where: { module: 'REMINDERS' }, orderBy: { at: 'asc' } });
    expect(audits.map((a) => a.action)).toEqual(['reminder.create', 'reminder.update', 'reminder.toggle', 'reminder.delete']);
    expect(audits[2]).toMatchObject({ params: { variant: 'off', title: 'Yangi nom' }, before: { active: true }, after: { active: false } });
  });

  it('ro\'yxat: kelgusi (yaqini oldin) → o\'tgan; ko\'rsatkichlar butun ro\'yxat bo\'yicha; filtr va qidiruv', async () => {
    const make = (title: string, sendAt: Date, extra: Record<string, unknown> = {}) =>
      t.prisma.schoolReminder.create({
        data: { schoolId, kind: 'EVENT', title, body: 'x', audience: SCHOOL, sendAt, byStaffId: director.me.staff.id, ...extra },
      });
    const anchor = new Date(Date.now() - 3 * DAY_MS);
    await make('Haftalik', anchor, { repeat: 'WEEKLY' });
    await make('Uzoq', new Date(Date.now() + 30 * DAY_MS));
    await make('Pauza', new Date(Date.now() + 2 * DAY_MS), { active: false });
    await make('Eski', new Date(Date.now() - 10 * DAY_MS), { kind: 'EXAM' });
    await call(director, 'POST', '/comms/reminders', input({ title: '7-A uchun', audience: classesAudience(cls7a), sendAt: '2099-01-01T08:00' }));

    const list = (await call(director, 'GET', '/comms/reminders')).json();
    expect(list.items.map((r: { title: string }) => r.title)).toEqual(['Pauza', 'Haftalik', 'Uzoq', '7-A uchun', 'Eski']);
    expect(list.counts).toEqual({ UPCOMING: 4, PAST: 1 });
    expect(list.stats).toMatchObject({ upcoming: 4, repeating: 1, paused: 1 });
    expect(list.stats.nextAt).toBe(toLocalDateTime(new Date(anchor.getTime() + 7 * DAY_MS)));
    const weekly = list.items.find((r: { title: string }) => r.title === 'Haftalik');
    expect(weekly).toMatchObject({ isPast: false, recipients: 1, audienceNames: [] });
    expect(list.items.find((r: { title: string }) => r.title === 'Eski')).toMatchObject({ isPast: true, nextAt: null });

    const titles = async (q: string) =>
      (await call(director, 'GET', `/comms/reminders?${q}`)).json().items.map((r: { title: string }) => r.title);
    expect(await titles('when=PAST')).toEqual(['Eski']);
    expect(await titles('kind=EXAM')).toEqual(['7-A uchun', 'Eski']);
    expect(await titles('search=7-a')).toEqual(['7-A uchun']);
    const paged = (await call(director, 'GET', '/comms/reminders?limit=2&page=2')).json();
    expect(paged.items.map((r: { title: string }) => r.title)).toEqual(['Uzoq', '7-A uchun']);
    expect(paged.stats.upcoming).toBe(4);
  });

  it('ruxsat va maktab chegarasi: sinf rahbari — 403, boshqa maktab eslatmasi — 404', async () => {
    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [cls7a]);
    const homeroom = await login(t.app, 'rahbar');
    expect((await call(homeroom, 'GET', '/comms/reminders')).statusCode).toBe(403);
    expect((await call(homeroom, 'POST', '/comms/reminders', input())).statusCode).toBe(403);

    const other = await createSchool(t.prisma, 'other-school');
    const foreign = await t.prisma.schoolReminder.create({
      data: { schoolId: other.school.id, kind: 'EVENT', title: 'Begona', body: 'x', audience: SCHOOL, sendAt: new Date(Date.now() + DAY_MS), byStaffId: other.director.id },
    });
    expect((await call(director, 'PUT', `/comms/reminders/${foreign.id}`, input())).statusCode).toBe(404);
    expect((await call(director, 'PATCH', `/comms/reminders/${foreign.id}/active`, { active: false })).statusCode).toBe(404);
    expect((await call(director, 'DELETE', `/comms/reminders/${foreign.id}`)).statusCode).toBe(404);
    expect((await call(director, 'GET', '/comms/reminders')).json().items).toHaveLength(0);
  });
});
