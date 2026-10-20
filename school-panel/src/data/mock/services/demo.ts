import { type Permission, roleHas } from '@/auth/permissions';
import type { RoleKey, School } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { minutesToHhmm } from '@/lib/utils';
import { simulateSurveyResponses } from '../care-sim';
import { clockMinute, clockNow, clockToday } from '../clock';
import { toLocalIso } from '../calendar';
import { assertCan, currentActor, inScope, newId, writeAudit } from '../context';
import { getTables, resetDb, transact } from '../db';
import { studentName } from '../lookups';
import { tickPsychAssignments } from '../psych/sim';

export type DemoTrigger = 'LATE' | 'EARLY_EXIT' | 'CARE_URGENT' | 'VERIFICATION' | 'SURVEY_RESPONSES' | 'TEST_COMPLETIONS';

/** Natija: `count` — so'rovnoma javoblari / test natijalari soni (boshqalarda null). */
export type DemoTriggerResult = { kind: DemoTrigger; count: number | null };

/** "Tezlashtirish": javoblar/natijalar shuncha daqiqa oldinga simulyatsiya qilinadi. */
const FAST_FORWARD_MINUTES = 30;

/**
 * Trigger tashqi hodisani simulyatsiya qiladi (o'quvchi QR'i, ota-ona so'rovi,
 * bola murojaati, ilovadagi javoblar) — faqat shu hodisani ko'ra oladigan rolga
 * va uning doirasida.
 */
const TRIGGER_ACCESS: Record<DemoTrigger, { perms: readonly Permission[]; roles?: readonly RoleKey[] }> = {
  LATE: { perms: ['attendance.view'] },
  EARLY_EXIT: { perms: ['attendance.earlyExit'] },
  CARE_URGENT: { perms: ['care.individual', 'care.aggregate'] },
  VERIFICATION: { perms: ['payments.manage'] },
  // So'rovnoma natijalarini psixolog (shaxsiy) va direktor (umumlashgan) kuzatadi.
  SURVEY_RESPONSES: { perms: ['care.surveys'], roles: ['DIRECTOR'] },
  TEST_COMPLETIONS: { perms: ['assessments.manage'] },
};

export function availableTriggers(role: RoleKey): DemoTrigger[] {
  return (Object.keys(TRIGGER_ACCESS) as DemoTrigger[]).filter((k) => {
    const access = TRIGGER_ACCESS[k];
    return access.perms.some((p) => roleHas(role, p)) || Boolean(access.roles?.includes(role));
  });
}

/** Demo boshqaruvi: tiklash va taqdimot paytida hodisa chaqirish. */
export const demoService = {
  /** Tiklash — maktab nomi/logosi (brend) saqlanadi. */
  reset(): void {
    const actor = currentActor();
    assertCan(actor, 'demo.reset');
    const brand: Pick<School, 'name' | 'shortName' | 'city' | 'logo'> = (() => {
      const s = getTables().school;
      return { name: s.name, shortName: s.shortName, city: s.city, logo: s.logo };
    })();
    resetDb();
    transact((t) => {
      t.school = { ...t.school, ...brand };
    });
  },

  trigger(kind: DemoTrigger): DemoTriggerResult {
    const actor = currentActor();
    if (!availableTriggers(actor.role).includes(kind)) throw new ServiceError('FORBIDDEN', `demo.${kind}`);
    if (kind === 'SURVEY_RESPONSES' || kind === 'TEST_COMPLETIONS') {
      return transact((t) => {
        writeAudit(t, actor, 'SETTINGS', 'demo.trigger', `Demo hodisa: ${kind}`);
        const minute = Math.floor(clockMinute()) + FAST_FORWARD_MINUTES;
        const run = kind === 'SURVEY_RESPONSES' ? simulateSurveyResponses : tickPsychAssignments;
        return { kind, count: run(t, clockToday(), minute) };
      });
    }
    transact((t) => {
      const today = clockToday();
      const now = toLocalIso(clockNow());
      const pool = inScope(actor, t.students.filter((s) => !s.archived));
      const pick = pool[Math.floor(Math.random() * pool.length)];
      if (!pick) throw new ServiceError('NOT_FOUND', 'student');
      const time = minutesToHhmm(Math.floor(clockMinute()));
      // Auditda shaxs yo'q — faqat qaysi simulyatsiya ishga tushgani.
      writeAudit(t, actor, 'SETTINGS', 'demo.trigger', `Demo hodisa: ${kind}`);
      switch (kind) {
        case 'LATE': {
          const notIn = pool.filter((s) => !t.attendance.some((r) => r.date === today && r.studentId === s.id && r.inAt));
          const student = notIn[Math.floor(Math.random() * notIn.length)] ?? pick;
          t.attendance = t.attendance.filter((r) => !(r.date === today && r.studentId === student.id));
          t.attendance.push({ id: `${today}:${student.id}`, date: today, studentId: student.id, classId: student.classId, status: 'LATE', inAt: time, outAt: null, source: 'QR', corrections: [], parentNotified: true });
          t.attendanceEvents.push({ id: newId('evt'), at: now, studentId: student.id, classId: student.classId, kind: 'IN', source: 'QR', late: true });
          return studentName(student);
        }
        case 'EARLY_EXIT': {
          t.earlyExits.push({ id: newId('exit'), studentId: pick.id, classId: pick.classId, date: today, time, reason: 'Ota-ona so\'rovi: shifokor qabuli', pickupBy: 'Onasi', status: 'PENDING', requestedAt: now, decidedByStaffId: null, decidedAt: null });
          return studentName(pick);
        }
        case 'CARE_URGENT': {
          t.careRequests.push({ id: newId('care'), studentId: pick.id, classId: pick.classId, createdAt: now, topic: 'BULLYING', message: 'Menga tanaffusda tazyiq o\'tkazishyapti, qo\'rqyapman.', urgency: 'URGENT', status: 'NEW', meetingAt: null, notes: [], protocolActivated: false });
          return 'care';
        }
        case 'VERIFICATION': {
          const payment = t.payments[Math.floor(Math.random() * t.payments.length)];
          if (!payment) throw new ServiceError('NOT_FOUND', 'payment');
          t.verifications.push({ id: newId('ver'), guardianId: payment.guardianId, paymentReminderId: payment.id, message: 'To\'lovni oldindan qilgandim, eslatma xato kelgan bo\'lishi mumkin. Tekshirib bering, iltimos.', createdAt: now, status: 'OPEN', answer: null, answeredByStaffId: null, answeredAt: null });
          return 'verification';
        }
      }
    });
    return { kind, count: null };
  },
};
