import { beforeEach, describe, expect, it } from 'vitest';

import type { LinkRequest } from '@/data/contracts';
import { auditText } from '@/features/audit/audit-text';
import { type TKey, translate } from '@/i18n/translate';
import type { Vars } from '@/i18n/types';
import { getTables } from '../db';
import { accessService } from '../services/access';
import { linkRequestsService } from '../services/link-requests';
import { freshDb, loginAs } from './helpers';

const ru = (key: TKey, vars?: Vars) => translate('ru', key, vars);
const uz = (key: TKey, vars?: Vars) => translate('uz', key, vars);

const byKind = (items: LinkRequest[], kind: LinkRequest['kind']) => items.filter((i) => i.kind === kind);
const isLinked = (studentId: string) => getTables().access.linkedStudentIds.includes(studentId);

describe('linkRequestsService.list', () => {
  beforeEach(freshDb);

  it('admin: barcha ochiq so\'rovlar (3 tekshiruv + 2 tuzatish), eng yangisi birinchi; maydonlar kontraktga mos', async () => {
    loginAs('ADMIN');
    const items = await linkRequestsService.list();
    expect(byKind(items, 'REVIEW')).toHaveLength(3);
    expect(byKind(items, 'CORRECTION')).toHaveLength(2);
    const times = items.map((i) => Date.parse(i.createdAt));
    expect(times).toEqual([...times].sort((a, b) => b - a));
    for (const item of items) {
      expect(Object.keys(item).sort()).toEqual(['className', 'createdAt', 'id', 'kind', 'note', 'parentUsed', 'reason', 'studentId', 'studentName']);
      expect(item.studentName).toMatch(/\S+ \S+/);
      expect(item.className).toMatch(/^\d+-[A-Z]$/);
    }
    expect(byKind(items, 'REVIEW').every((i) => i.note === null && i.reason === null)).toBe(true);
    expect(byKind(items, 'CORRECTION').every((i) => i.note && i.reason === 'WRONG_SCHOOL_OR_CLASS')).toBe(true);
    expect(byKind(items, 'REVIEW').some((i) => i.parentUsed)).toBe(true);
    expect(byKind(items, 'REVIEW').some((i) => !i.parentUsed)).toBe(true);
  });

  it('sinf rahbari: faqat o\'z sinfi (7-A); direktor ham hamma sinfni ko\'radi', async () => {
    loginAs('HOMEROOM');
    const own = await linkRequestsService.list();
    expect(own.length).toBeGreaterThan(0);
    expect(new Set(own.map((i) => i.className))).toEqual(new Set(['7-A']));
    loginAs('DIRECTOR');
    expect((await linkRequestsService.list()).length).toBe(5);
  });

  it('ruxsat: `guardians.link` yo\'q rollar (psixolog, navbatchi) — FORBIDDEN', async () => {
    loginAs('PSYCHOLOGIST');
    await expect(linkRequestsService.list()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('DUTY');
    await expect(linkRequestsService.list()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('linkRequestsService: tekshiruv (REVIEW)', () => {
  beforeEach(freshDb);

  it('tasdiqlash: o\'quvchi bola profiliga ulanadi (endi kirish ma\'lumotlari berilishi mumkin), so\'rov yopiladi', async () => {
    loginAs('ADMIN');
    const request = byKind(await linkRequestsService.list(), 'REVIEW')[0]!;
    expect(isLinked(request.studentId!)).toBe(false);
    await expect(accessService.credentials(request.studentId!)).resolves.toEqual({ linked: false, credentials: null });

    await linkRequestsService.confirm(request.id);
    expect(isLinked(request.studentId!)).toBe(true);
    await expect(accessService.credentials(request.studentId!)).resolves.toEqual({ linked: true, credentials: null });
    expect((await linkRequestsService.list()).some((i) => i.id === request.id)).toBe(false);
  });

  it('rad etish: o\'quvchi ulanmaydi, kodda o\'quvchi o\'rni bo\'shaydi (bola qayta kiritishi mumkin)', async () => {
    loginAs('ADMIN');
    const request = byKind(await linkRequestsService.list(), 'REVIEW')[0]!;
    await linkRequestsService.reject(request.id);
    expect(isLinked(request.studentId!)).toBe(false);
    const invite = await accessService.inviteCode(request.studentId!);
    expect(invite?.student).toEqual({ used: false, usedAt: null });
    expect((await linkRequestsService.list()).some((i) => i.id === request.id)).toBe(false);
  });

  it('hal qilingan so\'rovni qayta hal qilib bo\'lmaydi (CONFLICT); noma\'lum id — NOT_FOUND', async () => {
    loginAs('ADMIN');
    const request = byKind(await linkRequestsService.list(), 'REVIEW')[0]!;
    await linkRequestsService.confirm(request.id);
    await expect(linkRequestsService.confirm(request.id)).rejects.toMatchObject({ code: 'CONFLICT' });
    await expect(linkRequestsService.reject(request.id)).rejects.toMatchObject({ code: 'CONFLICT' });
    await expect(linkRequestsService.confirm('lnk-yoq')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('sinf rahbari: o\'z sinfini hal qiladi, boshqa sinfniki — FORBIDDEN', async () => {
    loginAs('ADMIN');
    const all = byKind(await linkRequestsService.list(), 'REVIEW');
    const own = all.find((i) => i.className === '7-A')!;
    const foreign = all.find((i) => i.className !== '7-A')!;
    loginAs('HOMEROOM');
    await expect(linkRequestsService.confirm(foreign.id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(linkRequestsService.reject(foreign.id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await linkRequestsService.confirm(own.id);
    expect(isLinked(own.studentId!)).toBe(true);
  });

  it('audit: kim, qaysi o\'quvchi — faqat ism (kod va boshqa maydonlarsiz), ikkala tilda', async () => {
    loginAs('ADMIN');
    const [a, b] = byKind(await linkRequestsService.list(), 'REVIEW');
    await linkRequestsService.confirm(a!.id);
    await linkRequestsService.reject(b!.id);
    const entries = getTables().audit.filter((e) => e.action.startsWith('student.link.'));
    expect(entries.map((e) => e.action)).toEqual(['student.link.confirm', 'student.link.reject']);
    expect(auditText(uz, entries[0]!)).toBe(`${a!.studentName}: bola profiliga ulanish tasdiqlandi`);
    expect(auditText(ru, entries[1]!)).toBe(`${b!.studentName}: подключение к детскому профилю отклонено`);
    for (const e of entries) {
      expect(Object.keys(e.params ?? {})).toEqual(['name']);
      expect(e.before).toBeNull();
      expect(e.after).toBeNull();
    }
  });
});

describe('linkRequestsService: tuzatish (CORRECTION)', () => {
  beforeEach(freshDb);

  it('ulanishni saqlash (confirm) — ulanish o\'zgarmaydi, so\'rov yopiladi', async () => {
    loginAs('ADMIN');
    const request = byKind(await linkRequestsService.list(), 'CORRECTION')[0]!;
    expect(isLinked(request.studentId!)).toBe(true);
    await linkRequestsService.confirm(request.id);
    expect(isLinked(request.studentId!)).toBe(true);
    expect((await linkRequestsService.list()).some((i) => i.id === request.id)).toBe(false);
    expect(auditText(uz, getTables().audit.at(-1)!)).toBe(`${request.studentName}: tuzatish soʻrovi koʻrib chiqildi, ulanish saqlandi`);
  });

  it('ulanishni uzish (reject) — o\'quvchi bola profilidan ajraladi: kirish ma\'lumotlari yana berilmaydi', async () => {
    loginAs('ADMIN');
    const request = byKind(await linkRequestsService.list(), 'CORRECTION')[0]!;
    await linkRequestsService.reject(request.id);
    expect(isLinked(request.studentId!)).toBe(false);
    await expect(accessService.issueCredentials(request.studentId!)).rejects.toMatchObject({ code: 'CONFLICT', detail: 'NOT_LINKED' });
    expect(auditText(ru, getTables().audit.at(-1)!)).toBe(`${request.studentName}: запрос на исправление рассмотрен, ученик отключён`);
  });
});
