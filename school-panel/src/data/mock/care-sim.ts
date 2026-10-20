import type { CareQuestion, CareResponse, CareSurvey, IsoDate, SchoolClass } from '@/data/contracts';
import { hashString, mulberry32, unitHash } from '@/lib/rng';
import { fromIsoDate, toLocalIso } from './calendar';
import { ageGroupOf, generateAnswers } from './seed/care';
import type { Tables } from './tables';

/** Taklif qilinganlarning taxminan qancha qismi javob beradi. */
export const SIM_PARTICIPATION = 0.78;
/** Javoblar faollashtirishdan keyingi shu oynaga yoyiladi (daqiqa). */
export const SIM_WINDOW_MINUTES = 6 * 60;
/** `activatedAt` bo'lmasa — so'rovnoma haftasining birinchi kuni shu vaqtdan. */
const DEFAULT_START_TIME = 'T08:00:00';
const MINUTE_MS = 60_000;

/** Javoblar oynasining boshlanishi (ms). */
function windowStartMs(survey: CareSurvey): number {
  return Date.parse(survey.activatedAt ?? `${survey.weekStart}${DEFAULT_START_TIME}`);
}

/** O'quvchining (so'rovnoma, o'quvchi) bo'yicha barqaror rejasi: qatnashadimi va qachon. */
function plannedAtMs(survey: CareSurvey, studentId: string, startMs: number): number | null {
  if (unitHash(survey.id, studentId, 'join') >= SIM_PARTICIPATION) return null;
  return startMs + Math.floor(unitHash(survey.id, studentId, 'at') * SIM_WINDOW_MINUTES) * MINUTE_MS;
}

function surveyQuestions(tables: Tables, survey: CareSurvey): CareQuestion[] {
  const byId = new Map(tables.careQuestions.map((q) => [q.id, q]));
  return survey.questionIds.flatMap((id) => {
    const q = byId.get(id);
    return q ? [q] : [];
  });
}

function respond(survey: CareSurvey, studentId: string, cls: SchoolClass, questions: readonly CareQuestion[], atMs: number): CareResponse | null {
  const answers = generateAnswers(questions, cls, mulberry32(hashString(`${survey.id}|${studentId}`)));
  if (Object.keys(answers).length === 0) return null;
  return {
    id: `rsp-${survey.id}-${studentId}`,
    surveyId: survey.id,
    studentId,
    classId: cls.id,
    grade: cls.grade,
    answers,
    submittedAt: toLocalIso(new Date(atMs)),
  };
}

function simulateSurvey(tables: Tables, survey: CareSurvey, nowMs: number): CareResponse[] {
  const startMs = windowStartMs(survey);
  if (!Number.isFinite(startMs) || nowMs < startMs) return [];
  const answered = new Set(tables.careResponses.filter((r) => r.surveyId === survey.id).map((r) => r.studentId));
  const classes = new Map(tables.classes.filter((c) => survey.ageGroups.includes(ageGroupOf(c.grade))).map((c) => [c.id, c]));
  const questions = surveyQuestions(tables, survey);
  const fresh: CareResponse[] = [];
  for (const student of tables.students) {
    const cls = classes.get(student.classId);
    if (student.archived || !cls || answered.has(student.id)) continue;
    const atMs = plannedAtMs(survey, student.id, startMs);
    if (atMs === null || atMs > nowMs) continue;
    const response = respond(survey, student.id, cls, questions, atMs);
    if (response) fresh.push(response);
  }
  return fresh;
}

/**
 * Demo: faol so'rovnomaga o'quvchilar javob beradi (DemoEngine har tikda chaqiradi).
 * - Deterministik: qatnashish (~78%), vaqt va javoblar (so'rovnoma, o'quvchi) xeshidan.
 * - Vaqt: `activatedAt` (yoki hafta boshidagi 08:00) dan 6 soatlik oynaga yoyilgan.
 * - Idempotent: javob ID `rsp-<so'rovnoma>-<o'quvchi>`, bor javob qayta yozilmaydi.
 * `tables` — tranzaksiya nusxasi (o'zgartiriladi). Yangi javoblar sonini qaytaradi.
 */
export function simulateSurveyResponses(tables: Tables, date: IsoDate, minute: number): number {
  const nowMs = fromIsoDate(date).getTime() + minute * MINUTE_MS;
  const fresh = tables.careSurveys.filter((s) => s.status === 'ACTIVE').flatMap((s) => simulateSurvey(tables, s, nowMs));
  if (fresh.length > 0) tables.careResponses = [...tables.careResponses, ...fresh];
  return fresh.length;
}
