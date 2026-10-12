import { describe, expect, it } from 'vitest';

import type { AttendanceEvent } from '@/data/contracts';
import { SINGLE_MAX, summarizeArrivals, visibleEvents } from '@/features/engine/arrivals';

function event(id: string, classId: string, kind: AttendanceEvent['kind'] = 'IN', late = false): AttendanceEvent {
  return { id, at: '2026-10-12T08:01:00', studentId: `stu-${id}`, classId, kind, source: 'QR', late };
}

const EVENTS: AttendanceEvent[] = [
  event('1', 'cls-7a'),
  event('2', 'cls-7a', 'IN', true),
  event('3', 'cls-8b'),
  event('4', 'cls-7a', 'OUT'),
];

describe('kelish toast\'lari: kim nimani ko\'radi', () => {
  it('maktab doirasidagi rol — barcha kelishlar, chiqishlarsiz', () => {
    expect(visibleEvents(EVENTS, { role: 'DUTY', classIds: [] }).map((e) => e.id)).toEqual(['1', '2', '3']);
    expect(visibleEvents(EVENTS, { role: 'DIRECTOR', classIds: [] })).toHaveLength(3);
  });

  it('sinf rahbari — faqat o\'z sinfi', () => {
    expect(visibleEvents(EVENTS, { role: 'HOMEROOM', classIds: ['cls-7a'] }).map((e) => e.id)).toEqual(['1', '2']);
  });

  it('psixolog — hech narsa (davomat ruxsati yo\'q)', () => {
    expect(visibleEvents(EVENTS, { role: 'PSYCHOLOGIST', classIds: [] })).toEqual([]);
  });
});

describe('kelishlarni umumlashtirish', () => {
  it('bo\'sh — NONE', () => {
    expect(summarizeArrivals([])).toEqual({ kind: 'NONE' });
  });

  it(`${SINGLE_MAX} tagacha — SINGLE (ismli toast)`, () => {
    const one = summarizeArrivals([event('1', 'cls-7a')]);
    expect(one.kind).toBe('SINGLE');
    const two = summarizeArrivals([event('1', 'cls-7a'), event('2', 'cls-7a')]);
    expect(two.kind === 'SINGLE' && two.events).toHaveLength(2);
  });

  it('ko\'p — BATCH: soni va kechikkanlar', () => {
    const batch = summarizeArrivals([event('1', 'a'), event('2', 'a', 'IN', true), event('3', 'b', 'IN', true), event('4', 'b')]);
    expect(batch).toEqual({ kind: 'BATCH', count: 4, late: 2 });
  });
});
