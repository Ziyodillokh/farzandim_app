// Natijalar ko'rinishi: eng so'nggi natija, taqsimot, sinf rahbari uchun faqat
// darajalar va rivojlanish bo'limi uchun baholangan o'qish.

import { PSYCH_TEMPLATES } from './psych/templates';
import { buildDistribution, distributionScale, latestPerStudent, scoreStoredResult, StoredResult, toResultRow } from './results-view';

const logic = PSYCH_TEMPLATES['tpl-logic'];
const career = PSYCH_TEMPLATES['tpl-career'];

function stored(id: string, studentId: string, day: string, total: number, extra: Partial<StoredResult> = {}): StoredResult {
  return {
    id,
    studentId,
    classId: 'c1',
    takenAt: new Date(`${day}T05:00:00.000Z`),
    origin: 'APP',
    assignmentId: 'a1',
    ageBand: 'A13_14',
    raw: { total },
    durationSec: 120,
    answersEnc: 'v1.x.y',
    ...extra,
  };
}

const lookups = { names: new Map([['s1', 'Karimov Aziz']]), classNames: new Map([['c1', '7-A']]) };

describe('results-view', () => {
  it('har o\'quvchining eng so\'nggi natijasi, yangidan eskiga', () => {
    const rows = [stored('r1', 's1', '2026-10-01', 5), stored('r2', 's2', '2026-10-02', 6), stored('r3', 's1', '2026-10-03', 7)];
    expect(latestPerStudent(rows).map((r) => r.id)).toEqual(['r3', 'r2']);
  });

  it('psixolog: to\'liq shkala, vaqt va javoblar; sinf rahbari: faqat darajalar', () => {
    const r = stored('r1', 's1', '2026-10-01', 10);
    const full = toResultRow(logic, r, false, lookups, '0123');
    expect(full).toMatchObject({ studentName: 'Karimov Aziz', className: '7-A', durationSec: 120, answers: '0123', takenAt: '2026-10-01T05:00:00.000Z' });
    expect(full.scales[0]).toMatchObject({ key: 'total', raw: 10, max: 16, standard: 99, percentile: 47, band: 'AVERAGE' }); // me'yor A13_14: 10.2 ± 2.8
    const banded = toResultRow(logic, r, true, lookups, '0123');
    expect(banded).not.toHaveProperty('answers');
    expect(banded).not.toHaveProperty('durationSec');
    expect(banded.scales).toEqual([{ key: 'total', band: 'AVERAGE' }]);
    expect(toResultRow(logic, { ...r, classId: null, studentId: 'x' }, true, lookups)).toMatchObject({ classId: '', className: '—', studentName: '—' });
  });

  it('taqsimot: qobiliyat darajalari; kasbiy qiziqish — RIASEC kodlari', () => {
    const rows = [stored('r1', 's1', '2026-10-01', 10), stored('r2', 's2', '2026-10-01', 16)].map((r) => toResultRow(logic, r, false, lookups));
    const scale = distributionScale(logic, undefined);
    expect(scale).toBe('total');
    expect(buildDistribution(logic, rows, scale)).toEqual([
      { band: 'VERY_LOW', count: 0 },
      { band: 'LOW', count: 0 },
      { band: 'AVERAGE', count: 1 },
      { band: 'HIGH', count: 0 },
      { band: 'VERY_HIGH', count: 1 },
    ]);
    const careerRow = toResultRow(career, stored('r3', 's1', '2026-10-01', 0, { raw: { I: 5, A: 4, R: 1 } }), false, lookups);
    expect(careerRow.topCodes).toBe('IAR');
    expect(distributionScale(career, undefined)).toBeNull();
    expect(buildDistribution(career, [careerRow], null).find((b) => b.band === 'I')?.count).toBe(1);
  });

  it('scoreStoredResult: joriy me\'yorlar bilan baholaydi, javoblarsiz', () => {
    const r = stored('r1', 's1', '2026-10-01', 13);
    const scored = scoreStoredResult({ ...logic, norms: { total: [{ band: 'A13_14', mean: 10, sd: 3 }] } }, { ...r, grade: 7, testId: logic.id, version: 1 });
    expect(scored).toMatchObject({ id: 'r1', grade: 7, testId: 'tpl-logic', raw: { total: 13 }, topCodes: null });
    expect(scored.scales[0]).toMatchObject({ z: 1, standard: 115, percentile: 84, band: 'HIGH' });
    expect(scored).not.toHaveProperty('answersEnc');
  });
});
