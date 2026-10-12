import { getTables, transact } from '../db';

/** Bola ovozi testlari uchun umumiy yordamchilar (test fayli emas). */
export function activeSurveyId(): string {
  const survey = getTables().careSurveys.find((s) => s.status === 'ACTIVE');
  if (!survey) throw new Error('no active survey');
  return survey.id;
}

/** Sinf javoblarini `keep` tagacha qisqartirish (k-anonimlikni sinash uchun). */
export function shrinkClass(surveyId: string, classId: string, keep: number): void {
  transact((t) => {
    let left = keep;
    t.careResponses = t.careResponses.filter((r) => {
      if (r.surveyId !== surveyId || r.classId !== classId) return true;
      left -= 1;
      return left >= 0;
    });
  });
}

/** Faqat birinchi `count` ta javobga savol javobini qo'shish (kam respondentli mavzu). */
export function addAnswers(surveyId: string, classId: string, questionId: string, count: number): void {
  transact((t) => {
    let left = count;
    t.careResponses = t.careResponses.map((r) => {
      if (r.surveyId !== surveyId || r.classId !== classId || left <= 0) return r;
      left -= 1;
      return { ...r, answers: { ...r.answers, [questionId]: 4 } };
    });
  });
}
