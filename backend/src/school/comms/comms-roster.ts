// Maktab "ro'yxati" (sinflar, vasiylar, faol o'quvchilar) — bitta so'rovda
// yuklanadi, auditoriya hisoblari esa xotirada (panel `comms-shared.ts` bilan
// bir xil mantiq): kimga yetib boradi, doira (sinf rahbari — faqat o'z sinfi).

import { GuardianLinkStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { actorCan, allowedClassIds, SchoolActor } from '../auth/school-actor';
import { compareClasses } from '../common/list-query';
import { forbidden, invalid } from '../common/school-errors';
import { Audience, AUDIENCE_KINDS } from './comms.schemas';

type Db = Prisma.TransactionClient | PrismaService;

export interface RosterGuardian {
  id: string;
  fullName: string;
  phone: string;
  linkStatus: GuardianLinkStatus;
  /** Parvoz Parents foydalanuvchisi — push faqat shunga boradi. */
  userId: string | null;
}

export interface RosterStudent {
  id: string;
  classId: string | null;
  name: string;
  guardianIds: string[];
}

export interface RosterClass {
  id: string;
  name: string;
  grade: number;
  letter: string;
}

export interface Roster {
  classes: Map<string, RosterClass>;
  guardians: Map<string, RosterGuardian>;
  /** Faqat arxivlanmagan o'quvchilar. */
  students: RosterStudent[];
  /** Vasiy → farzandlari o'qiydigan sinflar. */
  guardianClasses: Map<string, Set<string>>;
}

/** Ota-onaga ulangan (push) va qolganlari (SMS zaxira). */
export interface AudienceReach {
  students: number;
  guardians: number;
  linked: number;
  sms: number;
}

export interface ChildRef {
  id: string;
  name: string;
  className: string;
  classId: string;
}

export async function loadRoster(db: Db, schoolId: string): Promise<Roster> {
  const classes = await db.schoolClass.findMany({
    where: { schoolId },
    select: { id: true, name: true, grade: true, letter: true },
  });
  const guardians = await db.schoolGuardian.findMany({
    where: { schoolId },
    select: { id: true, fullName: true, phone: true, linkStatus: true, userId: true },
  });
  const students = await db.schoolStudent.findMany({
    where: { schoolId, archived: false },
    select: { id: true, classId: true, lastName: true, firstName: true, guardians: { select: { guardianId: true } } },
    orderBy: [{ lastName: 'asc' }, { firstName: 'asc' }],
  });
  const rosterStudents = students.map((s) => ({
    id: s.id,
    classId: s.classId,
    name: `${s.lastName} ${s.firstName}`,
    guardianIds: s.guardians.map((g) => g.guardianId),
  }));
  const guardianClasses = new Map<string, Set<string>>();
  for (const s of rosterStudents) {
    if (!s.classId) continue;
    for (const gid of s.guardianIds) guardianClasses.set(gid, new Set([...(guardianClasses.get(gid) ?? []), s.classId]));
  }
  return {
    classes: new Map(classes.map((c) => [c.id, c])),
    // Push faqat Parvoz Parents'ga ulangan (LINKED + userId) vasiyga.
    guardians: new Map(guardians.map((g) => [g.id, { ...g, userId: g.linkStatus === 'LINKED' ? g.userId : null }])),
    students: rosterStudents,
    guardianClasses,
  };
}

/** Bazadagi `audience` JSON → tur (buzilgan qiymat — butun maktab emas, bo'sh ro'yxat). */
export function toAudience(value: Prisma.JsonValue): Audience {
  const v = (value && typeof value === 'object' && !Array.isArray(value) ? value : {}) as Record<string, unknown>;
  const ids = (x: unknown) => (Array.isArray(x) ? x.filter((i): i is string => typeof i === 'string') : []);
  const kind = AUDIENCE_KINDS.find((k) => k === v.kind) ?? 'GUARDIANS';
  return { kind, classIds: ids(v.classIds), guardianIds: ids(v.guardianIds) };
}

/** Auditoriya → o'quvchilar va vasiylar to'plami. */
export function resolveAudience(r: Roster, a: Audience): { studentIds: Set<string>; guardianIds: Set<string> } {
  if (a.kind === 'GUARDIANS') {
    const guardianIds = new Set(a.guardianIds.filter((id) => r.guardians.has(id)));
    const studentIds = new Set(r.students.filter((s) => s.guardianIds.some((g) => guardianIds.has(g))).map((s) => s.id));
    return { studentIds, guardianIds };
  }
  const classIds = a.kind === 'CLASSES' ? new Set(a.classIds) : null;
  const students = classIds ? r.students.filter((s) => s.classId !== null && classIds.has(s.classId)) : r.students;
  const guardianIds = new Set(students.flatMap((s) => s.guardianIds).filter((id) => r.guardians.has(id)));
  return { studentIds: new Set(students.map((s) => s.id)), guardianIds };
}

/** Qabul qiluvchi vasiylar (barqaror tartibda). */
export function audienceGuardians(r: Roster, a: Audience): RosterGuardian[] {
  const { guardianIds } = resolveAudience(r, a);
  return [...guardianIds].map((id) => r.guardians.get(id)).filter((g): g is RosterGuardian => Boolean(g));
}

export function reachOf(r: Roster, a: Audience): AudienceReach {
  const guardians = audienceGuardians(r, a);
  const linked = guardians.filter((g) => g.userId !== null).length;
  const students = resolveAudience(r, a).studentIds.size;
  return { students, guardians: guardians.length, linked, sms: guardians.length - linked };
}

/** Ko'rsatish uchun nomlar: sinflar ("5-A") yoki vasiylar (F.I.Sh.). */
export function audienceNames(r: Roster, a: Audience): string[] {
  if (a.kind === 'CLASSES') {
    return a.classIds
      .map((id) => r.classes.get(id))
      .filter((c): c is RosterClass => Boolean(c))
      .sort(compareClasses)
      .map((c) => c.name);
  }
  if (a.kind === 'GUARDIANS') {
    return a.guardianIds.map((id) => r.guardians.get(id)?.fullName).filter((n): n is string => Boolean(n));
  }
  return [];
}

function guardianInClasses(r: Roster, guardianId: string, classIds: readonly string[]): boolean {
  const own = r.guardianClasses.get(guardianId);
  return Boolean(own && classIds.some((id) => own.has(id)));
}

/** Rol va doira bo'yicha shu auditoriyaga yuborish mumkinmi (TZ 2.1). */
export function canSendTo(actor: SchoolActor, r: Roster, a: Audience): boolean {
  if (actorCan(actor, 'messages.sendSchool')) return true;
  if (!actorCan(actor, 'messages.sendClass') || a.kind === 'SCHOOL') return false;
  const allowed = allowedClassIds(actor);
  if (!allowed) return true;
  if (a.kind === 'CLASSES') return a.classIds.every((id) => allowed.includes(id));
  return a.guardianIds.every((id) => guardianInClasses(r, id, allowed));
}

/** Mavjud bo'lmagan sinf / vasiy → VALIDATION; doiradan tashqari → FORBIDDEN. */
export function assertAudienceAllowed(actor: SchoolActor, r: Roster, a: Audience): void {
  if (a.classIds.some((id) => !r.classes.has(id))) throw invalid('audience.classIds');
  if (a.guardianIds.some((id) => !r.guardians.has(id))) throw invalid('audience.guardianIds');
  if (!canSendTo(actor, r, a)) throw forbidden(`audience ${a.kind}`);
}

/** Xabar yuborish huquqi umuman bormi (maktab yoki sinf). */
export function assertAnySend(actor: SchoolActor): void {
  if (!actorCan(actor, 'messages.sendSchool') && !actorCan(actor, 'messages.sendClass')) {
    throw forbidden('messages.send');
  }
}

/** Sinf rahbari ko'radigan auditoriya: butun maktab yoki o'z sinfiga tegishli. */
export function audienceTouchesScope(actor: SchoolActor, r: Roster, a: Audience): boolean {
  const allowed = allowedClassIds(actor);
  if (!allowed || a.kind === 'SCHOOL') return true;
  if (a.kind === 'CLASSES') return a.classIds.some((id) => allowed.includes(id));
  return a.guardianIds.some((id) => guardianInClasses(r, id, allowed));
}

/** Vasiy → farzandlari (arxivlanmaganlar). */
export function childrenByGuardian(r: Roster): Map<string, ChildRef[]> {
  const map = new Map<string, ChildRef[]>();
  for (const s of r.students) {
    const child: ChildRef = {
      id: s.id,
      name: s.name,
      className: (s.classId && r.classes.get(s.classId)?.name) || '',
      classId: s.classId ?? '',
    };
    for (const gid of s.guardianIds) map.set(gid, [...(map.get(gid) ?? []), child]);
  }
  return map;
}
