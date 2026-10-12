import { roleHas } from '@/auth/permissions';
import type {
  AttendanceRecord,
  DeviceState,
  Guardian,
  ListQuery,
  Paginated,
  ParentLinkStatus,
  SchoolModeException,
  Student,
} from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import {
  guardianInputSchema,
  studentCreateSchema,
  studentInputSchema,
  type GuardianInput,
  type StudentCreateInput,
  type StudentInput,
} from '@/data/schemas/students';
import { parseOrThrow } from '@/data/schemas/validate';
import { hashString } from '@/lib/rng';
import { clockToday } from '../clock';
import { allowedClassIds, assertCan, assertClassInScope, currentActor, inScope, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { buildIndexes, studentFullName, studentName } from '../lookups';
import { runListQuery } from '../query';
import { resolveRecord } from './attendance';

export type StudentRow = Student & {
  fullName: string;
  className: string;
  grade: number;
  linkStatus: ParentLinkStatus;
  guardianNames: string[];
  deviceStatus: DeviceState['status'];
  todayStatus: AttendanceRecord['status'] | null;
};

export type StudentFilter = ListQuery & {
  classId?: string;
  linkStatus?: ParentLinkStatus;
  device?: Student['device'];
  includeArchived?: boolean;
};

export type StudentDetail = StudentRow & {
  guardians: Guardian[];
  homeroomName: string | null;
  shiftName: string;
  today: AttendanceRecord | null;
  exceptions: SchoolModeException[];
  device: Student['device'];
  deviceState: DeviceState | null;
};

/** O'quvchining eng yaxshi ota-ona ulanish holati. */
function bestLink(guardians: Array<Guardian | undefined>): ParentLinkStatus {
  if (guardians.some((g) => g?.linkStatus === 'LINKED')) return 'LINKED';
  if (guardians.some((g) => g?.linkStatus === 'INVITED')) return 'INVITED';
  return 'NOT_INVITED';
}

function toRows(): StudentRow[] {
  const t = getTables();
  const idx = buildIndexes(t);
  const guardians = new Map(t.guardians.map((g) => [g.id, g]));
  const devices = new Map(t.devices.map((d) => [d.studentId, d]));
  const today = clockToday();
  const todayRecords = new Map(t.attendance.filter((r) => r.date === today).map((r) => [r.studentId, r]));
  return t.students.map((s) => {
    const cls = idx.classes.get(s.classId);
    const gs = s.guardianIds.map((id) => guardians.get(id));
    return {
      ...s,
      fullName: studentFullName(s),
      className: cls?.name ?? '—',
      grade: cls?.grade ?? 0,
      linkStatus: bestLink(gs),
      guardianNames: gs.filter((g): g is Guardian => Boolean(g)).map((g) => g.fullName),
      deviceStatus: devices.get(s.id)?.status ?? (s.device === 'NONE' ? 'NO_PHONE' : 'OFFLINE'),
      todayStatus: todayRecords.get(s.id)?.status ?? null,
    };
  });
}

function newStudentCode(existing: Set<string>, seed: string): string {
  let n = hashString(seed) % 9000;
  for (;;) {
    const code = `P-${1000 + n}`;
    if (!existing.has(code)) return code;
    n = (n + 37) % 9000;
  }
}

/**
 * Ota-onaga ulash huquqi yo'q rollar (psixolog) uchun: ota-ona, qurilma va
 * davomat ma'lumotlari servisdan umuman chiqmaydi (TZ: faqat ism va sinf).
 */
function redact(row: StudentRow): StudentRow {
  return { ...row, guardianIds: [], guardianNames: [], linkStatus: 'NOT_INVITED', device: 'NONE', deviceStatus: 'NO_PHONE', todayStatus: null };
}

export const studentsService = {
  async list(filter: StudentFilter = {}): Promise<Paginated<StudentRow>> {
    await latency(80, 180);
    const actor = currentActor();
    assertCan(actor, 'students.view');
    if (filter.classId) assertClassInScope(actor, filter.classId);
    const minimal = !roleHas(actor.role, 'guardians.link');
    const rows = inScope(actor, toRows()).map((r) => (minimal ? redact(r) : r)).filter(
      (r) =>
        (filter.includeArchived || !r.archived) &&
        (!filter.classId || r.classId === filter.classId) &&
        (!filter.linkStatus || r.linkStatus === filter.linkStatus) &&
        (!filter.device || r.device === filter.device),
    );
    return runListQuery(rows, filter, {
      searchText: (r) => `${r.fullName} ${r.studentCode} ${r.className} ${r.guardianNames.join(' ')}`,
      sorters: {
        name: (r) => `${r.lastName} ${r.firstName}`,
        class: (r) => r.grade * 10 + (r.className.endsWith('B') ? 1 : 0),
        birthDate: (r) => r.birthDate,
        link: (r) => r.linkStatus,
      },
      defaultSort: 'name',
    });
  },

  /** Eksport uchun — filtr bo'yicha barcha qatorlar (sahifalashsiz). */
  async exportRows(filter: StudentFilter = {}): Promise<StudentRow[]> {
    const page = await studentsService.list({ ...filter, page: 1, limit: 500 });
    if (page.pagination.totalPages <= 1) return page.items;
    const rest = await Promise.all(
      Array.from({ length: page.pagination.totalPages - 1 }, (_, i) => studentsService.list({ ...filter, page: i + 2, limit: 500 })),
    );
    return [...page.items, ...rest.flatMap((p) => p.items)];
  },

  async get(id: string): Promise<StudentDetail> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'students.view');
    const t = getTables();
    const row = toRows().find((r) => r.id === id);
    if (!row) throw new ServiceError('NOT_FOUND', id);
    assertClassInScope(actor, row.classId);
    const idx = buildIndexes(t);
    const cls = idx.classes.get(row.classId);
    const today = clockToday();
    const stored = t.attendance.find((r) => r.date === today && r.studentId === id);
    // Psixolog uchun minimal ma'lumot (TZ: faqat ism va sinf).
    const minimal = !roleHas(actor.role, 'guardians.link');
    return {
      ...(minimal ? redact(row) : row),
      guardians: minimal ? [] : t.guardians.filter((g) => row.guardianIds.includes(g.id)),
      homeroomName: cls?.homeroomStaffId ? (idx.staff.get(cls.homeroomStaffId)?.fullName ?? null) : null,
      shiftName: cls ? (idx.shifts.get(cls.shiftId)?.name ?? '') : '',
      today: minimal ? null : resolveRecord(t, row, today, today, stored),
      exceptions: minimal ? [] : t.exceptions.filter((e) => e.studentId === id),
      deviceState: minimal ? null : (t.devices.find((d) => d.studentId === id) ?? null),
    };
  },

  async create(input: StudentCreateInput): Promise<Student> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    const data = parseOrThrow(studentCreateSchema, input);
    return transact((t) => {
      if (!t.classes.some((c) => c.id === data.classId)) throw new ServiceError('VALIDATION', 'classId');
      const id = newId('stu');
      const guardianIds: string[] = [];
      if (data.guardian) {
        const guardian: Guardian = { id: newId('grd'), ...data.guardian, linkStatus: 'NOT_INVITED', inviteCode: null, inviteExpiresAt: null, linkedAt: null };
        t.guardians.push(guardian);
        guardianIds.push(guardian.id);
      }
      const { guardian: _guardian, ...fields } = data;
      void _guardian;
      const student: Student = {
        id,
        ...fields,
        guardianIds,
        studentCode: newStudentCode(new Set(t.students.map((s) => s.studentCode)), id),
        enrolledAt: clockToday(),
        archived: false,
      };
      t.students.push(student);
      t.devices.push({ studentId: id, status: student.device === 'NONE' ? 'NO_PHONE' : 'NO_PERMISSION', lastSeenAt: null });
      writeAudit(t, actor, 'STUDENTS', 'student.create', `${studentName(student)} qo'shildi`, id, null, student);
      return student;
    });
  },

  async update(id: string, input: StudentInput): Promise<Student> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    const data = parseOrThrow(studentInputSchema, input);
    return transact((t) => {
      const index = t.students.findIndex((s) => s.id === id);
      const before = t.students[index];
      if (!before) throw new ServiceError('NOT_FOUND', id);
      const next: Student = { ...before, ...data };
      t.students[index] = next;
      const device = t.devices.find((d) => d.studentId === id);
      if (device && before.device !== next.device) device.status = next.device === 'NONE' ? 'NO_PHONE' : 'NO_PERMISSION';
      writeAudit(t, actor, 'STUDENTS', 'student.update', `${studentName(next)} ma'lumotlari yangilandi`, id, before, next);
      return next;
    });
  },

  async setArchived(id: string, archived: boolean): Promise<Student> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    return transact((t) => {
      const student = t.students.find((s) => s.id === id);
      if (!student) throw new ServiceError('NOT_FOUND', id);
      student.archived = archived;
      writeAudit(t, actor, 'STUDENTS', archived ? 'student.archive' : 'student.restore', `${studentName(student)} ${archived ? 'arxivga olindi' : 'qayta tiklandi'}`, id);
      return student;
    });
  },

  /** CSV import: [familiya, ism, otasining ismi, sinf (7-A), jinsi (M/F), tug'ilgan sana, ota-ona, telefon]. */
  async importRows(rows: string[][]): Promise<{ created: number; skipped: Array<{ row: number; reason: string }> }> {
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    const t = getTables();
    const classByName = new Map(t.classes.map((c) => [c.name.toUpperCase(), c.id]));
    let created = 0;
    const skipped: Array<{ row: number; reason: string }> = [];
    for (const [i, cells] of rows.entries()) {
      const [lastName = '', firstName = '', middleName = '', className = '', gender = '', birthDate = '', guardianName = '', phone = ''] = cells.map((c) => c.trim());
      const classId = classByName.get(className.toUpperCase());
      if (!classId) {
        skipped.push({ row: i + 1, reason: `class:${className}` });
        continue;
      }
      try {
        await studentsService.create({
          lastName,
          firstName,
          middleName,
          classId,
          gender: /^(f|q|ж|female)/i.test(gender) ? 'FEMALE' : 'MALE',
          birthDate: /^\d{4}-\d{2}-\d{2}$/.test(birthDate) ? birthDate : '2014-01-01',
          device: 'NONE',
          guardian: guardianName && phone ? { fullName: guardianName, phone, relation: 'OTHER' } : undefined,
        });
        created += 1;
      } catch (error) {
        skipped.push({ row: i + 1, reason: error instanceof Error ? error.message : 'invalid' });
      }
    }
    return { created, skipped };
  },
};

export const guardiansService = {
  async list(filter: ListQuery & { linkStatus?: ParentLinkStatus; classId?: string } = {}): Promise<
    Paginated<Guardian & { children: Array<{ id: string; name: string; className: string }> }>
  > {
    await latency(80, 180);
    const actor = currentActor();
    assertCan(actor, 'students.view');
    if (actor.role === 'PSYCHOLOGIST') throw new ServiceError('FORBIDDEN', 'guardians');
    const t = getTables();
    const idx = buildIndexes(t);
    const allowed = allowedClassIds(actor);
    const childrenOf = new Map<string, Array<{ id: string; name: string; className: string; classId: string }>>();
    for (const s of t.students) {
      if (s.archived) continue;
      for (const gid of s.guardianIds) {
        const list = childrenOf.get(gid) ?? [];
        list.push({ id: s.id, name: studentName(s), className: idx.classes.get(s.classId)?.name ?? '', classId: s.classId });
        childrenOf.set(gid, list);
      }
    }
    const rows = t.guardians
      .map((g) => ({ ...g, children: childrenOf.get(g.id) ?? [] }))
      .filter((g) => g.children.length > 0)
      .filter((g) => !allowed || g.children.some((c) => allowed.includes(c.classId)))
      .filter((g) => !filter.linkStatus || g.linkStatus === filter.linkStatus)
      .filter((g) => !filter.classId || g.children.some((c) => c.classId === filter.classId));
    return runListQuery(rows, filter, {
      searchText: (g) => `${g.fullName} ${g.phone} ${g.children.map((c) => `${c.name} ${c.className}`).join(' ')}`,
      sorters: { name: (g) => g.fullName, status: (g) => g.linkStatus },
      defaultSort: 'name',
    });
  },

  /** Statistika: ulanganlar ulushi (bosh sahifa va ota-onalar sahifasi). */
  async stats(): Promise<Record<ParentLinkStatus, number> & { total: number }> {
    const page = await guardiansService.list({ limit: 500 });
    const all = page.pagination.totalPages > 1 ? await guardiansService.list({ limit: 5000 }) : page;
    const counts = { LINKED: 0, INVITED: 0, NOT_INVITED: 0, total: all.pagination.total };
    for (const g of all.items) counts[g.linkStatus] += 1;
    return counts;
  },

  /** Taklif kodi (7 kun amal qiladi) — ota-ona Parvoz Parents'da kiritadi. */
  async invite(guardianId: string): Promise<Guardian> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    return transact((t) => {
      const guardian = t.guardians.find((g) => g.id === guardianId);
      if (!guardian) throw new ServiceError('NOT_FOUND', guardianId);
      assertGuardianInScope(t, actor, guardianId);
      if (guardian.linkStatus === 'LINKED') throw new ServiceError('CONFLICT', 'linked');
      const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      const code = Array.from({ length: 6 }, (_, i) => alphabet[(hashString(`${guardianId}${Date.now()}${i}`) >>> 3) % alphabet.length]).join('');
      guardian.linkStatus = 'INVITED';
      guardian.inviteCode = code;
      guardian.inviteExpiresAt = new Date(Date.now() + 7 * 86_400_000).toISOString();
      writeAudit(t, actor, 'GUARDIANS', 'guardian.invite', `${guardian.fullName}ga Parvoz taklifi yuborildi (SMS)`, guardianId);
      return guardian;
    });
  },

  /** Demo: "ota-ona ilovada kodni kiritdi" — ulanishni simulyatsiya qilish. */
  async simulateLink(guardianId: string): Promise<Guardian> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    return transact((t) => {
      const guardian = t.guardians.find((g) => g.id === guardianId);
      if (!guardian) throw new ServiceError('NOT_FOUND', guardianId);
      assertGuardianInScope(t, actor, guardianId);
      guardian.linkStatus = 'LINKED';
      guardian.linkedAt = new Date().toISOString();
      guardian.inviteCode = null;
      guardian.inviteExpiresAt = null;
      writeAudit(t, actor, 'GUARDIANS', 'guardian.linked', `${guardian.fullName} Parvoz Parents'ga ulandi`, guardianId);
      return guardian;
    });
  },

  async addToStudent(studentId: string, input: GuardianInput): Promise<Guardian> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    const data = parseOrThrow(guardianInputSchema, input);
    return transact((t) => {
      const student = t.students.find((s) => s.id === studentId);
      if (!student) throw new ServiceError('NOT_FOUND', studentId);
      assertClassInScope(actor, student.classId);
      const guardian: Guardian = { id: newId('grd'), ...data, linkStatus: 'NOT_INVITED', inviteCode: null, inviteExpiresAt: null, linkedAt: null };
      t.guardians.push(guardian);
      student.guardianIds = [...student.guardianIds, guardian.id];
      writeAudit(t, actor, 'GUARDIANS', 'guardian.create', `${studentName(student)}ga ota-ona qo'shildi: ${guardian.fullName}`, guardian.id);
      return guardian;
    });
  },

  async update(guardianId: string, input: GuardianInput): Promise<Guardian> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    const data = parseOrThrow(guardianInputSchema, input);
    return transact((t) => {
      const guardian = t.guardians.find((g) => g.id === guardianId);
      if (!guardian) throw new ServiceError('NOT_FOUND', guardianId);
      assertGuardianInScope(t, actor, guardianId);
      const before = { ...guardian };
      Object.assign(guardian, data);
      writeAudit(t, actor, 'GUARDIANS', 'guardian.update', `${guardian.fullName} ma'lumotlari yangilandi`, guardianId, before, guardian);
      return guardian;
    });
  },
};

function assertGuardianInScope(t: ReturnType<typeof getTables>, actor: ReturnType<typeof currentActor>, guardianId: string): void {
  const allowed = allowedClassIds(actor);
  if (!allowed) return;
  const ok = t.students.some((s) => s.guardianIds.includes(guardianId) && allowed.includes(s.classId));
  if (!ok) throw new ServiceError('FORBIDDEN', guardianId);
}
