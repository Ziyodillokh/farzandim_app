// NFC kartalar: biriktirish va almashtirish, kiosk tegishi (kirish / chiqish, noma'lum,
// bloklangan, shubhali, oflayn navbat), NTAG 424 DNA kodi (imzo, qayta yuborish, nusxa)
// va School Mode «kirgandan boshlab bloklash» (haqiqiy vaqt bilan).

import { createCipheriv, randomBytes } from 'node:crypto';
import { AttendanceClock } from '../../src/school/attendance/attendance-time';
import { CardKeyService } from '../../src/school/attendance/card-keys.service';
import { deriveMetaKey, deriveTagKey, SUN_FILE_KEY_NO, sunMac } from '../../src/school/attendance/card-sun';
import { minutesToHhmm, tashkentMinute } from '../../src/school/school-mode/school-mode-time';
import { resetDb } from './db';
import { at, DAY, seedWorld, Session, setNow, World } from './school-attendance-fixtures';
import { createTestApp, TestApp } from './test-app';

const UID_A = '04:a1:b2:c3:d4:e5:f6';
const UID_B = '04:11:22:33:44:55:66';

/** NTAG 424 DNA tegishi: kartaning o'zi hisoblaydigan imzolangan manzil. */
function sunUrl(master: Buffer, uidHex: string, counter: number, tamper = false) {
  const uid = Buffer.from(uidHex, 'hex');
  const plain = Buffer.alloc(16);
  plain[0] = 0xc7;
  uid.copy(plain, 1);
  plain.writeUIntLE(counter, 8, 3);
  randomBytes(5).copy(plain, 11);
  const cipher = createCipheriv('aes-128-cbc', deriveMetaKey(master), Buffer.alloc(16)).setAutoPadding(false);
  const picc = Buffer.concat([cipher.update(plain), cipher.final()]);
  const mac = sunMac(deriveTagKey(master, uid, SUN_FILE_KEY_NO), Buffer.concat([uid, plain.subarray(8, 11)]));
  if (tamper) mac[0] ^= 0xff;
  return `https://farzandimedu.uz/k/?p=${picc.toString('hex').toUpperCase()}&c=${mac.toString('hex').toUpperCase()}`;
}

describe('NFC kartalar', () => {
  let t: TestApp;
  let w: World;

  const cards = (s: Session, method: 'GET' | 'POST' | 'DELETE', url = '', payload?: object) =>
    t.app.inject({ method, url: `/api/school/cards${url}`, headers: { authorization: `Bearer ${s.token}` }, ...(payload && { payload }) });
  const tap = (s: Session, payload: object) =>
    t.app.inject({ method: 'POST', url: '/api/school/attendance/kiosk/card-tap', headers: { authorization: `Bearer ${s.token}` }, payload });
  const settle = () => new Promise((r) => setTimeout(r, 50));

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
    setNow(t, at(DAY, '07:52'));
  });

  afterAll(() => t.close());

  it('biriktirish: raqam avtomatik, almashtirishda eski karta bloklanadi, band karta va ruxsat', async () => {
    const first = await cards(w.director, 'POST', '', { studentId: w.vali, uid: UID_A });
    expect(first.statusCode).toBe(201);
    expect(first.json()).toMatchObject({
      number: 'K-000001',
      uid: '04A1B2C3D4E5F6',
      kind: 'UID',
      status: 'ACTIVE',
      studentName: 'Aliyev Vali',
      className: '7-A',
      replacedNumber: null,
    });

    const second = (await cards(w.director, 'POST', '', { studentId: w.vali, uid: UID_B })).json();
    expect(second).toMatchObject({ number: 'K-000002', replacedNumber: 'K-000001' });
    const list = (await cards(w.director, 'GET')).json().items;
    expect(list.map((c: { number: string; status: string; blockedReason: string | null }) => [c.number, c.status, c.blockedReason])).toEqual([
      ['K-000002', 'ACTIVE', null],
      ['K-000001', 'BLOCKED', 'REPLACED'],
    ]);

    const taken = await cards(w.director, 'POST', '', { studentId: w.malika, uid: UID_A });
    expect(taken.statusCode).toBe(409);
    expect(taken.json().code).toBe('CARD_TAKEN');
    expect((await cards(w.director, 'POST', '', { studentId: w.malika, uid: 'salom' })).json().message).toBe('uid: errors.form.invalidCardUid');
    expect((await cards(w.director, 'POST', '', { studentId: w.malika, uid: '04:99:88:77:66:55:44', number: 'K-000002' })).json().code).toBe(
      'CARD_NUMBER_TAKEN',
    );
    expect((await cards(w.duty, 'POST', '', { studentId: w.malika, uid: '04:99:88:77:66:55:44' })).statusCode).toBe(403);
    // Sinf rahbari faqat o'z sinfi kartalarini ko'radi.
    expect((await cards(w.teacher, 'GET')).json().items).toEqual([]);
    expect(await t.prisma.schoolAuditLog.count({ where: { action: 'card.assign' } })).toBe(2);
  });

  it("kiosk tegishi: kirdi — ota-onaga xabar va telefonga push; qayta — NONE; noma'lum va bloklangan", async () => {
    const card = (await cards(w.director, 'POST', '', { studentId: w.vali, uid: UID_A })).json();
    const spy = jest.spyOn(t.fcm, 'pushChildResync');
    await settle();
    spy.mockClear();

    const res = await tap(w.duty, { uid: UID_A, kioskId: 'kiosk-1' });

    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({
      result: 'IN',
      status: 'PRESENT',
      time: '07:52',
      cardNumber: 'K-000001',
      className: '7-A',
      suspicious: false,
      student: { firstName: 'Vali', lastName: 'Aliyev' },
    });
    const record = await t.prisma.schoolAttendance.findUniqueOrThrow({ where: { studentId_date: { studentId: w.vali, date: DAY } } });
    expect(record).toMatchObject({ status: 'PRESENT', inAt: '07:52', source: 'CARD' });
    expect(t.fcm.pushesTo(w.parent.userId).map((p) => p.data?.kind)).toEqual(['ARRIVED']);
    await settle();
    expect(spy).toHaveBeenCalledWith(w.child.userId);

    expect((await tap(w.duty, { uid: UID_A, kioskId: 'kiosk-1' })).json().result).toBe('NONE');
    expect((await tap(w.duty, { uid: '04:00:00:00:00:00:01' })).json()).toMatchObject({ result: 'UNKNOWN', student: null });
    expect((await cards(w.homeroom, 'POST', `/${card.id}/block`, { reason: 'LOST' })).json()).toMatchObject({ status: 'LOST' });
    expect((await tap(w.duty, { uid: UID_A })).json().result).toBe('BLOCKED');
    expect((await tap(w.director, { uid: UID_A })).statusCode).toBe(403);

    const results = (await t.prisma.schoolCardTap.findMany({ orderBy: { at: 'asc' } })).map((r) => r.result);
    expect(results).toEqual(['IN', 'NONE', 'UNKNOWN', 'BLOCKED']);
    // Topilgan karta qayta faollashadi; o'quvchida boshqa faol karta bo'lsa — yo'q.
    expect((await cards(w.director, 'POST', `/${card.id}/unblock`)).json().status).toBe('ACTIVE');
  });

  it('chiqish, shubhali tegish va oflayn navbat', async () => {
    await cards(w.director, 'POST', '', { studentId: w.vali, uid: UID_A });
    await cards(w.director, 'POST', '', { studentId: w.malika, uid: UID_B });
    const early = at(DAY, '07:40');

    // Internet uzilgan: 07:40 dagi tegish 07:52 da yetib keldi — kirish vaqti 07:40.
    expect((await tap(w.duty, { uid: UID_A, kioskId: 'k1', tappedAt: early.toISOString() })).json()).toMatchObject({ result: 'IN', time: '07:40' });
    // Shu o'qigichda 2 soniyadan keyin boshqa karta — shubhali.
    const second = await tap(w.duty, { uid: UID_B, kioskId: 'k1', tappedAt: new Date(early.getTime() + 2_000).toISOString() });
    expect(second.json()).toMatchObject({ result: 'IN', suspicious: true });
    const flagged = (await cards(w.admin, 'GET', '/taps?suspicious=true')).json().items;
    expect(flagged).toHaveLength(1);
    expect(flagged[0]).toMatchObject({ studentName: 'Karimova Malika', cardNumber: 'K-000002', result: 'IN' });
    // 12 soatdan eski navbat qabul qilinmaydi.
    expect((await tap(w.duty, { uid: UID_A, tappedAt: at('2026-10-19', '18:00').toISOString() })).statusCode).toBe(400);

    setNow(t, at(DAY, '13:30'));
    expect((await tap(w.duty, { uid: UID_A, kioskId: 'k2' })).json()).toMatchObject({ result: 'OUT', time: '13:30' });
    expect(t.fcm.pushesTo(w.parent.userId).map((p) => p.data?.kind)).toEqual(['ARRIVED', 'LEFT']);
    setNow(t, at(DAY, '17:00'));
    expect((await tap(w.duty, { uid: UID_B })).json().result).toBe('OUTSIDE');
  });

  it("NTAG 424 DNA: imzolangan kod qabul; qayta yuborilgan, imzosiz, o'zgartirilgan va begona kod — INVALID", async () => {
    const master = await t.app.get(CardKeyService).ensure(w.schoolId);
    const uid = '04A1B2C3D4E5F6';
    const assigned = await cards(w.director, 'POST', '', { studentId: w.vali, url: sunUrl(master, uid, 1) });
    expect(assigned.json()).toMatchObject({ kind: 'SUN', uid });

    const fifth = sunUrl(master, uid, 5);
    expect((await tap(w.duty, { url: fifth, uid: UID_A })).json().result).toBe('IN');
    expect((await tap(w.duty, { url: fifth })).json().result).toBe('INVALID');
    expect((await tap(w.duty, { uid: UID_A })).json().result).toBe('INVALID');
    expect((await tap(w.duty, { url: sunUrl(master, uid, 6, true) })).json().result).toBe('INVALID');
    expect((await tap(w.duty, { url: sunUrl(randomBytes(16), uid, 7) })).json().result).toBe('INVALID');
    expect((await tap(w.duty, { url: sunUrl(master, uid, 8) })).json().result).toBe('NONE');
    expect((await t.prisma.schoolCard.findFirstOrThrow({ where: { uid } })).lastCounter).toBe(8);
    expect((await cards(w.director, 'POST', '', { studentId: w.malika, url: sunUrl(randomBytes(16), '04010203040506', 1) })).json().code).toBe(
      'CARD_CODE_INVALID',
    );
  });

  describe('School Mode «kirgandan boshlab bloklash»', () => {
    const schoolMode = (s: Session, payload: object) =>
      t.app.inject({ method: 'PUT', url: '/api/school/school-mode/policy', headers: { authorization: `Bearer ${s.token}` }, payload });
    const schoolRoutines = async () =>
      (await t.app.inject({ method: 'GET', url: `/api/children/${w.child.childId}/routines`, headers: { authorization: `Bearer ${w.child.token}` } }))
        .json()
        .routines.filter((r: { title: string }) => r.title.startsWith('Maktab'));
    const startOf = (r: { startHour: number; startMinute: number }) => r.startHour * 60 + r.startMinute;

    it("kirish qayd etilishi bilan jadval kirish vaqtidan boshlanadi, hudud sharti tushadi; sababli kelmagan — yo'q", async () => {
      // School Mode haqiqiy vaqt bilan ishlaydi — davomat soati ham haqiqiy.
      t.app.get(AttendanceClock).now = () => new Date();
      const minute = Math.floor(tashkentMinute(new Date()));
      if (minute < 30 || minute > 1439 - 150) return; // yarim tunga yaqin: oyna sig'maydi
      const start = minute + 30;
      const end = minute + 120;
      await t.prisma.schoolShift.update({
        where: { id: w.shiftId },
        data: {
          weekdays: [1, 2, 3, 4, 5, 6, 7],
          start: minutesToHhmm(start),
          end: minutesToHhmm(end),
          periods: [{ no: 1, start: minutesToHhmm(start), end: minutesToHhmm(end), kind: 'LESSON' }],
        },
      });
      await t.prisma.school.update({ where: { id: w.schoolId }, data: { latitude: 41.311081, longitude: 69.240562, zoneRadiusM: 120 } });
      expect((await schoolMode(w.director, { enabled: true, blockFromArrival: true, zoneRequired: true })).json()).toMatchObject({
        blockFromArrival: true,
        zoneRequired: true,
      });

      const [before] = await schoolRoutines();
      expect(startOf(before)).toBe(start);
      expect(before.schoolMode.zone).toMatchObject({ radiusM: 120 });

      await cards(w.director, 'POST', '', { studentId: w.vali, uid: UID_A });
      expect((await tap(w.duty, { uid: UID_A })).json().result).toBe('IN');
      const [after] = await schoolRoutines();
      expect(startOf(after)).toBeLessThanOrEqual(Math.floor(tashkentMinute(new Date())));
      expect(after.endHour * 60 + after.endMinute).toBe(end);
      expect(after.schoolMode.zone).toBeNull();

      const excused = await t.app.inject({
        method: 'POST',
        url: '/api/school/attendance/mark',
        headers: { authorization: `Bearer ${w.admin.token}` },
        payload: { studentId: w.vali, status: 'EXCUSED', reason: "Kasal, shifokor ma'lumotnomasi" },
      });
      expect(excused.statusCode).toBe(200);
      expect(await schoolRoutines()).toEqual([]);
    });
  });
});
