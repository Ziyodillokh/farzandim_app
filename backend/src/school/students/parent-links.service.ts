// Parvoz Parents ilovasi ↔ maktab: taklif kodini kiritish (vasiy yozuvi shu
// foydalanuvchiga bog'lanadi), bog'lanishlar ro'yxati, o'quvchini o'z
// farzandi (`Child`) bilan moslash va aloqani uzish. Ota-ona faqat o'z
// vasiy yozuvlari va o'z farzandlari bilan ishlaydi.

import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { SchoolAuditService } from '../common/school-audit.service';
import { parseOrThrow } from '../common/school-zod';
import { studentFullName, studentName } from './student-view';
import { childLinkSchema, redeemSchema } from './students.schemas';

type Tx = Prisma.TransactionClient;

const inviteInvalid = () =>
  new NotFoundException({ code: 'INVITE_INVALID', message: 'Invite code is invalid or expired' });
const studentNotFound = () => new NotFoundException({ code: 'STUDENT_NOT_FOUND', message: 'Student not found' });
const childNotFound = () => new NotFoundException({ code: 'CHILD_NOT_FOUND', message: 'Child not found' });

/** Bog'langan o'quvchi qaysi oila farzandiga ulangan. */
const linkedBy = (childId: string | null, mine: ReadonlySet<string>) =>
  childId === null ? 'NONE' : mine.has(childId) ? 'ME' : 'OTHER';

@Injectable()
export class ParentLinksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  /** Taklif kodi: bir martalik, 7 kun; parallel kiritishda faqat bittasi yutadi. */
  async redeem(userId: string, input: unknown) {
    const { code } = parseOrThrow(redeemSchema, input);
    await this.prisma.$transaction(async (tx) => {
      const guardian = await tx.schoolGuardian.findUnique({
        where: { inviteCode: code },
        include: { school: { select: { status: true } } },
      });
      if (
        !guardian ||
        guardian.linkStatus !== 'INVITED' ||
        !guardian.inviteExpiresAt ||
        guardian.inviteExpiresAt < new Date() ||
        guardian.school.status !== 'ACTIVE'
      ) {
        throw inviteInvalid();
      }
      const res = await tx.schoolGuardian.updateMany({
        where: { id: guardian.id, inviteCode: code, linkStatus: 'INVITED' },
        data: { userId, linkStatus: 'LINKED', linkedAt: new Date(), inviteCode: null, inviteExpiresAt: null },
      });
      if (res.count === 0) throw inviteInvalid();
      await this.audit.writeExternal(
        guardian.schoolId,
        `Ota-ona: ${guardian.fullName}`,
        {
          module: 'GUARDIANS',
          action: 'guardian.linked',
          summary: `${guardian.fullName} Parvoz Parents'ga ulandi`,
          entityId: guardian.id,
          params: { name: guardian.fullName },
        },
        tx,
      );
    });
    return this.links(userId);
  }

  /** Maktab bog'lanishlari va moslash uchun ota-onaning farzandlari. */
  async links(userId: string) {
    const [guardians, children] = await Promise.all([
      this.prisma.schoolGuardian.findMany({
        where: { userId, linkStatus: 'LINKED', school: { status: 'ACTIVE' } },
        include: {
          school: { select: { id: true, name: true, shortName: true, logo: true, city: true } },
          students: {
            where: { student: { archived: false } },
            select: {
              student: {
                select: { id: true, lastName: true, firstName: true, middleName: true, childId: true, class: { select: { name: true } } },
              },
            },
          },
        },
        orderBy: { linkedAt: 'asc' },
      }),
      this.prisma.child.findMany({ where: { parentId: userId }, select: { id: true, name: true }, orderBy: { createdAt: 'asc' } }),
    ]);
    const mine = new Set(children.map((c) => c.id));
    return {
      links: guardians.map((g) => ({
        guardianId: g.id,
        fullName: g.fullName,
        relation: g.relation,
        linkedAt: g.linkedAt?.toISOString() ?? null,
        school: g.school,
        students: g.students.map(({ student: s }) => ({
          id: s.id,
          fullName: studentFullName(s),
          className: s.class?.name ?? '',
          childId: s.childId && mine.has(s.childId) ? s.childId : null,
          linkedBy: linkedBy(s.childId, mine),
        })),
      })),
      children,
    };
  }

  /** O'quvchini o'z farzandi bilan moslash (`null` — moslashni olib tashlash). */
  async setChild(userId: string, studentId: string, input: unknown) {
    const { childId } = parseOrThrow(childLinkSchema, input);
    await this.prisma.$transaction(async (tx) => {
      const student = await tx.schoolStudent.findFirst({
        where: { id: studentId, archived: false, guardians: { some: { guardian: { userId, linkStatus: 'LINKED' } } } },
      });
      if (!student) throw studentNotFound();
      if (student.childId && student.childId !== childId && !(await this.ownsChild(tx, userId, student.childId))) {
        throw new ConflictException({ code: 'STUDENT_LINKED_ELSEWHERE', message: 'Linked by another family member' });
      }
      if (childId) {
        if (!(await this.ownsChild(tx, userId, childId))) throw childNotFound();
        // Farzand boshqa (masalan, eski / arxivdagi) o'quvchiga bog'langan bo'lsa — ko'chiriladi.
        await tx.schoolStudent.updateMany({ where: { childId, id: { not: studentId } }, data: { childId: null } });
      }
      if (student.childId === childId) return;
      await tx.schoolStudent.update({ where: { id: studentId }, data: { childId } });
      const name = studentName(student);
      await this.audit.writeExternal(
        student.schoolId,
        'Ota-ona',
        {
          module: 'STUDENTS',
          action: childId ? 'student.childLinked' : 'student.childUnlinked',
          summary: childId ? `${name}: Parvoz bola ilovasi bog'landi` : `${name}: Parvoz bola ilovasi uzildi`,
          entityId: studentId,
          params: { name },
        },
        tx,
      );
    });
    return this.links(userId);
  }

  /** Aloqani uzish: vasiy yozuvi bo'shaydi, shu oila farzandlari o'quvchilardan uziladi. */
  async unlink(userId: string, guardianId: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const guardian = await tx.schoolGuardian.findFirst({
        where: { id: guardianId, userId },
        include: { students: { select: { studentId: true } } },
      });
      if (!guardian) throw new NotFoundException({ code: 'LINK_NOT_FOUND', message: 'Link not found' });
      await tx.schoolGuardian.update({
        where: { id: guardianId },
        data: { userId: null, linkStatus: 'NOT_INVITED', linkedAt: null },
      });
      const children = await tx.child.findMany({ where: { parentId: userId }, select: { id: true } });
      // Shu oila boshqa vasiy yozuvi orqali ham bog'langan o'quvchida moslash qoladi.
      await tx.schoolStudent.updateMany({
        where: {
          id: { in: guardian.students.map((s) => s.studentId) },
          childId: { in: children.map((c) => c.id) },
          guardians: { none: { guardian: { userId, linkStatus: 'LINKED' } } },
        },
        data: { childId: null },
      });
      await this.audit.writeExternal(
        guardian.schoolId,
        `Ota-ona: ${guardian.fullName}`,
        {
          module: 'GUARDIANS',
          action: 'guardian.unlinked',
          summary: `${guardian.fullName} Parvoz Parents bilan aloqani uzdi`,
          entityId: guardianId,
          params: { name: guardian.fullName },
        },
        tx,
      );
    });
  }

  private async ownsChild(tx: Tx, userId: string, childId: string): Promise<boolean> {
    return (await tx.child.count({ where: { id: childId, parentId: userId } })) > 0;
  }
}
