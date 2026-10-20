// Sinflar (panel `classesService`): ro'yxat (hajm, ota-ona bog'lanishi,
// telefon ulushi), sahifa tafsiloti, yaratish / tahrirlash / o'chirish.
// Davomat, School Mode va ommaviy taklif — tegishli modullarda.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import {
  allowedClassIds,
  assertCan,
  assertClassInScope,
  SchoolActor,
} from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import { classInputSchema } from '../common/school-schemas';
import { parseOrThrow } from '../common/school-zod';
import { matchesSearch } from '../common/list-query';
import { toShiftView } from '../structure/school-info.service';

const classInclude = {
  shift: true,
  homeroom: {
    select: { id: true, fullName: true, position: true, phone: true, email: true, active: true },
  },
  students: {
    where: { archived: false },
    select: {
      device: true,
      guardians: { select: { guardian: { select: { linkStatus: true } } } },
    },
  },
} satisfies Prisma.SchoolClassInclude;

type ClassWithStats = Prisma.SchoolClassGetPayload<{ include: typeof classInclude }>;

export function toClassView(c: {
  id: string;
  grade: number;
  letter: string;
  name: string;
  shiftId: string;
  homeroomStaffId: string | null;
  room: string;
}) {
  return {
    id: c.id,
    grade: c.grade,
    letter: c.letter,
    name: c.name,
    shiftId: c.shiftId,
    homeroomStaffId: c.homeroomStaffId,
    room: c.room,
  };
}

function toRow(c: ClassWithStats) {
  const students = c.students;
  const linked = students.filter((s) => s.guardians.some((g) => g.guardian.linkStatus === 'LINKED')).length;
  const withPhone = students.filter((s) => s.device !== 'NONE').length;
  const rate = (n: number) => (students.length ? Math.round((n / students.length) * 100) : 0);
  return {
    ...toClassView(c),
    size: students.length,
    shiftName: c.shift.name,
    homeroomName: c.homeroom?.fullName ?? null,
    linkedRate: rate(linked),
    phoneRate: rate(withPhone),
  };
}

@Injectable()
export class ClassesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async list(actor: SchoolActor, filter: { shiftId?: string; search?: string } = {}) {
    assertCan(actor, 'classes.view');
    const allowed = allowedClassIds(actor);
    const classes = await this.prisma.schoolClass.findMany({
      where: {
        schoolId: actor.schoolId,
        ...(allowed && { id: { in: allowed } }),
        ...(filter.shiftId && { shiftId: filter.shiftId }),
      },
      include: classInclude,
      orderBy: [{ grade: 'asc' }, { letter: 'asc' }],
    });
    return classes
      .filter((c) => !filter.search || matchesSearch(c.name, filter.search))
      .map(toRow);
  }

  async get(actor: SchoolActor, id: string) {
    const row = (await this.list(actor)).find((r) => r.id === id);
    if (!row) throw notFound(id);
    return row;
  }

  /** Sinf sahifasi: qator + smena + sinf rahbari kontakti. */
  async detail(actor: SchoolActor, id: string) {
    assertCan(actor, 'classes.view');
    const cls = await this.prisma.schoolClass.findFirst({
      where: { id, schoolId: actor.schoolId },
      include: classInclude,
    });
    if (!cls) throw notFound(id);
    assertClassInScope(actor, id);
    const notInvited = await this.prisma.schoolGuardian.count({
      where: {
        schoolId: actor.schoolId,
        linkStatus: 'NOT_INVITED',
        students: { some: { student: { classId: id, archived: false } } },
      },
    });
    return {
      ...toRow(cls),
      shift: toShiftView(cls.shift),
      homeroom: cls.homeroom,
      notInvitedGuardians: notInvited,
    };
  }

  async create(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'classes.manage');
    const data = parseOrThrow(classInputSchema, input);
    const name = `${data.grade}-${data.letter}`;
    return this.prisma.$transaction(async (tx) => {
      await this.assertRefs(tx, actor.schoolId, data.shiftId, data.homeroomStaffId);
      if (await tx.schoolClass.findUnique({ where: { schoolId_name: { schoolId: actor.schoolId, name } } })) {
        throw conflict(name);
      }
      const cls = await tx.schoolClass.create({
        data: { schoolId: actor.schoolId, name, ...data },
      });
      if (cls.homeroomStaffId) await assignHomeroom(tx, cls.id, cls.homeroomStaffId);
      await this.audit.write(
        actor,
        {
          module: 'CLASSES',
          action: 'class.create',
          summary: `${name} sinfi yaratildi`,
          entityId: cls.id,
          after: toClassView(cls),
          params: { name },
        },
        tx,
      );
      return toClassView(cls);
    });
  }

  async update(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'classes.manage');
    const data = parseOrThrow(classInputSchema, input);
    const name = `${data.grade}-${data.letter}`;
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.schoolClass.findFirst({ where: { id, schoolId: actor.schoolId } });
      if (!before) throw notFound(id);
      await this.assertRefs(
        tx,
        actor.schoolId,
        data.shiftId,
        data.homeroomStaffId === before.homeroomStaffId ? null : data.homeroomStaffId,
      );
      const clash = await tx.schoolClass.findUnique({
        where: { schoolId_name: { schoolId: actor.schoolId, name } },
      });
      if (clash && clash.id !== id) throw conflict(name);
      const next = await tx.schoolClass.update({ where: { id }, data: { ...data, name } });
      if (next.homeroomStaffId !== before.homeroomStaffId) {
        await assignHomeroom(tx, id, next.homeroomStaffId);
      }
      await this.audit.write(
        actor,
        {
          module: 'CLASSES',
          action: 'class.update',
          summary: `${name} sinfi yangilandi`,
          entityId: id,
          before: toClassView(before),
          after: toClassView(next),
          params: { name },
        },
        tx,
      );
      return toClassView(next);
    });
  }

  async remove(actor: SchoolActor, id: string): Promise<void> {
    assertCan(actor, 'classes.manage');
    await this.prisma.$transaction(async (tx) => {
      const cls = await tx.schoolClass.findFirst({ where: { id, schoolId: actor.schoolId } });
      if (!cls) throw notFound(id);
      if (await tx.schoolStudent.count({ where: { classId: id, archived: false } })) {
        throw conflict('class has students');
      }
      await tx.schoolClass.delete({ where: { id } });
      await this.audit.write(
        actor,
        {
          module: 'CLASSES',
          action: 'class.delete',
          summary: `${cls.name} sinfi o'chirildi`,
          entityId: id,
          before: toClassView(cls),
          params: { name: cls.name },
        },
        tx,
      );
    });
  }

  /** Smena va sinf rahbari shu maktabda mavjud (rahbar — faol HOMEROOM). */
  private async assertRefs(
    tx: Prisma.TransactionClient,
    schoolId: string,
    shiftId: string,
    homeroomStaffId: string | null,
  ): Promise<void> {
    if (!(await tx.schoolShift.findFirst({ where: { id: shiftId, schoolId } }))) {
      throw invalid('shiftId');
    }
    if (!homeroomStaffId) return;
    const staff = await tx.schoolStaff.findFirst({ where: { id: homeroomStaffId, schoolId } });
    if (!staff || staff.role !== 'HOMEROOM' || !staff.active) throw invalid('homeroomStaffId');
  }
}

/**
 * Sinf rahbari ↔ sinf: yangi rahbarga sinf doirasi qo'shiladi, boshqa
 * HOMEROOM xodimlardan (oldingi rahbardan) bu sinf olinadi.
 */
async function assignHomeroom(
  tx: Prisma.TransactionClient,
  classId: string,
  staffId: string | null,
): Promise<void> {
  await tx.schoolStaffClass.deleteMany({
    where: {
      classId,
      staff: { role: 'HOMEROOM' },
      ...(staffId && { staffId: { not: staffId } }),
    },
  });
  if (staffId) {
    await tx.schoolStaffClass.upsert({
      where: { staffId_classId: { staffId, classId } },
      create: { staffId, classId },
      update: {},
    });
  }
}
