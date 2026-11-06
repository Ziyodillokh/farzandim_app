// Xodim tomoni: o'quvchi kodi (6 raqam, 24 soat). Yangi kod oldingisini yopadi (bitta o'quvchida bitta faol kod);
// `GET` faol kodni va ikki o'rin holatini beradi. Ruxsat — `guardians.link`, sinf rahbari faqat o'z sinfi.
// Kod auditga yozilmaydi (u kirish ma'lumoti).

import { Injectable } from '@nestjs/common';
import { Prisma, SchoolStudentInvite } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, notFound } from '../common/school-errors';
import { studentArchived } from './link-errors';
import { acquireLinkLocks, CODE_SPACE_LOCK, studentLock } from './link-locks';
import { randomStudentCode, STUDENT_CODE_TTL_MS } from './student-code';
import { studentName } from './student-view';

type Tx = Prisma.TransactionClient;

/** Bo'sh kod topish uchun urinishlar (faol kodlar 10^6 dan ancha kam — odatda bitta urinish yetadi). */
const MAX_CODE_ATTEMPTS = 50;

export interface StudentInviteView {
  id: string;
  code: string;
  expiresAt: string;
  createdAt: string;
  student: { status: 'FREE' | 'UNDER_REVIEW' | 'CONFIRMED'; usedAt: string | null };
  parent: { status: 'FREE' | 'USED'; usedAt: string | null };
}

const iso = (d: Date | null) => d?.toISOString() ?? null;

export function toInviteView(i: SchoolStudentInvite): StudentInviteView {
  const studentStatus = !i.studentChildId ? 'FREE' : i.studentConfirmedAt ? 'CONFIRMED' : 'UNDER_REVIEW';
  return {
    id: i.id,
    code: i.code,
    expiresAt: i.expiresAt.toISOString(),
    createdAt: i.createdAt.toISOString(),
    student: { status: studentStatus, usedAt: iso(i.studentUsedAt) },
    parent: { status: i.parentUserId ? 'USED' : 'FREE', usedAt: iso(i.parentUsedAt) },
  };
}

@Injectable()
export class StudentInvitesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  /** Yangi kod: o'quvchining oldingi (yopilmagan) kodlari yopiladi. */
  async generate(actor: SchoolActor, studentId: string): Promise<{ code: string; expiresAt: string }> {
    assertCan(actor, 'guardians.link');
    return this.prisma.$transaction(async (tx) => {
      const student = await tx.schoolStudent.findFirst({ where: { id: studentId, schoolId: actor.schoolId } });
      if (!student) throw notFound(studentId);
      assertClassInScope(actor, student.classId);
      if (student.archived) throw studentArchived();
      await acquireLinkLocks(tx, [CODE_SPACE_LOCK, studentLock(studentId)]);
      const now = new Date();
      await tx.schoolStudentInvite.updateMany({ where: { studentId, closedAt: null }, data: { closedAt: now } });
      const code = await this.freeCode(tx, now);
      const invite = await tx.schoolStudentInvite.create({
        data: {
          schoolId: actor.schoolId,
          studentId,
          code,
          expiresAt: new Date(now.getTime() + STUDENT_CODE_TTL_MS),
          createdByStaffId: actor.staffId,
        },
      });
      await this.audit.write(
        actor,
        {
          module: 'GUARDIANS',
          action: 'student.inviteCode',
          summary: `${studentName(student)} uchun o'quvchi kodi yaratildi`,
          entityId: studentId,
          params: { name: studentName(student) },
        },
        tx,
      );
      return { code: invite.code, expiresAt: invite.expiresAt.toISOString() };
    });
  }

  /** Faol kod va o'rinlar holati; faol kod yo'q (yoki muddati o'tgan) bo'lsa `null`. */
  async current(actor: SchoolActor, studentId: string): Promise<StudentInviteView | null> {
    assertCan(actor, 'guardians.link');
    const student = await this.prisma.schoolStudent.findFirst({
      where: { id: studentId, schoolId: actor.schoolId },
      select: { classId: true },
    });
    if (!student) throw notFound(studentId);
    assertClassInScope(actor, student.classId);
    const invite = await this.prisma.schoolStudentInvite.findFirst({
      where: { studentId, closedAt: null, expiresAt: { gt: new Date() } },
    });
    return invite ? toInviteView(invite) : null;
  }

  /**
   * Faol kodlar orasida band bo'lmagan tasodifiy kod. Muddati o'tgan, lekin yopilmagan qator ham kodni band qiladi
   * (qisman unique indeks `closed_at IS NULL`) — bunday qatorni yopamiz. `CODE_SPACE_LOCK` ostida poyga yo'q.
   */
  private async freeCode(tx: Tx, now: Date): Promise<string> {
    for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
      const code = randomStudentCode();
      await tx.schoolStudentInvite.updateMany({ where: { code, closedAt: null, expiresAt: { lte: now } }, data: { closedAt: now } });
      const taken = await tx.schoolStudentInvite.findFirst({ where: { code, closedAt: null }, select: { id: true } });
      if (!taken) return code;
    }
    throw conflict('student codes exhausted');
  }
}
