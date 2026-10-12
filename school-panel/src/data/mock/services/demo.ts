import type { School } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { minutesToHhmm } from '@/lib/utils';
import { clockMinute, clockNow, clockToday } from '../clock';
import { assertCan, currentActor, newId, writeAudit } from '../context';
import { getTables, resetDb, transact } from '../db';
import { studentName } from '../lookups';

export type DemoTrigger = 'LATE' | 'EARLY_EXIT' | 'CARE_URGENT' | 'VERIFICATION';

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

  trigger(kind: DemoTrigger): string {
    const actor = currentActor();
    return transact((t) => {
      const today = clockToday();
      const pool = t.students.filter((s) => !s.archived && t.classes.find((c) => c.id === s.classId)?.grade !== undefined);
      const pick = pool[Math.floor(Math.random() * pool.length)];
      if (!pick) throw new ServiceError('NOT_FOUND', 'student');
      const time = minutesToHhmm(Math.floor(clockMinute()));
      switch (kind) {
        case 'LATE': {
          const notIn = pool.filter((s) => !t.attendance.some((r) => r.date === today && r.studentId === s.id && r.inAt));
          const student = notIn[Math.floor(Math.random() * notIn.length)] ?? pick;
          t.attendance = t.attendance.filter((r) => !(r.date === today && r.studentId === student.id));
          t.attendance.push({ id: `${today}:${student.id}`, date: today, studentId: student.id, classId: student.classId, status: 'LATE', inAt: time, outAt: null, source: 'QR', corrections: [], parentNotified: true });
          t.attendanceEvents.push({ id: newId('evt'), at: clockNow().toISOString(), studentId: student.id, classId: student.classId, kind: 'IN', source: 'QR', late: true });
          return studentName(student);
        }
        case 'EARLY_EXIT': {
          t.earlyExits.push({ id: newId('exit'), studentId: pick.id, classId: pick.classId, date: today, time, reason: 'Ota-ona so\'rovi: shifokor qabuli', pickupBy: 'Onasi', status: 'PENDING', requestedAt: clockNow().toISOString(), decidedByStaffId: null, decidedAt: null });
          return studentName(pick);
        }
        case 'CARE_URGENT': {
          t.careRequests.push({ id: newId('care'), studentId: pick.id, classId: pick.classId, createdAt: clockNow().toISOString(), topic: 'BULLYING', message: 'Menga tanaffusda tazyiq o\'tkazishyapti, qo\'rqyapman.', urgency: 'URGENT', status: 'NEW', meetingAt: null, notes: [], protocolActivated: false });
          return 'care';
        }
        case 'VERIFICATION': {
          const payment = t.payments[Math.floor(Math.random() * t.payments.length)];
          if (!payment) throw new ServiceError('NOT_FOUND', 'payment');
          t.verifications.push({ id: newId('ver'), guardianId: payment.guardianId, paymentReminderId: payment.id, message: 'To\'lovni oldindan qilgandim, eslatma xato kelgan bo\'lishi mumkin. Tekshirib bering, iltimos.', createdAt: clockNow().toISOString(), status: 'OPEN', answer: null, answeredByStaffId: null, answeredAt: null });
          return 'verification';
        }
        default: {
          writeAudit(t, actor, 'SETTINGS', 'demo.trigger', kind);
          return kind;
        }
      }
    });
  },
};
