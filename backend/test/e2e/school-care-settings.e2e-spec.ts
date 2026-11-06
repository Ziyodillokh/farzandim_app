// Bola ovozi — sozlamalar (mas'ul psixolog, o'rinbosar, ish vaqti, muddatlar), bola uchun
// "contact" va ochilmagan murojaatlar eskalatsiyasi (cron, ish vaqtida) + saqlangan bildirishnomalar.

import { CareChildRequestsService } from '../../src/school/care/care-child-requests.service';
import { CareEscalationCron } from '../../src/school/care/care-escalation.cron';
import { directorNotificationId } from '../../src/school/care/care-notification-ids';
import { SchoolCryptoService } from '../../src/school/common/school-crypto.service';
import { resetDb } from './db';
import { createTestApp, TestApp } from './test-app';
import { AssessWorld, buildWorld, careChild, careStaff, createRequest, psychologist, schoolApi, Staff } from './school-care-fixtures';

const ALL_DAYS = [1, 2, 3, 4, 5, 6, 7];
/** Toshkent devor soati → lahza. */
const tk = (iso: string) => new Date(`${iso}+05:00`);

describe('Bola ovozi — sozlamalar, contact va eskalatsiya', () => {
  let t: TestApp;
  let w: AssessWorld;
  let staff: ReturnType<typeof careStaff>;
  let child: ReturnType<typeof careChild>;
  let school: ReturnType<typeof schoolApi>;
  let deputy: Staff & { id: string };

  beforeAll(async () => {
    t = await createTestApp();
    staff = careStaff(t);
    child = careChild(t);
    school = schoolApi(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await buildWorld(t);
    deputy = await psychologist(t, w.schoolId, 'deputy', 'Kamola Yusupova');
  });

  afterAll(() => t.close());

  const kid = () => w.kids7a[0]!;
  const settings = (over: Record<string, unknown> = {}) => ({
    psychologistStaffId: w.psych.staffId,
    psychologistDisplayName: 'Dilnoza opa',
    deputyStaffId: deputy.id,
    deputyDisplayName: 'Kamola opa',
    workDays: [1, 2, 3, 4, 5],
    workStart: '09:00',
    workEnd: '17:00',
    urgentSlaMinutes: 60,
    normalSlaHours: 24,
    ...over,
  });
  const configure = async (over: Record<string, unknown> = {}) => {
    const res = await staff(w.psych, 'PUT', '/settings', settings(over));
    if (res.statusCode !== 200) throw new Error(`settings ${res.statusCode}: ${res.body}`);
  };
  const feed = async (who: Staff) => (await school(who, 'GET', '/notifications/feed')).json() as Array<{ id: string; kind: string; params: Record<string, unknown>; subject: { uz: string } | null; href: string | null }>;
  /** Eskalatsiya testlari uchun: berilgan vaqtda yaratilgan murojaat (bola API'si vaqtni boshqarib bo'lmaydi). */
  const requestAt = async (createdAt: Date, over: Record<string, unknown> = {}) =>
    t.prisma.schoolCareRequest.create({
      data: {
        schoolId: w.schoolId,
        studentId: kid().studentId,
        classId: w.classes.c7a,
        topic: 'EMOTIONS',
        urgency: 'NORMAL',
        messageEnc: t.app.get(SchoolCryptoService).encrypt('matn'),
        createdAt,
        lastMessageAt: createdAt,
        ...over,
      },
    });

  describe('sozlamalar', () => {
    it('GET: sozlanmagan maktabda standart qiymatlar + faol psixologlar ro\'yxati', async () => {
      const res = await staff(w.director, 'GET', '/settings');
      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({
        psychologistStaffId: null,
        psychologistDisplayName: null,
        deputyStaffId: null,
        deputyDisplayName: null,
        workDays: [1, 2, 3, 4, 5],
        workStart: '09:00',
        workEnd: '17:00',
        urgentSlaMinutes: 60,
        normalSlaHours: 24,
        updatedAt: null,
        updatedByStaffId: null,
        staffOptions: [
          { id: deputy.id, fullName: 'Kamola Yusupova' },
          { id: w.psych.staffId, fullName: 'PSYCHOLOGIST xodim' },
        ],
      });
      expect((await staff(w.psych, 'GET', '/settings')).statusCode).toBe(200);
      expect((await staff(w.admin, 'GET', '/settings')).statusCode).toBe(200);
      for (const who of [w.homeroom, w.duty, w.teacher]) expect((await staff(who, 'GET', '/settings')).statusCode).toBe(403);
    });

    it('PUT: psixolog, direktor va administrator (care.settings) yozadi, qolganlari 403; audit shaxssiz', async () => {
      expect((await staff(w.psych, 'PUT', '/settings', settings())).statusCode).toBe(200);
      const saved = (await staff(w.director, 'PUT', '/settings', settings({ urgentSlaMinutes: 30, deputyDisplayName: null }))).json();
      expect(saved).toMatchObject({ psychologistStaffId: w.psych.staffId, psychologistDisplayName: 'Dilnoza opa', deputyDisplayName: null, urgentSlaMinutes: 30 });
      expect(saved.updatedAt).toEqual(expect.any(String));
      expect((await staff(w.director, 'GET', '/settings')).json()).toMatchObject({ urgentSlaMinutes: 30, updatedByStaffId: expect.any(String) });
      const byAdmin = await staff(w.admin, 'PUT', '/settings', settings({ normalSlaHours: 48 }));
      expect(byAdmin.statusCode).toBe(200);
      expect(byAdmin.json()).toMatchObject({ normalSlaHours: 48, updatedByStaffId: w.admin.staffId });
      for (const who of [w.homeroom, w.duty, w.teacher]) {
        const res = await staff(who, 'PUT', '/settings', settings({ normalSlaHours: 1 }));
        expect([res.statusCode, res.json().code]).toEqual([403, 'FORBIDDEN']);
      }
      expect((await staff(w.psych, 'GET', '/settings')).json().normalSlaHours).toBe(48);

      const audit = await t.prisma.schoolAuditLog.findMany({ where: { action: 'care.settings.update' } });
      expect(audit).toHaveLength(3);
      expect(JSON.stringify(audit)).not.toMatch(/Dilnoza|Kamola|Yusupova/);
      expect(await t.prisma.schoolCareSettings.count()).toBe(1);
    });

    it('/auth/me: care.settings ruxsati direktor, administrator va psixologda bor; sinf rahbari, o\'qituvchi va navbatchida yo\'q', async () => {
      const cases: Array<[Staff, boolean]> = [[w.director, true], [w.admin, true], [w.psych, true], [w.homeroom, false], [w.teacher, false], [w.duty, false]];
      for (const [who, expected] of cases) {
        const me = await school(who, 'GET', '/auth/me');
        expect(me.statusCode).toBe(200);
        expect((me.json().permissions as string[]).includes('care.settings')).toBe(expected);
      }
    });

    it.each([
      [{ deputyStaffId: 'psixolog-id' }, 'deputyStaffId: errors.form.duplicate'],
      [{ psychologistDisplayName: 'x'.repeat(41) }, 'psychologistDisplayName: errors.form.tooLong'],
      [{ workStart: '18:00' }, 'workEnd: errors.form.endBeforeStart'],
      [{ workDays: [1, 1] }, 'workDays: errors.form.duplicate'],
      [{ workDays: [8] }, 'workDays.0: errors.form.outOfRange'],
      [{ workDays: [] }, 'workDays: errors.form.selectAtLeastOne'],
      [{ urgentSlaMinutes: 14 }, 'urgentSlaMinutes: errors.form.outOfRange'],
      [{ normalSlaHours: 169 }, 'normalSlaHours: errors.form.outOfRange'],
      [{ workEnd: '25:00' }, 'workEnd: errors.form.invalidTime'],
    ])('PUT validatsiya %j -> %s', async (over, message) => {
      const body = { ...settings(), ...over };
      if (body.deputyStaffId === 'psixolog-id') body.deputyStaffId = w.psych.staffId;
      const res = await staff(w.psych, 'PUT', '/settings', body);
      expect([res.statusCode, res.json().code, res.json().message]).toEqual([400, 'VALIDATION', message]);
      expect(await t.prisma.schoolCareSettings.count()).toBe(0);
    });

    it('PUT: xodim shu maktabda, faol va PSYCHOLOGIST bo\'lishi shart', async () => {
      const other = await buildWorld(t, 'other-school');
      const inactive = await psychologist(t, w.schoolId, 'ketgan', 'Ketgan Psixolog');
      await t.prisma.schoolStaff.update({ where: { id: inactive.id }, data: { active: false } });
      const cases: Array<[Record<string, unknown>, string]> = [
        [{ psychologistStaffId: 'no-such-staff' }, 'psychologistStaffId: errors.form.invalidStaff'],
        [{ psychologistStaffId: other.psych.staffId }, 'psychologistStaffId: errors.form.invalidStaff'],
        [{ deputyStaffId: (await t.prisma.schoolStaff.findFirstOrThrow({ where: { role: 'HOMEROOM', schoolId: w.schoolId } })).id }, 'deputyStaffId: errors.form.invalidStaff'],
        [{ deputyStaffId: inactive.id }, 'deputyStaffId: errors.form.invalidStaff'],
      ];
      for (const [over, message] of cases) {
        const res = await staff(w.psych, 'PUT', '/settings', settings(over));
        expect([res.statusCode, res.json().message]).toEqual([400, message]);
      }
      expect(await t.prisma.schoolCareSettings.count()).toBe(0);
      // Boshqa maktab sozlamasi bu maktabnikini o'zgartirmaydi.
      expect((await staff(other.psych, 'PUT', '/settings', { workDays: [1] })).statusCode).toBe(200);
      expect(await t.prisma.schoolCareSettings.count({ where: { schoolId: w.schoolId } })).toBe(0);
      expect((await staff(w.psych, 'GET', '/settings')).json().workDays).toEqual([1, 2, 3, 4, 5]);
    });

    it('faol bo\'lmagan psixolog staffOptions da ko\'rinmaydi', async () => {
      await t.prisma.schoolStaff.update({ where: { id: deputy.id }, data: { active: false } });
      expect((await staff(w.psych, 'GET', '/settings')).json().staffOptions).toEqual([{ id: w.psych.staffId, fullName: 'PSYCHOLOGIST xodim' }]);
    });
  });

  describe('contact (bola ilovasi)', () => {
    const contactAt = (now: Date) => t.app.get(CareChildRequestsService).contact(kid().userId, now);

    it('sozlama yo\'q: yagona faol psixolog, soatlarsiz; bir nechta bo\'lsa null', async () => {
      await t.prisma.schoolStaff.update({ where: { id: deputy.id }, data: { active: false } });
      expect((await child(kid(), 'GET', '/contact')).json()).toEqual({ psychologist: { name: 'PSYCHOLOGIST xodim' }, deputy: null, hours: null, openNow: false, nextOpenAt: null });
      await t.prisma.schoolStaff.update({ where: { id: deputy.id }, data: { active: true } });
      expect((await child(kid(), 'GET', '/contact')).json()).toEqual({ psychologist: null, deputy: null, hours: null, openNow: false, nextOpenAt: null });
    });

    it('sozlangan: ko\'rsatiladigan ismlar, soatlar; ish vaqtida ochiq', async () => {
      await configure();
      const open = await contactAt(tk('2026-11-06T10:00:00'));
      expect(open).toEqual({
        psychologist: { name: 'Dilnoza opa' },
        deputy: { name: 'Kamola opa' },
        hours: { days: [1, 2, 3, 4, 5], start: '09:00', end: '17:00' },
        openNow: true,
        nextOpenAt: null,
      });
      expect((await child(kid(), 'GET', '/contact')).json()).toMatchObject({ psychologist: { name: 'Dilnoza opa' }, hours: { start: '09:00' } });
    });

    it('ko\'rsatiladigan ism yo\'q — xodimning F.I.Sh.; faol bo\'lmagan o\'rinbosar ko\'rsatilmaydi', async () => {
      await configure({ psychologistDisplayName: null, deputyDisplayName: null });
      expect(await contactAt(tk('2026-11-06T10:00:00'))).toMatchObject({ psychologist: { name: 'PSYCHOLOGIST xodim' }, deputy: { name: 'Kamola Yusupova' } });
      await t.prisma.schoolStaff.update({ where: { id: deputy.id }, data: { active: false } });
      expect((await contactAt(tk('2026-11-06T10:00:00'))).deputy).toBeNull();
    });

    it('dam olish kuni, ish vaqtidan tashqari va bayram yopiq; keyingi ochilish ISO', async () => {
      await configure();
      expect(await contactAt(tk('2026-11-07T10:00:00'))).toMatchObject({ openNow: false, nextOpenAt: '2026-11-09T04:00:00.000Z' });
      expect(await contactAt(tk('2026-11-06T18:00:00'))).toMatchObject({ openNow: false, nextOpenAt: '2026-11-09T04:00:00.000Z' });
      expect(await contactAt(tk('2026-11-06T07:00:00'))).toMatchObject({ openNow: false, nextOpenAt: '2026-11-06T04:00:00.000Z' });
      await t.prisma.schoolHoliday.createMany({ data: [{ schoolId: w.schoolId, date: '2026-11-06', name: 'Bayram' }, { schoolId: w.schoolId, date: '2026-11-09', name: 'Bayram 2' }] });
      expect(await contactAt(tk('2026-11-06T10:00:00'))).toMatchObject({ openNow: false, nextOpenAt: '2026-11-10T04:00:00.000Z' });
    });

    it('boshqa maktab bayrami ta\'sir qilmaydi', async () => {
      await configure();
      const other = await buildWorld(t, 'other-school');
      await t.prisma.schoolHoliday.create({ data: { schoolId: other.schoolId, date: '2026-11-06', name: 'Begona' } });
      expect(await contactAt(tk('2026-11-06T10:00:00'))).toMatchObject({ openNow: true });
    });
  });

  describe('shoshilinch murojaat: saqlangan bildirishnomalar', () => {
    it('sozlangan bo\'lsa mas\'ul psixolog va o\'rinbosarga nishonlanadi; lentada bittadan', async () => {
      await configure();
      const third = await psychologist(t, w.schoolId, 'uchinchi', 'Uchinchi Psixolog');
      const { id } = await createRequest(t, kid(), { urgency: 'URGENT', topic: 'BULLYING', message: 'Maxfiy' });

      const stored = await t.prisma.schoolStaffNotification.findMany();
      expect(stored).toHaveLength(1);
      expect(stored[0]).toMatchObject({ id: `care:${id}`, kind: 'CARE_URGENT', roles: ['PSYCHOLOGIST'], staffIds: [w.psych.staffId, deputy.id], params: { className: '7-A' } });
      expect(JSON.stringify(stored)).not.toMatch(/Maxfiy|Alfa/);

      for (const who of [w.psych, deputy, third]) {
        const items = (await feed(who)).filter((n) => n.id === `care:${id}`);
        expect(items).toHaveLength(1);
        expect(items[0]).toMatchObject({ kind: 'CARE_URGENT', params: { className: '7-A' } });
      }
      expect((await feed(w.director)).some((n) => n.id === `care:${id}`)).toBe(false);
    });

    it('oddiy murojaat yoki sozlama yo\'q — saqlangan yozuv yaratilmaydi', async () => {
      await createRequest(t, kid(), { urgency: 'URGENT' });
      await configure();
      await createRequest(t, w.kids7a[1]!, { urgency: 'NORMAL' });
      expect(await t.prisma.schoolStaffNotification.count()).toBe(0);
    });

    it('javob yozilgach (NEW dan chiqqach) saqlangan bildirishnoma tozalanadi', async () => {
      await configure();
      const { id } = await createRequest(t, kid(), { urgency: 'URGENT' });
      expect(await t.prisma.schoolStaffNotification.count()).toBe(1);
      await staff(w.psych, 'POST', `/requests/${id}/messages`, { text: 'Javob' });
      expect(await t.prisma.schoolStaffNotification.count()).toBe(0);
      expect((await feed(w.psych)).some((n) => n.id === `care:${id}`)).toBe(false);
    });
  });

  describe('eskalatsiya', () => {
    const sweep = (now: Date) => t.app.get(CareEscalationCron).sweep(now);

    it('ish vaqtida muddat o\'tgach murojaat o\'rinbosarga o\'tadi; bola ko\'radi', async () => {
      await configure();
      // Juma 16:30 + 60 daqiqa ish vaqti = dushanba 09:30.
      const req = await requestAt(tk('2026-11-06T16:30:00'), { urgency: 'URGENT' });

      expect(await sweep(tk('2026-11-06T17:30:00'))).toBe(0);
      expect(await sweep(tk('2026-11-07T12:00:00'))).toBe(0);
      expect(await sweep(tk('2026-11-09T09:29:59'))).toBe(0);
      expect(await sweep(tk('2026-11-09T09:30:00'))).toBe(1);

      const stored = await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id: req.id } });
      expect(stored).toMatchObject({ assignedStaffId: deputy.id, escalatedAt: tk('2026-11-09T09:30:00'), status: 'NEW', openedAt: null });
      expect(await sweep(tk('2026-11-09T10:00:00'))).toBe(0);

      const detail = (await child(kid(), 'GET', `/requests/${req.id}`)).json();
      expect(detail.handler).toEqual({ name: 'Kamola opa', isDeputy: true });
      const row = (await staff(w.psych, 'GET', '/requests')).json().items[0];
      expect(row).toMatchObject({ assignedTo: { id: deputy.id, name: 'Kamola Yusupova' }, escalatedAt: '2026-11-09T04:30:00.000Z' });
    });

    it('bayram kuni muddatni suradi', async () => {
      await configure();
      await t.prisma.schoolHoliday.create({ data: { schoolId: w.schoolId, date: '2026-11-09', name: 'Bayram' } });
      const req = await requestAt(tk('2026-11-06T16:30:00'), { urgency: 'URGENT' });

      expect(await sweep(tk('2026-11-09T12:00:00'))).toBe(0);
      expect(await sweep(tk('2026-11-10T09:30:00'))).toBe(1);
      expect((await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id: req.id } })).escalatedAt).not.toBeNull();
    });

    it('oddiy murojaat: 24 ish soati (uch ish kuni); ish soatlari sozlamasiga ergashadi', async () => {
      await configure({ workStart: '09:00', workEnd: '17:00' });
      const req = await requestAt(tk('2026-11-06T10:00:00'));
      expect(await sweep(tk('2026-11-10T16:00:00'))).toBe(0);
      expect(await sweep(tk('2026-11-11T09:59:59'))).toBe(0);
      expect(await sweep(tk('2026-11-11T10:00:00'))).toBe(1);
      expect((await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id: req.id } })).assignedStaffId).toBe(deputy.id);
    });

    it('ochilgan, javob berilgan, hal qilingan yoki allaqachon o\'tgan murojaat o\'tkazilmaydi', async () => {
      await configure();
      const at = tk('2026-11-06T10:00:00');
      const opened = await requestAt(at, { urgency: 'URGENT', openedAt: at, openedByStaffId: w.psych.staffId });
      const progress = await requestAt(at, { urgency: 'URGENT', status: 'IN_PROGRESS' });
      const resolved = await requestAt(at, { urgency: 'URGENT', status: 'RESOLVED' });
      const done = await requestAt(at, { urgency: 'URGENT', escalatedAt: at, assignedStaffId: deputy.id });

      expect(await sweep(tk('2026-11-20T10:00:00'))).toBe(0);
      for (const r of [opened, progress, resolved]) {
        expect((await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id: r.id } })).escalatedAt).toBeNull();
      }
      expect((await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id: done.id } })).escalatedAt).toEqual(at);
    });

    it('o\'rinbosar sozlanmagan, faol emas yoki sozlama yo\'q maktabda hech narsa o\'tmaydi', async () => {
      await requestAt(tk('2026-11-06T10:00:00'), { urgency: 'URGENT' });
      expect(await sweep(tk('2026-11-20T10:00:00'))).toBe(0);

      await configure({ deputyStaffId: null, deputyDisplayName: null });
      expect(await sweep(tk('2026-11-20T10:00:00'))).toBe(0);

      await configure();
      await t.prisma.schoolStaff.update({ where: { id: deputy.id }, data: { active: false } });
      expect(await sweep(tk('2026-11-20T10:00:00'))).toBe(0);
      expect(await t.prisma.schoolCareRequest.count({ where: { escalatedAt: { not: null } } })).toBe(0);
    });

    it('boshqa maktab sozlamalari bilan aralashmaydi', async () => {
      const other = await buildWorld(t, 'other-school');
      const otherDeputy = await psychologist(t, other.schoolId, 'other-deputy', 'Begona');
      await staff(other.psych, 'PUT', '/settings', settings({ psychologistStaffId: other.psych.staffId, deputyStaffId: otherDeputy.id }));
      await requestAt(tk('2026-11-06T10:00:00'), { urgency: 'URGENT' });

      expect(await sweep(tk('2026-11-20T10:00:00'))).toBe(0);
    });

    it('bildirishnomalar: o\'rinbosarga nishonlangan; shoshilinch bo\'lsa direktorga ismsiz signal; audit', async () => {
      await configure();
      const urgent = await requestAt(tk('2026-11-06T10:00:00'), { urgency: 'URGENT' });
      const normal = await requestAt(tk('2026-11-06T10:00:00'), { urgency: 'NORMAL' });

      expect(await sweep(tk('2026-11-20T10:00:00'))).toBe(2);
      // Lenta kelajak vaqtli yozuvni yashiradi; sinov soati haqiqiy soatdan oldinda bo'lishi mumkin.
      await t.prisma.schoolStaffNotification.updateMany({ data: { at: new Date() } });

      const forDeputy = await feed(deputy);
      expect(forDeputy.find((n) => n.id === `care-esc:${urgent.id}`)).toMatchObject({ kind: 'CARE_URGENT', params: { className: '7-A' }, subject: { uz: expect.stringContaining('o\'tkazildi') } });
      expect(forDeputy.find((n) => n.id === `care-esc:${normal.id}`)).toMatchObject({ kind: 'CARE_NEW' });
      // Boshqa psixolog (o'rinbosar emas) eskalatsiya yozuvini ko'rmaydi.
      expect((await feed(w.psych)).some((n) => n.id.startsWith('care-esc:'))).toBe(false);

      const forDirector = await feed(w.director);
      const signals = forDirector.filter((n) => n.id.startsWith('care-esc-dir:'));
      expect(signals).toHaveLength(1);
      expect(signals[0]).toMatchObject({ id: directorNotificationId(urgent.id), kind: 'SAFETY_SIGNAL', params: {}, subject: null, href: null });
      // Direktorga ketadigan id murojaat id'sini ochmaydi.
      expect(JSON.stringify(forDirector)).not.toContain(urgent.id);
      expect(JSON.stringify(forDirector)).not.toMatch(/Alfa|7-A|matn/);

      const audit = await t.prisma.schoolAuditLog.findMany({ where: { action: 'care.request.escalate' } });
      expect(audit).toHaveLength(2);
      expect(audit.every((a) => a.actorId === null && a.actorName === 'Tizim' && a.entityId === null)).toBe(true);
    });

    it('o\'rinbosar ochib javob bersa, saqlangan bildirishnomalar tozalanadi', async () => {
      await configure();
      const req = await requestAt(tk('2026-11-06T10:00:00'), { urgency: 'URGENT' });
      await sweep(tk('2026-11-20T10:00:00'));
      expect(await t.prisma.schoolStaffNotification.count()).toBe(2);

      expect((await staff(deputy, 'POST', `/requests/${req.id}/messages`, { text: 'Men o\'rinbosarman' })).statusCode).toBe(201);

      expect(await t.prisma.schoolStaffNotification.count()).toBe(0);
      const row = (await staff(deputy, 'GET', `/requests/${req.id}`)).json();
      expect(row).toMatchObject({ assignedTo: { id: deputy.id }, openedBy: { id: deputy.id }, status: 'IN_PROGRESS' });
    });

    it('parallel ikki nusxa bitta murojaatni ikki marta o\'tkazmaydi', async () => {
      await configure();
      await requestAt(tk('2026-11-06T10:00:00'), { urgency: 'URGENT' });

      const results = await Promise.all([sweep(tk('2026-11-20T10:00:00')), sweep(tk('2026-11-20T10:00:00'))]);

      expect(results.reduce((a, b) => a + b, 0)).toBe(1);
      expect(await t.prisma.schoolAuditLog.count({ where: { action: 'care.request.escalate' } })).toBe(1);
    });
  });
});
