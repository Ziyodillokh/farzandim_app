// Haqiqiy anonim so'rovnoma javobi. Anonim qator o'quvchi / bola identifikatorini
// VA vaqt belgisini saqlamaydi (yagona kalit — tasodifiy UUID, bazaning o'zi beradi);
// "kim javob berdi" faqat alohida `SchoolCareParticipation` jadvalida. Qator shakli
// shu yerda belgilanadi va unit testda (`care-anon.spec.ts`) tekshiriladi.

import { ageGroupOf } from './care.schemas';

/** Anonim qatorning YAGONA ruxsat etilgan maydonlari (id — bazada tasodifiy UUID). */
export const ANON_ROW_FIELDS = ['answersEnc', 'ageGroup', 'classId', 'grade', 'schoolId', 'surveyId'] as const;

export interface AnonRow {
  surveyId: string;
  schoolId: string;
  classId: string;
  grade: number;
  ageGroup: string;
  answersEnc: string;
}

/**
 * Anonim javob qatori. `cohort` — sinf va daraja nusxasi (guruhlash va K=5 yashirish uchun,
 * eski jadvaldagi kabi); o'quvchi / bola / vaqt maydonlari bu yerda yo'q va qo'shilmaydi.
 */
export function buildAnonRow(input: {
  surveyId: string;
  schoolId: string;
  classId: string;
  grade: number;
  answers: Readonly<Record<string, number>>;
  encrypt: (answers: Readonly<Record<string, number>>) => string;
}): AnonRow {
  return {
    surveyId: input.surveyId,
    schoolId: input.schoolId,
    classId: input.classId,
    grade: input.grade,
    ageGroup: ageGroupOf(input.grade),
    answersEnc: input.encrypt(input.answers),
  };
}
