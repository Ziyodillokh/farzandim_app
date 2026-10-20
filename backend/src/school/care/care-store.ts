// Bola ovozi ma'lumotlari: savollar banki (yangi maktabda standart 15 savol
// — birinchi murojaatda), sinflar, shifrlangan javoblarni ochish va
// respondentlar soni (shifrni ochmasdan).

import { Injectable } from '@nestjs/common';
import { SchoolCareQuestion, SchoolCareSurvey } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { SchoolCryptoService } from '../common/school-crypto.service';
import { ClassRow, QuestionMeta, ResponseRow, targetClasses } from './care-aggregate';
import { AgeGroup, CARE_TOPICS, CareTopic } from './care.schemas';

const ALL: AgeGroup[] = ['G1_4', 'G5_8', 'G9_11'];
const OLDER: AgeGroup[] = ['G5_8', 'G9_11'];

/** Standart savollar (bolalar psixologlari bilan kelishilgan namunaviy to'plam). */
const DEFAULT_BANK: Array<{ topic: CareTopic; ageGroups: AgeGroup[]; uz: string; ru: string; reverse?: boolean }> = [
  { topic: 'WELLBEING', ageGroups: ALL, uz: 'Bu hafta maktabda o‘zingni qanchalik xotirjam his qilding?', ru: 'Насколько спокойно ты чувствовал(а) себя в школе на этой неделе?' },
  { topic: 'WELLBEING', ageGroups: ALL, uz: 'Maktabga kelishni qanchalik xohlading?', ru: 'Насколько тебе хотелось приходить в школу?' },
  { topic: 'LEARNING', ageGroups: ALL, uz: 'Darslar senga qanchalik tushunarli bo‘ldi?', ru: 'Насколько понятными были уроки?' },
  { topic: 'SUPPORT', ageGroups: ALL, uz: 'Darsni tushunmaganingda yordam so‘ray olasanmi?', ru: 'Можешь ли ты попросить помощи, если не понял(а) урок?' },
  { topic: 'PEERS', ageGroups: ALL, uz: 'Sinfdoshlaring bilan munosabating qanday?', ru: 'Как складываются отношения с одноклассниками?' },
  { topic: 'PEERS', ageGroups: OLDER, uz: 'Maktabda seni ranjitgan yoki masxara qilgan holatlar bo‘ldimi?', ru: 'Были ли случаи, когда тебя обижали или высмеивали в школе?', reverse: true },
  { topic: 'SAFETY', ageGroups: OLDER, uz: 'Biror kishi seni istamagan ishingni qilishga majburladimi?', ru: 'Кто-то заставлял тебя делать то, чего ты не хотел(а)?', reverse: true },
  { topic: 'SAFETY', ageGroups: ALL, uz: 'Maktabda o‘zingni xavfsiz his qilasanmi?', ru: 'Чувствуешь ли ты себя в безопасности в школе?' },
  { topic: 'SUPPORT', ageGroups: ALL, uz: 'Qiynalganingda gaplasha oladigan ishonchli katta inson bormi?', ru: 'Есть ли взрослый, с которым ты можешь поговорить, когда трудно?' },
  { topic: 'LEARNING', ageGroups: OLDER, uz: 'Uy vazifalari hajmi senga qanchalik mos?', ru: 'Насколько тебе подходит объём домашних заданий?' },
  { topic: 'WELLBEING', ageGroups: OLDER, uz: 'Bu hafta yetarlicha uxladingmi?', ru: 'Высыпался(ась) ли ты на этой неделе?' },
  { topic: 'PEERS', ageGroups: ['G1_4'], uz: 'Tanaffusda birga o‘ynaydigan do‘sting bormi?', ru: 'Есть ли у тебя друг, с которым ты играешь на перемене?' },
  { topic: 'FEEDBACK', ageGroups: OLDER, uz: 'Maktabdagi o‘zgarishlar sen uchun qanchalik foydali bo‘ldi?', ru: 'Насколько полезными для тебя были изменения в школе?' },
  { topic: 'SAFETY', ageGroups: ['G9_11'], uz: 'Internetda senga yoqmagan yozishmalar bo‘ldimi?', ru: 'Были ли в интернете неприятные для тебя переписки?', reverse: true },
  { topic: 'LEARNING', ageGroups: ['G1_4'], uz: 'Darsda o‘qituvchi seni maqtadimi?', ru: 'Хвалил(а) ли тебя учитель на уроке?' },
];

export function toQuestionView(q: SchoolCareQuestion) {
  const text = (q.text ?? {}) as { uz?: unknown; ru?: unknown };
  return {
    id: q.id,
    topic: (CARE_TOPICS as readonly string[]).includes(q.topic) ? (q.topic as CareTopic) : 'FEEDBACK',
    ageGroups: q.ageGroups as AgeGroup[],
    text: { uz: typeof text.uz === 'string' ? text.uz : '', ru: typeof text.ru === 'string' ? text.ru : '' },
    reverse: q.reverse,
    active: q.active,
  };
}

export function toSurveyView(s: SchoolCareSurvey) {
  return {
    id: s.id,
    title: s.title,
    weekStart: s.weekStart,
    ageGroups: s.ageGroups as AgeGroup[],
    questionIds: s.questionIds,
    status: s.status as 'DRAFT' | 'ACTIVE' | 'CLOSED',
    invited: s.invited,
    activatedAt: s.activatedAt?.toISOString() ?? null,
  };
}

@Injectable()
export class CareStore {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: SchoolCryptoService,
  ) {}

  /** Savollar banki; bo'sh maktabda standart to'plam (parallel chaqiruvda bir marta). */
  async questions(schoolId: string): Promise<SchoolCareQuestion[]> {
    const existing = await this.prisma.schoolCareQuestion.findMany({ where: { schoolId }, orderBy: { createdAt: 'asc' } });
    if (existing.length > 0) return existing;
    await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`care-bank:${schoolId}`}, 0))`;
      if ((await tx.schoolCareQuestion.count({ where: { schoolId } })) > 0) return;
      const base = Date.now();
      await tx.schoolCareQuestion.createMany({
        data: DEFAULT_BANK.map((q, i) => ({
          schoolId,
          topic: q.topic,
          ageGroups: q.ageGroups,
          text: { uz: q.uz, ru: q.ru },
          reverse: q.reverse ?? false,
          createdAt: new Date(base + i),
        })),
      });
    });
    return this.prisma.schoolCareQuestion.findMany({ where: { schoolId }, orderBy: { createdAt: 'asc' } });
  }

  async questionMeta(schoolId: string): Promise<Map<string, QuestionMeta>> {
    const questions = await this.questions(schoolId);
    return new Map(questions.map((q) => [q.id, { topic: toQuestionView(q).topic, reverse: q.reverse }]));
  }

  classes(schoolId: string): Promise<ClassRow[]> {
    return this.prisma.schoolClass.findMany({ where: { schoolId }, select: { id: true, name: true, grade: true, letter: true } });
  }

  /** Taklif qilinganlar: so'rovnoma yosh guruhlaridagi faol o'quvchilar. */
  async invitedFor(schoolId: string, ageGroups: readonly string[]): Promise<number> {
    const classIds = targetClasses(await this.classes(schoolId), ageGroups).map((c) => c.id);
    return this.prisma.schoolStudent.count({ where: { schoolId, archived: false, classId: { in: classIds } } });
  }

  /** Distinct respondentlar (javob paytida so'rovnoma yosh guruhida bo'lganlar; shifr ochilmaydi). */
  respondentCount(survey: SchoolCareSurvey): Promise<number> {
    return this.prisma.schoolCareResponse.count({ where: { surveyId: survey.id } });
  }

  /** So'rovnoma javoblari — shifr ochiladi (faqat umumlashtirish va psixolog uchun). */
  async responses(surveyId: string): Promise<ResponseRow[]> {
    const rows = await this.prisma.schoolCareResponse.findMany({
      where: { surveyId },
      select: { studentId: true, classId: true, grade: true, answersEnc: true },
    });
    return rows.flatMap((r) =>
      r.classId
        ? [{ studentId: r.studentId, classId: r.classId, grade: r.grade, answers: this.crypto.decryptJson<Record<string, number>>(r.answersEnc) }]
        : [],
    );
  }
}
