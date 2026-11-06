// Maktab: o'quvchining bola ilovasi kirish maʼlumotlari. Faqat Parvoz bola profiliga bog'langan
// (`SchoolStudent.childId`) o'quvchi uchun — ota-ona roziligisiz hisob ochilmaydi. Ruxsat: `students.manage`
// + sinf doirasi. Parol va login auditga yozilmaydi.

import { ConflictException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import {
  ChildCredentialsService,
  CredentialView,
  IssuedCredential,
  toIssued,
} from '../../modules/child-auth/child-credentials.service';
import { ChildRecoveryService, RecoveryRequestView } from '../../modules/child-auth/child-recovery.service';
import type { IssueChildCredentialDto } from '../../modules/child-auth/dto/issue-child-credential.dto';
import { assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { notFound } from '../common/school-errors';
import { studentName } from '../students/student-view';

interface LinkedStudent {
  id: string;
  childId: string;
  firstName: string;
  lastName: string;
}

@Injectable()
export class StudentCredentialsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly credentials: ChildCredentialsService,
    private readonly recovery: ChildRecoveryService,
    private readonly audit: SchoolAuditService,
  ) {}

  async view(actor: SchoolActor, studentId: string): Promise<CredentialView | null> {
    const student = await this.linkedStudent(actor, studentId);
    return this.credentials.view(student.childId);
  }

  async issue(actor: SchoolActor, studentId: string, dto: IssueChildCredentialDto): Promise<IssuedCredential> {
    const student = await this.linkedStudent(actor, studentId, { forWrite: true });
    const outcome = await this.credentials.issueOrReset({
      childId: student.childId,
      actor: { kind: 'SCHOOL', staffId: actor.staffId },
      login: dto.login,
      signOutDevices: dto.signOutDevices ?? true,
      names: { firstName: student.firstName, lastName: student.lastName },
    });
    const name = studentName(student);
    await this.audit.write(actor, {
      module: 'STUDENTS',
      action: outcome.reset ? 'student.credential.reset' : 'student.credential.issue',
      summary: `${name}: kirish maʼlumotlari ${outcome.reset ? 'qayta tiklandi' : 'berildi'}`,
      entityId: studentId,
      params: { name },
    });
    // Shaffoflik: ota-onaga neytral push (login, parol, bola ismi yo'q) — fonda, javobni kechiktirmaydi.
    this.credentials.notifyParentOfSchoolAction(student.childId, outcome.reset);
    return toIssued(outcome);
  }

  async rejectRecovery(actor: SchoolActor, studentId: string, requestId: string): Promise<RecoveryRequestView> {
    const student = await this.linkedStudent(actor, studentId);
    const view = await this.recovery.reject(student.childId, requestId, 'SCHOOL');
    const name = studentName(student);
    await this.audit.write(actor, {
      module: 'STUDENTS',
      action: 'student.recovery.reject',
      summary: `${name}: kirish maʼlumotlarini tiklash so'rovi rad etildi`,
      entityId: studentId,
      params: { name },
    });
    return view;
  }

  /** Maktab va sinf doirasidagi, Parvoz bolasiga bog'langan o'quvchi (aks holda 404 / 403 / 409 NOT_LINKED). */
  private async linkedStudent(
    actor: SchoolActor,
    studentId: string,
    options: { forWrite?: boolean } = {},
  ): Promise<LinkedStudent> {
    assertCan(actor, 'students.manage');
    const student = await this.prisma.schoolStudent.findFirst({
      where: { id: studentId, schoolId: actor.schoolId },
      select: { id: true, childId: true, classId: true, archived: true, firstName: true, lastName: true },
    });
    if (!student) throw notFound(studentId);
    assertClassInScope(actor, student.classId);
    if (!student.childId) {
      throw new ConflictException({ code: 'NOT_LINKED', message: 'Student is not linked to a Parvoz child profile' });
    }
    if (options.forWrite && student.archived) {
      throw new ConflictException({ code: 'STUDENT_ARCHIVED', message: 'Student is archived' });
    }
    return { id: student.id, childId: student.childId, firstName: student.firstName, lastName: student.lastName };
  }
}
