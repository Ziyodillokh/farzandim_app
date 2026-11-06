import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ServiceError } from '@/data/contracts';
import { setAccessToken, setRefreshHandler, setSessionLostHandler } from '@/data/http/client';
import { linkRequestsHttp } from '@/data/http/services/access';
import { getTables } from '@/data/mock/db';
import { freshDb, loginAs } from '@/data/mock/__tests__/helpers';
import { linkRequestsService } from '@/data/mock/services/link-requests';
import { type TKey, translate } from '@/i18n/translate';
import { DECISION_ORDER, decisionErrorKey, LINK_ACTIONS, type LinkDecision, runDecision, toastKeyFor } from '../lib/decisions';

const uz = (key: TKey) => translate('uz', key);
const ru = (key: TKey) => translate('ru', key);
const KINDS = ['REVIEW', 'CORRECTION'] as const;
const DECISIONS: readonly LinkDecision[] = ['confirm', 'reject'];

describe('LINK_ACTIONS: tugma → endpoint (K2 §5)', () => {
  it('har bir (tur, qaror) yozuvi o\'z qarorini ko\'taradi; ikkala tur uchun ikki tugma, tartib: avval rad/uzish, keyin tasdiq/saqlash', () => {
    for (const kind of KINDS) {
      for (const decision of DECISIONS) expect(LINK_ACTIONS[kind][decision].decision).toBe(decision);
    }
    expect(DECISION_ORDER).toEqual(['reject', 'confirm']);
  });

  it('REVIEW: «Tasdiqlash» = confirm, «Rad etish» = reject', () => {
    expect(uz(LINK_ACTIONS.REVIEW.confirm.label)).toBe('Tasdiqlash');
    expect(uz(LINK_ACTIONS.REVIEW.reject.label)).toBe('Rad etish');
    expect(LINK_ACTIONS.REVIEW.confirm.decision).toBe('confirm');
    expect(LINK_ACTIONS.REVIEW.reject.decision).toBe('reject');
  });

  it('CORRECTION: «Ulanishni saqlash» = confirm (ulanish SAQLANADI), «Ulanishni uzish» = reject (ulanish UZILADI) — ikkala tilda', () => {
    const keep = LINK_ACTIONS.CORRECTION.confirm;
    const unlink = LINK_ACTIONS.CORRECTION.reject;
    expect([uz(keep.label), uz(unlink.label)]).toEqual(['Ulanishni saqlash', 'Ulanishni uzish']);
    expect([ru(keep.label), ru(unlink.label)]).toEqual(['Оставить подключение', 'Отключить']);
    expect([keep.decision, unlink.decision]).toEqual(['confirm', 'reject']);
    expect([keep.destructive, unlink.destructive]).toEqual([false, true]);
  });

  it('GUARDIAN: «Vasiy sifatida tasdiqlash» = confirm, «Rad etish» = reject; oyna matnida ota-ona va o\'quvchi', () => {
    const ok = LINK_ACTIONS.GUARDIAN.confirm;
    const no = LINK_ACTIONS.GUARDIAN.reject;
    expect([uz(ok.label), uz(no.label)]).toEqual(['Vasiy sifatida tasdiqlash', 'Rad etish']);
    expect([ok.decision, no.decision]).toEqual(['confirm', 'reject']);
    expect([ok.destructive, no.destructive]).toEqual([false, true]);
    for (const decision of DECISIONS) {
      for (const render of [uz, ru]) {
        const text = render(LINK_ACTIONS.GUARDIAN[decision].dialog.text);
        for (const variable of ['{parent}', '{name}', '{className}']) expect(text, decision).toContain(variable);
      }
    }
    expect(toastKeyFor({ id: 'g', kind: 'GUARDIAN', status: 'CONFIRMED' })).toBe('linkRequests.toast.guardianConfirmed');
    expect(toastKeyFor({ id: 'g', kind: 'GUARDIAN', status: 'REJECTED' })).toBe('linkRequests.toast.guardianRejected');
  });

  it('tasdiq oynasi matnlari ikkala tilda kerakli o\'zgaruvchilarni ishlatadi ({name}, {className}, {child})', () => {
    for (const kind of KINDS) {
      for (const decision of DECISIONS) {
        const { dialog } = LINK_ACTIONS[kind][decision];
        for (const render of [uz, ru]) {
          const text = render(dialog.text);
          for (const variable of ['{name}', '{className}', '{child}']) expect(text, `${kind}.${decision}`).toContain(variable);
          expect(render(dialog.title)).not.toBe(dialog.title);
        }
      }
    }
  });
});

describe('toastKeyFor: xabar backend NATIJASIga (kind + status) qarab', () => {
  it('REVIEW: tasdiqlandi / rad etildi; CORRECTION: saqlandi / uzildi', () => {
    expect(toastKeyFor({ id: 'a', kind: 'REVIEW', status: 'CONFIRMED' })).toBe('linkRequests.toast.confirmed');
    expect(toastKeyFor({ id: 'a', kind: 'REVIEW', status: 'REJECTED' })).toBe('linkRequests.toast.rejected');
    expect(toastKeyFor({ id: 'a', kind: 'CORRECTION', status: 'CONFIRMED' })).toBe('linkRequests.toast.kept');
    expect(toastKeyFor({ id: 'a', kind: 'CORRECTION', status: 'REJECTED' })).toBe('linkRequests.toast.unlinked');
    expect(uz('linkRequests.toast.kept')).toBe('Ulanish saqlandi');
    expect(uz('linkRequests.toast.unlinked')).toBe('Ulanish uzildi');
  });
});

describe('decisionErrorKey: K2 §5 xatolari uchun aniq matn (uz + ru)', () => {
  it.each([
    ['REQUEST_STALE', 'CONFLICT', 'errors.detail.REQUEST_STALE'],
    ['STUDENT_LINKED_ELSEWHERE', 'CONFLICT', 'errors.detail.STUDENT_LINKED_ELSEWHERE'],
    ['ALREADY_ENROLLED', 'CONFLICT', 'errors.detail.ALREADY_ENROLLED'],
  ] as const)('409 %s', (detail, code, expected) => {
    const key = decisionErrorKey(new ServiceError(code, 'x', detail));
    expect(key).toBe(expected);
    expect(uz(key)).not.toBe(key);
    expect(ru(key)).toMatch(/[А-Яа-я]/);
    expect(uz(key)).not.toMatch(/[А-Яа-я]/);
  });

  it('404 — so\'rov yo\'q (boshqa xodim hal qilgan): "Ma\'lumot topilmadi" emas, ro\'yxat yangilanishi haqida', () => {
    const key = decisionErrorKey(new ServiceError('NOT_FOUND', 'Link request not found', 'NOT_FOUND'));
    expect(key).toBe('linkRequests.errors.gone');
    expect(uz(key)).toContain('Roʻyxat yangilandi');
    expect(ru(key)).toContain('Список обновлён');
  });

  it('403 va noma\'lum xato — umumiy matn', () => {
    expect(decisionErrorKey(new ServiceError('FORBIDDEN', 'class c1', 'FORBIDDEN'))).toBe('errors.FORBIDDEN');
    expect(decisionErrorKey(new Error('boom'))).toBe('errors.UNKNOWN');
  });
});

describe('tugma → servis: mock', () => {
  beforeEach(() => {
    freshDb();
    loginAs('ADMIN');
  });

  async function openCorrection() {
    const request = (await linkRequestsService.list()).find((r) => r.kind === 'CORRECTION')!;
    return request;
  }

  it('«Ulanishni saqlash» tugmasi → ulanish SAQLANADI', async () => {
    const request = await openCorrection();
    const result = await runDecision(linkRequestsService, request.id, LINK_ACTIONS.CORRECTION.confirm.decision);
    expect(result).toEqual({ id: request.id, kind: 'CORRECTION', status: 'CONFIRMED' });
    expect(getTables().access.linkedStudentIds).toContain(request.student.id);
  });

  it('«Ulanishni uzish» tugmasi → ulanish UZILADI', async () => {
    const request = await openCorrection();
    const result = await runDecision(linkRequestsService, request.id, LINK_ACTIONS.CORRECTION.reject.decision);
    expect(result).toEqual({ id: request.id, kind: 'CORRECTION', status: 'REJECTED' });
    expect(getTables().access.linkedStudentIds).not.toContain(request.student.id);
  });
});

describe('tugma → servis: http (POST /school/link-requests/:id/(confirm|reject))', () => {
  const calls: Array<{ url: string; method: string }> = [];

  beforeEach(() => {
    calls.length = 0;
    setAccessToken('t1');
    setRefreshHandler(async () => false);
    setSessionLostHandler(null);
    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string, init: RequestInit) => {
        calls.push({ url, method: String(init.method) });
        const kind = url.includes('9b8f') ? 'CORRECTION' : 'REVIEW';
        const status = url.endsWith('/confirm') ? 'CONFIRMED' : 'REJECTED';
        return new Response(JSON.stringify({ id: '9b8f', kind, status }), { status: 200 });
      }),
    );
  });
  afterEach(() => vi.unstubAllGlobals());

  it('CORRECTION: «saqlash» → …/confirm, «uzish» → …/reject', async () => {
    await expect(runDecision(linkRequestsHttp, '9b8f', LINK_ACTIONS.CORRECTION.confirm.decision)).resolves.toMatchObject({ kind: 'CORRECTION', status: 'CONFIRMED' });
    await expect(runDecision(linkRequestsHttp, '9b8f', LINK_ACTIONS.CORRECTION.reject.decision)).resolves.toMatchObject({ kind: 'CORRECTION', status: 'REJECTED' });
    expect(calls.map((c) => [c.method, c.url])).toEqual([
      ['POST', '/api/school/link-requests/9b8f/confirm'],
      ['POST', '/api/school/link-requests/9b8f/reject'],
    ]);
  });

  it('REVIEW: «tasdiqlash» → …/confirm, «rad etish» → …/reject; id URL-kodlanadi', async () => {
    await runDecision(linkRequestsHttp, 'inv-1:chd-1', LINK_ACTIONS.REVIEW.confirm.decision);
    await runDecision(linkRequestsHttp, 'inv-1:chd-1', LINK_ACTIONS.REVIEW.reject.decision);
    expect(calls.map((c) => c.url)).toEqual(['/api/school/link-requests/inv-1%3Achd-1/confirm', '/api/school/link-requests/inv-1%3Achd-1/reject']);
  });
});
