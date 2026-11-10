import { beforeEach, describe, expect, it } from 'vitest';

import { WRITTEN_MATERIAL_ID } from '@/data/schemas/learning';
import { getTables } from '../db';
import { learningService } from '../services/learning';
import { freshDb, loginAs } from './helpers';

const DUE = '2026-10-20';
const base = { materialId: WRITTEN_MATERIAL_ID, classIds: ['cls-7a'], dueDate: DUE, note: 'Daftarga yozing' };

describe('yozma vazifa: tayinlash', () => {
  beforeEach(freshDb);

  it('sarlavha majburiy (≤120), izoh ≤300, vaqt 1–240', async () => {
    loginAs('HOMEROOM');
    await expect(learningService.createAssignment({ ...base })).rejects.toMatchObject({ code: 'VALIDATION', message: expect.stringContaining('title') });
    await expect(learningService.createAssignment({ ...base, title: '   ' })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(learningService.createAssignment({ ...base, title: 'x'.repeat(121) })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(learningService.createAssignment({ ...base, title: 'Insho', note: 'n'.repeat(301) })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(learningService.createAssignment({ ...base, title: 'Insho', estimatedMinutes: 0 })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(learningService.createAssignment({ ...base, title: 'Insho', estimatedMinutes: 241 })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(learningService.createAssignment({ ...base, title: 'Insho', estimatedMinutes: 12.5 })).rejects.toMatchObject({ code: 'VALIDATION' });
    for (const minutes of [1, 240]) {
      await expect(learningService.createAssignment({ ...base, title: 'Insho', estimatedMinutes: minutes })).resolves.toMatchObject({ estimatedMinutes: minutes });
    }
  });

  it('yozma vazifa ro\'yxatda WRITTEN turi, sarlavha va vaqt bilan ko\'rinadi; audit yoziladi', async () => {
    loginAs('HOMEROOM');
    const created = await learningService.createAssignment({ ...base, title: '  «Vatan» inshosi  ', estimatedMinutes: 30 });
    expect(created).toMatchObject({ materialId: 'written', title: '«Vatan» inshosi', estimatedMinutes: 30 });
    const row = (await learningService.assignments()).find((a) => a.id === created.id);
    expect(row).toMatchObject({ materialKind: 'WRITTEN', materialTitle: '«Vatan» inshosi', subject: null, estimatedMinutes: 30, canDelete: true });
    expect(getTables().audit.at(-1)).toMatchObject({ action: 'learning.assign', params: { title: '«Vatan» inshosi', classes: '7-A' } });
  });

  it('taxminiy vaqt katalog materialida ham ruxsat; katalogda sarlavha saqlanmaydi', async () => {
    loginAs('ADMIN');
    const created = await learningService.createAssignment({ materialId: 'mat-2', classIds: ['cls-7a'], dueDate: DUE, note: '', estimatedMinutes: 20, title: 'e\'tiborsiz' });
    expect(created.estimatedMinutes).toBe(20);
    expect(created.title).toBeUndefined();
  });

  it('o\'z sinfidan tashqariga yozma vazifa berib bo\'lmaydi (sinf rahbari)', async () => {
    loginAs('HOMEROOM');
    await expect(learningService.createAssignment({ ...base, title: 'Insho', classIds: ['cls-8b'] })).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('yozma vazifa: topshiriqlar ro\'yxati', () => {
  beforeEach(freshDb);

  it('seed: yozma vazifalar bor, o\'quvchilarning bir qismi topshirgan, qolgani topshirmagan; rasmlar bor', async () => {
    loginAs('ADMIN');
    const rows = await learningService.submissions('asg-6');
    const roster = getTables().students.filter((s) => s.classId === 'cls-7a' && !s.archived);
    expect(rows).toHaveLength(roster.length);
    const submitted = rows.filter((r) => r.submission);
    expect(submitted.length).toBeGreaterThan(5);
    expect(submitted.length).toBeLessThan(rows.length);
    for (const r of submitted) {
      expect(r.submission!.photos.length).toBeGreaterThanOrEqual(1);
      expect(r.submission!.photos[0]!.url.startsWith('data:image/svg+xml')).toBe(true);
    }
    const statuses = new Set(submitted.map((r) => r.submission!.status));
    expect(statuses).toEqual(new Set(['SUBMITTED', 'ACCEPTED', 'RETURNED']));
    // Qaytarilganlarda izoh bor, yuborilganlarda tekshiruv vaqti yo'q.
    for (const r of submitted) {
      if (r.submission!.status === 'RETURNED') expect(r.submission!.reviewNote).toBeTruthy();
      if (r.submission!.status === 'SUBMITTED') expect(r.submission!.reviewedAt).toBeNull();
    }
  });

  it('sinf rahbari ikki sinfli topshiriqda faqat o\'z sinfi o\'quvchilarini ko\'radi, direktor — ikkalasini', async () => {
    loginAs('HOMEROOM');
    expect(new Set((await learningService.submissions('asg-7')).map((r) => r.classId))).toEqual(new Set(['cls-7a']));
    loginAs('DIRECTOR');
    expect(new Set((await learningService.submissions('asg-7')).map((r) => r.classId))).toEqual(new Set(['cls-7a', 'cls-7b']));
  });

  it('katalog topshirig\'ida topshiriqlar yo\'q; noma\'lum id — NOT_FOUND; psixolog ko\'ra olmaydi', async () => {
    loginAs('ADMIN');
    await expect(learningService.submissions('asg-1')).rejects.toMatchObject({ code: 'NOT_FOUND' });
    await expect(learningService.submissions('asg-yoq')).rejects.toMatchObject({ code: 'NOT_FOUND' });
    loginAs('PSYCHOLOGIST');
    await expect(learningService.submissions('asg-6')).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('boshqa sinfning yozma vazifasi sinf rahbariga yopiq', async () => {
    loginAs('ADMIN');
    const created = await learningService.createAssignment({ ...base, title: 'Insho', classIds: ['cls-8b'] });
    loginAs('HOMEROOM');
    await expect(learningService.submissions(created.id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('yozma vazifa: tekshirish', () => {
  beforeEach(freshDb);

  async function pendingOf(assignmentId = 'asg-6') {
    const rows = await learningService.submissions(assignmentId);
    const row = rows.find((r) => r.submission?.status === 'SUBMITTED');
    if (!row?.submission) throw new Error('kutayotgan ish yo\'q');
    return row.submission;
  }

  it('qabul qilish: holat va tekshiruv vaqti o\'zgaradi, audit yoziladi', async () => {
    loginAs('HOMEROOM');
    const pending = await pendingOf();
    const result = await learningService.reviewSubmission(pending.id, { status: 'ACCEPTED' });
    expect(result).toMatchObject({ id: pending.id, status: 'ACCEPTED', reviewNote: null });
    expect(result.reviewedAt).toBeTruthy();
    const after = (await learningService.submissions('asg-6')).find((r) => r.submission?.id === pending.id);
    expect(after?.submission?.status).toBe('ACCEPTED');
    expect(getTables().audit.at(-1)).toMatchObject({ action: 'learning.review', params: { variant: 'accepted' } });
  });

  it('qaytarish: izoh majburiy (≤500)', async () => {
    loginAs('HOMEROOM');
    const pending = await pendingOf();
    await expect(learningService.reviewSubmission(pending.id, { status: 'RETURNED' })).rejects.toMatchObject({ code: 'VALIDATION', message: expect.stringContaining('note') });
    await expect(learningService.reviewSubmission(pending.id, { status: 'RETURNED', note: '   ' })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(learningService.reviewSubmission(pending.id, { status: 'RETURNED', note: 'x'.repeat(501) })).rejects.toMatchObject({ code: 'VALIDATION' });
    const returned = await learningService.reviewSubmission(pending.id, { status: 'RETURNED', note: ' Rasm xira ' });
    expect(returned).toMatchObject({ status: 'RETURNED', reviewNote: 'Rasm xira' });
    expect(getTables().audit.at(-1)).toMatchObject({ action: 'learning.review', params: { variant: 'returned' } });
  });

  it('ruxsat: faqat learning.assign; sinf rahbari boshqa sinf ishini tekshira olmaydi', async () => {
    loginAs('ADMIN');
    const other = (await learningService.submissions('asg-7')).find((r) => r.classId === 'cls-7b' && r.submission);
    expect(other?.submission).toBeTruthy();
    loginAs('HOMEROOM');
    await expect(learningService.reviewSubmission(other!.submission!.id, { status: 'ACCEPTED' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('PSYCHOLOGIST');
    await expect(learningService.reviewSubmission(other!.submission!.id, { status: 'ACCEPTED' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('ADMIN');
    await expect(learningService.reviewSubmission('sub-yoq', { status: 'ACCEPTED' })).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('topshiriq o\'chirilganda uning ishlari ham o\'chadi', async () => {
    loginAs('ADMIN');
    expect(getTables().submissions.some((s) => s.assignmentId === 'asg-8')).toBe(true);
    await learningService.deleteAssignment('asg-8');
    expect(getTables().submissions.some((s) => s.assignmentId === 'asg-8')).toBe(false);
    expect(getTables().submissions.some((s) => s.assignmentId === 'asg-6')).toBe(true);
  });
});
