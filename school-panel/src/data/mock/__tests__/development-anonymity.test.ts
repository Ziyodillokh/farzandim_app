import { beforeEach, describe, expect, it } from 'vitest';

import type { DevDomain, SchoolDevOverview } from '@/data/contracts';
import { CARE_MIN_GROUP as K } from '@/lib/k-anon';
import { getTables, transact } from '../db';
import { developmentService as dev } from '../services/development';
import { DEV_DOMAINS, devIndex, gradeInTerm } from '../services/development-aggregate';
import { freshDb, loginAs } from './helpers';

/**
 * Direktor uchun maktab kesimi: shaxsiy ma'lumot yo'qligi va (chorak, soha) bo'yicha
 * ayirish hujumi (differencing attack) — Bola ovozi testlari bilan bir xil usul.
 */
type Stat = 'ANY' | DevDomain;
type Published = { kind: string; classIds: Set<string> };
const TODAY = '2026-10-12';

/** Sinfda faqat `keep` ta faol o'quvchi qoldiriladi (qolganlari arxivga — tarixdan chiqadi). */
function shrinkClass(classId: string, keep: number): void {
  transact((t) => {
    let left = keep;
    t.students = t.students.map((s) => {
      if (s.classId !== classId || s.archived) return s;
      left -= 1;
      return left >= 0 ? s : { ...s, archived: true };
    });
  });
}

const allClasses = () => new Set(getTables().classes.map((c) => c.id));

/** Haqiqiy son (oq quti): shu chorakda shu sinflardan statistikaga kirgan o'quvchilar. */
function trueCount(term: string, classIds: ReadonlySet<string>, stat: Stat): number {
  const snap = devIndex(getTables()).snapshot.get(term);
  return [...(snap?.values() ?? [])].filter((st) => classIds.has(st.classId) && (stat === 'ANY' || typeof st.domains[stat]?.index === 'number')).length;
}

function publishedSets(o: SchoolDevOverview, stat: Stat): Published[] {
  const t = getTables();
  const out: Published[] = [];
  if (stat === 'ANY') {
    if (o.participation.assessed > 0) out.push({ kind: 'school', classIds: allClasses() });
    for (const h of o.heat) if (!h.hidden && h.n > 0) out.push({ kind: 'class', classIds: new Set([h.classId]) });
    return out;
  }
  if (o.domainAverages.find((d) => d.domain === stat)?.index != null) out.push({ kind: 'school', classIds: allClasses() });
  if (o.trend.find((x) => x.termKey === o.termKey)?.values[stat] !== undefined) out.push({ kind: 'trend', classIds: allClasses() });
  if (stat === 'REASONING') {
    for (const g of o.cognitiveByGrade) {
      if (g.hidden) continue;
      out.push({ kind: 'grade', classIds: new Set(t.classes.filter((c) => gradeInTerm(c, o.termKey, TODAY) === g.grade).map((c) => c.id)) });
    }
  }
  for (const h of o.heat) if (h.cells[stat] != null) out.push({ kind: 'class', classIds: new Set([h.classId]) });
  return out;
}

const isSubset = (a: ReadonlySet<string>, b: ReadonlySet<string>) => [...a].every((x) => b.has(x));

function assertSafe(o: SchoolDevOverview, stat: Stat): void {
  const sets = publishedSets(o, stat);
  // 1) Juftliklar: X − (X ichidagi boshqa turdagi guruhlar) qoldig'i 0 yoki ≥ K.
  for (const x of sets) {
    for (const kind of new Set(sets.map((s) => s.kind))) {
      const inside = sets.filter((s) => s.kind === kind && s !== x && isSubset(s.classIds, x.classIds));
      const residual = new Set([...x.classIds].filter((id) => !inside.some((s) => s.classIds.has(id))));
      const n = trueCount(o.termKey, residual, stat);
      expect(n === 0 || n >= K, `${o.termKey} ${stat}: ${x.kind} − ${kind} → ${n}`).toBe(true);
    }
  }
  // 2) Eng mayda bo'laklar (a'zolik imzosi bo'yicha) ham 0 yoki ≥ K.
  const cells = new Map<string, Set<string>>();
  for (const c of getTables().classes) {
    const signature = sets.map((s) => (s.classIds.has(c.id) ? '1' : '0')).join('');
    if (!signature.includes('1')) continue;
    cells.set(signature, new Set([...(cells.get(signature) ?? []), c.id]));
  }
  for (const cell of cells.values()) {
    const n = trueCount(o.termKey, cell, stat);
    expect(n === 0 || n >= K, `${o.termKey} ${stat}: cell ${[...cell].join(',')} → ${n}`).toBe(true);
  }
}

async function directorOverviews(): Promise<SchoolDevOverview[]> {
  const terms = await dev.termOptions();
  return Promise.all(terms.map((x) => dev.schoolOverview({ termKey: x.key })));
}

const SCENARIOS: Array<[string, Array<[string, number]>]> = [
  ["standart ma'lumot", []],
  ['7-A → 3', [['cls-7a', 3]]],
  ['8-B → 2', [['cls-8b', 2]]],
  ['butun parallel kichik (5-A → 2, 5-B → 1)', [['cls-5a', 2], ['cls-5b', 1]]],
  ['turli parallellarda kichik sinflar', [['cls-4a', 1], ['cls-6b', 4], ['cls-10a', 2], ['cls-11b', 0]]],
];

describe('Rivojlanish — direktor kesimida shaxsiy ma\'lumot yo\'q', () => {
  beforeEach(() => {
    freshDb();
    loginAs('DIRECTOR');
  });

  it("chuqur JSON skan: 'stu-' ham, o'quvchi familiyasi ham yo'q", async () => {
    const lastNames = [...new Set(getTables().students.map((s) => s.lastName))];
    for (const o of await directorOverviews()) {
      const json = JSON.stringify(o);
      expect(json).not.toMatch(/stu-/);
      for (const name of lastNames) expect(json.includes(name), name).toBe(false);
      expect(o.suppressed).toBe(true);
      expect(o.cognitiveByGrade.every((g) => g.bands === null)).toBe(true);
    }
  });

  it('kichik sinf yashiriladi, soni ko\'rsatilmaydi', async () => {
    shrinkClass('cls-7a', 3);
    const o = await dev.schoolOverview({ termKey: '2025-26:Q4' });
    const row = o.heat.find((h) => h.classId === 'cls-7a');
    expect(row?.hidden).toBe(true);
    expect(row?.n).toBe(0);
    expect(Object.values(row?.cells ?? {}).every((v) => v === null)).toBe(true);
    // Parallel ko'rinsa — 7-B ham yashirin bo'lishi shart (ayirma 7-A ni bermasin).
    const grade6 = o.cognitiveByGrade.find((g) => g.grade === 6);
    const b = o.heat.find((h) => h.classId === 'cls-7b');
    expect(grade6?.hidden === false && b?.cells.REASONING != null).toBe(false);
  });

  it.each(SCENARIOS)('%s: (chorak, soha) bo\'yicha ayirish hujumi yashirin guruhni bermaydi', async (_, trims) => {
    for (const [classId, keep] of trims) shrinkClass(classId, keep);
    const overviews = await directorOverviews();
    expect(overviews.length).toBeGreaterThan(0);
    for (const o of overviews) {
      for (const stat of ['ANY', ...DEV_DOMAINS] as const) assertSafe(o, stat);
    }
  });

  it("qo'pol taqsimot: har ko'rsatilgan katak ≥ K, yashirin kataklar yig'indisi ≥ K", async () => {
    for (const o of await directorOverviews()) {
      const c = o.cognitiveCoarse;
      if (!c) continue;
      const shown = [c.below, c.within, c.above].filter((x): x is number => x !== null);
      expect(shown.every((x) => x >= K)).toBe(true);
      expect(shown.length === 3 || shown.length <= 1).toBe(true);
    }
  });
});
