// Bola ovozi (3-faza) e2e fixture'lari: maktab dunyosi, psixolog / o'rinbosar sessiyalari,
// so'rovnoma va murojaat yordamchilari.

import type { LightMyRequestResponse } from 'fastify';
import { randomUUID } from 'node:crypto';
import { sessionFor, Staff, buildWorld, AssessWorld, Kid, enroll } from './school-assessments-fixtures';
import type { TestApp } from './test-app';

export type { AssessWorld, Kid, Staff };
export { buildWorld, enroll, sessionFor };

type Method = 'GET' | 'POST' | 'PUT' | 'DELETE';

/** Xodim paneli: `/api/school/care` + url. */
export function careStaff(t: TestApp) {
  return (who: Staff, method: Method, url: string, payload?: unknown): Promise<LightMyRequestResponse> =>
    t.app.inject({ method, url: `/api/school/care${url}`, payload: payload as object, headers: { authorization: `Bearer ${who.token}` } });
}

/** Bola ilovasi: `/api/child/school/care` + url. */
export function careChild(t: TestApp) {
  return (kid: { token: string }, method: Method, url: string, payload?: unknown): Promise<LightMyRequestResponse> =>
    t.app.inject({ method, url: `/api/child/school/care${url}`, payload: payload as object, headers: { authorization: `Bearer ${kid.token}` } });
}

/** Har qanday `/api` yo'li (xodim tokeni bilan). */
export function schoolApi(t: TestApp) {
  return (who: Staff, method: Method, url: string, payload?: unknown): Promise<LightMyRequestResponse> =>
    t.app.inject({ method, url: `/api/school${url}`, payload: payload as object, headers: { authorization: `Bearer ${who.token}` } });
}

/** Ismi aniq psixolog (o'rinbosar yoki ikkinchi psixolog uchun). */
export async function psychologist(t: TestApp, schoolId: string, username: string, fullName: string): Promise<Staff & { id: string }> {
  const staff = await t.prisma.schoolStaff.create({ data: { schoolId, fullName, role: 'PSYCHOLOGIST', username } });
  return { ...(await sessionFor(t, staff.id)), id: staff.id };
}

/** Psixolog: 5-8-sinflar uchun `n` savolli so'rovnoma yaratib faollashtiradi. */
export async function activateSurvey(t: TestApp, psych: Staff, n = 4): Promise<{ id: string; questionIds: string[] }> {
  const api = careStaff(t);
  const questions = (await api(psych, 'GET', '/questions')).json() as Array<{ id: string; ageGroups: string[] }>;
  const questionIds = questions.filter((q) => q.ageGroups.includes('G5_8')).slice(0, n).map((q) => q.id);
  const created = await api(psych, 'POST', '/surveys', { title: 'Haftalik so\'rovnoma', weekStart: '2026-11-02', ageGroups: ['G5_8'], questionIds });
  if (created.statusCode !== 201) throw new Error(`survey ${created.statusCode}: ${created.body}`);
  const survey = created.json() as { id: string };
  const activated = await api(psych, 'POST', `/surveys/${survey.id}/activate`);
  if (activated.statusCode !== 200) throw new Error(`activate ${activated.statusCode}: ${activated.body}`);
  return { id: survey.id, questionIds };
}

export const answersOf = (questionIds: string[], value: number) => Object.fromEntries(questionIds.map((q) => [q, value]));

/** Bola murojaati (yaratish) — javob tanasi. */
export async function createRequest(t: TestApp, kid: { token: string }, body: Record<string, unknown> = {}) {
  const res = await careChild(t)(kid, 'POST', '/requests', { message: 'Menga yordam kerak', urgency: 'NORMAL', topic: 'OTHER', ...body });
  if (res.statusCode !== 201) throw new Error(`createRequest ${res.statusCode}: ${res.body}`);
  return res.json() as { id: string; [k: string]: unknown };
}

export const uuid = () => randomUUID();

/** Bolaning qurilma tokeni (push yuboriladigan bo'lishi uchun). */
export async function addFcmToken(t: TestApp, kid: { userId: string }) {
  await t.prisma.fcmToken.create({ data: { userId: kid.userId, token: `tok-${randomUUID()}` } });
}
