// Bola ovozi sozlamalari: mas'ul psixolog, o'rinbosar, ish vaqti va javob muddatlari.
// O'qish — `care.aggregate`, `care.individual` yoki `care.settings`; yozish — FAQAT `care.settings`
// (direktor, administrator, psixolog). Ichki xizmatlar (bola ilovasi, cron) `load` / `people` /
// `holidays` dan foydalanadi. Audit yozuvida shaxsiy ma'lumot yo'q.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, assertCanAny, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { invalid } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { CarePerson, CareSettingsData, toSettingsData } from './care-settings';
import { CareSettingsInput, careSettingsInputSchema, SETTINGS_MSG } from './care-settings.schemas';

type Db = Prisma.TransactionClient | PrismaService;

export interface SettingsState {
  /** Maktabda sozlama qatori bormi (yo'q bo'lsa standart qiymatlar). */
  configured: boolean;
  settings: CareSettingsData;
  updatedAt: Date | null;
  updatedByStaffId: string | null;
}

export interface CarePeople {
  psychologist: CarePerson | null;
  deputy: CarePerson | null;
  /** Xodim → bolaga ko'rinadigan ism (ko'rsatiladigan ism, bo'lmasa F.I.Sh.); noma'lum — `null`. */
  nameOf(staffId: string | null): string | null;
}

@Injectable()
export class CareSettingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async get(actor: SchoolActor) {
    assertCanAny(actor, ['care.aggregate', 'care.individual', 'care.settings']);
    return this.view(actor.schoolId);
  }

  async update(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'care.settings');
    const data = parseOrThrow(careSettingsInputSchema, input);
    await this.assertPsychologists(actor.schoolId, data);
    await this.prisma.$transaction(async (tx) => {
      const values = { ...data, updatedByStaffId: actor.staffId };
      await tx.schoolCareSettings.upsert({
        where: { schoolId: actor.schoolId },
        create: { schoolId: actor.schoolId, ...values },
        update: values,
      });
      await this.audit.write(actor, { module: 'CARE', action: 'care.settings.update', summary: 'Bola ovozi: sozlamalar yangilandi' }, tx);
    });
    return this.view(actor.schoolId);
  }

  // ── Ichki xizmatlar ────────────────────────────────────────────────

  async load(schoolId: string, db: Db = this.prisma): Promise<SettingsState> {
    const row = await db.schoolCareSettings.findUnique({ where: { schoolId } });
    return { configured: row !== null, settings: toSettingsData(row), updatedAt: row?.updatedAt ?? null, updatedByStaffId: row?.updatedByStaffId ?? null };
  }

  /**
   * Bolaga ko'rinadigan mas'ul shaxslar. Psixolog xodimi o'rnatilmagan va ko'rsatiladigan ism ham
   * yo'q bo'lsa — maktabdagi YAGONA faol psixolog (bir nechta bo'lsa — `null`). Faol bo'lmagan
   * (ishdan ketgan) xodim mas'ul sifatida ko'rsatilmaydi.
   */
  async people(schoolId: string, state: SettingsState, extraStaffIds: readonly string[] = [], db: Db = this.prisma): Promise<CarePeople> {
    const s = state.settings;
    const wanted = [...new Set([s.psychologistStaffId, s.deputyStaffId, ...extraStaffIds].filter((id): id is string => id !== null))];
    const staff = wanted.length ? await db.schoolStaff.findMany({ where: { schoolId, id: { in: wanted } }, select: { id: true, fullName: true, active: true } }) : [];
    const byId = new Map(staff.map((x) => [x.id, x]));
    const activeName = (id: string | null, display: string | null): string | null => {
      const found = id ? byId.get(id) : undefined;
      return found?.active ? (display ?? found.fullName) : null;
    };
    let psychologist: string | null;
    if (s.psychologistStaffId) psychologist = activeName(s.psychologistStaffId, s.psychologistDisplayName);
    else psychologist = s.psychologistDisplayName ?? (await this.onlyPsychologist(schoolId, db));
    const deputy = activeName(s.deputyStaffId, s.deputyDisplayName);
    return {
      psychologist: psychologist ? { name: psychologist } : null,
      deputy: deputy ? { name: deputy } : null,
      nameOf: (id) => {
        if (!id) return null;
        if (id === s.psychologistStaffId && s.psychologistDisplayName) return s.psychologistDisplayName;
        if (id === s.deputyStaffId && s.deputyDisplayName) return s.deputyDisplayName;
        return byId.get(id)?.fullName ?? null;
      },
    };
  }

  /** Bayram kunlari (`from` kundan boshlab, `YYYY-MM-DD`) — ish vaqti hisobi uchun. */
  async holidays(schoolId: string, from: string, db: Db = this.prisma): Promise<Set<string>> {
    const rows = await db.schoolHoliday.findMany({ where: { schoolId, date: { gte: from } }, select: { date: true } });
    return new Set(rows.map((h) => h.date));
  }

  /** Muddatida ochilmagan murojaat o'tkaziladigan o'rinbosar: faol psixolog bo'lsa `staffId`, aks holda `null`. */
  async activeDeputyId(schoolId: string, state: SettingsState, db: Db = this.prisma): Promise<string | null> {
    const id = state.settings.deputyStaffId;
    if (!id) return null;
    const found = await db.schoolStaff.findFirst({ where: { id, schoolId, active: true, role: 'PSYCHOLOGIST' }, select: { id: true } });
    return found?.id ?? null;
  }

  // ── Yordamchi ──────────────────────────────────────────────────────

  private async view(schoolId: string) {
    const [state, options] = await Promise.all([
      this.load(schoolId),
      this.prisma.schoolStaff.findMany({
        where: { schoolId, active: true, role: 'PSYCHOLOGIST' },
        orderBy: [{ fullName: 'asc' }, { id: 'asc' }],
        select: { id: true, fullName: true },
      }),
    ]);
    return {
      ...state.settings,
      updatedAt: state.updatedAt?.toISOString() ?? null,
      updatedByStaffId: state.updatedByStaffId,
      staffOptions: options,
    };
  }

  private async onlyPsychologist(schoolId: string, db: Db): Promise<string | null> {
    const found = await db.schoolStaff.findMany({ where: { schoolId, active: true, role: 'PSYCHOLOGIST' }, select: { fullName: true }, take: 2 });
    return found.length === 1 ? (found[0]?.fullName ?? null) : null;
  }

  /** Tanlangan xodimlar shu maktabda, faol va PSYCHOLOGIST roli bilan bo'lishi shart. */
  private async assertPsychologists(schoolId: string, data: CareSettingsInput): Promise<void> {
    const checks = [
      ['psychologistStaffId', data.psychologistStaffId],
      ['deputyStaffId', data.deputyStaffId],
    ] as const;
    for (const [field, id] of checks) {
      if (!id) continue;
      const found = await this.prisma.schoolStaff.findFirst({ where: { id, schoolId, active: true, role: 'PSYCHOLOGIST' }, select: { id: true } });
      if (!found) throw invalid(`${field}: ${SETTINGS_MSG.invalidStaff}`);
    }
  }
}
