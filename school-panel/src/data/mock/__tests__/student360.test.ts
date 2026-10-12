import { beforeEach, describe, expect, it } from 'vitest';

import { forbiddenHints } from '@/auth/forbidden-hints';
import { roleHas, type Permission } from '@/auth/permissions';
import { findRoute } from '@/auth/route-manifest';
import type { RoleKey } from '@/data/contracts';
import { visibleStudentTabs } from '@/features/students/student-tabs';
import { getTables, transact } from '../db';
import { attendanceService } from '../services/attendance';
import { schoolModeService } from '../services/school-mode';
import { studentsService } from '../services/students';
import { freshDb, loginAs } from './helpers';

const TODAY = '2026-10-12';
const NOTE = 'Onasi bilan suhbat: haftada ikki marta qo\'shimcha mashg\'ulot';

function studentIn(classId: string, index = 0): string {
  const student = getTables().students.filter((s) => s.classId === classId && !s.archived)[index];
  if (!student) throw new Error(classId);
  return student.id;
}

/** 7-A o'quvchisi, oilasida to'lov eslatmasi bor. */
function studentWithPayment(): string {
  const t = getTables();
  const ids = new Set(t.students.filter((s) => s.classId === 'cls-7a' && !s.archived).map((s) => s.id));
  const payment = t.payments.find((p) => p.studentIds.some((id) => ids.has(id)));
  const id = payment?.studentIds.find((sid) => ids.has(sid));
  if (!id) throw new Error('no 7-A payment');
  return id;
}

describe('O\'quvchi 360°: eslatmalar — huquq va doira', () => {
  beforeEach(freshDb);

  it('sinf rahbari o\'z sinfi o\'quvchisiga eslatma qo\'shadi va ko\'radi', async () => {
    loginAs('HOMEROOM');
    const id = studentIn('cls-7a');
    const note = await studentsService.addNote(id, `  ${NOTE}  `);
    expect(note.text).toBe(NOTE);
    expect(note.classId).toBe('cls-7a');
    const list = await studentsService.notes(id);
    expect(list).toHaveLength(1);
    expect(list[0]).toMatchObject({ text: NOTE, canDelete: true });
    expect(list[0]?.byName).toBe('Rasulova Malika Hamidovna');
  });

  it('sinf rahbari boshqa sinf o\'quvchisi uchun — FORBIDDEN', async () => {
    loginAs('HOMEROOM');
    const other = studentIn('cls-8b');
    await expect(studentsService.notes(other)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(studentsService.addNote(other, NOTE)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    expect(getTables().studentNotes).toHaveLength(0);
  });

  it('psixolog eslatmalarni o\'qiy ham, yoza ham olmaydi — FORBIDDEN', async () => {
    loginAs('PSYCHOLOGIST');
    const id = studentIn('cls-7a');
    await expect(studentsService.notes(id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(studentsService.addNote(id, NOTE)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    // Bo'sh matn bilan ham avval huquq tekshiriladi.
    await expect(studentsService.addNote(id, '')).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('matn 1–1000 belgi: bo\'sh va 1001 — VALIDATION, 1000 — saqlanadi', async () => {
    loginAs('ADMIN');
    const id = studentIn('cls-5b');
    await expect(studentsService.addNote(id, '   ')).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(studentsService.addNote(id, 'x'.repeat(1001))).rejects.toMatchObject({ code: 'VALIDATION' });
    const note = await studentsService.addNote(id, 'y'.repeat(1000));
    expect(note.text).toHaveLength(1000);
  });

  it('audit yozuvida eslatma matni yo\'q — faqat parametrlar', async () => {
    loginAs('HOMEROOM');
    const id = studentIn('cls-7a');
    const note = await studentsService.addNote(id, NOTE);
    const entry = getTables().audit.at(-1);
    expect(entry).toMatchObject({ module: 'STUDENTS', action: 'student.note.add', entityId: note.id, before: null, after: null });
    expect(entry?.params).toMatchObject({ chars: NOTE.length });
    expect(JSON.stringify(entry)).not.toContain('suhbat');

    await studentsService.deleteNote(note.id);
    const removed = getTables().audit.at(-1);
    expect(removed?.action).toBe('student.note.delete');
    expect(JSON.stringify(removed)).not.toContain('suhbat');
    expect(getTables().studentNotes).toHaveLength(0);
  });

  it('o\'chirish: muallif yoki direktor/admin; sinf rahbari boshqaning eslatmasini o\'chira olmaydi', async () => {
    loginAs('ADMIN');
    const id = studentIn('cls-7a');
    const adminNote = await studentsService.addNote(id, 'Admin eslatmasi');
    loginAs('HOMEROOM');
    expect((await studentsService.notes(id))[0]?.canDelete).toBe(false);
    await expect(studentsService.deleteNote(adminNote.id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    const own = await studentsService.addNote(id, 'Sinf rahbari eslatmasi');
    loginAs('DIRECTOR');
    await studentsService.deleteNote(own.id);
    expect(getTables().studentNotes.map((n) => n.id)).toEqual([adminNote.id]);
    await expect(studentsService.deleteNote('note-yoq')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('O\'quvchi 360°: tarix', () => {
  beforeEach(freshDb);

  it('erta ketish, tuzatish, ota-onaga xabar va istisno bitta lentada (eng yangisi birinchi)', async () => {
    loginAs('ADMIN');
    const id = studentIn('cls-7a', 2);
    await attendanceService.correct({ studentId: id, date: '2026-10-09', status: 'EXCUSED', reason: 'Shifokor ma\'lumotnomasi' });
    const exit = await attendanceService.createEarlyExit({ studentId: id, time: '12:30', reason: 'Shifokor', pickupBy: 'Onasi' });
    await schoolModeService.createException({ studentId: id, until: '11:30', reason: 'Tibbiy ilova' });
    transact((t) => {
      const guardianId = t.students.find((s) => s.id === id)?.guardianIds[0] ?? 'g';
      t.parentNotifications.push({ id: 'ntf-test', at: `${TODAY}T09:05:00`, studentId: id, guardianId, kind: 'ARRIVED', delivered: true });
    });

    const history = await studentsService.history(id);
    const kinds = new Set(history.items.map((i) => i.kind));
    expect(kinds).toEqual(new Set(['CORRECTION', 'EARLY_EXIT', 'EXCEPTION', 'NOTIFICATION', ...(history.items.some((i) => i.kind === 'PAYMENT') ? ['PAYMENT'] : [])]));
    expect(history.items.find((i) => i.kind === 'EARLY_EXIT')).toMatchObject({ id: `exit:${exit.id}`, status: 'PENDING', time: '12:30', pickupBy: 'Onasi' });
    expect(history.items.find((i) => i.kind === 'CORRECTION')).toMatchObject({ date: '2026-10-09', to: 'EXCUSED', reason: 'Shifokor ma\'lumotnomasi' });
    expect(history.items.find((i) => i.kind === 'NOTIFICATION')).toMatchObject({ notification: 'ARRIVED', delivered: true });
    const times = history.items.map((i) => Date.parse(i.at));
    expect(times).toEqual([...times].sort((a, b) => b - a));
    // Boshqa o'quvchining yozuvlari aralashmaydi.
    expect(history.items.every((i) => i.kind !== 'NOTIFICATION' || i.id === 'ntf:ntf-test')).toBe(true);
  });

  it('to\'lov eslatmasi holati faqat `payments.manage` bilan: admin ko\'radi, sinf rahbari — yo\'q', async () => {
    const id = studentWithPayment();
    loginAs('ADMIN');
    const admin = await studentsService.history(id);
    expect(admin.payment).not.toBeNull();
    expect(admin.items.some((i) => i.kind === 'PAYMENT')).toBe(true);

    loginAs('HOMEROOM');
    const homeroom = await studentsService.history(id);
    expect(homeroom.payment).toBeNull();
    expect(homeroom.items.some((i) => i.kind === 'PAYMENT')).toBe(false);
  });

  it('tarix: psixolog va boshqa sinf uchun sinf rahbari — FORBIDDEN', async () => {
    loginAs('PSYCHOLOGIST');
    await expect(studentsService.history(studentIn('cls-7a'))).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('HOMEROOM');
    await expect(studentsService.history(studentIn('cls-8b'))).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(studentsService.history('stu-yoq')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('O\'quvchi 360°: rol bo\'yicha tablar', () => {
  const tabsOf = (role: RoleKey) => visibleStudentTabs((p: Permission) => roleHas(role, p));

  it('psixolog — profil va rivojlanish; direktor/admin — rivojlanishsiz; sinf rahbari — hammasi', () => {
    expect(tabsOf('PSYCHOLOGIST')).toEqual(['profile', 'development']);
    expect(tabsOf('DIRECTOR')).toEqual(['profile', 'attendance', 'history', 'notes']);
    expect(tabsOf('ADMIN')).toEqual(['profile', 'attendance', 'history', 'notes']);
    expect(tabsOf('HOMEROOM')).toEqual(['profile', 'attendance', 'development', 'history', 'notes']);
    expect(tabsOf('TEACHER')).toEqual(['profile']);
  });
});

describe('"Ruxsat yo\'q": rolga mos izoh va muqobil havolalar', () => {
  const roles: RoleKey[] = ['DIRECTOR', 'ADMIN', 'HOMEROOM', 'PSYCHOLOGIST', 'DUTY'];

  it('direktorga "direktorga murojaat qiling" demaydi', () => {
    const hint = forbiddenHints('DIRECTOR', '/care/requests');
    expect(hint.adviceKey).toBe('auth.forbiddenAdvice.DIRECTOR');
    expect(hint.sectionKey).toBe('nav.careRequests');
    expect(hint.allowedRoles).toEqual(['PSYCHOLOGIST']);
    expect(forbiddenHints('HOMEROOM', '/audit').adviceKey).toBe('auth.forbiddenAdvice.STAFF');
  });

  it('muqobillar: ko\'pi bilan 3 ta, rolga ochiq, bosh sahifasiz va avval shu bo\'limdan', () => {
    for (const role of roles) {
      for (const path of ['/audit', '/care/requests', '/attendance/corrections', '/settings', '/reminders/payments']) {
        const { links } = forbiddenHints(role, path);
        expect(links.length).toBeLessThanOrEqual(3);
        expect(links.length).toBeGreaterThan(0);
        expect(links.some((l) => l.path === '/dashboard' || l.path === path)).toBe(false);
        for (const l of links) expect(roleHas(role, findRoute(l.path)?.perm ?? 'demo.reset'), `${role} ${l.path}`).toBe(true);
      }
    }
    expect(forbiddenHints('DIRECTOR', '/care/requests').links[0]?.path).toBe('/care');
    expect(forbiddenHints('DUTY', '/attendance/corrections').links.map((l) => l.path)).toContain('/attendance');
  });
});
