// Parvoz Growth bola ilovasi: o'z sinfiga berilgan maktab topshiriqlari.
// Test topshirig'i shu fan bo'yicha topshiriq berilgandan keyin yakunlangan
// kunlik test bilan "bajarildi" hisoblanadi.

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, tashkentDay } from '../../common/time/tashkent';
import { loadCatalog, testSubjectOf } from './school-learning-catalog';

/** Muddati o'tganlar shuncha kun ko'rinib turadi. */
const OVERDUE_VISIBLE_DAYS = 7;

@Injectable()
export class SchoolLearningChildService {
  constructor(private readonly prisma: PrismaService) {}

  async assignments(childUserId: string) {
    const child = await this.prisma.child.findUnique({ where: { childUserId }, select: { id: true } });
    const student = child
      ? await this.prisma.schoolStudent.findUnique({
          where: { childId: child.id },
          select: { schoolId: true, classId: true, archived: true, school: { select: { status: true } } },
        })
      : null;
    if (!child || !student || student.archived || !student.classId || student.school.status !== 'ACTIVE') return [];
    const today = tashkentDay();
    const [rows, catalog] = await Promise.all([
      this.prisma.schoolLearningAssignment.findMany({
        where: { schoolId: student.schoolId, classIds: { has: student.classId }, dueDate: { gte: addDays(today, -OVERDUE_VISIBLE_DAYS) } },
        orderBy: { dueDate: 'asc' },
      }),
      loadCatalog(this.prisma),
    ]);
    const material = new Map(catalog.map((m) => [m.id, m]));
    return Promise.all(
      rows.map(async (a) => {
        const m = material.get(a.materialId);
        const subject = testSubjectOf(a.materialId);
        const done = subject
          ? (await this.prisma.learningAttempt.count({
              where: { childId: child.id, subject, status: 'COMPLETED', completedAt: { gte: a.createdAt } },
            })) > 0
          : null;
        return {
          id: a.id,
          kind: m?.kind ?? a.materialKind,
          materialId: a.materialId,
          title: m?.title ?? '—',
          subject: subject,
          dueDate: a.dueDate,
          note: a.note,
          overdue: a.dueDate < today,
          done,
        };
      }),
    );
  }
}
