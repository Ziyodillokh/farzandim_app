// Parvoz IQ maktabda (docs/IQ-REJA.md §7): psixolog `parvoz-iq` ni sinflarga
// tayinlaydi, bola uni odatdagi /iq oqimida yechadi. Tarix umumiy — maktab
// tayinlovining natijasi bolaning oxirgi 180 kundagi (qayta topshirish oralig'i)
// eng so'nggi yakunlangan IQ sessiyasi. Ko'rinish:
//   psixolog (`assessments.manage`) — har qanday sinf, ism bilan;
//   sinf rahbari (`development.individual`) — faqat o'z sinfi, ism bilan;
//   direktor / admin (`development.view`) — faqat daraja taqsimoti, K=5.

import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, SchoolPsychAssignment } from '@prisma/client';
import { z } from 'zod';
import { PrismaService } from '../../common/database/prisma.service';
import { IqBand } from '../../modules/iq/domain/scoring';
import { RETAKE_DAYS } from '../../modules/iq/domain/levels';
import { IqResultView } from '../../modules/iq/iq.views';
import { IqService } from '../../modules/iq/iq.service';
import { actorCan, assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { CARE_MIN_GROUP } from '../care/care-suppression';
import { parseOrThrow } from '../common/school-zod';

export const PARVOZ_IQ_TEST_ID = 'parvoz-iq';
export const PARVOZ_IQ_TITLE = { uz: 'Parvoz IQ — mantiqiy fikrlash', ru: 'Parvoz IQ — логическое мышление' } as const;
export const PARVOZ_IQ_DESCRIPTION = {
  uz: 'Rasmli topshiriqlar: naqshni topib, yetishmayotgan qismni tanlang. 20 ta savol.',
  ru: 'Задания с картинками: найдите закономерность и выберите недостающую часть. 20 вопросов.',
} as const;
export const IQ_FORM_SIZE = 20;
const DAY_MS = 86_400_000;
const BANDS: readonly IqBand[] = ['VERY_HIGH', 'HIGH', 'ABOVE_AVERAGE', 'AVERAGE', 'BELOW_AVERAGE', 'LOW', 'VERY_LOW'];

const resultsQuerySchema = z.object({ classId: z.string().min(1) });

/** Tayinlash oynasi: ochilishdan 180 kun oldingi natija ham hisoblanadi (umumiy tarix). */
export const iqWindowStart = (opensAt: Date): Date => new Date(opensAt.getTime() - RETAKE_DAYS * DAY_MS);

export interface IqStudentRow {
  studentId: string;
  name: string;
  linked: boolean;
  result: IqResultView | null;
}

export interface IqClassResults {
  classId: string;
  className: string;
  mode: 'INDIVIDUAL' | 'AGGREGATE';
  students: number;
  linked: number;
  completed: number;
  /** Daraja taqsimoti; AGGREGATE rejimda K=5 dan kam bo'lsa null. */
  bands: Record<IqBand, number> | null;
  suppressed: boolean;
  rows: IqStudentRow[];
}

export function countBands(results: ReadonlyArray<Pick<IqResultView, 'band'>>): Record<IqBand, number> {
  const counts = Object.fromEntries(BANDS.map((b) => [b, 0])) as Record<IqBand, number>;
  for (const r of results) counts[r.band as IqBand] = (counts[r.band as IqBand] ?? 0) + 1;
  return counts;
}

type Db = Prisma.TransactionClient | PrismaService;

@Injectable()
export class AssessmentsIqService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly iq: IqService,
  ) {}

  /** Sinf bo'yicha joriy IQ natijalari (oxirgi 180 kun) — rolga qarab. */
  async results(actor: SchoolActor, query: unknown): Promise<IqClassResults> {
    const { classId } = parseOrThrow(resultsQuerySchema, query ?? {});
    let mode: IqClassResults['mode'];
    if (actorCan(actor, 'assessments.manage')) mode = 'INDIVIDUAL';
    else if (actorCan(actor, 'development.individual')) {
      assertClassInScope(actor, classId);
      mode = 'INDIVIDUAL';
    } else {
      assertCan(actor, 'development.view');
      mode = 'AGGREGATE';
    }
    const cls = await this.prisma.schoolClass.findFirst({
      where: { id: classId, schoolId: actor.schoolId },
      select: { id: true, grade: true, letter: true },
    });
    if (!cls) throw new NotFoundException({ code: 'NOT_FOUND', message: 'Class not found' });
    const students = await this.prisma.schoolStudent.findMany({
      where: { schoolId: actor.schoolId, classId, archived: false },
      orderBy: [{ lastName: 'asc' }, { firstName: 'asc' }],
      select: { id: true, lastName: true, firstName: true, childId: true },
    });
    const childIds = students.flatMap((s) => (s.childId ? [s.childId] : []));
    const scored = await this.iq.latestScored(childIds, iqWindowStart(new Date()));
    const rows: IqStudentRow[] = students.map((s) => ({
      studentId: s.id,
      name: `${s.lastName} ${s.firstName}`,
      linked: s.childId !== null,
      result: (s.childId && scored.get(s.childId)?.result) || null,
    }));
    const done = rows.flatMap((r) => (r.result ? [r.result] : []));
    const suppressed = mode === 'AGGREGATE' && done.length < CARE_MIN_GROUP;
    return {
      classId,
      className: `${cls.grade}-${cls.letter}`,
      mode,
      students: students.length,
      linked: childIds.length,
      completed: done.length,
      bands: suppressed ? null : countBands(done),
      suppressed,
      rows: mode === 'INDIVIDUAL' ? rows : [],
    };
  }

  /** IQ tayinlovlari bo'yicha yakunlaganlar soni (tayinlangan sinflarning ulangan o'quvchilari). */
  async completedCounts(db: Db, schoolId: string, rows: ReadonlyArray<Pick<SchoolPsychAssignment, 'id' | 'classIds' | 'opensAt' | 'closesAt'>>): Promise<Map<string, number>> {
    const counts = new Map<string, number>();
    for (const a of rows) {
      const students = await db.schoolStudent.findMany({
        where: { schoolId, archived: false, classId: { in: a.classIds }, childId: { not: null } },
        select: { childId: true },
      });
      const childIds = students.flatMap((s) => (s.childId ? [s.childId] : []));
      const done = childIds.length === 0 ? [] : await db.iqSession.findMany({
        where: { childId: { in: childIds }, status: 'COMPLETED', completedAt: { gte: iqWindowStart(a.opensAt), lte: a.closesAt } },
        select: { childId: true },
        distinct: ['childId'],
      });
      counts.set(a.id, done.length);
    }
    return counts;
  }

  /** Bola bu tayinlov oynasida IQ testni allaqachon yakunlaganmi (umumiy tarix). */
  async childDone(childId: string, opensAt: Date): Promise<boolean> {
    const count = await this.prisma.iqSession.count({
      where: { childId, status: 'COMPLETED', completedAt: { gte: iqWindowStart(opensAt) } },
    });
    return count > 0;
  }
}
