import { beforeEach, describe, expect, it } from 'vitest';

import type { LinkRequest } from '@/data/contracts';
import { auditText } from '@/features/audit/audit-text';
import { type TKey, translate } from '@/i18n/translate';
import type { Vars } from '@/i18n/types';
import { accessNotificationId } from '../access-model';
import { getTables, transact } from '../db';
import { accessService } from '../services/access';
import { linkRequestsService } from '../services/link-requests';
import { freshDb, loginAs } from './helpers';

const ru = (key: TKey, vars?: Vars) => translate('ru', key, vars);
const uz = (key: TKey, vars?: Vars) => translate('uz', key, vars);

const byKind = (items: LinkRequest[], kind: LinkRequest['kind']) => items.filter((i) => i.kind === kind);
const isLinked = (studentId: string) => getTables().access.linkedStudentIds.includes(studentId);
const notificationIds = () => getTables().notifications.map((n) => n.id);
const lastAudit = () => getTables().audit.at(-1)!;

/** Birinchi ochiq so'rov (admin ko'rinishida) — seed holatiga qattiq bog'lanmaydi. */
async function first(kind: LinkRequest['kind']): Promise<LinkRequest> {
  loginAs('ADMIN');
  return byKind(await linkRequestsService.list(), kind)[0]!;
}

describe('linkRequestsService.list (K2 §5 shakli)', () => {
  beforeEach(freshDb);

  it('admin: barcha ochiq so\'rovlar (3 tekshiruv + 2 tuzatish); maydonlar aynan kontraktdagidek', async () => {
    loginAs('ADMIN');
    const items = await linkRequestsService.list();
    expect(byKind(items, 'REVIEW')).toHaveLength(3);
    expect(byKind(items, 'CORRECTION')).toHaveLength(2);
    for (const item of items) {
      expect(Object.keys(item).sort()).toEqual(['child', 'createdAt', 'id', 'kind', 'note', 'parentLinked', 'reason', 'student']);
      expect(Object.keys(item.student).sort()).toEqual(['classId', 'className', 'fullName', 'id']);
      expect(Object.keys(item.child)).toEqual(['name']);
      expect(item.student.fullName).toMatch(/\S+ \S+/);
      expect(item.student.className).toMatch(/^\d+-[A-Z]$/);
      expect(item.child.name).toBeTruthy();
      expect(typeof item.parentLinked).toBe('boolean');
    }
    expect(byKind(items, 'REVIEW').every((i) => i.note === null && i.reason === null)).toBe(true);
    expect(byKind(items, 'CORRECTION').every((i) => i.note && i.reason === 'WRONG_SCHOOL_OR_CLASS')).toBe(true);
    expect(byKind(items, 'REVIEW').some((i) => i.parentLinked)).toBe(true);
    expect(byKind(items, 'REVIEW').some((i) => !i.parentLinked)).toBe(true);
  });

  it('tartib: ENG ESKILARI BIRINCHI (navbat)', async () => {
    loginAs('ADMIN');
    const times = (await linkRequestsService.list()).map((i) => Date.parse(i.createdAt));
    expect(times).toEqual([...times].sort((a, b) => a - b));
  });

  it('REVIEW id\'si shaffof "<kod yozuvi>:<bola>", CORRECTION id\'si oddiy; bola ismi — ota-ona bergan ism', async () => {
    loginAs('ADMIN');
    const items = await linkRequestsService.list();
    for (const item of byKind(items, 'REVIEW')) expect(item.id).toMatch(/^[^:]+:[^:]+$/);
    for (const item of byKind(items, 'CORRECTION')) expect(item.id).not.toContain(':');
    // Seed: bittasida bola profilidagi ism o'quvchinikiga mos emas — xodim buni ko'rib qaror qiladi.
    const students = new Map(getTables().students.map((s) => [s.id, s]));
    const mismatched = items.filter((i) => i.child.name !== students.get(i.student.id)!.firstName);
    expect(mismatched).toHaveLength(1);
  });

  it('sinf rahbari: faqat o\'z sinfi (7-A); direktor hamma sinfni ko\'radi', async () => {
    loginAs('HOMEROOM');
    const own = await linkRequestsService.list();
    expect(own.length).toBeGreaterThan(0);
    expect(new Set(own.map((i) => i.student.className))).toEqual(new Set(['7-A']));
    loginAs('DIRECTOR');
    expect((await linkRequestsService.list()).length).toBe(5);
  });

  it('arxivdagi o\'quvchi so\'rovlari ko\'rsatilmaydi; bog\'lanishi boshqa yo\'l bilan uzilgan tuzatish so\'rovi ham', async () => {
    const review = await first('REVIEW');
    const correction = await first('CORRECTION');
    transact((t) => {
      t.students.find((s) => s.id === review.student.id)!.archived = true;
      t.access.linkedStudentIds = t.access.linkedStudentIds.filter((id) => id !== correction.student.id);
    });
    const ids = (await linkRequestsService.list()).map((i) => i.id);
    expect(ids).not.toContain(review.id);
    expect(ids).not.toContain(correction.id);
    expect(ids).toHaveLength(3);
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

  it('confirm → 200 { id, kind: REVIEW, status: CONFIRMED }: o\'quvchi bola profiliga ulanadi, so\'rov yopiladi, o\'quvchi o\'rni tasdiqlangan', async () => {
    loginAs('ADMIN');
    // Faol kodli so'rov (ota-ona o'rni hali bo'sh): kod yopiq emas — o'quvchi o'rni holati ko'rinadi.
    const request = byKind(await linkRequestsService.list(), 'REVIEW').find((r) => !r.parentLinked)!;
    expect(isLinked(request.student.id)).toBe(false);
    await expect(accessService.inviteCode(request.student.id)).resolves.toMatchObject({ student: { status: 'UNDER_REVIEW' } });
    await expect(accessService.credentials(request.student.id)).resolves.toEqual({ linked: false, credentials: null });

    await expect(linkRequestsService.confirm(request.id)).resolves.toEqual({ id: request.id, kind: 'REVIEW', status: 'CONFIRMED' });
    expect(isLinked(request.student.id)).toBe(true);
    await expect(accessService.credentials(request.student.id)).resolves.toEqual({ linked: true, credentials: null });
    expect((await linkRequestsService.list()).some((i) => i.id === request.id)).toBe(false);
    const invite = await accessService.inviteCode(request.student.id);
    expect(invite?.student.status).toBe('CONFIRMED');
  });

  it('reject → 200 { …, status: REJECTED }: o\'quvchi ulanmaydi, o\'quvchi o\'rni bo\'shaydi (bola qayta kirita oladi)', async () => {
    loginAs('ADMIN');
    const request = byKind(await linkRequestsService.list(), 'REVIEW').find((r) => !r.parentLinked)!;
    await expect(linkRequestsService.reject(request.id)).resolves.toEqual({ id: request.id, kind: 'REVIEW', status: 'REJECTED' });
    expect(isLinked(request.student.id)).toBe(false);
    const invite = await accessService.inviteCode(request.student.id);
    expect(invite?.student).toEqual({ status: 'FREE', usedAt: null });
    expect((await linkRequestsService.list()).some((i) => i.id === request.id)).toBe(false);
  });

  it('qarori xodim ko\'rgan so\'rovga bog\'lanadi: id o\'zgartirilmay beriladi; noma\'lum id — 404 NOT_FOUND', async () => {
    const request = await first('REVIEW');
    await expect(linkRequestsService.confirm(`${request.id}x`)).rejects.toMatchObject({ code: 'NOT_FOUND', detail: 'NOT_FOUND' });
    await expect(linkRequestsService.confirm('lnk-yoq')).rejects.toMatchObject({ code: 'NOT_FOUND', detail: 'NOT_FOUND' });
    expect(isLinked(request.student.id)).toBe(false);
  });

  it('idempotent: bir xil qaror takrori 200 (o\'zgarishsiz); qarama-qarshi qaror — 409 REQUEST_STALE', async () => {
    const request = await first('REVIEW');
    const done = await linkRequestsService.confirm(request.id);
    await expect(linkRequestsService.confirm(request.id)).resolves.toEqual(done);
    await expect(linkRequestsService.reject(request.id)).rejects.toMatchObject({ code: 'CONFLICT', detail: 'REQUEST_STALE' });
    expect(isLinked(request.student.id)).toBe(true);
  });

  it('rad etilgan REVIEW ro\'yxatdan chiqqan: qayta rad etish — 404, tasdiqlash — 409 REQUEST_STALE', async () => {
    const request = await first('REVIEW');
    await linkRequestsService.reject(request.id);
    await expect(linkRequestsService.reject(request.id)).rejects.toMatchObject({ code: 'NOT_FOUND', detail: 'NOT_FOUND' });
    await expect(linkRequestsService.confirm(request.id)).rejects.toMatchObject({ code: 'CONFLICT', detail: 'REQUEST_STALE' });
    expect(isLinked(request.student.id)).toBe(false);
  });

  it('o\'quvchi allaqachon ulangan bo\'lsa — tasdiqlash 409 STUDENT_LINKED_ELSEWHERE, so\'rov ochiq qoladi; xodim rad eta oladi', async () => {
    const request = await first('REVIEW');
    transact((t) => t.access.linkedStudentIds.push(request.student.id));
    await expect(linkRequestsService.confirm(request.id)).rejects.toMatchObject({ code: 'CONFLICT', detail: 'STUDENT_LINKED_ELSEWHERE' });
    expect((await linkRequestsService.list()).some((i) => i.id === request.id)).toBe(true);
    await expect(linkRequestsService.reject(request.id)).resolves.toMatchObject({ status: 'REJECTED' });
    expect((await linkRequestsService.list()).some((i) => i.id === request.id)).toBe(false);
  });

  it('arxivga olingan o\'quvchining so\'rovi — 409 REQUEST_STALE', async () => {
    const request = await first('REVIEW');
    transact((t) => {
      t.students.find((s) => s.id === request.student.id)!.archived = true;
    });
    await expect(linkRequestsService.confirm(request.id)).rejects.toMatchObject({ code: 'CONFLICT', detail: 'REQUEST_STALE' });
  });

  it('sinf rahbari: o\'z sinfini hal qiladi, boshqa sinfniki — FORBIDDEN (403)', async () => {
    loginAs('ADMIN');
    const all = byKind(await linkRequestsService.list(), 'REVIEW');
    const own = all.find((i) => i.student.className === '7-A')!;
    const foreign = all.find((i) => i.student.className !== '7-A')!;
    loginAs('HOMEROOM');
    await expect(linkRequestsService.confirm(foreign.id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(linkRequestsService.reject(foreign.id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await linkRequestsService.confirm(own.id);
    expect(isLinked(own.student.id)).toBe(true);
    // Qaror yo'q: faqat `guardians.link` egalari.
    loginAs('PSYCHOLOGIST');
    await expect(linkRequestsService.confirm(foreign.id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('hal bo\'lgan so\'rovning xodim bildirishnomasi o\'chadi (K2 §7)', async () => {
    loginAs('ADMIN');
    const [a, b] = byKind(await linkRequestsService.list(), 'REVIEW');
    expect(notificationIds()).toEqual(expect.arrayContaining([accessNotificationId('LINK_REVIEW', a!.id), accessNotificationId('LINK_REVIEW', b!.id)]));
    await linkRequestsService.confirm(a!.id);
    await linkRequestsService.reject(b!.id);
    expect(notificationIds()).not.toContain(accessNotificationId('LINK_REVIEW', a!.id));
    expect(notificationIds()).not.toContain(accessNotificationId('LINK_REVIEW', b!.id));
    // Boshqa so'rovlarniki o'z joyida.
    expect(notificationIds().filter((id) => id.startsWith('ntf-link-review-'))).toHaveLength(1);
  });

  it('audit (K2 §8): tasdiq — `student.childLinked`, rad — `student.linkRejected`; faqat ism, ikkala tilda', async () => {
    loginAs('ADMIN');
    const [a, b] = byKind(await linkRequestsService.list(), 'REVIEW');
    await linkRequestsService.confirm(a!.id);
    const confirmed = lastAudit();
    await linkRequestsService.reject(b!.id);
    const rejected = lastAudit();
    expect([confirmed.action, rejected.action]).toEqual(['student.childLinked', 'student.linkRejected']);
    expect([confirmed.module, rejected.module]).toEqual(['STUDENTS', 'STUDENTS']);
    expect(auditText(uz, confirmed)).toBe(`${a!.student.fullName.split(' ').slice(0, 2).join(' ')}: Parvoz bola ilovasi bog'landi`);
    expect(auditText(uz, rejected)).toBe(`${b!.student.fullName.split(' ').slice(0, 2).join(' ')}: bola ulanish soʻrovi rad etildi`);
    expect(auditText(ru, rejected)).toContain('запрос ребёнка на подключение отклонён');
    for (const e of [confirmed, rejected]) {
      expect(Object.keys(e.params ?? {})).toEqual(['name']);
      expect(e.before).toBeNull();
      expect(e.after).toBeNull();
    }
  });
});

describe('linkRequestsService: tuzatish (CORRECTION) — confirm = ulanishni SAQLASH, reject = ulanishni UZISH', () => {
  beforeEach(freshDb);

  it('confirm (saqlash) → { kind: CORRECTION, status: CONFIRMED }: ulanish o\'zgarmaydi, so\'rov yopiladi, audit `student.linkCorrectionKept`', async () => {
    const request = await first('CORRECTION');
    expect(isLinked(request.student.id)).toBe(true);
    await expect(linkRequestsService.confirm(request.id)).resolves.toEqual({ id: request.id, kind: 'CORRECTION', status: 'CONFIRMED' });
    expect(isLinked(request.student.id)).toBe(true);
    expect((await linkRequestsService.list()).some((i) => i.id === request.id)).toBe(false);
    expect(lastAudit()).toMatchObject({ action: 'student.linkCorrectionKept', module: 'STUDENTS' });
    expect(auditText(uz, lastAudit())).toMatch(/bola soʻrovi koʻrib chiqildi, ulanish saqlandi$/);
    expect(auditText(ru, lastAudit())).toMatch(/запрос ребёнка рассмотрен, подключение сохранено$/);
  });

  it('reject (uzish) → { kind: CORRECTION, status: REJECTED }: o\'quvchi bola profilidan ajraladi, kirish ma\'lumoti berilmaydi, audit `student.childUnlinked`', async () => {
    const request = await first('CORRECTION');
    await expect(linkRequestsService.reject(request.id)).resolves.toEqual({ id: request.id, kind: 'CORRECTION', status: 'REJECTED' });
    expect(isLinked(request.student.id)).toBe(false);
    await expect(accessService.issueCredentials(request.student.id)).rejects.toMatchObject({ code: 'CONFLICT', detail: 'NOT_LINKED' });
    expect(lastAudit()).toMatchObject({ action: 'student.childUnlinked', module: 'STUDENTS' });
    expect(auditText(uz, lastAudit())).toMatch(/Parvoz bola ilovasi uzildi$/);
    expect(auditText(ru, lastAudit())).toMatch(/детское приложение Parvoz отключено$/);
  });

  it('uzishda bolaning kod o\'rinlari bo\'shaydi (qayta kiritish mumkin)', async () => {
    const request = await first('CORRECTION');
    transact((t) => {
      t.access.inviteCodes.push({
        id: 'inv-test',
        studentId: request.student.id,
        code: '012345',
        createdAt: '2026-10-12T05:00:00',
        expiresAt: '2026-10-13T05:00:00',
        studentUsedAt: '2026-10-12T05:10:00',
        studentConfirmedAt: '2026-10-12T05:20:00',
        parentUsedAt: null,
        closedAt: null,
        createdByStaffId: 'stf-admin',
      });
    });
    await expect(accessService.inviteCode(request.student.id)).resolves.toMatchObject({ student: { status: 'CONFIRMED' } });
    await linkRequestsService.reject(request.id);
    await expect(accessService.inviteCode(request.student.id)).resolves.toMatchObject({ student: { status: 'FREE', usedAt: null } });
  });

  it('idempotent: bir xil qaror takrori 200; qarama-qarshi qaror — 409 REQUEST_STALE (ikkala yo\'nalishda)', async () => {
    const keep = await first('CORRECTION');
    const kept = await linkRequestsService.confirm(keep.id);
    await expect(linkRequestsService.confirm(keep.id)).resolves.toEqual(kept);
    await expect(linkRequestsService.reject(keep.id)).rejects.toMatchObject({ code: 'CONFLICT', detail: 'REQUEST_STALE' });
    expect(isLinked(keep.student.id)).toBe(true);

    const unlink = await first('CORRECTION');
    expect(unlink.id).not.toBe(keep.id);
    const unlinked = await linkRequestsService.reject(unlink.id);
    await expect(linkRequestsService.reject(unlink.id)).resolves.toEqual(unlinked);
    await expect(linkRequestsService.confirm(unlink.id)).rejects.toMatchObject({ code: 'CONFLICT', detail: 'REQUEST_STALE' });
    expect(isLinked(unlink.student.id)).toBe(false);
  });

  it('hal bo\'lgan tuzatish so\'rovining bildirishnomasi o\'chadi', async () => {
    const request = await first('CORRECTION');
    expect(notificationIds()).toContain(accessNotificationId('LINK_CORRECTION', request.id));
    await linkRequestsService.confirm(request.id);
    expect(notificationIds()).not.toContain(accessNotificationId('LINK_CORRECTION', request.id));
  });

  it('sinf rahbari faqat o\'z sinfini hal qiladi', async () => {
    loginAs('ADMIN');
    const all = byKind(await linkRequestsService.list(), 'CORRECTION');
    const own = all.find((i) => i.student.className === '7-A')!;
    const foreign = all.find((i) => i.student.className !== '7-A')!;
    loginAs('HOMEROOM');
    await expect(linkRequestsService.reject(foreign.id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(linkRequestsService.confirm(own.id)).resolves.toMatchObject({ status: 'CONFIRMED' });
  });
});
