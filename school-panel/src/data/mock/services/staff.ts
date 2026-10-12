import { ROLES, type RoleDefinition } from '@/auth/permissions';
import type { AuditLog, AuditModule, ListQuery, Paginated, RoleKey, Staff } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { staffInputSchema, type StaffInput } from '@/data/schemas/staff';
import { parseOrThrow } from '@/data/schemas/validate';
import { assertCan, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { buildIndexes } from '../lookups';
import { runListQuery } from '../query';

export type StaffRow = Staff & { classNames: string[] };

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
      searchText: (s) => `${s.fullName} ${s.position} ${s.phone} ${s.classNames.join(' ')}`,
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

  async create(input: StaffInput): Promise<Staff> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'staff.manage');
    const data = parseOrThrow(staffInputSchema, input);
    return transact((t) => {
      const staff: Staff = { id: newId('stf'), ...data, username: null };
      t.staff.push(staff);
      writeAudit(t, actor, 'STAFF', 'staff.create', `Xodim qo'shildi: ${staff.fullName}`, staff.id, null, staff);
      return staff;
    });
  },

  async update(id: string, input: StaffInput): Promise<Staff> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'staff.manage');
    const data = parseOrThrow(staffInputSchema, input);
    return transact((t) => {
      const index = t.staff.findIndex((s) => s.id === id);
      const before = t.staff[index];
      if (!before) throw new ServiceError('NOT_FOUND', id);
      if (before.username && data.role !== before.role) throw new ServiceError('CONFLICT', 'demo account role');
      const next: Staff = { ...before, ...data };
      t.staff[index] = next;
      if (next.role === 'HOMEROOM') {
        for (const cls of t.classes) {
          if (next.classIds.includes(cls.id)) cls.homeroomStaffId = next.id;
          else if (cls.homeroomStaffId === next.id) cls.homeroomStaffId = null;
        }
      }
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
      const staff = t.staff.find((s) => s.id === id);
      if (!staff) throw new ServiceError('NOT_FOUND', id);
      if (staff.username) throw new ServiceError('CONFLICT', 'demo account');
      staff.active = active;
      writeAudit(t, actor, 'STAFF', active ? 'staff.activate' : 'staff.deactivate', `${staff.fullName} ${active ? 'faollashtirildi' : 'faolsizlantirildi'}`, id);
      return staff;
    });
  },

  async roles(): Promise<RoleDefinition[]> {
    const actor = currentActor();
    assertCan(actor, 'staff.view');
    return Object.values(ROLES);
  },
};

export const auditService = {
  async list(filter: ListQuery & { module?: AuditModule; actorId?: string; from?: string; to?: string } = {}): Promise<Paginated<AuditLog>> {
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

  async actors(): Promise<Array<{ id: string; name: string }>> {
    const actor = currentActor();
    assertCan(actor, 'audit.view');
    const seen = new Map<string, string>();
    for (const a of getTables().audit) seen.set(a.actorId, a.actorName);
    return [...seen.entries()].map(([id, name]) => ({ id, name })).sort((a, b) => a.name.localeCompare(b.name, 'uz'));
  },
};
