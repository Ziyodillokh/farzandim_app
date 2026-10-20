import { beforeEach, describe, expect, it } from 'vitest';

import type { PsychResult } from '@/data/contracts';
import { scoreResult } from '@/lib/psych/scoring';
import { getTables, transact } from '../db';
import { findTest } from '../psych/catalog';
import { __resetHistoryMemo, HISTORY_PARTICIPATION, historyResults } from '../psych/history';
import { allResults, resultsForStudent } from '../psych/results';
import { TEMPLATE_SPECS } from '../seed/psych-templates/specs';
import { freshDb } from './helpers';

/** Standart ball o'rtachalari shkala bo'yicha (me'yorlar bo'yicha o'qishda hisoblanadi). */
function standardMeans(results: readonly PsychResult[]): Map<string, { n: number; mean: number }> {
  const acc = new Map<string, number[]>();
  for (const r of results) {
    const test = findTest(getTables(), r.testId);
    if (!test) continue;
    for (const s of scoreResult(test, r).scales) {
      if (s.standard !== null) acc.set(`${r.testId}:${s.key}`, [...(acc.get(`${r.testId}:${s.key}`) ?? []), s.standard]);
    }
  }
  return new Map([...acc].map(([k, xs]) => [k, { n: xs.length, mean: xs.reduce((a, b) => a + b, 0) / xs.length }]));
}

describe("Psixologik testlar tarixi (o'tgan choraklar, saqlanmaydi)", () => {
  beforeEach(() => {
    __resetHistoryMemo();
    freshDb();
  });

  it('deterministik: yangi baza va tozalangan memo — aynan bir xil natijalar', () => {
    const first = JSON.stringify(historyResults(getTables()));
    __resetHistoryMemo();
    freshDb();
    expect(JSON.stringify(historyResults(getTables()))).toBe(first);
    expect(first.length).toBeGreaterThan(1000);
  });

  it("memo: o'quvchilar o'zgarmasa — transact'dan keyin ham o'sha massiv; arxivlansa — qayta hisoblanadi", () => {
    const before = historyResults(getTables());
    transact((t) => {
      t.audit.push({ ...t.audit[0]!, id: 'aud-test' });
    });
    expect(historyResults(getTables())).toBe(before);
    const victim = before[0]!.studentId;
    transact((t) => {
      t.students = t.students.map((s) => (s.id === victim ? { ...s, archived: true } : s));
    });
    const after = historyResults(getTables());
    expect(after).not.toBe(before);
    expect(after.some((r) => r.studentId === victim)).toBe(false);
  });

  it("natija tuzilishi: id formati, SEED, joriy sinf, o'sha paytdagi sinf test sinflari ichida", () => {
    const t = getTables();
    const classes = new Map(t.classes.map((c) => [c.id, c]));
    const students = new Map(t.students.map((s) => [s.id, s]));
    for (const r of historyResults(t)) {
      expect(r.id).toMatch(new RegExp(`^ph-\\d-${r.testId}-${r.studentId}$`));
      expect(r.origin).toBe('SEED');
      expect(r.classId).toBe(students.get(r.studentId)?.classId);
      expect(r.grade).toBe((classes.get(r.classId)?.grade ?? 0) - 1);
      expect(TEMPLATE_SPECS[r.testId as keyof typeof TEMPLATE_SPECS].grades).toContain(r.grade);
      const spec = TEMPLATE_SPECS[r.testId as keyof typeof TEMPLATE_SPECS];
      for (const [key, raw] of Object.entries(r.raw)) {
        expect(raw).toBeGreaterThanOrEqual(spec.ranges[key]!.min);
        expect(raw).toBeLessThanOrEqual(spec.ranges[key]!.max);
      }
    }
  });

  it("1–2-sinflarda (va o'tgan yili 2-sinf bo'lgan 3-sinflarda) tarix yo'q", () => {
    const t = getTables();
    const young = new Set(t.classes.filter((c) => c.grade <= 3).map((c) => c.id));
    expect(historyResults(t).filter((r) => young.has(r.classId))).toEqual([]);
  });

  it('standart ball o\'rtachalari ≈ 100 ± 3 (har shkala)', () => {
    const means = standardMeans(historyResults(getTables()));
    expect(means.size).toBeGreaterThanOrEqual(6);
    for (const [key, { n, mean }] of means) {
      expect(n, key).toBeGreaterThan(100);
      expect(Math.abs(mean - 100), `${key}: ${mean.toFixed(1)}`).toBeLessThanOrEqual(3);
    }
  });

  it("to'lqinda qatnashish ≈ 88%", () => {
    const t = getTables();
    const eligible = t.students.filter((s) => !s.archived && (t.classes.find((c) => c.id === s.classId)?.grade ?? 0) >= 4).length;
    const waves = t.psychHistory.waves.length;
    const took = new Set(historyResults(t).map((r) => `${r.id.split('-')[1]}:${r.studentId}`)).size;
    expect(took / (eligible * waves)).toBeGreaterThan(HISTORY_PARTICIPATION - 0.05);
    expect(took / (eligible * waves)).toBeLessThan(HISTORY_PARTICIPATION + 0.05);
  });

  it('kasbiy qiziqish: 8-sinfdan, xom ball 0..6, 6 soha', () => {
    const career = historyResults(getTables()).filter((r) => r.testId === 'tpl-career');
    expect(career.length).toBeGreaterThan(50);
    for (const r of career) {
      expect(r.grade).toBeGreaterThanOrEqual(8);
      expect(Object.keys(r.raw).sort()).toEqual(['A', 'C', 'E', 'I', 'R', 'S']);
      expect(Object.values(r.raw).every((v) => v >= 0 && v <= 6)).toBe(true);
    }
  });

  it("allResults: saqlangan + tarix, vaqt bo'yicha saralangan; resultsForStudent filtrlaydi", () => {
    const stored: PsychResult = { ...historyResults(getTables())[0]!, id: 'psr-test', origin: 'APP', takenAt: '2026-10-12T09:00:00Z' };
    transact((t) => {
      t.psychResults = [...t.psychResults, stored];
    });
    const all = allResults(getTables());
    expect(all.at(-1)?.id).toBe('psr-test');
    const times = all.map((r) => Date.parse(r.takenAt));
    expect(times.every((x, i) => i === 0 || x >= times[i - 1]!)).toBe(true);
    expect(allResults(getTables())).toBe(all);
    expect(resultsForStudent(getTables(), stored.studentId).every((r) => r.studentId === stored.studentId)).toBe(true);
  });
});
