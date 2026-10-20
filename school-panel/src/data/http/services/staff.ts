import type { AuditLog, Paginated, Staff } from '@/data/contracts';
import type { RoleDefinition } from '@/auth/permissions';
import type { AuditFilter, StaffOption, StaffRow, StaffSummary, auditService, staffService } from '@/data/mock/services/staff';
import type { StaffInput } from '@/data/schemas/staff';
import { http } from '../client';

const EXPORT_PAGE_LIMIT = 500;
const id = (v: string) => encodeURIComponent(v);

export const staffHttp: typeof staffService = {
  list: (filter = {}) => http<Paginated<StaffRow>>('GET', '/school/staff', { query: filter }),
  options: (role) => http<StaffOption[]>('GET', '/school/staff/options', { query: { role } }),
  summary: () => http<StaffSummary>('GET', '/school/staff/summary'),
  create: (input: StaffInput) => http<Staff>('POST', '/school/staff', { body: input }),
  update: (staffId, input: StaffInput) => http<Staff>('PUT', `/school/staff/${id(staffId)}`, { body: input }),
  setActive: (staffId, active) => http<Staff>('PATCH', `/school/staff/${id(staffId)}/active`, { body: { active } }),
  setAccount: (staffId, input) => http<Staff>('PUT', `/school/staff/${id(staffId)}/account`, { body: input }),
  removeAccount: (staffId) => http<Staff>('DELETE', `/school/staff/${id(staffId)}/account`),
  roles: () => http<RoleDefinition[]>('GET', '/school/staff/roles'),
};

export const auditHttp: typeof auditService = {
  list: (filter: AuditFilter = {}) => http<Paginated<AuditLog>>('GET', '/school/audit', { query: filter }),
  async exportRows(filter: AuditFilter = {}) {
    const out: AuditLog[] = [];
    for (let page = 1; ; page++) {
      const res = await auditHttp.list({ ...filter, page, limit: EXPORT_PAGE_LIMIT });
      out.push(...res.items);
      if (page >= res.pagination.totalPages) return out;
    }
  },
  actors: () => http<Array<{ id: string; name: string }>>('GET', '/school/audit/actors'),
};
