// Parvoz Growth bola ilovasi ↔ Bola ovozi so'rovnomasi: faol so'rovnoma (bolaning yosh
// guruhi bo'yicha) va HAQIQIY ANONIM javob. Javob yuborilganda:
//   - `SchoolCareParticipation` — faqat "bu bola shu so'rovnomaga javob berdi" (javobsiz);
//   - `SchoolCareAnonResponse` — shifrlangan javoblar, o'quvchi / bola id'si va vaqt belgisisiz;
// ikkalasi BITTA tranzaksiyada yoziladi, lekin ularni bog'laydigan ustun yo'q.
// Psixologga murojaat (yozishma) — `care-child-requests.service.ts`.

import { ConflictException, HttpException, HttpStatus, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { EnrolledStudent, findEnrolledStudent, requireEnrolledStudent } from '../common/child-student';
import { SchoolCryptoService } from '../common/school-crypto.service';
import { parseOrThrow } from '../common/school-zod';
import { estimatedMinutes } from '../common/estimated-minutes';
import { buildAnonRow } from './care-anon';
import { toQuestionView } from './care-store';
import { ageGroupOf, careAnswersSchema } from './care.schemas';

const alreadyAnswered = () => new ConflictException({ code: 'ALREADY_ANSWERED', message: 'Survey already answered' });
const invalidAnswers = (reason: string) => new HttpException({ code: 'VALIDATION', message: `answers: ${reason}` }, HttpStatus.BAD_REQUEST);

@Injectable()
export class CareChildService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: SchoolCryptoService,
  ) {}

  /** Faol so'rovnoma (yosh guruhiga mos savollar, bola tilida); javob bergan bo'lsa — `answered`. */
  async activeSurvey(childUserId: string) {
    const student = await findEnrolledStudent(this.prisma, childUserId);
    if (!student) return { enrolled: false, survey: null, answered: false };
    const group = ageGroupOf(student.grade);
    const survey = await this.prisma.schoolCareSurvey.findFirst({
      where: { schoolId: student.schoolId, status: 'ACTIVE', ageGroups: { has: group } },
      orderBy: { activatedAt: 'desc' },
    });
    if (!survey) return { enrolled: true, survey: null, answered: false };
    if (await this.hasAnswered(this.prisma, survey.id, student.studentId)) return { enrolled: true, survey: null, answered: true };
    const questions = await this.eligibleQuestions(this.prisma, student, survey.questionIds);
    const order = new Map(survey.questionIds.map((id, i) => [id, i]));
    const views = [...questions]
      .sort((a, b) => (order.get(a.id) ?? 0) - (order.get(b.id) ?? 0))
      .map((q) => {
        const view = toQuestionView(q);
        return { id: q.id, text: student.lang === 'ru' ? view.text.ru : view.text.uz };
      });
    return {
      enrolled: true,
      answered: false,
      survey: {
        id: survey.id,
        title: survey.title,
        activatedAt: survey.activatedAt?.toISOString() ?? null,
        questionCount: views.length,
        estimatedMinutes: estimatedMinutes(views.length),
        questions: views,
      },
    };
  }

  /**
   * Anonim javob. O'tkazib yuborilgan savol umuman yuborilmaydi (0 sifatida saqlanmaydi); noma'lum
   * savol id'si — 400; ikkinchi marta — 409. Ishtirok va anonim qator bitta tranzaksiyada.
   */
  async submitSurvey(childUserId: string, surveyId: string, input: unknown): Promise<{ ok: true }> {
    const student = await requireEnrolledStudent(this.prisma, childUserId);
    const { answers } = parseOrThrow(careAnswersSchema, input);
    const group = ageGroupOf(student.grade);
    const survey = await this.prisma.schoolCareSurvey.findFirst({
      where: { id: surveyId, schoolId: student.schoolId, status: 'ACTIVE', ageGroups: { has: group } },
    });
    if (!survey) throw new NotFoundException({ code: 'SURVEY_NOT_FOUND', message: 'Survey is not active' });
    const allowed = new Set((await this.eligibleQuestions(this.prisma, student, survey.questionIds)).map((q) => q.id));
    if (Object.keys(answers).some((id) => !allowed.has(id))) throw invalidAnswers('errors.form.invalid');
    const row = buildAnonRow({
      surveyId: survey.id,
      schoolId: student.schoolId,
      classId: student.classId,
      grade: student.grade,
      answers,
      encrypt: (value) => this.crypto.encryptJson(value),
    });
    await this.prisma.$transaction(async (tx) => {
      // So'rovnoma qatori ulashiladi: yopish (UPDATE) shu javob yozilguncha kutadi, yopilgan bo'lsa javob qabul qilinmaydi.
      const live = await tx.$queryRaw<{ status: string }[]>`SELECT status FROM school_care_surveys WHERE id = ${survey.id} FOR SHARE`;
      if (live[0]?.status !== 'ACTIVE') throw new NotFoundException({ code: 'SURVEY_NOT_FOUND', message: 'Survey is not active' });
      if (await tx.schoolCareResponse.count({ where: { surveyId: survey.id, studentId: student.studentId } })) throw alreadyAnswered();
      try {
        await tx.schoolCareParticipation.create({ data: { surveyId: survey.id, studentId: student.studentId } });
      } catch (err) {
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') throw alreadyAnswered();
        throw err;
      }
      await tx.schoolCareAnonResponse.create({ data: row });
    });
    return { ok: true };
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  /** Eski (o'quvchiga bog'langan) javob YOKI ishtirok belgisi. */
  private async hasAnswered(db: PrismaService, surveyId: string, studentId: string): Promise<boolean> {
    const [participation, legacy] = await Promise.all([
      db.schoolCareParticipation.count({ where: { surveyId, studentId } }),
      db.schoolCareResponse.count({ where: { surveyId, studentId } }),
    ]);
    return participation + legacy > 0;
  }

  private eligibleQuestions(db: PrismaService, student: EnrolledStudent, questionIds: string[]) {
    return db.schoolCareQuestion.findMany({
      where: { schoolId: student.schoolId, id: { in: questionIds }, active: true, ageGroups: { has: ageGroupOf(student.grade) } },
    });
  }
}
