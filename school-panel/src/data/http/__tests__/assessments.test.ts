import { describe, expect, it } from 'vitest';

import { toAssignBody, toAssignmentRow, toAssignmentRows } from '../services/assessments-adapters';

/** Mavjud backend `toAssignmentRow` (assessments-view.ts) qatori; `target` — saqlangan JSON. */
const CLASS_ROW = {
  id: 'pa-1',
  testId: 'tpl-logic',
  testVersion: 1,
  target: { kind: 'CLASSES', classIds: ['c1', 'c2'] },
  classIds: ['c1', 'c2'],
  opensAt: '2026-11-06T03:00:00.000Z',
  closesAt: '2026-11-13T13:00:00.000Z',
  status: 'OPEN',
  invited: 52,
  consent: 'PARENTS_INFORMED',
  createdBy: 'stf-1',
  createdAt: '2026-11-05T10:00:00.000Z',
  state: 'ACTIVE',
  completed: 10,
  testTitle: { uz: 'Mantiqiy fikrlash', ru: 'Логическое мышление' },
  testKind: 'COGNITIVE',
  classNames: ['7-A', '7-B'],
};

describe('toAssignmentRow', () => {
  it('sinf bo\'yicha tayinlash o\'zgarishsiz', () => {
    const row = toAssignmentRow(CLASS_ROW);
    expect(row).toMatchObject({ id: 'pa-1', target: { kind: 'CLASSES', classIds: ['c1', 'c2'] }, state: 'ACTIVE', completed: 10, invited: 52, classNames: ['7-A', '7-B'], testKind: 'COGNITIVE' });
    expect('careRequestId' in row).toBe(false);
  });

  it('shaxsiy tayinlash (kontrakt D): target STUDENTS, careRequestId, bo\'sh classNames', () => {
    const row = toAssignmentRow({
      ...CLASS_ROW,
      target: { kind: 'STUDENTS', studentIds: ['st1', 'st2'] },
      careRequestId: 'care-9',
      classIds: ['c1'],
      invited: 2,
      classNames: ['7-A'],
    });
    expect(row.target).toEqual({ kind: 'STUDENTS', studentIds: ['st1', 'st2'] });
    expect(row.careRequestId).toBe('care-9');
    expect(row.invited).toBe(2);
  });

  it('`target` bo\'lmasa (faqat ustunlar): studentIds → STUDENTS, aks holda classIds → CLASSES', () => {
    const { target: _t, ...noTarget } = CLASS_ROW;
    void _t;
    expect(toAssignmentRow({ ...noTarget, studentIds: ['st1'] }).target).toEqual({ kind: 'STUDENTS', studentIds: ['st1'] });
    expect(toAssignmentRow({ ...noTarget, studentIds: [] }).target).toEqual({ kind: 'CLASSES', classIds: ['c1', 'c2'] });
  });

  it('classNames/classIds yo\'q bo\'lsa — bo\'sh ro\'yxat (shaxsiy tayinlashda sinf bo\'lmasligi mumkin)', () => {
    const { classNames: _c, classIds: _ci, ...rest } = CLASS_ROW;
    void [_c, _ci];
    expect(toAssignmentRow({ ...rest, target: { kind: 'STUDENTS', studentIds: ['st1'] } })).toMatchObject({ classNames: [], classIds: [] });
  });

  it('noto\'g\'ri shakl aniq xato beradi', () => {
    expect(() => toAssignmentRow({ ...CLASS_ROW, state: 'DONE' })).toThrowError(/kutilmagan javob shakli/);
    expect(() => toAssignmentRow({ ...CLASS_ROW, target: { kind: 'EVERYONE' } })).toThrowError(/kutilmagan javob shakli/);
    expect(() => toAssignmentRow({ ...CLASS_ROW, invited: '52' })).toThrowError(/kutilmagan javob shakli/);
    expect(() => toAssignmentRow({ ...CLASS_ROW, target: { kind: 'STUDENTS', studentIds: [1] } })).toThrowError(/kutilmagan javob shakli/);
    expect(() => toAssignmentRows({ items: [] })).toThrowError(/kutilmagan javob shakli/);
    expect(toAssignmentRows([CLASS_ROW])).toHaveLength(1);
  });
});

describe('toAssignBody', () => {
  const base = { testId: 'tpl-logic', opensAt: '2026-11-06T09:00', closesAt: '2026-11-13T18:00', consent: true as const };

  it('shaxsiy tayinlash: target STUDENTS, careRequestId YUQORI darajada', () => {
    expect(toAssignBody({ ...base, target: { kind: 'STUDENTS', studentIds: ['st1'] }, careRequestId: 'care-9' })).toEqual({
      testId: 'tpl-logic',
      target: { kind: 'STUDENTS', studentIds: ['st1'] },
      opensAt: '2026-11-06T09:00',
      closesAt: '2026-11-13T18:00',
      consent: true,
      careRequestId: 'care-9',
    });
  });

  it('careRequestId bo\'lmasa kalit umuman yuborilmaydi; sinf/parallel maqsadlari avvalgidek', () => {
    const body = toAssignBody({ ...base, target: { kind: 'CLASSES', classIds: ['c1'] } });
    expect('careRequestId' in body).toBe(false);
    expect(body.target).toEqual({ kind: 'CLASSES', classIds: ['c1'] });
    expect(toAssignBody({ ...base, target: { kind: 'GRADES', grades: [7] } }).target).toEqual({ kind: 'GRADES', grades: [7] });
  });
});
