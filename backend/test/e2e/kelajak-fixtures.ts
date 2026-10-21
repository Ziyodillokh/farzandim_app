// Kelajak e2e fixture'lari. Bank haqiqiy JSON'dan — migratsiya bilan bir xil
// parser va qarorlar nusxasi (resetDb bazani tozalagani uchun har testda
// qayta yuklanadi). Yosh sozlash, so'rov va "o'tgan kun" yordamchilari.

import { Prisma, PrismaClient } from '@prisma/client';
import {
  buildKelajakBankRows,
  KELAJAK_MIGRATION_OVERRIDES_FILE,
  loadKelajakOverrides,
} from '../../scripts/kelajak/build-bank-migration';
import { addDays, tashkentDay } from '../../src/common/time/tashkent';
import type { TestApp } from './test-app';

const DAY_MS = 24 * 60 * 60 * 1000;

export async function seedKelajakBank(prisma: PrismaClient): Promise<number> {
  const rows = buildKelajakBankRows();
  await prisma.kelajakQuestion.createMany({
    data: rows.map((q) => ({
      ...q,
      text: q.text as Prisma.InputJsonValue,
      options: q.options as unknown as Prisma.InputJsonValue,
      scoring: q.scoring === null ? Prisma.DbNull : (q.scoring as Prisma.InputJsonValue),
    })),
  });
  return rows.length;
}

/** Migratsiya qarorlari bo'yicha nofaol savollar (Q061 va h.k.). */
export const INACTIVE_EXTERNAL_IDS: readonly string[] = Object.keys(
  loadKelajakOverrides(KELAJAK_MIGRATION_OVERRIDES_FILE).inactive,
);

export type AgeSpec = { via: 'birthDate' | 'age'; years: number } | { via: 'none' };

/** Toshkent bugungi kunida aynan `years` to'liq yoshli bolaning tug'ilgan sanasi. */
export function birthDateFor(years: number, today: string = tashkentDay()): Date {
  const [y, m, d] = addDays(today, -60).split('-');
  const day = m === '02' && d === '29' ? '28' : d;
  return new Date(`${Number(y) - years}-${m}-${day}T00:00:00Z`);
}

export async function setChildAge(prisma: PrismaClient, childId: string, spec: AgeSpec): Promise<void> {
  const data =
    spec.via === 'none'
      ? { age: null, birthDate: null }
      : spec.via === 'age'
        ? { age: spec.years, birthDate: null }
        : // `age` ustuni ataylab boshqa guruhda — `birthDate` ustunligi tekshiriladi.
          { age: spec.years >= 13 ? 8 : 16, birthDate: birthDateFor(spec.years) };
  await prisma.child.update({ where: { id: childId }, data });
}

export type Method = 'GET' | 'POST' | 'PUT' | 'DELETE';
export type Call = (token: string, method: Method, url: string, payload?: object) => ReturnType<TestApp['app']['inject']>;

export function caller(t: TestApp): Call {
  return (token, method, url, payload) =>
    t.app.inject({
      method,
      url: `/api${url}`,
      headers: { authorization: `Bearer ${token}` },
      ...(payload && { payload }),
    });
}

export interface SessionLike {
  id: string;
  questions: Array<{ id: string; answerType: string; options: Array<{ value: number }> }>;
}

/** Barcha shkala savollariga javob (`pick` — variant qiymatlaridan); ochiq savollar o'tkaziladi. */
export async function answerScale(
  call: Call,
  token: string,
  session: SessionLike,
  pick: (values: number[]) => number = (values) => Math.max(...values),
): Promise<void> {
  for (const q of session.questions) {
    if (q.answerType === 'text') continue;
    const res = await call(token, 'PUT', `/kelajak/sessions/${session.id}/answers/${q.id}`, {
      value: pick(q.options.map((o) => o.value)),
    });
    expect(res.statusCode).toBe(200);
  }
}

export const lowest = (values: number[]) => Math.min(...values);

/**
 * Har savolga tashvishsiz javob: ijobiy savolga eng yuqori, teskari savolga
 * (reverse — yuqori qiymat tashvish) eng past qiymat.
 */
export async function answerCalm(prisma: PrismaClient, call: Call, token: string, session: SessionLike): Promise<void> {
  const reversed = new Set(
    (await prisma.kelajakQuestion.findMany({ where: { id: { in: session.questions.map((q) => q.id) }, reverse: true } })).map(
      (q) => q.id,
    ),
  );
  for (const q of session.questions) {
    if (q.answerType === 'text') continue;
    const values = q.options.map((o) => o.value);
    const value = reversed.has(q.id) ? Math.min(...values) : Math.max(...values);
    const res = await call(token, 'PUT', `/kelajak/sessions/${session.id}/answers/${q.id}`, { value });
    expect(res.statusCode).toBe(200);
  }
}

/** Sessiyani (kun, vaqtlar va javob vaqtlari) `days` kun orqaga suradi. */
export async function shiftSessionDays(prisma: PrismaClient, sessionId: string, days: number): Promise<void> {
  const session = await prisma.kelajakSession.findUniqueOrThrow({ where: { id: sessionId } });
  const back = (at: Date) => new Date(at.getTime() - days * DAY_MS);
  await prisma.kelajakSession.update({
    where: { id: sessionId },
    data: {
      day: addDays(session.day, -days),
      startedAt: back(session.startedAt),
      completedAt: session.completedAt && back(session.completedAt),
    },
  });
  await prisma.$executeRaw`
    UPDATE "kelajak_answers" SET "answered_at" = "answered_at" - make_interval(days => ${days}::int)
    WHERE "session_id" = ${sessionId}`;
}
