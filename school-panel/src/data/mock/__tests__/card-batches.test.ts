import { beforeEach, describe, expect, it } from 'vitest';

import { importRowsFromCsv } from '@/features/cards/batch-csv';
import { isValidCardNumber } from '@/lib/card-number';
import { __setClockForTests } from '../clock';
import { setLatencyEnabled } from '../context';
import { __resetForTests, getDb, getTables } from '../db';
import { cardBatchService } from '../services/card-batches';
import { loginAs } from './helpers';

function fresh(): void {
  setLatencyEnabled(false);
  __resetForTests();
  __setClockForTests({ mode: 'SCENARIO', scenarioDate: '2026-10-12', scenarioStartMinute: 9 * 60, realStartedAt: Date.now(), speed: 1 });
  getDb();
}

/** Sinfdagi bir nechta o'quvchining faol kartasini olib tashlash (yangi kelganlar kabi). */
function withoutCards(classId: string, count: number): string[] {
  const t = getTables();
  const ids = t.students.filter((s) => !s.archived && s.classId === classId).slice(0, count).map((s) => s.id);
  t.cards = t.cards.filter((c) => !ids.includes(c.studentId));
  return ids;
}

describe('karta partiyasi (demo)', () => {
  beforeEach(fresh);

  it('raqam faqat kartasizlarga, qayta berilmaydi; ketma-ket bog\'lash raqamni saqlaydi', async () => {
    loginAs('DIRECTOR');
    const classId = getTables().classes[0]!.id;
    const ids = withoutCards(classId, 3);

    const first = await cardBatchService.reserve({ classIds: [classId] });
    expect(first.created).toBe(3);
    expect(first.items.map((i) => i.studentId).sort()).toEqual([...ids].sort());
    expect(first.items.every((i) => isValidCardNumber(i.number))).toBe(true);
    expect((await cardBatchService.reserve({ classIds: [classId] })).created).toBe(0);

    const target = first.items[0]!;
    const card = await cardBatchService.bind(target.id, { uid: '0012345678' });
    expect(card).toMatchObject({ number: target.number, uid: '00BC614E', studentId: target.studentId, status: 'ACTIVE' });
    expect((await cardBatchService.list()).map((i) => i.id)).not.toContain(target.id);

    // Band karta — rad, raqam navbatda qoladi.
    const other = first.items[1]!;
    await expect(cardBatchService.bind(other.id, { uid: '0012345678' })).rejects.toMatchObject({ detail: 'CARD_TAKEN' });
    expect((await cardBatchService.list()).map((i) => i.id)).toContain(other.id);
  });

  it('ta\'minotchi fayli: qatorma-qator natija', async () => {
    loginAs('DIRECTOR');
    const classId = getTables().classes[0]!.id;
    withoutCards(classId, 2);
    const { items } = await cardBatchService.reserve({ classIds: [classId] });
    const summary = await cardBatchService.importBindings({
      rows: [
        { number: `${items[0]!.number.slice(0, 5)} ${items[0]!.number.slice(5)}`, uid: '04:AA:BB:CC:DD:EE:01' },
        { number: '1000000000', uid: '04AABBCCDDEE02' },
        { number: items[1]!.number, uid: 'salom' },
      ],
    });
    expect(summary).toEqual({
      bound: 1,
      results: [
        { number: items[0]!.number, ok: true, code: null },
        { number: '1000000000', ok: false, code: 'RESERVATION_NOT_FOUND' },
        { number: items[1]!.number, ok: false, code: 'INVALID_UID' },
      ],
    });
  });

  it('faqat students.manage', async () => {
    loginAs('DUTY');
    await expect(cardBatchService.list()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('ta\'minotchi fayli (CSV)', () => {
  it('sarlavha nomidan ustunlar, o\'nlik UID hex\'ga, bo\'sh qatorlar tashlanadi', () => {
    expect(
      importRowsFromCsv([
        ['UID', 'Karta raqami'],
        ['0012345678', '48210 93753'],
        ['', ''],
        ['04:a1:b2:c3:d4:e5:f6', '1234567890'],
      ]),
    ).toEqual([
      { number: '4821093753', uid: '00BC614E' },
      { number: '1234567890', uid: '04A1B2C3D4E5F6' },
    ]);
  });

  it('sarlavhasiz: 1-ustun raqam, 2-ustun UID; noma\'lum sarlavha tashlanadi', () => {
    expect(importRowsFromCsv([['4821093753', 'A1B2C3D4']])).toEqual([{ number: '4821093753', uid: 'A1B2C3D4' }]);
    expect(importRowsFromCsv([['No', 'Code'], ['4821093753', 'A1B2C3D4']])).toEqual([{ number: '4821093753', uid: 'A1B2C3D4' }]);
    expect(importRowsFromCsv([])).toEqual([]);
  });
});
