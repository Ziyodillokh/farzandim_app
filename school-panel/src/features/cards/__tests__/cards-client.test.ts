import { describe, expect, it } from 'vitest';

import { ServiceError } from '@/data/contracts';
import { normalizeCardUid } from '@/data/schemas/cards';
import { outcomeFromTap, toneFor } from '@/features/attendance/components/kiosk/kiosk-card';
import { cardReadFrom, createRepeatFilter } from '../nfc';
import { enqueueTap, kioskId, loadQueue, saveQueue } from '../tap-queue';
import { flushQueue, isRetryable } from '../use-tap-queue';

const encode = (text: string) => new DataView(new TextEncoder().encode(text).buffer);
const SUN_URL = 'https://farzandimedu.uz/k/?p=EF963FF7828658A599F3041510671E88&c=94EED9EE65337086';

describe('Web NFC o\'qish', () => {
  it('seriya raqami va birinchi URL yozuvi olinadi', () => {
    expect(cardReadFrom('04:de:5f:1e:ac:c0:40', [{ recordType: 'text', data: encode('salom') }, { recordType: 'url', data: encode(SUN_URL) }])).toEqual({
      uid: '04:de:5f:1e:ac:c0:40',
      url: SUN_URL,
    });
    expect(cardReadFrom('04:11:22:33', [])).toEqual({ uid: '04:11:22:33' });
    expect(cardReadFrom('', [{ recordType: 'absolute-url', data: encode(SUN_URL) }])).toEqual({ url: SUN_URL });
  });

  it('karta ushlab turilsa 2,5 soniya ichida qayta hisoblanmaydi, boshqa karta — darhol', () => {
    const fresh = createRepeatFilter();
    expect(fresh({ uid: 'A' }, 1_000)).toBe(true);
    expect(fresh({ uid: 'A' }, 2_000)).toBe(false);
    expect(fresh({ uid: 'B' }, 2_100)).toBe(true);
    expect(fresh({ uid: 'A' }, 2_200)).toBe(true);
    expect(fresh({ uid: 'A' }, 5_000)).toBe(true);
  });

  it('UID ko\'rinishlari', () => {
    expect(normalizeCardUid('04:de:5f:1e:ac:c0:40')).toBe('04DE5F1EACC040');
    expect(normalizeCardUid('04 DE 5F 1E')).toBe('04DE5F1E');
    expect(normalizeCardUid('04:de')).toBeNull();
    expect(normalizeCardUid('salom!')).toBeNull();
  });
});

describe('kiosk natijasi', () => {
  const student = { id: 's1', firstName: 'Vali', lastName: 'Aliyev', studentCode: 'P-1001' };
  const base = { time: '07:52', suspicious: false, cardNumber: 'K-000001', student, className: '7-A', status: 'PRESENT' as const };

  it('kirdi, takror, chiqdi va rad etilgan natijalar', () => {
    expect(outcomeFromTap({ ...base, result: 'IN' })).toEqual({ kind: 'success', name: 'Aliyev Vali', className: '7-A', status: 'PRESENT', time: '07:52', already: false, suspicious: false });
    expect(outcomeFromTap({ ...base, result: 'NONE' })).toMatchObject({ kind: 'success', already: true });
    expect(outcomeFromTap({ ...base, result: 'OUT' })).toEqual({ kind: 'left', name: 'Aliyev Vali', className: '7-A', time: '07:52' });
    expect(outcomeFromTap({ ...base, result: 'BLOCKED' })).toEqual({ kind: 'card', result: 'BLOCKED', name: 'Aliyev Vali' });
    expect(outcomeFromTap({ ...base, student: null, status: null, result: 'UNKNOWN' })).toEqual({ kind: 'card', result: 'UNKNOWN', name: null });
  });

  it('ovoz: kirdi — ok, shubhali yoki navbatda — ogohlantirish, rad — xato', () => {
    expect(toneFor(outcomeFromTap({ ...base, result: 'IN' }))).toBe('ok');
    expect(toneFor(outcomeFromTap({ ...base, result: 'IN', suspicious: true }))).toBe('warn');
    expect(toneFor({ kind: 'queued' })).toBe('warn');
    expect(toneFor(outcomeFromTap({ ...base, result: 'INVALID' }))).toBe('fail');
  });
});

describe('oflayn navbat', () => {
  const tap = (n: number) => ({ uid: `04:00:00:0${n}`, kioskId: 'k1', tappedAt: `2026-10-12T07:5${n}:00.000Z` });

  it('tarmoq xatosida to\'xtaydi, boshqa xatoda o\'sha tegish tashlanadi, muvaffaqiyatda o\'chadi', async () => {
    saveQueue([]);
    enqueueTap(tap(1));
    enqueueTap(tap(2));
    enqueueTap(tap(3));
    const sent: string[] = [];
    const rest = await flushQueue(async (t) => {
      sent.push(t.uid ?? '');
      if (t.uid === '04:00:00:02') throw new ServiceError('VALIDATION', 'tappedAt: errors.form.invalidDate');
      if (t.uid === '04:00:00:03') throw new ServiceError('UNKNOWN', 'network');
    });

    expect(sent).toEqual(['04:00:00:01', '04:00:00:02', '04:00:00:03']);
    expect(rest.map((t) => t.uid)).toEqual(['04:00:00:03']);
    expect(loadQueue()).toEqual(rest);
    expect(isRetryable(new ServiceError('UNKNOWN', 'network'))).toBe(true);
    expect(isRetryable(new ServiceError('FORBIDDEN', 'x'))).toBe(false);
  });

  it('kiosk belgisi bir xil qoladi', () => {
    expect(kioskId()).toBe(kioskId());
  });
});
