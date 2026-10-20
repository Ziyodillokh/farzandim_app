// Parvoz Growth bola ilovasi ↔ Bola ovozi: faol so'rovnoma (bolaning yosh
// guruhi bo'yicha), javob yuborish (shifrlanadi, bir marta) va psixologga
// murojaat (kuniga cheklangan). Bola faqat o'zi haqida yozadi.

import { ConflictException, HttpException, HttpStatus, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay, tashkentDayStart } from '../../common/time/tashkent';
import { SchoolCryptoService } from '../common/school-crypto.service';
import { parseOrThrow } from '../common/school-zod';
import { toQuestionView } from './care-store';
import { ageGroupOf, careAnswersSchema, careRequestInputSchema } from './care.schemas';

/** Bitta bola kuniga ko'pi bilan shuncha murojaat yubora oladi. */
export const MAX_REQUESTS_PER_DAY = 5;

const notEnrolled = () => new NotFoundException({ code: 'NOT_ENROLLED', message: 'Child is not linked to a school' });

@Injectable()
export class CareChildService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: SchoolCryptoService,
  ) {}

  /** Faol so'rovnoma (yosh guruhiga mos savollar, bola tilida); javob bergan bo'lsa — `answered`. */
  async activeSurvey(childUserId: string) {
    const student = await this.student(childUserId);
    if (!student) return { enrolled: false, survey: null, answered: false };
    const group = ageGroupOf(student.grade);
    const survey = await this.prisma.schoolCareSurvey.findFirst({
      where: { schoolId: student.schoolId, status: 'ACTIVE', ageGroups: { has: group } },
      orderBy: { activatedAt: 'desc' },
    });
    if (!survey) return { enrolled: true, survey: null, answered: false };
    const answered = (await this.prisma.schoolCareResponse.count({ where: { surveyId: survey.id, studentId: student.id } })) > 0;
    if (answered) return { enrolled: true, survey: null, answered: true };
    const questions = await this.prisma.schoolCareQuestion.findMany({
      where: { schoolId: student.schoolId, id: { in: survey.questionIds }, active: true, ageGroups: { has: group } },
    });
    const order = new Map(survey.questionIds.map((id, i) => [id, i]));
    return {
      enrolled: true,
      answered: false,
      survey: {
        id: survey.id,
        title: survey.title,
        questions: questions
          .sort((a, b) => (order.get(a.id) ?? 0) - (order.get(b.id) ?? 0))
          .map((q) => {
            const view = toQuestionView(q);
            return { id: q.id, text: student.lang === 'ru' ? view.text.ru : view.text.uz };
          }),
      },
    };
  }

  async submitSurvey(childUserId: string, surveyId: string, input: unknown): Promise<{ ok: true }> {
    const student = await this.student(childUserId);
    if (!student) throw notEnrolled();
    const { answers } = parseOrThrow(careAnswersSchema, input);
    const group = ageGroupOf(student.grade);
    const survey = await this.prisma.schoolCareSurvey.findFirst({
      where: { id: surveyId, schoolId: student.schoolId, status: 'ACTIVE', ageGroups: { has: group } },
    });
    if (!survey) throw new NotFoundException({ code: 'SURVEY_NOT_FOUND', message: 'Survey is not active' });
    const allowed = await this.prisma.schoolCareQuestion.findMany({
      where: { schoolId: student.schoolId, id: { in: survey.questionIds }, active: true, ageGroups: { has: group } },
      select: { id: true },
    });
    const allowedIds = new Set(allowed.map((q) => q.id));
    const clean = Object.fromEntries(Object.entries(answers).filter(([id]) => allowedIds.has(id)));
    if (Object.keys(clean).length === 0) throw new HttpException({ code: 'VALIDATION', message: 'answers: errors.form.selectAtLeastOne' }, HttpStatus.BAD_REQUEST);
    try {
      await this.prisma.schoolCareResponse.create({
        data: {
          schoolId: student.schoolId,
          surveyId: survey.id,
          studentId: student.id,
          classId: student.classId,
          grade: student.grade,
          answersEnc: this.crypto.encryptJson(clean),
        },
      });
    } catch (err) {
      if ((err as { code?: string }).code === 'P2002') {
        throw new ConflictException({ code: 'ALREADY_ANSWERED', message: 'Survey already answered' });
      }
      throw err;
    }
    return { ok: true };
  }

  /** Psixologga murojaat (matn shifrlanadi); kunlik cheklov. */
  async createRequest(childUserId: string, input: unknown) {
    const student = await this.student(childUserId);
    if (!student) throw notEnrolled();
    const data = parseOrThrow(careRequestInputSchema, input);
    const today = await this.prisma.schoolCareRequest.count({
      where: { studentId: student.id, createdAt: { gte: tashkentDayStart(tashkentDay()) } },
    });
    if (today >= MAX_REQUESTS_PER_DAY) {
      throw new HttpException({ code: 'TOO_MANY_REQUESTS', message: 'Daily request limit reached' }, HttpStatus.TOO_MANY_REQUESTS);
    }
    const request = await this.prisma.schoolCareRequest.create({
      data: {
        schoolId: student.schoolId,
        studentId: student.id,
        classId: student.classId,
        topic: data.topic,
        urgency: data.urgency,
        messageEnc: this.crypto.encrypt(data.message),
      },
    });
    return toChildRequest(request);
  }

  /** Bolaning o'z murojaatlari — holati va suhbat vaqti (eslatmalarsiz). */
  async myRequests(childUserId: string) {
    const student = await this.student(childUserId);
    if (!student) return [];
    const rows = await this.prisma.schoolCareRequest.findMany({
      where: { studentId: student.id },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    return rows.map(toChildRequest);
  }

  private async student(childUserId: string) {
    const child = await this.prisma.child.findUnique({
      where: { childUserId },
      select: { id: true, childUser: { select: { language: true } } },
    });
    if (!child) return null;
    const student = await this.prisma.schoolStudent.findUnique({
      where: { childId: child.id },
      select: { id: true, schoolId: true, classId: true, archived: true, class: { select: { grade: true } }, school: { select: { status: true } } },
    });
    if (!student || student.archived || !student.class || student.school.status !== 'ACTIVE') return null;
    return {
      id: student.id,
      schoolId: student.schoolId,
      classId: student.classId,
      grade: student.class.grade,
      lang: child.childUser?.language ?? 'uz',
    };
  }
}

function toChildRequest(r: { id: string; topic: string; urgency: string; status: string; createdAt: Date; meetingAt: Date | null }) {
  return { id: r.id, topic: r.topic, urgency: r.urgency, status: r.status, createdAt: r.createdAt.toISOString(), meetingAt: r.meetingAt?.toISOString() ?? null };
}
