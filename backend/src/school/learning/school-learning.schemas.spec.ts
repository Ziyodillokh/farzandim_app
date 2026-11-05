import { assignmentInputSchema, isWrittenInput } from './school-learning.schemas';

const base = { classIds: ['c1'], dueDate: '2026-11-10' };
const issue = (input: unknown) => {
  const r = assignmentInputSchema.safeParse(input);
  return r.success ? null : r.error.issues[0];
};

describe('assignmentInputSchema', () => {
  it('keeps catalog assignments unchanged (TEST / AUDIOBOOK need materialId only)', () => {
    const r = assignmentInputSchema.parse({ ...base, materialId: 'test:MATH' });

    expect(isWrittenInput(r)).toBe(false);
    expect(r.title).toBeUndefined();
    expect(issue({ ...base })?.path).toEqual(['materialId']);
  });

  it("accepts a written assignment by materialId 'written' or materialKind WRITTEN, title required", () => {
    expect(isWrittenInput(assignmentInputSchema.parse({ ...base, materialId: 'written', title: 'Masala 5' }))).toBe(true);
    expect(isWrittenInput(assignmentInputSchema.parse({ ...base, materialKind: 'WRITTEN', title: 'Masala 5' }))).toBe(true);
    expect(issue({ ...base, materialId: 'written' })?.path).toEqual(['title']);
    expect(issue({ ...base, materialId: 'written', title: '   ' })?.path).toEqual(['title']);
    expect(issue({ ...base, materialId: 'written', title: 'x'.repeat(121) })?.path).toEqual(['title']);
  });

  it('rejects a written assignment that also names a catalog material', () => {
    expect(issue({ ...base, materialKind: 'WRITTEN', materialId: 'test:MATH', title: 'x' })?.path).toEqual(['materialId']);
  });

  it.each([[0], [241], [1.5], ['30']])('rejects estimatedMinutes %p on any kind', (estimatedMinutes) => {
    expect(issue({ ...base, materialId: 'test:MATH', estimatedMinutes })?.path).toEqual(['estimatedMinutes']);
  });

  it('accepts estimatedMinutes 1..240', () => {
    expect(assignmentInputSchema.parse({ ...base, materialId: 'test:MATH', estimatedMinutes: 240 }).estimatedMinutes).toBe(240);
    expect(assignmentInputSchema.parse({ ...base, materialId: 'test:MATH', estimatedMinutes: 1 }).estimatedMinutes).toBe(1);
  });
});
