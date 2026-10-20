// Bola qurilmasida School Mode. Android bola ilovasi har 15 soniyada
// `GET /children/:id/routines` ni o'qib, hozirgi oynadagi jadvallarning
// `blockedApps` paketlarini bloklaydi — School Mode shu ro'yxatga virtual
// "Maktab" jadvallari sifatida qo'shiladi (ilovani o'zgartirish shart emas,
// ota-ona ularni tahrirlay olmaydi). iOS: ota-ona qurilmada tanlagan
// ilovalar to'plami (virtual paket) dars oynalarida bloklanadi — tanlov
// qurilmadan chiqmaydi. O'zgarishda bolaga jim `restrictions_sync` push.

import { Injectable, Logger } from '@nestjs/common';
import { SchoolModePolicy } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { addDays, tashkentDay, tashkentDayStart, isoWeekday } from '../../common/time/tashkent';
import { classifyPackage, IOS_SELECTION_PACKAGE } from '../../modules/installed-apps/app-category.util';
import { allowedAppsOf, SchoolModeStore } from './school-mode-store';
import {
  dayWindowOf,
  emergencyCovers,
  isSchoolDay,
  policyCovers,
  restrictedWindows,
  subtractWindow,
  Window,
} from './school-mode-time';

/** Hisoblangan jadval shu muddat keshda turadi (yozuvda maktab versiyasi oshadi). */
const CACHE_TTL_MS = 60_000;
/** Bola ilovasining o'zi va Parvoz ilovalari hech qachon bloklanmaydi. */
const SELF_PACKAGE_PREFIXES = ['com.farzandim', 'uz.parvoz'];
export const SCHOOL_ROUTINE_TITLE = 'Maktab (School Mode)';
const PUSH_BATCH = 25;

export interface VirtualRoutine {
  id: string;
  childId: string;
  title: string;
  type: 'SCHOOL';
  startHour: number;
  startMinute: number;
  endHour: number;
  endMinute: number;
  weekdays: number[];
  isActive: true;
  blockedApps: string[];
  source: 'SCHOOL_MODE';
  createdAt: Date;
  updatedAt: Date;
}

interface CacheEntry {
  expiresAt: number;
  day: string;
  schoolId: string | null;
  version: number;
  routines: VirtualRoutine[];
}

const normalizeName = (name: string) => name.trim().toLowerCase().replace(/\s+/g, ' ');

@Injectable()
export class SchoolModeSyncService {
  private readonly logger = new Logger(SchoolModeSyncService.name);
  private readonly cache = new Map<string, CacheEntry>();
  private readonly versions = new Map<string, number>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly store: SchoolModeStore,
    private readonly fcm: FcmService,
  ) {}

  /** Bugungi School Mode oynalari — bola ilovasi jadvallari formatida. */
  async routinesForChild(childId: string, now = new Date()): Promise<VirtualRoutine[]> {
    const day = tashkentDay(now);
    const hit = this.cache.get(childId);
    if (hit && hit.expiresAt > now.getTime() && hit.day === day && hit.version === this.version(hit.schoolId)) {
      return hit.routines;
    }
    const { schoolId, routines } = await this.compute(childId, day, now);
    this.cache.set(childId, { expiresAt: now.getTime() + CACHE_TTL_MS, day, schoolId, version: this.version(schoolId), routines });
    return routines;
  }

  /**
   * Maktab o'zgarishi: kesh bekor, ta'sir qilgan bog'langan bolalarga jim push
   * (ilova darhol qayta sync qiladi). Best-effort — xato yozuvni buzmaydi.
   */
  async resync(schoolId: string, scope: { classIds?: string[]; studentIds?: string[] } = {}): Promise<void> {
    this.versions.set(schoolId, this.version(schoolId) + 1);
    try {
      const students = await this.prisma.schoolStudent.findMany({
        where: {
          schoolId,
          archived: false,
          childId: { not: null },
          ...(scope.classIds && { classId: { in: scope.classIds } }),
          ...(scope.studentIds && { id: { in: scope.studentIds } }),
        },
        select: { child: { select: { childUserId: true } } },
      });
      for (let i = 0; i < students.length; i += PUSH_BATCH) {
        await Promise.all(students.slice(i, i + PUSH_BATCH).map((s) => this.fcm.pushChildResync(s.child?.childUserId)));
      }
    } catch (err) {
      this.logger.warn(`school mode resync: ${String(err)}`);
    }
  }

  private version(schoolId: string | null): number {
    return schoolId ? (this.versions.get(schoolId) ?? 0) : 0;
  }

  private async compute(childId: string, day: string, now: Date): Promise<{ schoolId: string | null; routines: VirtualRoutine[] }> {
    const student = await this.prisma.schoolStudent.findUnique({
      where: { childId },
      select: {
        id: true,
        schoolId: true,
        classId: true,
        archived: true,
        school: { select: { status: true } },
        class: { select: { shiftId: true } },
      },
    });
    if (!student || student.archived || !student.classId || !student.class || student.school.status !== 'ACTIVE') {
      return { schoolId: student?.schoolId ?? null, routines: [] };
    }
    const none = { schoolId: student.schoolId, routines: [] };
    const ctx = await this.store.context(student.schoolId, day);
    const shift = ctx.shifts.find((s) => s.id === student.class?.shiftId);
    if (
      !shift ||
      !isSchoolDay(day, shift, ctx.holidays) ||
      !policyCovers(ctx.policy, shift.id) ||
      emergencyCovers(ctx.emergency, student.classId)
    ) {
      return none;
    }
    const windows = await this.withoutExceptions(student.id, day, restrictedWindows(shift, ctx.policy));
    if (windows.length === 0) return none;
    const blockedApps = await this.blockedPackages(childId, ctx.policy);
    if (blockedApps.length === 0) return none;
    return {
      schoolId: student.schoolId,
      routines: windows.map((w, i) => ({
        id: `school-mode-${day}-${i + 1}`,
        childId,
        title: SCHOOL_ROUTINE_TITLE,
        type: 'SCHOOL',
        startHour: Math.floor(w.start / 60),
        startMinute: w.start % 60,
        endHour: Math.floor(w.end / 60),
        endMinute: w.end % 60,
        weekdays: [isoWeekday(day)],
        isActive: true,
        blockedApps,
        source: 'SCHOOL_MODE',
        createdAt: now,
        updatedAt: now,
      })),
    };
  }

  /** Istisno (bekor qilinmagan) oralig'i cheklov oynalaridan olib tashlanadi. */
  private async withoutExceptions(studentId: string, day: string, windows: Window[]): Promise<Window[]> {
    const exceptions = await this.prisma.schoolModeException.findMany({
      where: {
        studentId,
        revokedAt: null,
        from: { lt: tashkentDayStart(addDays(day, 1)) },
        until: { gt: tashkentDayStart(day) },
      },
      select: { from: true, until: true },
    });
    return exceptions.reduce((acc, e) => {
      const cut = dayWindowOf(day, e.from, e.until);
      return cut ? subtractWindow(acc, cut) : acc;
    }, windows);
  }

  /** Bloklanadigan toifadagi o'rnatilgan ilovalar (ruxsat etilganlardan tashqari). */
  private async blockedPackages(childId: string, policy: SchoolModePolicy): Promise<string[]> {
    const apps = await this.prisma.installedApp.findMany({
      where: { childId, isSystem: false },
      select: { packageName: true, appName: true, category: true },
    });
    const allowed = new Set(allowedAppsOf(policy).map((a) => normalizeName(a.name)));
    const blocked = new Set(policy.blockedCategories);
    return apps
      .filter((a) => {
        if (a.packageName === IOS_SELECTION_PACKAGE) return true;
        if (SELF_PACKAGE_PREFIXES.some((p) => a.packageName.startsWith(p))) return false;
        if (allowed.has(normalizeName(a.appName))) return false;
        return blocked.has(a.category ?? classifyPackage(a.packageName));
      })
      .map((a) => a.packageName)
      .sort();
  }
}
