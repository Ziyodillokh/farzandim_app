import type { Guardian, IsoDate, SchoolClass, Shift, Staff } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { bulkInviteSchema, classInputSchema, type BulkInviteInput, type ClassInput } from '@/data/schemas/classes';
import { parseOrThrow } from '@/data/schemas/validate';
import { hashString } from '@/lib/rng';
import { clockMinute, clockNow, clockToday } from '../clock';
import { allowedClassIds, assertCan, assertClassInScope, currentActor, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { buildIndexes, classSizes, compareClasses, type Indexes } from '../lookups';
import { classModeState, type ClassModeState } from '../school-mode-state';
import type { Tables } from '../tables';
import { attendanceService } from './attendance';
import { guardiansService } from './students';

export type ClassRow = SchoolClass & {
  size: number;
  shiftName: string;
  homeroomName: string | null;
  linkedRate: number;
  phoneRate: number;
};

export type ClassHomeroom = Pick<Staff, 'id' | 'fullName' | 'position' | 'phone' | 'email' | 'active'>;

export type ClassDetail = ClassRow & {
  shift: Shift | null;
  homeroom: ClassHomeroom | null;
  /** Hali taklif qilinmagan ota-onalar soni (ommaviy taklif tugmasi uchun). */
  notInvitedGuardians: number;
};

export type ClassModeNow = { classId: string; date: IsoDate; minute: number; state: ClassModeState };

const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const INVITE_CODE_LENGTH = 6;
const INVITE_TTL_MS = 7 * 86_400_000;
const BULK_PAGE_LIMIT = 500;

function toRow(t: Tables, c: SchoolClass, idx: Indexes, sizes: Map<string, number>, guardians: Map<string, Guardian>): ClassRow {
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
}

/** Smena va sinf rahbari haqiqatan mavjudligini tekshirish. */
function assertClassRefs(t: Tables, shiftId: string, homeroomStaffId: string | null): void {
  if (!t.shifts.some((s) => s.id === shiftId)) throw new ServiceError('VALIDATION', 'shiftId');
  if (!homeroomStaffId) return;
  const staff = t.staff.find((s) => s.id === homeroomStaffId);
  if (!staff || staff.role !== 'HOMEROOM' || !staff.active) throw new ServiceError('VALIDATION', 'homeroomStaffId');
}

function newInviteCode(seed: string, taken: Set<string>): string {
  for (let attempt = 0; ; attempt++) {
    const code = Array.from(
      { length: INVITE_CODE_LENGTH },
      (_, i) => INVITE_ALPHABET[hashString(`${seed}:${attempt}:${i}`) % INVITE_ALPHABET.length],
    ).join('');
    if (!taken.has(code)) {
      taken.add(code);
      return code;
    }
  }
}

/** Filtrga mos, hali taklif qilinmagan ota-onalar (ro'yxat bilan AYNAN bir xil mantiq). */
async function notInvitedIds(filter: BulkInviteInput): Promise<string[]> {
  const ids: string[] = [];
  for (let page = 1; ; page++) {
    const res = await guardiansService.list({ ...filter, linkStatus: 'NOT_INVITED', page, limit: BULK_PAGE_LIMIT });
    ids.push(...res.items.map((g) => g.id));
    if (page >= res.pagination.totalPages) return ids;
  }
}

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
      .map((c) => toRow(t, c, idx, sizes, guardians));
  },

  async get(id: string): Promise<ClassRow> {
    const rows = await classesService.list();
    const row = rows.find((r) => r.id === id);
    if (!row) throw new ServiceError('NOT_FOUND', id);
    return row;
  },

  /** Sinf sahifasi: qator + smena + sinf rahbari kontakti. */
  async detail(id: string): Promise<ClassDetail> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'classes.view');
    const t = getTables();
    const cls = t.classes.find((c) => c.id === id);
    if (!cls) throw new ServiceError('NOT_FOUND', id);
    assertClassInScope(actor, id);
    const idx = buildIndexes(t);
    const guardians = new Map(t.guardians.map((g) => [g.id, g]));
    const staff = cls.homeroomStaffId ? idx.staff.get(cls.homeroomStaffId) : undefined;
    const guardianIds = new Set(t.students.filter((s) => !s.archived && s.classId === id).flatMap((s) => s.guardianIds));
    return {
      ...toRow(t, cls, idx, classSizes(t), guardians),
      shift: idx.shifts.get(cls.shiftId) ?? null,
      homeroom: staff
        ? { id: staff.id, fullName: staff.fullName, position: staff.position, phone: staff.phone, email: staff.email, active: staff.active }
        : null,
      notInvitedGuardians: [...guardianIds].filter((g) => guardians.get(g)?.linkStatus === 'NOT_INVITED').length,
    };
  },

  /** Sinfning hozirgi School Mode holati (demo soati bo'yicha). */
  async modeNow(id: string): Promise<ClassModeNow> {
    await latency(30, 80);
    const actor = currentActor();
    assertCan(actor, 'classes.view');
    const t = getTables();
    const cls = t.classes.find((c) => c.id === id);
    if (!cls) throw new ServiceError('NOT_FOUND', id);
    assertClassInScope(actor, id);
    const date = clockToday();
    const minute = Math.floor(clockMinute());
    return { classId: id, date, minute, state: classModeState(t, cls, date, minute) };
  },

  /** Barcha (ruxsat etilgan) sinflarning hozirgi School Mode holati. */
  async modesNow(): Promise<Record<string, ClassModeState>> {
    await latency(30, 80);
    const actor = currentActor();
    assertCan(actor, 'classes.view');
    const t = getTables();
    const allowed = allowedClassIds(actor);
    const date = clockToday();
    const minute = Math.floor(clockMinute());
    const out: Record<string, ClassModeState> = {};
    for (const cls of t.classes) {
      if (allowed && !allowed.includes(cls.id)) continue;
      out[cls.id] = classModeState(t, cls, date, minute);
    }
    return out;
  },

  async create(input: ClassInput): Promise<SchoolClass> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'classes.manage');
    const data = parseOrThrow(classInputSchema, input);
    return transact((t) => {
      assertClassRefs(t, data.shiftId, data.homeroomStaffId);
      const name = `${data.grade}-${data.letter}`;
      if (t.classes.some((c) => c.name === name)) throw new ServiceError('CONFLICT', name);
      const cls: SchoolClass = { id: `cls-${data.grade}${data.letter.toLowerCase()}-${Date.now().toString(36)}`, name, ...data };
      t.classes.push(cls);
      if (cls.homeroomStaffId) assignHomeroom(t, cls.id, cls.homeroomStaffId);
      writeAudit(t, actor, 'CLASSES', 'class.create', `${name} sinfi yaratildi`, cls.id, null, cls, { name });
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
      assertClassRefs(t, data.shiftId, data.homeroomStaffId === before.homeroomStaffId ? null : data.homeroomStaffId);
      const name = `${data.grade}-${data.letter}`;
      if (t.classes.some((c) => c.name === name && c.id !== id)) throw new ServiceError('CONFLICT', name);
      const next: SchoolClass = { ...before, ...data, name };
      t.classes[index] = next;
      if (next.homeroomStaffId !== before.homeroomStaffId) assignHomeroom(t, id, next.homeroomStaffId);
      writeAudit(t, actor, 'CLASSES', 'class.update', `${name} sinfi yangilandi`, id, before, next, { name });
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
      t.staff = t.staff.map((s) => (s.classIds.includes(id) ? { ...s, classIds: s.classIds.filter((c) => c !== id) } : s));
      writeAudit(t, actor, 'CLASSES', 'class.delete', `${cls.name} sinfi o'chirildi`, id, cls, null, { name: cls.name });
    });
  },

  /** Sinf kartochkasi uchun bugungi davomat (sinf rahbari ham ko'radi). */
  async today(id: string) {
    const actor = currentActor();
    assertClassInScope(actor, id);
    return attendanceService.classDay(id, clockToday());
  },

  /**
   * Ommaviy taklif: filtrga mos (sinf, qidiruv), hali taklif qilinmagan barcha
   * ota-onalarga Parvoz Parents kodi (7 kun). Jurnalga bitta yozuv.
   */
  async inviteGuardians(input: BulkInviteInput = {}): Promise<{ invited: number }> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    const filter = parseOrThrow(bulkInviteSchema, input);
    if (filter.classId) assertClassInScope(actor, filter.classId);
    const ids = await notInvitedIds(filter);
    if (ids.length === 0) return { invited: 0 };
    return transact((t) => {
      const wanted = new Set(ids);
      const taken = new Set(t.guardians.map((g) => g.inviteCode).filter((c): c is string => Boolean(c)));
      const expiresAt = new Date(clockNow().getTime() + INVITE_TTL_MS).toISOString();
      const stamp = Date.now().toString(36);
      let invited = 0;
      t.guardians = t.guardians.map((g) => {
        if (!wanted.has(g.id) || g.linkStatus !== 'NOT_INVITED') return g;
        invited += 1;
        return { ...g, linkStatus: 'INVITED', inviteCode: newInviteCode(`${g.id}:${stamp}`, taken), inviteExpiresAt: expiresAt };
      });
      const className = filter.classId ? t.classes.find((c) => c.id === filter.classId)?.name : null;
      const scope = className ? `${className} sinfi: ` : '';
      writeAudit(t, actor, 'GUARDIANS', 'guardian.inviteBulk', `${scope}${invited} ota-onaga Parvoz taklifi yuborildi (SMS)`, filter.classId ?? null, null, {
        invited,
        guardianIds: ids,
      }, className ? { variant: 'class', className, count: invited } : { variant: 'all', count: invited });
      return { invited };
    });
  },
};

function assignHomeroom(t: Tables, classId: string, staffId: string | null): void {
  t.staff = t.staff.map((s) => {
    if (s.role === 'HOMEROOM' && s.id !== staffId && s.classIds.includes(classId)) {
      return { ...s, classIds: s.classIds.filter((c) => c !== classId) };
    }
    if (s.id === staffId && !s.classIds.includes(classId)) return { ...s, classIds: [...s.classIds, classId] };
    return s;
  });
}
