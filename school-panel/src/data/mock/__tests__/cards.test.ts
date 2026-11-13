import { beforeEach, describe, expect, it } from 'vitest';

import { DEMO_ACCOUNTS } from '@/auth/demo-accounts';

import { __setClockForTests } from '../clock';
import { setLatencyEnabled } from '../context';
import { __resetForTests, getDb, getTables } from '../db';
import { cardsService } from '../services/cards';
import { schoolModeService } from '../services/school-mode';
import { loginAs } from './helpers';

const TODAY = '2026-10-12';

/** Demo bazasi belgilangan daqiqada (dushanba): 1-smena 08:00 dan. */
function freshAt(minute: number): void {
  setLatencyEnabled(false);
  __resetForTests();
  __setClockForTests({ mode: 'SCENARIO', scenarioDate: TODAY, scenarioStartMinute: minute, realStartedAt: Date.now(), speed: 1 });
  getDb();
}

/** 1-smena o'quvchisi: bugun hali yozuvi yo'q va faol kartasi bor. */
function arrivingStudent(skip = 0) {
  const t = getTables();
  const firstShift = new Set(t.classes.filter((c) => c.grade >= 5).map((c) => c.id));
  const candidates = t.students.filter(
    (s) =>
      !s.archived &&
      firstShift.has(s.classId) &&
      !t.attendance.some((r) => r.date === TODAY && r.studentId === s.id) &&
      t.cards.some((c) => c.studentId === s.id && c.status === 'ACTIVE'),
  );
  return candidates[skip]!;
}

const activeCard = (studentId: string) => getTables().cards.find((c) => c.studentId === studentId && c.status === 'ACTIVE')!;

describe('NFC kartalar (demo)', () => {
  beforeEach(() => freshAt(7 * 60 + 45));

  it('seed: faol o\'quvchilarning har biriga karta; sinf rahbari faqat o\'z sinfini ko\'radi', async () => {
    const t = getTables();
    expect(t.cards.length).toBe(t.students.filter((s) => !s.archived).length);
    expect(new Set(t.cards.map((c) => c.uid)).size).toBe(t.cards.length);

    loginAs('HOMEROOM');
    const own = await cardsService.list();
    const account = DEMO_ACCOUNTS.find((a) => a.role === 'HOMEROOM')!;
    const staff = t.staff.find((s) => s.id === account.staffId)!;
    expect(own.length).toBeGreaterThan(0);
    expect(own.every((c) => c.classId !== null && staff.classIds.includes(c.classId))).toBe(true);
  });

  it('biriktirish: raqam avtomatik, almashtirishda eski bloklanadi; band karta va noto\'g\'ri UID', async () => {
    loginAs('DIRECTOR');
    const student = arrivingStudent();
    const old = activeCard(student.id);

    const card = await cardsService.assign({ studentId: student.id, uid: '04:aa:bb:cc:dd:ee:01' });

    expect(card).toMatchObject({ uid: '04AABBCCDDEE01', status: 'ACTIVE', replacedNumber: old.number });
    expect(getTables().cards.find((c) => c.id === old.id)).toMatchObject({ status: 'BLOCKED', blockedReason: 'REPLACED' });
    await expect(cardsService.assign({ studentId: arrivingStudent(1).id, uid: '04AABBCCDDEE01' })).rejects.toMatchObject({ detail: 'CARD_TAKEN' });
    await expect(cardsService.assign({ studentId: student.id, uid: 'salom' })).rejects.toMatchObject({ code: 'VALIDATION' });
    loginAs('DUTY');
    await expect(cardsService.assign({ studentId: student.id, uid: '04:aa:bb:cc:dd:ee:02' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('kiosk tegishi: kirdi, takror, noma\'lum, bloklangan va shubhali', async () => {
    const first = arrivingStudent();
    const second = arrivingStudent(1);
    loginAs('DUTY');

    const tap = await cardsService.tap({ uid: activeCard(first.id).uid, kioskId: 'k1' });

    expect(tap).toMatchObject({ result: 'IN', status: 'PRESENT', suspicious: false, student: { id: first.id } });
    expect(getTables().attendance.find((r) => r.date === TODAY && r.studentId === first.id)).toMatchObject({ source: 'CARD', inAt: '07:45' });
    expect((await cardsService.tap({ uid: activeCard(first.id).uid, kioskId: 'k2' })).result).toBe('NONE');
    expect((await cardsService.tap({ uid: '04:00:00:00:00:00:99' })).result).toBe('UNKNOWN');
    // Shu kioskda darhol boshqa karta — shubhali.
    expect(await cardsService.tap({ uid: activeCard(second.id).uid, kioskId: 'k2' })).toMatchObject({ result: 'IN', suspicious: true });

    loginAs('ADMIN');
    const lost = activeCard(first.id);
    await cardsService.block(lost.id, { reason: 'LOST' });
    loginAs('DUTY');
    expect((await cardsService.tap({ uid: lost.uid })).result).toBe('BLOCKED');
    loginAs('ADMIN');
    expect((await cardsService.taps({ suspicious: true })).map((r) => r.studentId)).toEqual([second.id]);
  });

  it('dars vaqtidan tashqari tegish rad etiladi', async () => {
    freshAt(5 * 60 + 30);
    loginAs('DUTY');
    expect((await cardsService.tap({ uid: activeCard(arrivingStudent().id).uid })).result).toBe('OUTSIDE');
  });

  it('School Mode siyosati: «kirgandan boshlab bloklash» saqlanadi', async () => {
    loginAs('DIRECTOR');
    expect((await schoolModeService.updatePolicy({ blockFromArrival: true })).blockFromArrival).toBe(true);
    expect((await schoolModeService.updatePolicy({ relaxDuringBreaks: true })).blockFromArrival).toBe(true);
  });
});
