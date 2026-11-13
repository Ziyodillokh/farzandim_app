// Maktab profili, logo, hudud va bayram kunlari (panel `schoolService`).
// Bola telefoniga ta'sir qiladigan o'zgarish (hudud, bugungi bayram) — School Mode qayta sync.

import { ConflictException, Injectable } from '@nestjs/common';
import { School, SchoolHoliday, SchoolShift } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import {
  holidayInputSchema,
  LOGO_PATTERN,
  MAX_LOGO_BYTES,
  schoolProfileSchema,
  schoolZoneSchema,
} from '../common/school-schemas';
import { parseOrThrow } from '../common/school-zod';
import { SchoolModeSyncService } from '../school-mode/school-mode-sync.service';

export type SchoolView = Omit<School, 'kioskSecret' | 'status' | 'createdAt' | 'updatedAt' | 'code'> & {
  code: string;
};

export function toSchoolView(s: School): SchoolView {
  const { kioskSecret: _secret, status: _status, createdAt: _c, updatedAt: _u, ...rest } = s;
  void _secret;
  void _status;
  void _c;
  void _u;
  return rest;
}

export function toShiftView(s: SchoolShift) {
  return {
    id: s.id,
    name: s.name,
    start: s.start,
    end: s.end,
    weekdays: s.weekdays,
    periods: s.periods,
  };
}

export const toHolidayView = (h: SchoolHoliday) => ({ id: h.id, date: h.date, name: h.name });

@Injectable()
export class SchoolInfoService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
    private readonly sync: SchoolModeSyncService,
  ) {}

  async get(actor: SchoolActor) {
    const school = await this.prisma.school.findUniqueOrThrow({
      where: { id: actor.schoolId },
      include: {
        shifts: { orderBy: [{ sortOrder: 'asc' }, { start: 'asc' }] },
        holidays: { orderBy: { date: 'asc' } },
      },
    });
    return {
      school: toSchoolView(school),
      shifts: school.shifts.map(toShiftView),
      holidays: school.holidays.map(toHolidayView),
    };
  }

  /** Kirish sahifasi uchun — sessiyasiz, faqat nom va logo. */
  async brand(code: string) {
    const school = await this.prisma.school.findUnique({
      where: { code: code.trim().toLowerCase() },
      select: { name: true, shortName: true, logo: true, city: true, academicYear: true, status: true },
    });
    if (!school || school.status !== 'ACTIVE') throw notFound('school');
    const { status: _status, ...brand } = school;
    return brand;
  }

  async updateProfile(actor: SchoolActor, input: unknown): Promise<SchoolView> {
    assertCan(actor, 'settings.manage');
    const data = parseOrThrow(schoolProfileSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.school.findUniqueOrThrow({ where: { id: actor.schoolId } });
      const after = await tx.school.update({ where: { id: actor.schoolId }, data });
      await this.audit.write(
        actor,
        {
          module: 'SETTINGS',
          action: 'school.update',
          summary: 'Maktab profili yangilandi',
          entityId: after.id,
          before: { ...toSchoolView(before), logo: undefined },
          after: { ...toSchoolView(after), logo: undefined },
          params: {},
        },
        tx,
      );
      return toSchoolView(after);
    });
  }

  /**
   * Maktab hududi (markaz + radius). School Mode «faqat hududda» shu bilan ishlaydi: telefon hudud ichida
   * ekanini qurilmaning o'zi aniqlaydi, joylashuv maktabga yuborilmaydi.
   */
  async setZone(actor: SchoolActor, input: unknown): Promise<SchoolView> {
    assertCan(actor, 'settings.manage');
    const { latitude, longitude, radiusM } = parseOrThrow(schoolZoneSchema, input);
    const { school, inUse } = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.school.update({ where: { id: actor.schoolId }, data: { latitude, longitude, zoneRadiusM: radiusM } });
      await this.audit.write(
        actor,
        {
          module: 'SETTINGS',
          action: 'school.zone',
          summary: `Maktab hududi belgilandi (radius ${radiusM} m)`,
          entityId: updated.id,
          params: { radius: radiusM },
        },
        tx,
      );
      const required = await tx.schoolModePolicy.count({ where: { schoolId: actor.schoolId, zoneRequired: true } });
      return { school: updated, inUse: required > 0 };
    });
    // Hudud faqat «faqat hududda» yoqilganda telefonga boradi — shunda yangi markaz/radius darhol yetsin.
    if (inUse) void this.sync.resync(actor.schoolId);
    return toSchoolView(school);
  }

  /** Hududni olib tashlash; School Mode «faqat hududda» yoqilgan bo'lsa — 409 (avval o'shani o'chirish kerak). */
  async clearZone(actor: SchoolActor): Promise<SchoolView> {
    assertCan(actor, 'settings.manage');
    return this.prisma.$transaction(async (tx) => {
      const inUse = await tx.schoolModePolicy.count({ where: { schoolId: actor.schoolId, zoneRequired: true } });
      if (inUse > 0) throw new ConflictException({ code: 'ZONE_IN_USE', message: 'School Mode requires the school zone' });
      const school = await tx.school.update({ where: { id: actor.schoolId }, data: { latitude: null, longitude: null, zoneRadiusM: null } });
      await this.audit.write(
        actor,
        { module: 'SETTINGS', action: 'school.zoneRemove', summary: 'Maktab hududi olib tashlandi', entityId: school.id, params: {} },
        tx,
      );
      return toSchoolView(school);
    });
  }

  async setLogo(actor: SchoolActor, logo: unknown): Promise<SchoolView> {
    assertCan(actor, 'settings.manage');
    if (logo !== null && (typeof logo !== 'string' || !LOGO_PATTERN.test(logo) || logo.length > MAX_LOGO_BYTES)) {
      throw invalid('logo');
    }
    return this.prisma.$transaction(async (tx) => {
      const school = await tx.school.update({ where: { id: actor.schoolId }, data: { logo } });
      await this.audit.write(
        actor,
        {
          module: 'SETTINGS',
          action: logo ? 'school.logo' : 'school.logoRemove',
          summary: logo ? 'Maktab logosi yangilandi' : 'Maktab logosi olib tashlandi',
          entityId: school.id,
          params: {},
        },
        tx,
      );
      return toSchoolView(school);
    });
  }

  async addHoliday(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'schoolMode.manage');
    const data = parseOrThrow(holidayInputSchema, input);
    const holiday = await this.prisma.$transaction(async (tx) => {
      const exists = await tx.schoolHoliday.findUnique({
        where: { schoolId_date: { schoolId: actor.schoolId, date: data.date } },
      });
      if (exists) throw conflict(data.date);
      const created = await tx.schoolHoliday.create({ data: { schoolId: actor.schoolId, ...data } });
      await this.audit.write(
        actor,
        {
          module: 'SCHOOL_MODE',
          action: 'holiday.create',
          summary: `Bayram kuni qo'shildi: ${data.date} — ${data.name}`,
          entityId: created.id,
          params: { date: data.date, name: data.name },
        },
        tx,
      );
      return created;
    });
    this.resyncIfToday(actor.schoolId, holiday.date);
    return toHolidayView(holiday);
  }

  async removeHoliday(actor: SchoolActor, id: string): Promise<void> {
    assertCan(actor, 'schoolMode.manage');
    const date = await this.prisma.$transaction(async (tx) => {
      const holiday = await tx.schoolHoliday.findFirst({ where: { id, schoolId: actor.schoolId } });
      if (!holiday) throw notFound(id);
      await tx.schoolHoliday.delete({ where: { id } });
      await this.audit.write(
        actor,
        {
          module: 'SCHOOL_MODE',
          action: 'holiday.delete',
          summary: `Bayram kuni olib tashlandi: ${holiday.date}`,
          entityId: id,
          params: { date: holiday.date },
        },
        tx,
      );
      return holiday.date;
    });
    this.resyncIfToday(actor.schoolId, date);
  }

  /** Bugungi bayram School Mode'ni shu zahoti yoqadi/o'chiradi; boshqa kunlar o'z kunida hisoblanadi. */
  private resyncIfToday(schoolId: string, date: string): void {
    if (date === tashkentDay()) void this.sync.resync(schoolId);
  }
}
