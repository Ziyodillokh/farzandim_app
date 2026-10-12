import type { AuditLog, EarlyExitRequest, Staff, Student } from '@/data/contracts';
import { addDays } from '../calendar';
import { FIXED_STAFF } from './people';

export function buildEarlyExits(students: Student[], baseIso: string): EarlyExitRequest[] {
  const of = (classId: string, i: number) => students.filter((s) => s.classId === classId)[i];
  const spec: Array<[Student | undefined, string, string, string, EarlyExitRequest['status']]> = [
    [of('cls-7a', 8), '11:40', 'Shifokor qabuli (stomatolog)', 'Onasi — oldindan qo\'ng\'iroq qildi', 'PENDING'],
    [of('cls-10a', 4), '12:25', 'Viloyat olimpiadasiga jo\'nash', 'Murabbiy — Informatika o\'qituvchisi', 'APPROVED'],
    [of('cls-3b', 6), '15:10', 'Oilaviy sabab', 'Bobosi', 'PENDING'],
  ];
  return spec
    .filter((x): x is [Student, string, string, string, EarlyExitRequest['status']] => Boolean(x[0]))
    .map(([student, time, reason, pickupBy, status], i) => ({
      id: `exit-${i + 1}`,
      studentId: student.id,
      classId: student.classId,
      date: baseIso,
      time,
      reason,
      pickupBy,
      status,
      requestedAt: `${baseIso}T07:${String(20 + i * 7).padStart(2, '0')}:00`,
      decidedByStaffId: status === 'APPROVED' ? FIXED_STAFF.admin : null,
      decidedAt: status === 'APPROVED' ? `${baseIso}T08:15:00` : null,
    }));
}

export function buildAudit(staff: Staff[], baseIso: string): AuditLog[] {
  const name = (id: string) => staff.find((s) => s.id === id)?.fullName ?? id;
  const entry = (offsetDays: number, time: string, actorId: string, module: AuditLog['module'], action: string, summary: string, i: number): AuditLog => ({
    id: `aud-seed-${i}`,
    at: `${addDays(baseIso, offsetDays)}T${time}:00`,
    actorId,
    actorName: name(actorId),
    module,
    action,
    entityId: null,
    summary,
    before: null,
    after: null,
  });
  const rows: Array<[number, string, string, AuditLog['module'], string, string]> = [
    [-6, '08:05', FIXED_STAFF.admin, 'SCHOOL_MODE', 'policy.update', '"Dars vaqti" siyosatiga "Lug\'at" ilovasi qo\'shildi'],
    [-5, '10:12', FIXED_STAFF.director, 'SETTINGS', 'school.update', 'Kechikish chegarasi 10 daqiqa etib belgilandi'],
    [-4, '16:40', FIXED_STAFF.admin, 'MESSAGES', 'announcement.send', '"Kuzgi sport musobaqalari" xabari yuborildi'],
    [-3, '09:31', FIXED_STAFF.homeroom7a, 'ATTENDANCE', 'attendance.correct', '7-A: kechikish "sababli" deb tuzatildi (shifokor ma\'lumotnomasi)'],
    [-3, '11:02', FIXED_STAFF.admin, 'PAYMENTS', 'payment.bulkShift', '18 oila uchun eslatma sanasi 1 oyga surildi (oldindan to\'lov)'],
    [-2, '09:15', FIXED_STAFF.director, 'MESSAGES', 'announcement.send', '"Ota-onalar umumiy yig\'ilishi" xabari yuborildi'],
    [-2, '14:48', FIXED_STAFF.admin, 'STUDENTS', 'student.create', '5-B sinfiga yangi o\'quvchi qo\'shildi'],
    [-1, '12:05', FIXED_STAFF.homeroom7a, 'SCHOOL_MODE', 'exception.create', '7-A: tibbiy ilova uchun doimiy istisno'],
    [-1, '18:05', FIXED_STAFF.homeroom7a, 'MESSAGES', 'announcement.send', '"7-A: matematika nazorat ishi" xabari yuborildi'],
    [0, '07:35', FIXED_STAFF.duty, 'AUTH', 'auth.login', 'Kirish nuqtasi ochildi (navbatchi)'],
  ];
  return rows.map(([d, t, actor, module, action, summary], i) => entry(d, t, actor, module, action, summary, i + 1));
}
