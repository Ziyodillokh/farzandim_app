import { describe, expect, it } from 'vitest';

import type { BellPeriod, TimetableLesson } from '@/data/contracts';
import { EMPTY_DRAFT_MODEL, isDraftDirty, reconcileDraft } from '../draft-model';
import { setCell, toLessons, toVisibleGrid } from '../grid';

const PERIODS: BellPeriod[] = [
  { no: 1, start: '08:00', end: '08:45', kind: 'LESSON' },
  { no: 2, start: '08:50', end: '09:35', kind: 'LESSON' },
];
const lesson = (weekday: number, periodNo: number, subject: string): TimetableLesson => ({ weekday: weekday as TimetableLesson['weekday'], periodNo, subject });

const A = toVisibleGrid([lesson(1, 1, 'math'), lesson(2, 2, 'english')], PERIODS);
const B = toVisibleGrid([lesson(1, 1, 'history')], PERIODS);
const edit = (grid: typeof A) => setCell(grid, 3, 1, { subject: 'physics', room: '', teacherName: '' });

describe('reconcileDraft', () => {
  it('birinchi ma\'lumot — qoralama serverdagiga teng, o\'zgarmagan', () => {
    const model = reconcileDraft(EMPTY_DRAFT_MODEL, 'cls-a', A);
    expect(model).toEqual({ classKey: 'cls-a', base: A, draft: A });
    expect(isDraftDirty(model, 'cls-a')).toBe(false);
  });

  it('ma\'lumot hali yo\'q — bo\'sh holat saqlanadi', () => {
    expect(reconcileDraft(EMPTY_DRAFT_MODEL, 'cls-a', null)).toBe(EMPTY_DRAFT_MODEL);
    expect(reconcileDraft(EMPTY_DRAFT_MODEL, null, A)).toBe(EMPTY_DRAFT_MODEL);
  });

  it('fon yangilanishi: o\'zgarmagan qoralama yangi ma\'lumotni oladi', () => {
    const loaded = reconcileDraft(EMPTY_DRAFT_MODEL, 'cls-a', A);
    const next = reconcileDraft(loaded, 'cls-a', B);
    expect(next).toEqual({ classKey: 'cls-a', base: B, draft: B });
  });

  it('fon yangilanishi: foydalanuvchi o\'zgartirgan qoralama saqlanadi, faqat base yangilanadi', () => {
    const loaded = reconcileDraft(EMPTY_DRAFT_MODEL, 'cls-a', A);
    const editing = { ...loaded, draft: edit(loaded.draft) };
    const next = reconcileDraft(editing, 'cls-a', B);
    expect(next.draft).toBe(editing.draft);
    expect(next.base).toBe(B);
    expect(isDraftDirty(next, 'cls-a')).toBe(true);
  });

  it('bir xil ma\'lumot qayta kelsa — holat o\'zgarmaydi (qayta render yo\'q)', () => {
    const loaded = reconcileDraft(EMPTY_DRAFT_MODEL, 'cls-a', A);
    expect(reconcileDraft(loaded, 'cls-a', { ...A })).toBe(loaded);
  });

  it('sinf almashganda eski qoralama darhol tashlanadi; tez qaytganda ham tiklanmaydi', () => {
    const loaded = reconcileDraft(EMPTY_DRAFT_MODEL, 'cls-a', A);
    const dirty = { ...loaded, draft: edit(loaded.draft) };
    // B tanlandi, ma'lumoti hali kelmagan.
    const switched = reconcileDraft(dirty, 'cls-b', null);
    expect(switched).toBe(EMPTY_DRAFT_MODEL);
    // B yuklanmasdan A ga qaytildi — A serverdagi holatda, tashlangan qoralamasiz.
    const back = reconcileDraft(switched, 'cls-a', A);
    expect(back).toEqual({ classKey: 'cls-a', base: A, draft: A });
    expect(isDraftDirty(back, 'cls-a')).toBe(false);
  });

  it('isDraftDirty: boshqa sinf yoki sinf yo\'q — hech qachon "o\'zgargan" emas', () => {
    const loaded = reconcileDraft(EMPTY_DRAFT_MODEL, 'cls-a', A);
    const dirty = { ...loaded, draft: edit(loaded.draft) };
    expect(isDraftDirty(dirty, 'cls-a')).toBe(true);
    expect(isDraftDirty(dirty, 'cls-b')).toBe(false);
    expect(isDraftDirty(dirty, null)).toBe(false);
  });
});

describe('ko\'rinmaydigan ("yetim") darslar qoralamani abadiy "o\'zgargan" qilmaydi', () => {
  const server = [lesson(1, 1, 'math'), lesson(1, 9, 'chemistry')]; // 9-davr smenada yo'q

  it('saqlashdan keyin (yetim dars tushib qolgach) qoralama serverga teng bo\'ladi', () => {
    const before = reconcileDraft(EMPTY_DRAFT_MODEL, 'cls-a', toVisibleGrid(server, PERIODS));
    const editing = { ...before, draft: edit(before.draft) };
    // Foydalanuvchi saqlaydi: yuboriladigan darslarda 9-davr yo'q; server shuni qaytaradi.
    const sent = toLessons(editing.draft, PERIODS);
    expect(sent.some((l) => l.periodNo === 9)).toBe(false);
    const after = reconcileDraft(editing, 'cls-a', toVisibleGrid(sent, PERIODS));
    expect(isDraftDirty(after, 'cls-a')).toBe(false);
  });
});
