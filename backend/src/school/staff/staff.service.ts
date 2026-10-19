// Xodimlar (panel `staffService`) + panel hisobi (login / parol) boshqaruvi.

import { Injectable } from '@nestjs/common';
import { Prisma, SchoolStaff, SchoolStaffRole } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { CLASS_SCOPED_ROLES, SCHOOL_ROLES } from '../auth/permissions';
import { assertCan, assertCanAny, SchoolActor } from '../auth/school-actor';
import { hashStaffPassword } from '../auth/school-auth.service';
import { compareUz, runListQuery } from '../common/list-query';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import { staffAccountSchema, staffFormSchema } from '../common/school-schemas';
import { ListQuery, listQuerySchema, parseOrThrow } from '../common/school-zod';

type StaffWithClasses = SchoolStaff & { classes: { classId: string }[] };

export function toStaffView(s: StaffWithClasses) {
  return {
    id: s.id,
    fullName: s.fullName,
    position: s.position,
    role: s.role,
    phone: s.phone,
    email: s.email,
    classIds: s.classes.map((c) => c.classId),
    username: s.username,
    active: s.active,
    photo: s.photo,
    portrait: s.portrait ?? undefined,
  };
}

/** Audit uchun — rasm baytlarisiz. */
const auditView = (s: StaffWithClasses) => ({ ...toStaffView(s), photo: undefined });

@Injectable()
export class StaffService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async list(actor: SchoolActor, rawQuery: Record<string, unknown>) {
    assertCan(actor, 'staff.view');
    const query: ListQuery = parseOrThrow(listQuerySchema, rawQuery);
    const role = rawQuery.role as SchoolStaffRole | undefined;
    const active =
      rawQuery.active === undefined ? undefined : rawQuery.active === true || rawQuery.active === 'true';
    const [staff, classes] = await Promise.all([
      this.prisma.schoolStaff.findMany({
        where: { schoolId: actor.schoolId, ...(role && { role }), ...(active !== undefined && { active }) },
        include: { classes: { select: { classId: true } } },
      }),
      this.classNames(actor.schoolId),
    ]);
    const rows = staff.map((s) => {
      const view = toStaffView(s);
      return { ...view, classNames: view.classIds.map((c) => classes.get(c) ?? '').filter(Boolean) };
    });
    return runListQuery(rows, query, {
      searchText: (s) => `${s.fullName} ${s.position} ${s.phone} ${s.email} ${s.classNames.join(' ')}`,
      sorters: { name: (s) => s.fullName, role: (s) => s.role, position: (s) => s.position },
      defaultSort: 'name',
    });
  }

  /** Tanlovlar (sinf rahbari tanlash va h.k.). */
  async options(actor: SchoolActor, role?: SchoolStaffRole) {
    assertCanAny(actor, ['staff.view', 'classes.manage']);
    const staff = await this.prisma.schoolStaff.findMany({
      where: { schoolId: actor.schoolId, active: true, ...(role && { role }) },
      select: { id: true, fullName: true, role: true },
    });
    return staff.sort((a, b) => compareUz(a.fullName, b.fullName));
  }

  async summary(actor: SchoolActor) {
    assertCan(actor, 'staff.view');
    const staff = await this.prisma.schoolStaff.findMany({
      where: { schoolId: actor.schoolId },
      select: { role: true, active: true, username: true },
    });
    const byRole = Object.fromEntries(Object.keys(SCHOOL_ROLES).map((k) => [k, 0])) as Record<SchoolStaffRole, number>;
    for (const s of staff) if (s.active) byRole[s.role] += 1;
    const active = staff.filter((s) => s.active).length;
    return {
      total: staff.length,
      active,
      inactive: staff.length - active,
      demo: staff.filter((s) => s.username).length,
      byRole,
    };
  }

  roles(actor: SchoolActor) {
    assertCan(actor, 'staff.view');
    return Object.values(SCHOOL_ROLES);
  }

  async create(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'staff.manage');
    const data = parseOrThrow(staffFormSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const classIds = await normalizeClassIds(tx, actor.schoolId, data.role, data.classIds);
      const staff = await tx.schoolStaff.create({
        data: {
          schoolId: actor.schoolId,
          fullName: data.fullName,
          position: data.position,
          role: data.role,
          phone: data.phone,
          email: data.email,
          active: data.active,
          classes: { create: classIds.map((classId) => ({ classId })) },
        },
        include: { classes: { select: { classId: true } } },
      });
      await syncHomeroom(tx, staff.id, staff.role, classIds);
      await this.audit.write(
        actor,
        {
          module: 'STAFF',
          action: 'staff.create',
          summary: `Xodim qo'shildi: ${staff.fullName}`,
          entityId: staff.id,
          after: auditView(staff),
          params: { name: staff.fullName },
        },
        tx,
      );
      return toStaffView(staff);
    });
  }

  /** Tahrirlash. Faollik `setActive` orqali; o'z rolini o'zgartirib bo'lmaydi. */
  async update(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'staff.manage');
    const data = parseOrThrow(staffFormSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const before = await this.find(tx, actor.schoolId, id);
      if (id === actor.staffId && data.role !== before.role) throw conflict('self role');
      const classIds = await normalizeClassIds(tx, actor.schoolId, data.role, data.classIds);
      await tx.schoolStaffClass.deleteMany({ where: { staffId: id } });
      const next = await tx.schoolStaff.update({
        where: { id },
        data: {
          fullName: data.fullName,
          position: data.position,
          role: data.role,
          phone: data.phone,
          email: data.email,
          classes: { create: classIds.map((classId) => ({ classId })) },
          // Rol o'zgarsa — ruxsatlar o'zgaradi: eski tokenlar bekor.
          ...(data.role !== before.role && { tokenVersion: { increment: 1 } }),
        },
        include: { classes: { select: { classId: true } } },
      });
      await syncHomeroom(tx, id, next.role, classIds);
      await this.audit.write(
        actor,
        {
          module: 'STAFF',
          action: 'staff.update',
          summary: `Xodim yangilandi: ${next.fullName}`,
          entityId: id,
          before: auditView(before),
          after: auditView(next),
          params: { name: next.fullName },
        },
        tx,
      );
      return toStaffView(next);
    });
  }

  async setActive(actor: SchoolActor, id: string, active: unknown) {
    assertCan(actor, 'staff.manage');
    if (typeof active !== 'boolean') throw invalid('active');
    if (id === actor.staffId) throw conflict('self');
    return this.prisma.$transaction(async (tx) => {
      const before = await this.find(tx, actor.schoolId, id);
      const next = await tx.schoolStaff.update({
        where: { id },
        data: { active, ...(!active && { tokenVersion: { increment: 1 } }) },
        include: { classes: { select: { classId: true } } },
      });
      if (!active) {
        await tx.schoolStaffSession.updateMany({
          where: { staffId: id, revokedAt: null },
          data: { revokedAt: new Date() },
        });
      }
      await this.audit.write(
        actor,
        {
          module: 'STAFF',
          action: active ? 'staff.activate' : 'staff.deactivate',
          summary: `${next.fullName} ${active ? 'faollashtirildi' : 'faolsizlantirildi'}`,
          entityId: id,
          before: { active: before.active },
          after: { active },
          params: { name: next.fullName },
        },
        tx,
      );
      return toStaffView(next);
    });
  }

  /** Panel hisobi: login + vaqtinchalik parol (birinchi kirishda almashtiriladi). */
  async setAccount(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'staff.manage');
    const data = parseOrThrow(staffAccountSchema, input);
    const passwordHash = await hashStaffPassword(data.password);
    return this.prisma.$transaction(async (tx) => {
      const staff = await this.find(tx, actor.schoolId, id);
      const taken = await tx.schoolStaff.findUnique({
        where: { schoolId_username: { schoolId: actor.schoolId, username: data.username } },
      });
      if (taken && taken.id !== id) throw conflict('username');
      const next = await tx.schoolStaff.update({
        where: { id },
        data: {
          username: data.username,
          passwordHash,
          mustChangePassword: id !== actor.staffId,
          failedLogins: 0,
          lockedUntil: null,
          tokenVersion: { increment: 1 },
        },
        include: { classes: { select: { classId: true } } },
      });
      await tx.schoolStaffSession.updateMany({
        where: { staffId: id, revokedAt: null, ...(id === actor.staffId && { id: { not: actor.sessionId } }) },
        data: { revokedAt: new Date() },
      });
      await this.audit.write(
        actor,
        {
          module: 'STAFF',
          action: staff.username ? 'staff.accountReset' : 'staff.accountCreate',
          summary: `Panel hisobi: ${next.fullName} (${data.username})`,
          entityId: id,
          params: { name: next.fullName, username: data.username },
        },
        tx,
      );
      return toStaffView(next);
    });
  }

  async removeAccount(actor: SchoolActor, id: string) {
    assertCan(actor, 'staff.manage');
    if (id === actor.staffId) throw conflict('self');
    return this.prisma.$transaction(async (tx) => {
      const staff = await this.find(tx, actor.schoolId, id);
      const next = await tx.schoolStaff.update({
        where: { id },
        data: {
          username: null,
          passwordHash: null,
          totpEnabled: false,
          totpSecret: null,
          tokenVersion: { increment: 1 },
        },
        include: { classes: { select: { classId: true } } },
      });
      await tx.schoolStaffSession.updateMany({
        where: { staffId: id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      await this.audit.write(
        actor,
        {
          module: 'STAFF',
          action: 'staff.accountRemove',
          summary: `Panel hisobi o'chirildi: ${staff.fullName}`,
          entityId: id,
          params: { name: staff.fullName },
        },
        tx,
      );
      return toStaffView(next);
    });
  }

  private async find(tx: Prisma.TransactionClient, schoolId: string, id: string) {
    const staff = await tx.schoolStaff.findFirst({
      where: { id, schoolId },
      include: { classes: { select: { classId: true } } },
    });
    if (!staff) throw notFound(id);
    return staff;
  }

  private async classNames(schoolId: string): Promise<Map<string, string>> {
    const classes = await this.prisma.schoolClass.findMany({
      where: { schoolId },
      select: { id: true, name: true },
    });
    return new Map(classes.map((c) => [c.id, c.name]));
  }
}

/** Sinf doirasi faqat sinf rahbari / o'qituvchida; sinflar shu maktabniki. */
async function normalizeClassIds(
  tx: Prisma.TransactionClient,
  schoolId: string,
  role: SchoolStaffRole,
  classIds: readonly string[],
): Promise<string[]> {
  if (!CLASS_SCOPED_ROLES.includes(role)) return [];
  const unique = [...new Set(classIds)];
  const found = await tx.schoolClass.count({ where: { schoolId, id: { in: unique } } });
  if (found !== unique.length) throw invalid('classIds');
  return unique;
}

/**
 * Sinf rahbari ↔ sinf: xodim (HOMEROOM) sinflarining `homeroomStaffId`'si
 * shu xodimga o'tadi, oldingi rahbardan sinf olinadi; boshqa rolga o'tsa —
 * rahbarlikdan bo'shaydi.
 */
async function syncHomeroom(
  tx: Prisma.TransactionClient,
  staffId: string,
  role: SchoolStaffRole,
  classIds: string[],
): Promise<void> {
  const owns = role === 'HOMEROOM' ? classIds : [];
  await tx.schoolClass.updateMany({
    where: { homeroomStaffId: staffId, id: { notIn: owns } },
    data: { homeroomStaffId: null },
  });
  if (owns.length === 0) return;
  await tx.schoolClass.updateMany({ where: { id: { in: owns } }, data: { homeroomStaffId: staffId } });
  await tx.schoolStaffClass.deleteMany({
    where: { classId: { in: owns }, staffId: { not: staffId }, staff: { role: 'HOMEROOM' } },
  });
}
