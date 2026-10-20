// Rivojlanish ma'lumotlari: jonli ro'yxat (ko'rsatish, qamrov, kirish huquqi) va
// natijalar indeksi — `live` (psixolog, sinf rahbarining o'z sinfi) yoki
// `released` (direktor / admin va psixolog bo'lmagan maktab kesimlari: faqat
// yakuniy partiyalar, har (partiya, chorak, sinf) bo'lagi ≥ K — `development-release.ts`).

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AssessmentsStore } from '../assessments/assessments-store';
import { isAssignmentFinal } from '../assessments/assessments-view';
import { termOf } from '../assessments/psych/terms';
import { buildIndex, DevIndex, localDay } from './development-index';
import { releasedResults } from './development-release';
import type { Roster } from './development.types';

export type IndexMode = 'live' | 'released';

@Injectable()
export class DevelopmentDataService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: AssessmentsStore,
  ) {}

  async roster(schoolId: string): Promise<Roster> {
    const [classes, students] = await Promise.all([
      this.prisma.schoolClass.findMany({ where: { schoolId }, select: { id: true, name: true, grade: true, letter: true } }),
      this.prisma.schoolStudent.findMany({
        where: { schoolId },
        select: { id: true, classId: true, lastName: true, firstName: true, archived: true, enrolledAt: true, birthDate: true },
      }),
    ]);
    return { classes, students };
  }

  async index(schoolId: string, mode: IndexMode, now: Date = new Date()): Promise<DevIndex> {
    const [tests, results] = await Promise.all([this.store.allTests(schoolId), this.store.scoredResults(schoolId)]);
    const byId = new Map(tests.map((t) => [t.id, t]));
    if (mode === 'live') return buildIndex(results, byId);
    const assignments = await this.prisma.schoolPsychAssignment.findMany({
      where: { schoolId },
      select: { id: true, status: true, closesAt: true, testId: true },
    });
    const final = new Set(assignments.filter((a) => isAssignmentFinal(a, byId.get(a.testId), now.getTime())).map((a) => a.id));
    return buildIndex(releasedResults(results, final, (r) => termOf(localDay(r.takenAt)).key), byId);
  }

  /** Natija bor sinflar (natijadagi nusxa) — psixolog sinf tanlovi uchun. */
  async classesWithResults(schoolId: string): Promise<Set<string>> {
    const rows = await this.prisma.schoolPsychResult.groupBy({ by: ['classId'], where: { schoolId, classId: { not: null } } });
    return new Set(rows.flatMap((r) => (r.classId ? [r.classId] : [])));
  }
}
