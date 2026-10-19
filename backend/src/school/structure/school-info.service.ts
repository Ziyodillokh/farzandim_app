// Maktab profili, logo va bayram kunlari (panel `schoolService`).

import { Injectable } from '@nestjs/common';
import { School, SchoolHoliday, SchoolShift } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import {
  holidayInputSchema,
  LOGO_PATTERN,
  MAX_LOGO_BYTES,
  schoolProfileSchema,
} from '../common/school-schemas';
import { parseOrThrow } from '../common/school-zod';

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
      select: { name: true, shortName: true, logo: true, status: true },
    });
    if (!school || school.status !== 'ACTIVE') throw notFound('school');
    return { name: school.name, shortName: school.shortName, logo: school.logo };
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
    return this.prisma.$transaction(async (tx) => {
      const exists = await tx.schoolHoliday.findUnique({
        where: { schoolId_date: { schoolId: actor.schoolId, date: data.date } },
      });
      if (exists) throw conflict(data.date);
      const holiday = await tx.schoolHoliday.create({ data: { schoolId: actor.schoolId, ...data } });
      await this.audit.write(
        actor,
        {
          module: 'SCHOOL_MODE',
          action: 'holiday.create',
          summary: `Bayram kuni qo'shildi: ${data.date} — ${data.name}`,
          entityId: holiday.id,
          params: { date: data.date, name: data.name },
        },
        tx,
      );
      return toHolidayView(holiday);
    });
  }

  async removeHoliday(actor: SchoolActor, id: string): Promise<void> {
    assertCan(actor, 'schoolMode.manage');
    await this.prisma.$transaction(async (tx) => {
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
    });
  }
}
