import { roleHas } from '@/auth/permissions';
import type { Audience, Guardian, ParentLinkStatus } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { clockNow } from '../clock';
import { type Actor, allowedClassIds } from '../context';
import { buildIndexes, compareClasses, studentName } from '../lookups';
import type { Tables } from '../tables';

/**
 * Xabarlar / eslatmalar / to'lov eslatmalari uchun umumiy yordamchilar:
 * auditoriya (kimga yetib boradi), doira (sinf rahbari faqat o'z sinfi) va vaqt.
 */

/** Parvoz Parents'ga ulangan ota-ona — push; qolganlari — SMS zaxira. */
export type AudienceReach = { students: number; guardians: number; linked: number; sms: number };

export type ChildRef = { id: string; name: string; className: string; classId: string };

/** Mahalliy vaqt "YYYY-MM-DDTHH:MM:SS" (seed bilan bir xil format, UTC'siz). */
export function localIso(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

export function nowLocalIso(): string {
  return localIso(clockNow());
}

/** "2026-10-14T08:00" → "2026-10-14T08:00:00". */
export function normalizeLocal(value: string): string {
  return value.length === 16 ? `${value}:00` : value;
}

export function staffName(t: Tables, staffId: string | null): string {
  if (!staffId) return '—';
  return t.staff.find((s) => s.id === staffId)?.fullName ?? '—';
}

/** Ota-ona → farzandlari (arxivlanmaganlar). */
export function childrenByGuardian(t: Tables): Map<string, ChildRef[]> {
  const idx = buildIndexes(t);
  const map = new Map<string, ChildRef[]>();
  for (const s of t.students) {
    if (s.archived) continue;
    const child: ChildRef = { id: s.id, name: studentName(s), className: idx.classes.get(s.classId)?.name ?? '', classId: s.classId };
    for (const gid of s.guardianIds) map.set(gid, [...(map.get(gid) ?? []), child]);
  }
  return map;
}

/** Auditoriya → o'quvchilar va ota-onalar to'plami. */
export function resolveAudience(t: Tables, audience: Audience): { studentIds: Set<string>; guardianIds: Set<string> } {
  const active = t.students.filter((s) => !s.archived);
  if (audience.kind === 'GUARDIANS') {
    const guardianIds = new Set(audience.guardianIds.filter((id) => t.guardians.some((g) => g.id === id)));
    const studentIds = new Set(active.filter((s) => s.guardianIds.some((g) => guardianIds.has(g))).map((s) => s.id));
    return { studentIds, guardianIds };
  }
  const classIds = audience.kind === 'CLASSES' ? new Set(audience.classIds) : null;
  const students = classIds ? active.filter((s) => classIds.has(s.classId)) : active;
  return { studentIds: new Set(students.map((s) => s.id)), guardianIds: new Set(students.flatMap((s) => s.guardianIds)) };
}

export function reachOf(t: Tables, audience: Audience): AudienceReach {
  const { studentIds, guardianIds } = resolveAudience(t, audience);
  const status = new Map<string, ParentLinkStatus>(t.guardians.map((g) => [g.id, g.linkStatus]));
  let linked = 0;
  for (const id of guardianIds) if (status.get(id) === 'LINKED') linked += 1;
  return { students: studentIds.size, guardians: guardianIds.size, linked, sms: guardianIds.size - linked };
}

/** Ko'rsatish uchun nomlar: sinflar ("5-A") yoki ota-onalar (F.I.Sh.). */
export function audienceNames(t: Tables, audience: Audience): string[] {
  if (audience.kind === 'CLASSES') {
    return t.classes
      .filter((c) => audience.classIds.includes(c.id))
      .sort(compareClasses)
      .map((c) => c.name);
  }
  if (audience.kind === 'GUARDIANS') {
    const byId = new Map<string, Guardian>(t.guardians.map((g) => [g.id, g]));
    return audience.guardianIds.map((id) => byId.get(id)?.fullName).filter((n): n is string => Boolean(n));
  }
  return [];
}

function guardianInClasses(t: Tables, guardianId: string, classIds: readonly string[]): boolean {
  return t.students.some((s) => !s.archived && s.guardianIds.includes(guardianId) && classIds.includes(s.classId));
}

/** Rol va doira bo'yicha shu auditoriyaga yuborish mumkinmi (TZ 2.1). */
export function canSendTo(actor: Actor, t: Tables, audience: Audience): boolean {
  if (roleHas(actor.role, 'messages.sendSchool')) return true;
  if (!roleHas(actor.role, 'messages.sendClass') || audience.kind === 'SCHOOL') return false;
  const allowed = allowedClassIds(actor);
  if (!allowed) return true;
  if (audience.kind === 'CLASSES') return audience.classIds.every((id) => allowed.includes(id));
  return audience.guardianIds.every((id) => guardianInClasses(t, id, allowed));
}

/** Mavjud bo'lmagan sinf/ota-ona → VALIDATION; doiradan tashqari → FORBIDDEN. */
export function assertAudienceAllowed(actor: Actor, t: Tables, audience: Audience): void {
  if (audience.classIds.some((id) => !t.classes.some((c) => c.id === id))) throw new ServiceError('VALIDATION', 'audience.classIds');
  if (audience.guardianIds.some((id) => !t.guardians.some((g) => g.id === id))) throw new ServiceError('VALIDATION', 'audience.guardianIds');
  if (!canSendTo(actor, t, audience)) throw new ServiceError('FORBIDDEN', `audience ${audience.kind}`);
}

/** Xabar yuborish huquqi umuman bormi (maktab yoki sinf). */
export function assertAnySend(actor: Actor): void {
  if (!roleHas(actor.role, 'messages.sendSchool') && !roleHas(actor.role, 'messages.sendClass')) {
    throw new ServiceError('FORBIDDEN', 'messages.send');
  }
}

/** Sinf rahbari ko'radigan auditoriya: butun maktab yoki o'z sinfiga tegishli. */
export function audienceTouchesScope(actor: Actor, t: Tables, audience: Audience): boolean {
  const allowed = allowedClassIds(actor);
  if (!allowed || audience.kind === 'SCHOOL') return true;
  if (audience.kind === 'CLASSES') return audience.classIds.some((id) => allowed.includes(id));
  return audience.guardianIds.some((id) => guardianInClasses(t, id, allowed));
}
