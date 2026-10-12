import { ROLES, type RoleDefinition } from '@/auth/permissions';
import type { AuditLog, AuditModule, ListQuery, Paginated, RoleKey, Staff } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { CLASS_SCOPED_ROLES, staffFormSchema, type StaffInput } from '@/data/schemas/staff';
import { parseOrThrow } from '@/data/schemas/validate';
import { assertCan, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { buildIndexes } from '../lookups';
import { runListQuery } from '../query';
import type { Tables } from '../tables';

export type StaffRow = Staff & { classNames: string[] };

export type StaffSummary = { total: number; active: number; inactive: number; demo: number; byRole: Record<RoleKey, number> };

export type AuditFilter = ListQuery & { module?: AuditModule; actorId?: string; from?: string; to?: string };

const EXPORT_PAGE_LIMIT = 500;

/** Sinf doirasi faqat sinf rahbari va o'qituvchida; boshqa rollarda sinflar tozalanadi. */
function normalizeClassIds(t: Tables, role: RoleKey, classIds: readonly string[]): string[] {
  if (!(CLASS_SCOPED_ROLES as readonly RoleKey[]).includes(role)) return [];
  const unique = [...new Set(classIds)];
  if (unique.some((id) => !t.classes.some((c) => c.id === id))) throw new ServiceError('VALIDATION', 'classIds');
  return unique;
}

/**
 * Sinf rahbari ↔ sinf bog'lanishini sinxronlash: xodim sinflarining
 * `homeroomStaffId`'si shu xodimga o'tadi, oldingi rahbardan sinf olinadi.
 */
function syncHomeroom(t: Tables, staff: Staff): void {
  const owns = new Set(staff.role === 'HOMEROOM' ? staff.classIds : []);
  t.classes = t.classes.map((c) => {
    if (owns.has(c.id)) return c.homeroomStaffId === staff.id ? c : { ...c, homeroomStaffId: staff.id };
    return c.homeroomStaffId === staff.id ? { ...c, homeroomStaffId: null } : c;
  });
  if (owns.size === 0) return;
  t.staff = t.staff.map((s) =>
    s.id !== staff.id && s.role === 'HOMEROOM' && s.classIds.some((c) => owns.has(c))
      ? { ...s, classIds: s.classIds.filter((c) => !owns.has(c)) }
      : s,
  );
}

export const staffService = {
  async list(filter: ListQuery & { role?: RoleKey; active?: boolean } = {}): Promise<Paginated<StaffRow>> {
    await latency(80, 160);
    const actor = currentActor();
    assertCan(actor, 'staff.view');
    const t = getTables();
    const idx = buildIndexes(t);
    const rows = t.staff
      .filter((s) => !filter.role || s.role === filter.role)
      .filter((s) => filter.active === undefined || s.active === filter.active)
      .map((s) => ({ ...s, classNames: s.classIds.map((c) => idx.classes.get(c)?.name ?? '').filter(Boolean) }));
    return runListQuery(rows, filter, {
      searchText: (s) => `${s.fullName} ${s.position} ${s.phone} ${s.email} ${s.classNames.join(' ')}`,
      sorters: { name: (s) => s.fullName, role: (s) => s.role, position: (s) => s.position },
      defaultSort: 'name',
    });
  },

  /** Ro'yxat tanlovlari uchun (sinf rahbari tanlash va h.k.). */
  async options(role?: RoleKey): Promise<Array<{ id: string; fullName: string; role: RoleKey }>> {
    const actor = currentActor();
    assertCan(actor, 'classes.view');
    return getTables()
      .staff.filter((s) => s.active && (!role || s.role === role))
      .map((s) => ({ id: s.id, fullName: s.fullName, role: s.role }))
      .sort((a, b) => a.fullName.localeCompare(b.fullName, 'uz'));
  },

  /** Xodimlar statistikasi (sahifa sarlavhasi va rollar jadvali uchun). */
  async summary(): Promise<StaffSummary> {
    await latency(40, 100);
    const actor = currentActor();
    assertCan(actor, 'staff.view');
    const byRole = Object.fromEntries(Object.keys(ROLES).map((k) => [k, 0])) as Record<RoleKey, number>;
    const staff = getTables().staff;
    for (const s of staff) if (s.active) byRole[s.role] += 1;
    const active = staff.filter((s) => s.active).length;
    return { total: staff.length, active, inactive: staff.length - active, demo: staff.filter((s) => s.username).length, byRole };
  },

  async create(input: StaffInput): Promise<Staff> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'staff.manage');
    const data = parseOrThrow(staffFormSchema, input);
    return transact((t) => {
      const staff: Staff = { id: newId('stf'), ...data, classIds: normalizeClassIds(t, data.role, data.classIds), username: null };
      t.staff = [...t.staff, staff];
      syncHomeroom(t, staff);
      writeAudit(t, actor, 'STAFF', 'staff.create', `Xodim qo'shildi: ${staff.fullName}`, staff.id, null, staff);
      return staff;
    });
  },

  /** Tahrirlash. Faollik `setActive` orqali o'zgaradi; demo hisob roli qulflangan. */
  async update(id: string, input: StaffInput): Promise<Staff> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'staff.manage');
    const data = parseOrThrow(staffFormSchema, input);
    return transact((t) => {
      const before = t.staff.find((s) => s.id === id);
      if (!before) throw new ServiceError('NOT_FOUND', id);
      if (before.username && data.role !== before.role) throw new ServiceError('CONFLICT', 'demo account role');
      const next: Staff = { ...before, ...data, active: before.active, classIds: normalizeClassIds(t, data.role, data.classIds) };
      t.staff = t.staff.map((s) => (s.id === id ? next : s));
      syncHomeroom(t, next);
      writeAudit(t, actor, 'STAFF', 'staff.update', `Xodim yangilandi: ${next.fullName}`, id, before, next);
      return next;
    });
  },

  async setActive(id: string, active: boolean): Promise<Staff> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'staff.manage');
    if (id === actor.staffId) throw new ServiceError('CONFLICT', 'self');
    return transact((t) => {
      const before = t.staff.find((s) => s.id === id);
      if (!before) throw new ServiceError('NOT_FOUND', id);
      if (before.username) throw new ServiceError('CONFLICT', 'demo account');
      const next: Staff = { ...before, active };
      t.staff = t.staff.map((s) => (s.id === id ? next : s));
      writeAudit(
        t,
        actor,
        'STAFF',
        active ? 'staff.activate' : 'staff.deactivate',
        `${next.fullName} ${active ? 'faollashtirildi' : 'faolsizlantirildi'}`,
        id,
        { active: before.active },
        { active },
      );
      return next;
    });
  },

  async roles(): Promise<RoleDefinition[]> {
    const actor = currentActor();
    assertCan(actor, 'staff.view');
    return Object.values(ROLES);
  },
};

export const auditService = {
  async list(filter: AuditFilter = {}): Promise<Paginated<AuditLog>> {
    await latency(80, 160);
    const actor = currentActor();
    assertCan(actor, 'audit.view');
    const rows = getTables()
      .audit.filter((a) => !filter.module || a.module === filter.module)
      .filter((a) => !filter.actorId || a.actorId === filter.actorId)
      .filter((a) => !filter.from || a.at.slice(0, 10) >= filter.from)
      .filter((a) => !filter.to || a.at.slice(0, 10) <= filter.to);
    return runListQuery(rows, { sortBy: 'at', sortDir: 'desc', ...filter }, {
      searchText: (a) => `${a.actorName} ${a.summary} ${a.action}`,
      sorters: { at: (a) => a.at, actor: (a) => a.actorName, module: (a) => a.module },
      defaultSort: 'at',
    });
  },

  /** Eksport uchun — filtr bo'yicha barcha yozuvlar (sahifalashsiz). */
  async exportRows(filter: AuditFilter = {}): Promise<AuditLog[]> {
    const out: AuditLog[] = [];
    for (let page = 1; ; page++) {
      const res = await auditService.list({ ...filter, page, limit: EXPORT_PAGE_LIMIT });
      out.push(...res.items);
      if (page >= res.pagination.totalPages) return out;
    }
  },

  async actors(): Promise<Array<{ id: string; name: string }>> {
    const actor = currentActor();
    assertCan(actor, 'audit.view');
    const seen = new Map<string, string>();
    for (const a of getTables().audit) seen.set(a.actorId, a.actorName);
    return [...seen.entries()].map(([id, name]) => ({ id, name })).sort((a, b) => a.name.localeCompare(b.name, 'uz'));
  },
};
