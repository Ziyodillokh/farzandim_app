// School Mode ma'lumotlari: maktabning yagona siyosati (birinchi o'qishda
// standart, o'chirilgan holda yaratiladi), favqulodda holat yozuvi, smenalar
// va bugungi bayram — o'qish / yozish servislari va bola qurilmasi uchun.

import { Injectable } from '@nestjs/common';
import { Prisma, SchoolEmergency, SchoolModePolicy, SchoolShift } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { BellPeriod, ShiftLike } from './school-mode-time';

type Db = Prisma.TransactionClient | PrismaService;

export const DEFAULT_POLICY_NAME = 'Dars vaqti — asosiy tartib';
const DEFAULT_BLOCKED = ['GAME', 'SOCIAL', 'VIDEO'];

export interface AllowedApp {
  id: string;
  name: string;
  category: string;
}

export type NamedShift = ShiftLike & { name: string };

export interface ModeContext {
  shifts: NamedShift[];
  holidays: Array<{ id: string; date: string; name: string }>;
  policy: SchoolModePolicy;
  emergency: SchoolEmergency;
}

/** JSON davr — faqat to'g'ri shakldagilari. */
function toPeriod(p: unknown): BellPeriod[] {
  if (!p || typeof p !== 'object') return [];
  const v = p as Record<string, unknown>;
  if (typeof v.start !== 'string' || typeof v.end !== 'string' || (v.kind !== 'LESSON' && v.kind !== 'BREAK')) return [];
  return [{ no: typeof v.no === 'number' ? v.no : 1, start: v.start, end: v.end, kind: v.kind }];
}

export function toShiftLike(s: SchoolShift): NamedShift {
  const periods = Array.isArray(s.periods) ? s.periods.flatMap(toPeriod) : [];
  return { id: s.id, name: s.name, start: s.start, end: s.end, weekdays: s.weekdays, periods };
}

export function allowedAppsOf(policy: SchoolModePolicy): AllowedApp[] {
  if (!Array.isArray(policy.allowedApps)) return [];
  return policy.allowedApps.flatMap((a) => {
    if (!a || typeof a !== 'object' || Array.isArray(a)) return [];
    const { id, name, category } = a as Record<string, unknown>;
    return typeof id === 'string' && typeof name === 'string' && typeof category === 'string' ? [{ id, name, category }] : [];
  });
}

export function toPolicyView(policy: SchoolModePolicy) {
  return {
    id: policy.id,
    name: policy.name,
    blockedCategories: policy.blockedCategories,
    allowedApps: allowedAppsOf(policy),
    alwaysAllowCalls: true as const,
    shiftIds: policy.shiftIds,
    enabled: policy.enabled,
    relaxDuringBreaks: policy.relaxDuringBreaks,
    zoneRequired: policy.zoneRequired,
  };
}

/**
 * Favqulodda o'chirish kuchdami: faol VA muddati o'tmagan. Standart muddat — yoqilgan kun oxiri (Toshkent);
 * `until`siz eski yozuv — `at` kuni oxirigacha. Muddati o'tgan o'chirish ertasi kuni o'z-o'zidan tugaydi
 * (School Mode qayta ishlaydi) — direktor uni o'chirishni unutib qo'ysa ham.
 */
export function emergencyLive(e: Pick<SchoolEmergency, 'active' | 'until' | 'at'>, now = new Date()): boolean {
  if (!e.active) return false;
  if (e.until) return e.until.getTime() > now.getTime();
  return e.at ? tashkentDay(e.at) === tashkentDay(now) : false;
}

/** Muddati o'tgan o'chirish — o'chiq ko'rinadi (DB keyingi yoqishda yangilanadi). */
export const effectiveEmergency = (e: SchoolEmergency, now = new Date()): SchoolEmergency =>
  emergencyLive(e, now) ? e : { ...e, active: false };

export function toEmergencyView(e: SchoolEmergency, now = new Date()) {
  const live = effectiveEmergency(e, now);
  return {
    active: live.active,
    scope: live.scope === 'CLASS' ? ('CLASS' as const) : ('SCHOOL' as const),
    classIds: live.classIds,
    reason: live.reason,
    byStaffId: live.byStaffId,
    at: live.at?.toISOString() ?? null,
    until: live.active ? (live.until?.toISOString() ?? null) : null,
  };
}

@Injectable()
export class SchoolModeStore {
  constructor(private readonly prisma: PrismaService) {}

  /** Yagona siyosat; yo'q bo'lsa standart (o'chirilgan — direktor ongli ravishda yoqadi). */
  async policy(schoolId: string, db: Db = this.prisma): Promise<SchoolModePolicy> {
    const existing = await db.schoolModePolicy.findFirst({ where: { schoolId }, orderBy: { createdAt: 'asc' } });
    if (existing) return existing;
    return this.prisma.$transaction(async (tx) => {
      // Parallel birinchi o'qishlarda ikkinchi siyosat yaratilmasin.
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`school-mode-policy:${schoolId}`}, 0))`;
      const again = await tx.schoolModePolicy.findFirst({ where: { schoolId }, orderBy: { createdAt: 'asc' } });
      if (again) return again;
      const shifts = await tx.schoolShift.findMany({ where: { schoolId }, select: { id: true } });
      return tx.schoolModePolicy.create({
        data: {
          schoolId,
          name: DEFAULT_POLICY_NAME,
          blockedCategories: DEFAULT_BLOCKED,
          shiftIds: shifts.map((s) => s.id),
          enabled: false,
          relaxDuringBreaks: false,
        },
      });
    });
  }

  emergency(schoolId: string, db: Db = this.prisma): Promise<SchoolEmergency> {
    return db.schoolEmergency.upsert({ where: { schoolId }, create: { schoolId }, update: {} });
  }

  async context(schoolId: string, day: string): Promise<ModeContext> {
    const [shifts, holidays, policy, emergency] = await Promise.all([
      this.prisma.schoolShift.findMany({ where: { schoolId }, orderBy: [{ sortOrder: 'asc' }, { start: 'asc' }] }),
      this.prisma.schoolHoliday.findMany({ where: { schoolId, date: day } }),
      this.policy(schoolId),
      this.emergency(schoolId),
    ]);
    return { shifts: shifts.map(toShiftLike), holidays, policy, emergency: effectiveEmergency(emergency) };
  }
}
