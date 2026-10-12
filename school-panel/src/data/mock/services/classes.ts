import type { SchoolClass } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { classInputSchema, type ClassInput } from '@/data/schemas/classes';
import { parseOrThrow } from '@/data/schemas/validate';
import { clockToday } from '../clock';
import { allowedClassIds, assertCan, assertClassInScope, currentActor, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { buildIndexes, classSizes, compareClasses } from '../lookups';
import { attendanceService } from './attendance';

export type ClassRow = SchoolClass & {
  size: number;
  shiftName: string;
  homeroomName: string | null;
  linkedRate: number;
  phoneRate: number;
};

export const classesService = {
  async list(filter: { shiftId?: string; search?: string } = {}): Promise<ClassRow[]> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'classes.view');
    const t = getTables();
    const idx = buildIndexes(t);
    const sizes = classSizes(t);
    const allowed = allowedClassIds(actor);
    const guardians = new Map(t.guardians.map((g) => [g.id, g]));
    const q = filter.search?.trim().toLowerCase() ?? '';
    return t.classes
      .filter((c) => !allowed || allowed.includes(c.id))
      .filter((c) => !filter.shiftId || c.shiftId === filter.shiftId)
      .filter((c) => !q || c.name.toLowerCase().includes(q))
      .sort(compareClasses)
      .map((c) => {
        const students = t.students.filter((s) => !s.archived && s.classId === c.id);
        const linked = students.filter((s) => s.guardianIds.some((g) => guardians.get(g)?.linkStatus === 'LINKED')).length;
        const withPhone = students.filter((s) => s.device !== 'NONE').length;
        return {
          ...c,
          size: sizes.get(c.id) ?? 0,
          shiftName: idx.shifts.get(c.shiftId)?.name ?? '',
          homeroomName: c.homeroomStaffId ? (idx.staff.get(c.homeroomStaffId)?.fullName ?? null) : null,
          linkedRate: students.length ? Math.round((linked / students.length) * 100) : 0,
          phoneRate: students.length ? Math.round((withPhone / students.length) * 100) : 0,
        };
      });
  },

  async get(id: string): Promise<ClassRow> {
    const rows = await classesService.list();
    const row = rows.find((r) => r.id === id);
    if (!row) throw new ServiceError('NOT_FOUND', id);
    return row;
  },

  async create(input: ClassInput): Promise<SchoolClass> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'classes.manage');
    const data = parseOrThrow(classInputSchema, input);
    return transact((t) => {
      const name = `${data.grade}-${data.letter}`;
      if (t.classes.some((c) => c.name === name)) throw new ServiceError('CONFLICT', name);
      const cls: SchoolClass = { id: `cls-${data.grade}${data.letter.toLowerCase()}-${Date.now().toString(36)}`, name, ...data };
      t.classes.push(cls);
      if (cls.homeroomStaffId) assignHomeroom(t, cls.id, cls.homeroomStaffId);
      writeAudit(t, actor, 'CLASSES', 'class.create', `${name} sinfi yaratildi`, cls.id, null, cls);
      return cls;
    });
  },

  async update(id: string, input: ClassInput): Promise<SchoolClass> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'classes.manage');
    const data = parseOrThrow(classInputSchema, input);
    return transact((t) => {
      const index = t.classes.findIndex((c) => c.id === id);
      const before = t.classes[index];
      if (!before) throw new ServiceError('NOT_FOUND', id);
      const name = `${data.grade}-${data.letter}`;
      if (t.classes.some((c) => c.name === name && c.id !== id)) throw new ServiceError('CONFLICT', name);
      const next: SchoolClass = { ...before, ...data, name };
      t.classes[index] = next;
      if (next.homeroomStaffId !== before.homeroomStaffId) assignHomeroom(t, id, next.homeroomStaffId);
      writeAudit(t, actor, 'CLASSES', 'class.update', `${name} sinfi yangilandi`, id, before, next);
      return next;
    });
  },

  async remove(id: string): Promise<void> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'classes.manage');
    transact((t) => {
      const cls = t.classes.find((c) => c.id === id);
      if (!cls) throw new ServiceError('NOT_FOUND', id);
      if (t.students.some((s) => !s.archived && s.classId === id)) throw new ServiceError('CONFLICT', 'class has students');
      t.classes = t.classes.filter((c) => c.id !== id);
      for (const s of t.staff) s.classIds = s.classIds.filter((c) => c !== id);
      writeAudit(t, actor, 'CLASSES', 'class.delete', `${cls.name} sinfi o'chirildi`, id, cls, null);
    });
  },

  /** Sinf kartochkasi uchun bugungi davomat (sinf rahbari ham ko'radi). */
  async today(id: string) {
    const actor = currentActor();
    assertClassInScope(actor, id);
    return attendanceService.classDay(id, clockToday());
  },
};

function assignHomeroom(t: Parameters<Parameters<typeof transact>[0]>[0], classId: string, staffId: string | null): void {
  for (const s of t.staff) {
    if (s.role === 'HOMEROOM') s.classIds = s.classIds.filter((c) => c !== classId);
  }
  if (!staffId) return;
  const staff = t.staff.find((s) => s.id === staffId);
  if (staff && !staff.classIds.includes(classId)) staff.classIds = [...staff.classIds, classId];
}
