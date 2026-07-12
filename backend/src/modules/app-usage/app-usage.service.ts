import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { GamificationService } from '../gamification/gamification.service';
import { BatchUpsertUsageDto } from './dto/batch-upsert-usage.dto';
import { GameOpenDto } from './dto/game-open.dto';
import { ListAppUsageDto } from './dto/list-app-usage.dto';

// O'zbekiston (Toshkent) UTC+5 — DST yo'q. Kun chegarasi shu vaqt bilan.
const TASHKENT_OFFSET_MS = 5 * 60 * 60 * 1000;

// Qadam → don konversiyasi: HAR 1000 QADAM = 5 DON.
const STEPS_PER_DON_UNIT = 1000;
const DON_PER_UNIT = 5;
// Bir kun maksimal foreground vaqti (xato data'dan himoya).
const MAX_DAY_MS = 24 * 60 * 60 * 1000;

// Launcher / systemUI / klaviatura / fon servislar — ekran vaqtiga kirmaydi.
// MUHIM: parent `AppUsageDay.filteredApps` bilan BIR XIL (tor) ro'yxat —
// aks holda haftalik grafik soni `_TimeCard` jamisidan farq qilardi
// (masalan soat/kamera grafikdan tushib qolardi). Soat/kamera/sozlamalar
// kabi foydalanuvchi ilovalari KO'RINADI.
const SYSTEM_PREFIXES = [
  // Launcher'lar (uy ekrani).
  'com.android.launcher',
  'com.sec.android.app.launcher',
  'com.miui.home',
  'com.google.android.apps.nexuslauncher',
  // System UI / fon servislar.
  'com.android.systemui',
  'com.google.android.gms',
  'com.google.android.packageinstaller',
  'com.google.android.permissioncontroller',
  // Klaviaturalar (IME).
  'com.google.android.inputmethod',
  'com.sec.android.inputmethod',
  'com.samsung.android.honeyboard',
  // ESLATMA: 'com.farzandim.' (Parvoz) endi FILTRLANMAYDI — bola Parvoz
  // ichida video/audiokitob ko'radi, bu ham haqiqiy ekran vaqti. Parent
  // filteredApps (app_usage.dart) bilan BIR XIL ro'yxat saqlanishi shart.
];

function isSystemPackage(pkg: string): boolean {
  return pkg === 'android' || SYSTEM_PREFIXES.some((p) => pkg.startsWith(p));
}

/** Toshkent (UTC+5) "hozir" — UTC komponentlari local sanani beradi. */
function tashkentDayKey(offsetDays = 0): string {
  const d = new Date(Date.now() + TASHKENT_OFFSET_MS);
  d.setUTCDate(d.getUTCDate() + offsetDays);
  return d.toISOString().slice(0, 10);
}

@Injectable()
export class AppUsageService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly fcm: FcmService,
    private readonly gamification: GamificationService,
  ) {}

  /**
   * Bola o'yin (CATEGORY_GAME) ochganini xabar qiladi — ota-onaga push.
   * Native (UsageStats) faqat o'yinlarni filtrlaydi; bu yerda push +
   * actionable data (Bloklash uchun packageName) yuboriladi.
   */
  async gameOpen(childId: string, userId: string, dto: GameOpenDto) {
    const child = await this.validateChildAccess(childId, userId);
    void this.notifyGamePlay(child, dto.packageName, dto.appName);
    return { ok: true };
  }

  private async notifyGamePlay(
    child: { id: string; name: string; parentId: string },
    packageName: string,
    appName: string,
  ): Promise<void> {
    try {
      await this.fcm.sendPushToUser(child.parentId, {
        title: `${child.name} — ${appName}`,
        body: "O'yin o'ynayapti",
        data: {
          type: 'game',
          childId: child.id,
          packageName,
          appName,
        },
      });
    } catch {
      // push xatosi muhim emas — xabar bermaslik o'yinni to'xtatmaydi
    }
  }

  private async validateChildAccess(childId: string, userId: string) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }
    return child;
  }

  async batchUpsert(
    childId: string,
    userId: string,
    dto: BatchUpsertUsageDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    await this.validateChildAccess(childId, userId);

    // Soatlik taqsimot: sync har ~60s keladi — oldingi jami bilan farq
    // (delta) JORIY Toshkent soati bucket'iga yoziladi. Shu bilan hech
    // qanday qurilma o'zgarishisiz real soatlik grafik hosil bo'ladi.
    const nowTk = new Date(Date.now() + 5 * 3600 * 1000);
    const todayTk = nowTk.toISOString().slice(0, 10);
    const hourTk = nowTk.getUTCHours();

    const existing = await this.prisma.appUsage.findMany({
      where: {
        childId,
        OR: dto.entries.map((e) => ({
          packageName: e.packageName,
          date: new Date(`${e.date}T00:00:00.000Z`),
        })),
      },
    });
    const prevMap = new Map(
      existing.map((r) => [
        `${r.packageName}|${r.date.toISOString().slice(0, 10)}`,
        r,
      ]),
    );

    const ops = dto.entries.map((entry) => {
      const dateObj = new Date(`${entry.date}T00:00:00.000Z`);

      // Faqat bugungi (Toshkent) yozuvlar uchun soatlik delta yoziladi.
      let hourly: number[] | undefined;
      if (entry.date === todayTk) {
        const prev = prevMap.get(`${entry.packageName}|${entry.date}`);
        const prevMs = prev ? Number(prev.foregroundMs) : 0;
        const raw = prev && Array.isArray(prev.hourlyMs)
          ? (prev.hourlyMs as unknown[]).map((v) => Number(v) || 0)
          : [];
        const base = new Array<number>(24).fill(0);
        for (let i = 0; i < Math.min(24, raw.length); i++) base[i] = raw[i];
        const delta = entry.foregroundMs - prevMs;
        if (delta > 0) base[hourTk] += delta;
        hourly = base;
      }

      return this.prisma.appUsage.upsert({
        where: {
          childId_packageName_date: {
            childId,
            packageName: entry.packageName,
            date: dateObj,
          },
        },
        update: {
          foregroundMs: BigInt(entry.foregroundMs),
          lastUsedAt: entry.lastUsedAt
            ? new Date(entry.lastUsedAt)
            : undefined,
          openCount: entry.openCount,
          ...(hourly ? { hourlyMs: hourly } : {}),
        },
        create: {
          childId,
          packageName: entry.packageName,
          date: dateObj,
          foregroundMs: BigInt(entry.foregroundMs),
          lastUsedAt: entry.lastUsedAt
            ? new Date(entry.lastUsedAt)
            : undefined,
          openCount: entry.openCount,
          hourlyMs: hourly ?? new Array<number>(24).fill(0),
        },
      });
    });

    await this.prisma.$transaction(ops);

    await this.audit.log(
      userId,
      'app_usage',
      'BATCH_UPSERT',
      childId,
      { count: dto.entries.length },
      request,
    );

    return { ok: true, upserted: dto.entries.length };
  }

  /**
   * Kunlik soatlik taqsimot — barcha ilovalar bo'yicha yig'ilgan [24] ms.
   * `date` YYYY-MM-DD (Toshkent kuni); berilmasa bugungi kun.
   */
  async hourly(childId: string, userId: string, date?: string) {
    await this.validateChildAccess(childId, userId);
    const day =
      date ??
      new Date(Date.now() + 5 * 3600 * 1000).toISOString().slice(0, 10);
    const rows = await this.prisma.appUsage.findMany({
      where: { childId, date: new Date(`${day}T00:00:00.000Z`) },
      select: { hourlyMs: true },
    });
    const hours = new Array<number>(24).fill(0);
    for (const r of rows) {
      if (!Array.isArray(r.hourlyMs)) continue;
      const arr = r.hourlyMs as unknown[];
      for (let i = 0; i < Math.min(24, arr.length); i++) {
        hours[i] += Number(arr[i]) || 0;
      }
    }
    return { date: day, hours };
  }

  async list(childId: string, userId: string, query: ListAppUsageDto) {
    await this.validateChildAccess(childId, userId);

    const { from, to, packageName, limit } = query;

    const usage = await this.prisma.appUsage.findMany({
      where: {
        childId,
        ...(packageName && { packageName }),
        ...(from || to
          ? {
              date: {
                ...(from && { gte: new Date(`${from}T00:00:00.000Z`) }),
                ...(to && { lte: new Date(`${to}T00:00:00.000Z`) }),
              },
            }
          : {}),
      },
      orderBy: [{ date: 'desc' }, { foregroundMs: 'desc' }],
      take: limit,
    });

    // Real ilova nomini (PackageManager label) InstalledApp jadvalidan olamiz —
    // usage'da faqat packageName bor, shuning uchun ota-onada "org.telegram..."
    // emas "Telegram" ko'rinishi uchun nomni shu yerda biriktiramiz.
    const pkgs = Array.from(new Set(usage.map((u) => u.packageName)));
    const installed =
      pkgs.length > 0
        ? await this.prisma.installedApp.findMany({
            where: { childId, packageName: { in: pkgs } },
            select: { packageName: true, appName: true },
          })
        : [];
    const nameByPkg = new Map(installed.map((a) => [a.packageName, a.appName]));

    // BigInt -> number for JSON serialization + real appName.
    const serialized = usage.map((u) => ({
      ...u,
      foregroundMs: Number(u.foregroundMs),
      appName: nameByPkg.get(u.packageName) ?? null,
    }));

    return { usage: serialized, count: serialized.length };
  }

  private last7DayKeys(): string[] {
    const keys: string[] = [];
    for (let i = 6; i >= 0; i -= 1) keys.push(tashkentDayKey(-i));
    return keys;
  }

  async weekly(childId: string, userId: string) {
    await this.validateChildAccess(childId, userId);
    return this.screenTimeWeekly(childId);
  }

  // Ekran vaqti — oxirgi 7 kun (Toshkent), system filtrlangan.
  private async screenTimeWeekly(childId: string) {
    const dayKeys = this.last7DayKeys();
    const fromDate = new Date(`${dayKeys[0]}T00:00:00.000Z`);

    const rows = await this.prisma.appUsage.findMany({
      where: { childId, date: { gte: fromDate } },
      select: { date: true, foregroundMs: true, packageName: true },
    });

    const totalsByDay = new Map<string, number>();
    for (const key of dayKeys) totalsByDay.set(key, 0);
    for (const row of rows) {
      if (isSystemPackage(row.packageName)) continue;
      const key = row.date.toISOString().slice(0, 10);
      if (totalsByDay.has(key)) {
        totalsByDay.set(
          key,
          (totalsByDay.get(key) ?? 0) + Number(row.foregroundMs),
        );
      }
    }

    const days = dayKeys.map((date) => {
      const totalMs = Math.min(totalsByDay.get(date) ?? 0, MAX_DAY_MS);
      return { date, totalMs, totalMinutes: Math.round(totalMs / 60000) };
    });
    const weekTotalMs = days.reduce((sum, d) => sum + d.totalMs, 0);

    return {
      days,
      weekTotalMs,
      weekTotalMinutes: Math.round(weekTotalMs / 60000),
    };
  }

  // Qadamlar — oxirgi 7 kun (Toshkent).
  private async stepsWeekly(childId: string) {
    const dayKeys = this.last7DayKeys();
    const fromDate = new Date(`${dayKeys[0]}T00:00:00.000Z`);

    const rows = await this.prisma.childStepDaily.findMany({
      where: { childId, date: { gte: fromDate } },
      select: { date: true, steps: true },
    });

    const byDay = new Map<string, number>();
    for (const key of dayKeys) byDay.set(key, 0);
    for (const row of rows) {
      const key = row.date.toISOString().slice(0, 10);
      if (byDay.has(key)) byDay.set(key, row.steps);
    }

    const days = dayKeys.map((date) => ({ date, steps: byDay.get(date) ?? 0 }));
    const weekTotal = days.reduce((s, d) => s + d.steps, 0);
    return { days, weekTotal, dailyAvg: Math.round(weekTotal / 7) };
  }

  // Hafta davomida eng ko'p ishlatilgan ilovalar (top 8, system'siz).
  private async topApps(childId: string) {
    const dayKeys = this.last7DayKeys();
    const fromDate = new Date(`${dayKeys[0]}T00:00:00.000Z`);

    const rows = await this.prisma.appUsage.findMany({
      where: { childId, date: { gte: fromDate } },
      select: { packageName: true, foregroundMs: true },
    });

    const byPkg = new Map<string, number>();
    for (const row of rows) {
      if (isSystemPackage(row.packageName)) continue;
      byPkg.set(
        row.packageName,
        (byPkg.get(row.packageName) ?? 0) + Number(row.foregroundMs),
      );
    }
    const sorted = [...byPkg.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8);
    const pkgs = sorted.map(([p]) => p);
    const installed =
      pkgs.length > 0
        ? await this.prisma.installedApp.findMany({
            where: { childId, packageName: { in: pkgs } },
            select: { packageName: true, appName: true },
          })
        : [];
    const nameByPkg = new Map(installed.map((a) => [a.packageName, a.appName]));

    return sorted.map(([packageName, totalMs]) => ({
      packageName,
      appName: nameByPkg.get(packageName) ?? packageName,
      totalMs,
      totalMinutes: Math.round(totalMs / 60000),
    }));
  }

  /** Haftalik hisobot — ekran vaqti + qadamlar + top ilovalar (1 endpoint). */
  async weeklyReport(childId: string, userId: string) {
    await this.validateChildAccess(childId, userId);
    const [screenTime, steps, topApps] = await Promise.all([
      this.screenTimeWeekly(childId),
      this.stepsWeekly(childId),
      this.topApps(childId),
    ]);
    return { screenTime, steps, topApps };
  }

  /**
   * Bola Parvoz pedometeridan kunlik qadamlarni yuboradi (batch upsert).
   *
   * Qadamlarni saqlash bilan birga QADAM MUKOFOTI beriladi: har 1000 qadam
   * = 5 don. `ChildStepDaily.donAwarded` orqali IDEMPOTENT — takroriy sync
   * (har 5 daqiqada) don ikki marta bermaydi, faqat YANGI delta beriladi.
   * Bugun 1000+ qadam bo'lsa streak ham yangilanadi (yurish = faollik).
   */
  async upsertSteps(
    childId: string,
    userId: string,
    entries: Array<{ date: string; steps: number }>,
  ) {
    await this.validateChildAccess(childId, userId);

    const todayKey = tashkentDayKey();
    let totalDonDelta = 0;
    let activeToday = false;

    for (const e of entries) {
      const dateObj = new Date(`${e.date}T00:00:00.000Z`);
      const steps = Math.max(0, Math.min(200000, Math.round(e.steps)));

      // Shu kun uchun allaqachon berilgan don (idempotentlik).
      const existing = await this.prisma.childStepDaily.findUnique({
        where: { childId_date: { childId, date: dateObj } },
        select: { donAwarded: true },
      });
      const prevAwarded = existing?.donAwarded ?? 0;
      const earnedDon =
        Math.floor(steps / STEPS_PER_DON_UNIT) * DON_PER_UNIT;
      // Faqat yangi qism (qadam kamaymaydi; reboot chekka holatda 0'ga clamp).
      const delta = Math.max(0, earnedDon - prevAwarded);
      const newAwarded = Math.max(prevAwarded, earnedDon);

      await this.prisma.childStepDaily.upsert({
        where: { childId_date: { childId, date: dateObj } },
        update: { steps, donAwarded: newAwarded },
        create: { childId, date: dateObj, steps, donAwarded: newAwarded },
      });

      totalDonDelta += delta;
      if (e.date === todayKey && steps >= STEPS_PER_DON_UNIT) {
        activeToday = true;
      }
    }

    // Profilga don qo'shish + streak yangilash (real, backend'da).
    if (totalDonDelta > 0 || activeToday) {
      await this.gamification.awardStepDon(childId, totalDonDelta, activeToday);
    }

    return { ok: true, upserted: entries.length, donAwarded: totalDonDelta };
  }
}
