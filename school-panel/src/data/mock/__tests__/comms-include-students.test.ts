import { beforeEach, describe, expect, it } from 'vitest';

import type { AnnouncementInput } from '@/data/schemas/comms';
import { getTables } from '../db';
import { commsService } from '../services/comms';
import { freshDb, loginAs } from './helpers';

const input = (audience: AnnouncementInput['audience']): AnnouncementInput => ({
  title: 'Sinov e\'loni',
  body: 'Ertaga ko\'rgazma bo\'ladi.',
  priority: 'NORMAL',
  audience,
});

describe('e\'lon: includeStudents (Parvoz Growth)', () => {
  beforeEach(freshDb);

  it('maktab auditoriyasida belgi saqlanadi va yuborilgach ham qoladi', async () => {
    loginAs('DIRECTOR');
    const draft = await commsService.announcements.saveDraft(input({ kind: 'SCHOOL', classIds: [], guardianIds: [], includeStudents: true }));
    expect(draft.audience.includeStudents).toBe(true);
    const sent = await commsService.announcements.send(input({ kind: 'SCHOOL', classIds: [], guardianIds: [], includeStudents: true }), { id: draft.id });
    expect(sent.audience.includeStudents).toBe(true);
    const detail = await commsService.announcements.get(sent.id);
    expect(detail.audience.includeStudents).toBe(true);
  });

  it('sinflar auditoriyasida belgi berilmasa — aniq false yuboriladi', async () => {
    loginAs('HOMEROOM');
    const saved = await commsService.announcements.saveDraft(input({ kind: 'CLASSES', classIds: ['cls-7a'], guardianIds: [] }));
    expect(saved.audience.includeStudents).toBe(false);
  });

  it('tanlangan ota-onalar auditoriyasida belgi umuman yuborilmaydi', async () => {
    loginAs('DIRECTOR');
    const guardianId = getTables().guardians[0]!.id;
    const saved = await commsService.announcements.saveDraft(input({ kind: 'GUARDIANS', classIds: [], guardianIds: [guardianId], includeStudents: true }));
    expect(saved.audience).not.toHaveProperty('includeStudents');
  });

  it('belgini qaytarib olish mumkin (true → false)', async () => {
    loginAs('DIRECTOR');
    const first = await commsService.announcements.saveDraft(input({ kind: 'SCHOOL', classIds: [], guardianIds: [], includeStudents: true }));
    const second = await commsService.announcements.saveDraft(input({ kind: 'SCHOOL', classIds: [], guardianIds: [], includeStudents: false }), first.id);
    expect(second.audience.includeStudents).toBe(false);
  });

  it('sinf rahbari nusxalaganda belgi o\'z sinfi auditoriyasiga ko\'chadi', async () => {
    loginAs('HOMEROOM');
    // ann-2: 5–8-sinflar, o'quvchilarga ham ko'rinadi (seed) — 7-A rahbari uni faqat o'z sinfiga nusxalaydi.
    const copy = await commsService.announcements.duplicate('ann-2');
    expect(copy.audience).toEqual({ kind: 'CLASSES', classIds: ['cls-7a'], guardianIds: [], includeStudents: true });
  });

  it('seed: ba\'zi e\'lonlar o\'quvchilarga ham ko\'rinadi, qolganlari yo\'q', async () => {
    loginAs('DIRECTOR');
    const list = await commsService.announcements.list({ limit: 50 });
    const flagged = list.items.filter((a) => a.audience.includeStudents === true).map((a) => a.id);
    expect(flagged).toEqual(expect.arrayContaining(['ann-2', 'ann-3']));
    expect(list.items.find((a) => a.id === 'ann-1')?.audience.includeStudents).toBeFalsy();
  });
});
