import { getSession } from '@/auth/session';
import { type Permission, roleHas, ROLES, type Scope } from '@/auth/permissions';
import type { AuditLog, AuditModule, RoleKey } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { sleep } from '@/lib/utils';
import { toLocalIso } from './calendar';
import { clockNow } from './clock';
import { getTables } from './db';
import type { Tables } from './tables';

/** Servis chaqiruvidagi foydalanuvchi — kelajakdagi backend guard'lari bilan bir xil mantiq. */
export type Actor = { staffId: string; name: string; role: RoleKey; scope: Scope; classIds: string[] };

export function currentActor(): Actor {
  const session = getSession();
  if (!session) throw new ServiceError('FORBIDDEN', 'not authenticated');
  const staff = getTables().staff.find((s) => s.id === session.staffId);
  return {
    staffId: session.staffId,
    name: staff?.fullName ?? session.username,
    role: session.role,
    scope: ROLES[session.role].scope,
    classIds: staff?.classIds ?? [],
  };
}

export function assertCan(actor: Actor, permission: Permission): void {
  if (!roleHas(actor.role, permission)) throw new ServiceError('FORBIDDEN', permission);
}

/** `null` — butun maktab; aks holda ruxsat etilgan sinflar. */
export function allowedClassIds(actor: Actor): string[] | null {
  return actor.scope === 'SCHOOL' ? null : actor.classIds;
}

export function assertClassInScope(actor: Actor, classId: string): void {
  const allowed = allowedClassIds(actor);
  if (allowed && !allowed.includes(classId)) throw new ServiceError('FORBIDDEN', `class ${classId}`);
}

export function inScope<T extends { classId: string }>(actor: Actor, items: readonly T[]): T[] {
  const allowed = allowedClassIds(actor);
  return allowed ? items.filter((i) => allowed.includes(i.classId)) : [...items];
}

let seq = 0;
export function newId(prefix: string): string {
  seq += 1;
  return `${prefix}-${Date.now().toString(36)}${seq.toString(36)}${Math.floor(Math.random() * 1e4).toString(36)}`;
}

/** Har o'zgarish — audit jurnaliga (kim, nima, qachon, oldin/keyin). */
export function writeAudit(
  tables: Tables,
  actor: Actor,
  module: AuditModule,
  action: string,
  summary: string,
  entityId: string | null = null,
  before: unknown = null,
  after: unknown = null,
  /** Tarjima parametrlari: audit sahifasi `audit.actions.<action>` kalitini shular bilan render qiladi. */
  params?: Record<string, string | number>,
): void {
  const entry: AuditLog = {
    id: newId('aud'),
    // Demo soati bo'yicha (ssenariyda panel ko'rsatayotgan vaqt bilan mos), mahalliy format.
    at: toLocalIso(clockNow()),
    actorId: actor.staffId,
    actorName: actor.name,
    module,
    action,
    entityId,
    summary,
    ...(params ? { params } : {}),
    before,
    after,
  };
  tables.audit.push(entry);
}

/** Tarmoq kechikishini taqlid qilish (yuklanish holatlari ko'rinsin). Testda 0. */
let latencyEnabled = true;
export function setLatencyEnabled(enabled: boolean): void {
  latencyEnabled = enabled;
}
export async function latency(min = 120, max = 300): Promise<void> {
  if (!latencyEnabled) return;
  await sleep(min + Math.random() * (max - min));
}
