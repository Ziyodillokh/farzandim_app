// Ota-onalar (panel `guardiansService`, `parentsService`, `classes.inviteGuardians`):
// doiradagi ro'yxat, statistika, taklif kodi (bitta / ommaviy), qo'shish va
// tahrirlash. Sinf rahbari faqat o'z sinfidagi farzandi bor ota-onani va
// faqat o'z sinfidagi farzandlarini ko'radi (boshqa sinfdagi aka-uka yashirin).

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import {
  actorCan,
  allowedClassIds,
  assertCan,
  assertClassInScope,
  SchoolActor,
} from '../auth/school-actor';
import { matchesSearch, runListQuery } from '../common/list-query';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, forbidden, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { INVITE_TTL_MS, uniqueInviteCode } from './invite-code';
import { bestLink, studentName, toGuardianView } from './student-view';
import { bulkInviteSchema, GuardianFilter, guardianFilterSchema, guardianInputSchema } from './students.schemas';

type Tx = Prisma.TransactionClient;
type GuardianRow = ReturnType<typeof toGuardianView> & {
  children: Array<{ id: string; name: string; className: string }>;
};

const percent = (part: number, total: number) => (total ? Math.round((part / total) * 100) : 0);
const searchText = (g: GuardianRow) =>
  `${g.fullName} ${g.phone} ${g.children.map((c) => `${c.name} ${c.className}`).join(' ')}`;

@Injectable()
export class GuardiansService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async list(actor: SchoolActor, query: unknown) {
    const filter = parseOrThrow(guardianFilterSchema, query);
    return runListQuery(await this.rows(actor, filter), filter, {
      searchText,
      sorters: { name: (g) => g.fullName, status: (g) => g.linkStatus },
      defaultSort: 'name',
    });
  }

  /** Ulanganlar ulushi — sahifalashsiz, to'g'ridan-to'g'ri hisob. */
  async stats(actor: SchoolActor) {
    const rows = await this.rows(actor, {});
    const counts = { LINKED: 0, INVITED: 0, NOT_INVITED: 0, total: rows.length };
    for (const g of rows) counts[g.linkStatus] += 1;
    return counts;
  }

  /**
   * Ota-onalar ulanishi — yagona hisob (bosh sahifa, /parents): kamida bitta
   * ota-onasi ulangan faol o'quvchilar ulushi va ota-onalar ichida ulanganlar.
   */
  async linkSummary(actor: SchoolActor) {
    if (!actorCan(actor, 'guardians.link') && !actorCan(actor, 'students.view')) throw forbidden('guardians.link');
    const allowed = allowedClassIds(actor);
    const students = await this.prisma.schoolStudent.findMany({
      where: { schoolId: actor.schoolId, archived: false, ...(allowed && { classId: { in: allowed } }) },
      select: { guardians: { select: { guardian: { select: { id: true, linkStatus: true } } } } },
    });
    const statusOf = new Map(students.flatMap((s) => s.guardians.map((g) => [g.guardian.id, g.guardian.linkStatus] as const)));
    const linkedStudents = students.filter((s) => bestLink(s.guardians.map((g) => g.guardian)) === 'LINKED').length;
    const statuses = [...statusOf.values()];
    const linked = statuses.filter((x) => x === 'LINKED').length;
    return {
      students: { linked: linkedStudents, total: students.length, rate: percent(linkedStudents, students.length) },
      guardians: {
        linked,
        invited: statuses.filter((x) => x === 'INVITED').length,
        total: statuses.length,
        rate: percent(linked, statuses.length),
      },
    };
  }

  /** Taklif kodi (7 kun) — ota-ona Parvoz Parents ilovasida kiritadi. */
  async invite(actor: SchoolActor, guardianId: string) {
    assertCan(actor, 'guardians.link');
    return this.prisma.$transaction(async (tx) => {
      const guardian = await this.scopedGuardian(tx, actor, guardianId);
      if (guardian.linkStatus === 'LINKED') throw conflict('linked');
      const updated = await tx.schoolGuardian.update({
        where: { id: guardianId },
        data: {
          linkStatus: 'INVITED',
          inviteCode: await uniqueInviteCode(tx),
          inviteExpiresAt: new Date(Date.now() + INVITE_TTL_MS),
        },
      });
      await this.audit.write(
        actor,
        {
          module: 'GUARDIANS',
          action: 'guardian.invite',
          summary: `${guardian.fullName} uchun Parvoz taklif kodi yaratildi`,
          entityId: guardianId,
          params: { name: guardian.fullName, variant: 'code' },
        },
        tx,
      );
      return toGuardianView(updated);
    });
  }

  /** Filtrga mos, hali taklif qilinmagan ota-onalarga kod (ro'yxat bilan aynan bir xil mantiq). */
  async inviteBulk(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'guardians.link');
    const filter = parseOrThrow(bulkInviteSchema, input ?? {});
    if (filter.classId) assertClassInScope(actor, filter.classId);
    const targets = (await this.rows(actor, { classId: filter.classId, linkStatus: 'NOT_INVITED' })).filter(
      (g) => !filter.search || matchesSearch(searchText(g), filter.search),
    );
    if (targets.length === 0) return { invited: 0 };
    return this.prisma.$transaction(
      async (tx) => {
        const reserved = new Set<string>();
        const expiresAt = new Date(Date.now() + INVITE_TTL_MS);
        let invited = 0;
        for (const g of targets) {
          const res = await tx.schoolGuardian.updateMany({
            where: { id: g.id, schoolId: actor.schoolId, linkStatus: 'NOT_INVITED' },
            data: { linkStatus: 'INVITED', inviteCode: await uniqueInviteCode(tx, reserved), inviteExpiresAt: expiresAt },
          });
          invited += res.count;
        }
        const cls = filter.classId
          ? await tx.schoolClass.findFirst({ where: { id: filter.classId, schoolId: actor.schoolId }, select: { name: true } })
          : null;
        await this.audit.write(
          actor,
          {
            module: 'GUARDIANS',
            action: 'guardian.inviteBulk',
            summary: `${cls ? `${cls.name} sinfi: ` : ''}${invited} ota-ona uchun Parvoz taklif kodi yaratildi`,
            entityId: filter.classId ?? null,
            after: { invited, guardianIds: targets.map((g) => g.id) },
            params: cls ? { variant: 'codeClass', className: cls.name, count: invited } : { variant: 'codeAll', count: invited },
          },
          tx,
        );
        return { invited };
      },
      { timeout: 60_000 },
    );
  }

  async addToStudent(actor: SchoolActor, studentId: string, input: unknown) {
    assertCan(actor, 'guardians.link');
    const data = parseOrThrow(guardianInputSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const student = await tx.schoolStudent.findFirst({ where: { id: studentId, schoolId: actor.schoolId } });
      if (!student) throw notFound(studentId);
      assertClassInScope(actor, student.classId);
      const guardian = await tx.schoolGuardian.create({
        data: { ...data, schoolId: actor.schoolId, students: { create: [{ studentId }] } },
      });
      await this.audit.write(
        actor,
        {
          module: 'GUARDIANS',
          action: 'guardian.create',
          summary: `${studentName(student)}ga ota-ona qo'shildi: ${guardian.fullName}`,
          entityId: guardian.id,
          params: { student: studentName(student), name: guardian.fullName },
        },
        tx,
      );
      return toGuardianView(guardian);
    });
  }

  async update(actor: SchoolActor, guardianId: string, input: unknown) {
    assertCan(actor, 'guardians.link');
    const data = parseOrThrow(guardianInputSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const before = await this.scopedGuardian(tx, actor, guardianId);
      const after = await tx.schoolGuardian.update({ where: { id: guardianId }, data });
      await this.audit.write(
        actor,
        {
          module: 'GUARDIANS',
          action: 'guardian.update',
          summary: `${after.fullName} ma'lumotlari yangilandi`,
          entityId: guardianId,
          before: toGuardianView(before),
          after: toGuardianView(after),
          params: { name: after.fullName },
        },
        tx,
      );
      return toGuardianView(after);
    });
  }

  /**
   * Maktab tomonidan aloqani uzish (masalan, kod begona qo'lga tushgan): vasiy
   * yozuvi bo'shaydi, shu foydalanuvchining farzandlari o'quvchilardan uziladi
   * (u boshqa vasiy yozuvi orqali ham bog'langan bo'lsa — qoladi). Yangi taklif
   * kodi alohida yaratiladi.
   */
  async unlink(actor: SchoolActor, guardianId: string) {
    assertCan(actor, 'guardians.link');
    return this.prisma.$transaction(async (tx) => {
      const guardian = await this.scopedGuardian(tx, actor, guardianId);
      // Uzish ota-onaning BARCHA farzandlariga ta'sir qiladi — sinf rahbari faqat
      // hamma faol farzandi o'z doirasida bo'lsa uza oladi (boshqa sinf buzilmasin).
      const allowed = allowedClassIds(actor);
      if (allowed) {
        const outside = await tx.schoolStudentGuardian.count({
          where: { guardianId, student: { archived: false, OR: [{ classId: null }, { classId: { notIn: allowed } }] } },
        });
        if (outside > 0) throw forbidden(guardianId);
      }
      if (guardian.linkStatus !== 'LINKED' || !guardian.userId) throw conflict('not linked');
      const userId = guardian.userId;
      const updated = await tx.schoolGuardian.update({
        where: { id: guardianId },
        data: { userId: null, linkStatus: 'NOT_INVITED', linkedAt: null, inviteCode: null, inviteExpiresAt: null },
      });
      const [links, children] = await Promise.all([
        tx.schoolStudentGuardian.findMany({ where: { guardianId }, select: { studentId: true } }),
        tx.child.findMany({ where: { parentId: userId }, select: { id: true } }),
      ]);
      await tx.schoolStudent.updateMany({
        where: {
          id: { in: links.map((l) => l.studentId) },
          childId: { in: children.map((c) => c.id) },
          guardians: { none: { guardian: { userId, linkStatus: 'LINKED' } } },
        },
        data: { childId: null },
      });
      await this.audit.write(
        actor,
        {
          module: 'GUARDIANS',
          action: 'guardian.unlinked',
          summary: `${guardian.fullName}: Parvoz Parents bilan aloqa maktab tomonidan uzildi`,
          entityId: guardianId,
          params: { name: guardian.fullName, variant: 'staff' },
        },
        tx,
      );
      return toGuardianView(updated);
    });
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  /** Ota-ona + maktab + sinf doirasi (kamida bitta farzandi doirada bo'lishi shart). */
  private async scopedGuardian(tx: Tx, actor: SchoolActor, guardianId: string) {
    const guardian = await tx.schoolGuardian.findFirst({
      where: { id: guardianId, schoolId: actor.schoolId },
      include: { students: { select: { student: { select: { classId: true } } } } },
    });
    if (!guardian) throw notFound(guardianId);
    const allowed = allowedClassIds(actor);
    if (allowed && !guardian.students.some((s) => s.student.classId && allowed.includes(s.student.classId))) {
      throw forbidden(guardianId);
    }
    const { students: _students, ...rest } = guardian;
    return rest;
  }

  private async rows(actor: SchoolActor, filter: Partial<GuardianFilter>): Promise<GuardianRow[]> {
    assertCan(actor, 'guardians.link');
    if (filter.classId) assertClassInScope(actor, filter.classId);
    const allowed = allowedClassIds(actor);
    const studentWhere: Prisma.SchoolStudentWhereInput = {
      archived: false,
      ...(allowed && { classId: { in: allowed } }),
    };
    const guardians = await this.prisma.schoolGuardian.findMany({
      where: {
        schoolId: actor.schoolId,
        students: { some: { student: { ...studentWhere, ...(filter.classId && { classId: filter.classId }) } } },
        ...(filter.linkStatus && { linkStatus: filter.linkStatus }),
      },
      include: {
        students: {
          where: { student: studentWhere },
          select: { student: { select: { id: true, lastName: true, firstName: true, class: { select: { name: true } } } } },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
    return guardians.map(({ students, ...g }) => ({
      ...toGuardianView(g),
      children: students.map(({ student }) => ({
        id: student.id,
        name: studentName(student),
        className: student.class?.name ?? '',
      })),
    }));
  }
}
