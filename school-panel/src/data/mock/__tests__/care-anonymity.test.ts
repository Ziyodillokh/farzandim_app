import { beforeEach, describe, expect, it } from 'vitest';

import type { CareAggregate, CareTopic } from '@/data/contracts';
import { CARE_BREAKDOWNS, CARE_TOPICS, type CareBreakdown } from '@/data/schemas/care';
import { CARE_MIN_GROUP as K } from '@/lib/k-anon';
import { getTables } from '../db';
import { ageGroupOf } from '../seed/care';
import { careService } from '../services/care';
import { activeSurveyId, addAnswers, shrinkClass } from './care-fixtures';
import { freshDb, loginAs } from './helpers';

/**
 * Ayirish hujumi (differencing attack) testlari: direktor bir so'rovnoma uchun barcha
 * 4 kesimni oladi va ularni bir-biridan ayirib yashirin guruhni topishga urinadi.
 */
type Stat = 'ANY' | CareTopic;
type Published = { breakdown: CareBreakdown | 'OVERALL'; classIds: Set<string>; n: number };

/** Guruh kaliti → sinflar to'plami (aggregate'dan mustaqil hisob). */
function classesOf(breakdown: CareBreakdown, key: string): Set<string> {
  const classes = getTables().classes;
  const pick = (ok: (grade: number, id: string) => boolean) => new Set(classes.filter((c) => ok(c.grade, c.id)).map((c) => c.id));
  switch (breakdown) {
    case 'SCHOOL':
      return pick(() => true);
    case 'AGE_GROUP':
      return pick((grade) => ageGroupOf(grade) === key);
    case 'GRADE':
      return pick((grade) => String(grade) === key);
    case 'CLASS':
      return pick((_, id) => id === key);
  }
}

/** Haqiqiy son: to'plamdagi distinct respondentlar (mavzu bo'yicha — shu mavzuga javob berganlar). */
function trueCount(surveyId: string, classIds: ReadonlySet<string>, stat: Stat): number {
  const t = getTables();
  const topicOf = new Map(t.careQuestions.map((q) => [q.id, q.topic]));
  const people = t.careResponses
    .filter((r) => r.surveyId === surveyId && classIds.has(r.classId))
    .filter((r) => stat === 'ANY' || Object.keys(r.answers).some((q) => topicOf.get(q) === stat))
    .map((r) => r.studentId);
  return new Set(people).size;
}

/** Statistika bo'yicha e'lon qilingan barcha to'plamlar (4 kesim + maktab o'rtachasi). */
async function publishedSets(surveyId: string, stat: Stat): Promise<Published[]> {
  const out: Published[] = [];
  for (const breakdown of CARE_BREAKDOWNS) {
    const agg: CareAggregate = await careService.aggregate({ surveyId, breakdown });
    for (const g of agg.groups) {
      const shown = !g.hidden && (stat === 'ANY' || g.topicScores?.[stat] !== undefined);
      if (shown) out.push({ breakdown, classIds: classesOf(breakdown, g.key), n: g.respondents });
    }
    const overallShown = stat === 'ANY' ? agg.respondents >= K : agg.overall[stat] !== undefined;
    if (breakdown === 'SCHOOL' && overallShown) out.push({ breakdown: 'OVERALL', classIds: classesOf('SCHOOL', ''), n: agg.respondents });
  }
  return out;
}

const isSubset = (a: ReadonlySet<string>, b: ReadonlySet<string>) => [...a].every((x) => b.has(x));

/** 1) Har kesim juftligi: X − (X ichidagi boshqa kesim guruhlari) qoldig'i 0 yoki ≥ K. */
async function assertPairwiseSafe(surveyId: string, stat: Stat): Promise<void> {
  const sets = await publishedSets(surveyId, stat);
  const kinds = [...new Set(sets.map((s) => s.breakdown))];
  for (const x of sets) {
    for (const kind of kinds) {
      const inside = sets.filter((s) => s.breakdown === kind && s !== x && isSubset(s.classIds, x.classIds));
      const residual = new Set([...x.classIds].filter((id) => !inside.some((s) => s.classIds.has(id))));
      const n = trueCount(surveyId, residual, stat);
      expect(n === 0 || n >= K, `${stat}: ${x.breakdown}${[...x.classIds].slice(0, 2)} − ${kind} → ${n}`).toBe(true);
    }
  }
}

/** 2) Umumiy isbot: e'lon qilingan to'plamlar a'zoligi bo'yicha eng mayda bo'lak ham 0 yoki ≥ K. */
async function assertFinestCellsSafe(surveyId: string, stat: Stat): Promise<void> {
  const sets = await publishedSets(surveyId, stat);
  const cells = new Map<string, Set<string>>();
  for (const c of getTables().classes) {
    const signature = sets.map((s) => (s.classIds.has(c.id) ? '1' : '0')).join('');
    if (!signature.includes('1')) continue;
    cells.set(signature, new Set([...(cells.get(signature) ?? []), c.id]));
  }
  for (const cell of cells.values()) {
    const n = trueCount(surveyId, cell, stat);
    expect(n === 0 || n >= K, `${stat}: cell ${[...cell].join(',')} → ${n}`).toBe(true);
  }
}

async function assertSafe(surveyId: string): Promise<void> {
  for (const stat of ['ANY', ...CARE_TOPICS] as const) {
    await assertPairwiseSafe(surveyId, stat);
    await assertFinestCellsSafe(surveyId, stat);
  }
}

const SCENARIOS: Array<[string, Array<[string, number]>]> = [
  ['standart ma\'lumot', []],
  ['7-A → 3 (koordinator misoli)', [['cls-7a', 3]]],
  ['8-B → 2', [['cls-8b', 2]]],
  ['butun parallel kichik (1-A → 2, 1-B → 1)', [['cls-1a', 2], ['cls-1b', 1]]],
  ['butun yosh guruhi kichik (1–4 → 4 kishi)', [['cls-1a', 1], ['cls-1b', 1], ['cls-2a', 1], ['cls-2b', 1], ['cls-3a', 0], ['cls-3b', 0], ['cls-4a', 0], ['cls-4b', 0]]],
  ['turli parallellarda kichik sinflar', [['cls-3a', 1], ['cls-5b', 4], ['cls-10a', 2], ['cls-11b', 0]]],
];

describe('Bola ovozi — kesimlararo ayirish hujumi', () => {
  beforeEach(() => {
    freshDb();
    loginAs('DIRECTOR');
  });

  it.each(SCENARIOS)('%s: hech bir kesim juftligidan yashirin guruh topilmaydi', async (_, trims) => {
    const surveyId = activeSurveyId();
    for (const [classId, keep] of trims) shrinkClass(surveyId, classId, keep);
    await assertSafe(surveyId);
  });

  it('koordinator misoli: 7-A ni 7-parallel − 7-B orqali topib bo\'lmaydi', async () => {
    const surveyId = activeSurveyId();
    shrinkClass(surveyId, 'cls-7a', 3);
    const byClass = await careService.aggregate({ surveyId, breakdown: 'CLASS' });
    const byGrade = await careService.aggregate({ surveyId, breakdown: 'GRADE' });
    expect(byClass.groups.find((g) => g.key === 'cls-7a')?.hidden).toBe(true);
    const grade7 = byGrade.groups.find((g) => g.key === '7');
    const class7b = byClass.groups.find((g) => g.key === 'cls-7b');
    // Parallel ko'rinsa — 7-B ham yashirin bo'lishi shart (aks holda ayirma 7-A ni beradi).
    expect(grade7?.hidden === false && class7b?.hidden === false).toBe(false);
  });

  it('jami K dan kam bo\'lsa — hamma guruh va maktab o\'rtachasi yashirin', async () => {
    const surveyId = activeSurveyId();
    const keep = new Set(['cls-5a']);
    for (const c of getTables().classes) shrinkClass(surveyId, c.id, keep.has(c.id) ? 3 : 0);
    for (const breakdown of CARE_BREAKDOWNS) {
      const agg = await careService.aggregate({ surveyId, breakdown });
      expect(agg.groups.every((g) => g.hidden)).toBe(true);
      expect(agg.overall).toEqual({});
    }
  });
});

describe('Bola ovozi — mavzu bo\'yicha K ta distinct respondent', () => {
  beforeEach(() => {
    freshDb();
    loginAs('DIRECTOR');
  });

  it('mavzuga 5 tadan kam kishi javob bergan bo\'lsa — hech qayerda chiqmaydi', async () => {
    const surveyId = activeSurveyId();
    addAnswers(surveyId, 'cls-7b', 'q-13', 3); // FEEDBACK — faqat 3 kishi
    for (const breakdown of CARE_BREAKDOWNS) {
      const agg = await careService.aggregate({ surveyId, breakdown });
      expect(agg.overall.FEEDBACK).toBeUndefined();
      for (const g of agg.groups) expect(g.topicScores?.FEEDBACK).toBeUndefined();
    }
    await assertSafe(surveyId);
  });

  it('mavzu atomlari: 7-B (6) ko\'rinsa, 7-parallel − 7-B orqali 7-A (3) topilardi — 7-B yashiriladi', async () => {
    const surveyId = activeSurveyId();
    addAnswers(surveyId, 'cls-7a', 'q-13', 3);
    addAnswers(surveyId, 'cls-7b', 'q-13', 6);
    const byClass = await careService.aggregate({ surveyId, breakdown: 'CLASS' });
    expect(byClass.groups.find((g) => g.key === 'cls-7b')?.topicScores?.FEEDBACK).toBeUndefined();
    await assertSafe(surveyId);
  });

  it('ikki kichik sinf birgalikda ≥ K: parallel ko\'rinadi, sinflar yo\'q', async () => {
    const surveyId = activeSurveyId();
    addAnswers(surveyId, 'cls-7a', 'q-13', 3);
    addAnswers(surveyId, 'cls-7b', 'q-13', 3);
    const byGrade = await careService.aggregate({ surveyId, breakdown: 'GRADE' });
    const byClass = await careService.aggregate({ surveyId, breakdown: 'CLASS' });
    expect(byGrade.groups.find((g) => g.key === '7')?.topicScores?.FEEDBACK).toBeDefined();
    expect(byGrade.overall.FEEDBACK).toBeDefined();
    for (const key of ['cls-7a', 'cls-7b']) expect(byClass.groups.find((g) => g.key === key)?.topicScores?.FEEDBACK).toBeUndefined();
    await assertSafe(surveyId);
  });
});
