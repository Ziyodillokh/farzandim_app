import { beforeEach, describe, expect, it } from 'vitest';

import { decodeAnswers, rawScores } from '@/lib/psych/scoring';
import { getTables, transact } from '../db';
import { findTest, scoreStored } from '../psych/catalog';
import { allResults } from '../psych/results';
import { seedAssessments } from '../psych/seed-assessments';
import { PARTICIPATION, simulateAnswers, tickPsychAssignments } from '../psych/sim';
import { PSYCH_TEMPLATES } from '../seed/psych-templates';
import type { Tables } from '../tables';
import { freshDb } from './helpers';

const ANCHOR = '2026-10-12';

function inputs(): Pick<Tables, 'classes' | 'students'> {
  const t = getTables();
  return { classes: t.classes, students: t.students };
}

function mean(values: readonly number[]): number {
  return values.reduce((s, v) => s + v, 0) / Math.max(1, values.length);
}

describe('Psixologik testlar seed\'i', () => {
  beforeEach(freshDb);

  it('deterministik: bir xil kirish — bir xil natija', () => {
    const a = seedAssessments(inputs(), ANCHOR, 7);
    const b = seedAssessments(inputs(), ANCHOR, 7);
    expect(JSON.stringify(a)).toBe(JSON.stringify(b));
    expect(a.psychAssignments.map((x) => x.id)).toEqual(['pa-1', 'pa-2', 'pa-3']);
    for (const r of a.psychResults) expect(r.id).toBe(`pr-${r.assignmentId}-${r.studentId}`);
  });

  it('pa-1 ~55%, pa-2 ~45% yakunlangan; pa-3 rejalashtirilgan va natijasiz', () => {
    const { psychAssignments: as, psychResults: rs } = seedAssessments(inputs(), ANCHOR, 7);
    const share = (id: string) => rs.filter((r) => r.assignmentId === id).length / (as.find((a) => a.id === id)?.invited ?? 1);
    expect(share('pa-1')).toBeGreaterThan(0.4);
    expect(share('pa-1')).toBeLessThan(0.7);
    expect(share('pa-2')).toBeGreaterThan(0.3);
    expect(share('pa-2')).toBeLessThan(0.6);
    expect(rs.some((r) => r.assignmentId === 'pa-3')).toBe(false);
    const pa3 = as.find((a) => a.id === 'pa-3');
    expect(pa3?.opensAt).toBe('2026-10-19T08:00:00');
    expect(pa3?.classIds.sort()).toEqual(['cls-10a', 'cls-10b', 'cls-11a', 'cls-11b', 'cls-9a', 'cls-9b']);
    expect(as.find((a) => a.id === 'pa-1')).toMatchObject({ opensAt: '2026-10-09T08:00:00', closesAt: '2026-10-16T18:00:00', classIds: ['cls-7a', 'cls-7b'] });
  });

  it('natijalar: ilova, javoblar kodlangan, xom ball javoblarga mos, oyna ichida', () => {
    const { psychResults: rs } = seedAssessments(inputs(), ANCHOR, 7);
    for (const r of rs) {
      const test = PSYCH_TEMPLATES[r.testId as 'tpl-logic'];
      expect(r.origin).toBe('APP');
      expect(r.answers).toHaveLength(test.items.length);
      expect(rawScores(test, decodeAnswers(test, r.answers ?? ''))).toEqual(r.raw);
      expect(r.takenAt >= '2026-10-09T08:00' && r.takenAt < `${ANCHOR}T00:00`).toBe(true);
    }
  });

  it('kalibrovka: 7-A/7-B o\'rtachasi ~100, 85 dan pastlar ~10–25%, tarix bilan mos', () => {
    transact((t) => tickPsychAssignments(t, ANCHOR, 18 * 60));
    const t = getTables();
    const standard = (r: Parameters<typeof scoreStored>[1]) => scoreStored(t, r)?.scales[0]?.standard ?? 0;
    const live = t.psychResults.filter((r) => r.testId === 'tpl-logic').map(standard);
    const history = allResults(t)
      .filter((r) => r.testId === 'tpl-logic' && r.origin === 'SEED' && ['cls-7a', 'cls-7b'].includes(r.classId) && r.takenAt > '2026-04-01')
      .map(standard);
    expect(live.length).toBeGreaterThan(30);
    expect(Math.abs(mean(live) - 100)).toBeLessThan(5);
    const low = live.filter((v) => v < 85).length / live.length;
    expect(low).toBeGreaterThan(0.08);
    expect(low).toBeLessThan(0.28);
    expect(Math.abs(mean(live) - mean(history))).toBeLessThan(6);
  });

  it('simulateAnswers deterministik; MULTI — variant indekslari', () => {
    const career = PSYCH_TEMPLATES['tpl-career'];
    const a = simulateAnswers(career, 'stu-5', 'cls-9a', '2026-10-12T10:00:00', 's');
    expect(simulateAnswers(career, 'stu-5', 'cls-9a', '2026-10-12T10:00:00', 's')).toEqual(a);
    for (const answer of a) {
      expect(Array.isArray(answer)).toBe(true);
      for (const idx of answer as number[]) expect(idx).toBeLessThan(3);
    }
  });
});

describe('tickPsychAssignments', () => {
  beforeEach(freshDb);

  const tick = (minute: number) => transact((t) => tickPsychAssignments(t, ANCHOR, minute));

  it('idempotent: qayta yoki kichikroq daqiqa bilan — hech narsa qo\'shilmaydi', () => {
    const first = tick(12 * 60);
    expect(first).toBeGreaterThan(0);
    expect(tick(12 * 60)).toBe(0);
    expect(tick(9 * 60)).toBe(0);
    const rest = tick(18 * 60);
    const t = getTables();
    const pa1 = t.psychAssignments.find((a) => a.id === 'pa-1');
    const done = t.psychResults.filter((r) => r.assignmentId === 'pa-1').length;
    expect(done / (pa1?.invited ?? 1)).toBeGreaterThan(PARTICIPATION - 0.15);
    expect(done / (pa1?.invited ?? 1)).toBeLessThanOrEqual(1);
    expect(first + rest).toBeGreaterThan(0);
    expect(t.psychResults.some((r) => r.assignmentId === 'pa-3')).toBe(false);
    expect(new Set(t.psychResults.map((r) => r.id)).size).toBe(t.psychResults.length);
  });

  it('har tayinlash uchun kuniga bitta TEST_COMPLETED', () => {
    tick(11 * 60);
    tick(15 * 60);
    const ntf = getTables().notifications.filter((n) => n.kind === 'TEST_COMPLETED');
    expect(ntf.map((n) => n.id).sort()).toEqual(['ntf-test-pa-1-2026-10-12', 'ntf-test-pa-2-2026-10-12']);
    const todays = getTables().psychResults.filter((r) => r.assignmentId === 'pa-1' && r.takenAt.startsWith(ANCHOR)).length;
    expect(ntf.find((n) => n.id === 'ntf-test-pa-1-2026-10-12')?.params.count).toBe(todays);
    expect(ntf[0]).toMatchObject({ roles: ['PSYCHOLOGIST'], classIds: null, href: expect.stringContaining('/assessments?tab=results') });
  });

  it('noto\'g\'ri kirishda xato tashlamaydi', () => {
    expect(transact((t) => tickPsychAssignments(t, 'bad', 600))).toBe(0);
    expect(transact((t) => tickPsychAssignments(t, ANCHOR, Number.NaN))).toBe(0);
    expect(tickPsychAssignments({} as Tables, ANCHOR, 600)).toBe(0);
  });

  it('yopilgan tayinlash ishlanmaydi; natija test bilan baholanadi', () => {
    transact((t) => {
      t.psychAssignments = t.psychAssignments.map((a) => (a.id === 'pa-2' ? { ...a, status: 'CLOSED' as const } : a));
    });
    tick(18 * 60);
    const t = getTables();
    expect(t.psychResults.filter((r) => r.assignmentId === 'pa-2' && r.takenAt.startsWith(ANCHOR))).toHaveLength(0);
    const fresh = t.psychResults.find((r) => r.assignmentId === 'pa-1' && r.takenAt.startsWith(ANCHOR));
    const test = findTest(t, 'tpl-logic');
    expect(fresh && test && scoreStored(t, fresh)?.scales[0]?.band).toBeTruthy();
  });
});
