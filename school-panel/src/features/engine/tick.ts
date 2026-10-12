import type { AttendanceEvent } from '@/data/contracts';
import { simulateSurveyResponses } from '@/data/mock/care-sim';
import { clockMinute, clockToday, getClockState } from '@/data/mock/clock';
import { getTables, transact } from '@/data/mock/db';
import { tickPsychAssignments } from '@/data/mock/psych/sim';
import { simulate } from '@/data/mock/simulator';

/** Shundan katta sakrash (fon tab, qayta boshlash) — "yetib olish": toast'siz. */
const CATCH_UP_MINUTES = 5;

export type EngineTick = {
  /** Yangi daqiqa bo'lmasa yoki boshqa tab allaqachon o'ynagan bo'lsa — null. */
  events: AttendanceEvent[];
  catchingUp: boolean;
  tests: number;
  surveys: number;
};

/**
 * Bitta demo daqiqasi: davomat, psixologik testlar va so'rovnoma javoblari —
 * hammasi BITTA `transact` ichida. Panel ham, kiosk ham shu funksiyani chaqiradi
 * (simulyator `processedUntilMinute` bo'yicha idempotent).
 */
export function runEngineTick(lastKey: { current: string }): EngineTick | null {
  const date = clockToday();
  const minute = Math.floor(clockMinute());
  const epoch = getClockState().epoch;
  const simKey = `${date}#${epoch}`;
  const key = `${simKey}#${minute}`;
  if (key === lastKey.current) return null;
  lastKey.current = key;
  const sim = getTables().sim;
  if (sim.date === simKey && sim.processedUntilMinute >= minute) return null;
  const catchingUp = sim.date !== simKey || sim.processedUntilMinute < 0 || minute - sim.processedUntilMinute > CATCH_UP_MINUTES;
  return transact((tables) => ({
    events: simulate(tables, date, minute, epoch),
    catchingUp,
    tests: tickPsychAssignments(tables, date, minute),
    surveys: simulateSurveyResponses(tables, date, minute),
  }));
}
