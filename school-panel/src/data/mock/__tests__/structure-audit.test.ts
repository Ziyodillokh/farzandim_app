import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import type { AuditLog } from '@/data/contracts';
import { auditShape, diffValues } from '@/features/audit/diff';
import { getTables, transact } from '../db';
import { classesService } from '../services/classes';
import { auditService, staffService } from '../services/staff';
import { freshDb, loginAs } from './helpers';

describe('audit jurnali', () => {
  beforeEach(freshDb);

  it('modul, xodim va sana bo\'yicha filtr; eksport hammasini qaytaradi', async () => {
    loginAs('DIRECTOR');
    await classesService.create({ grade: 4, letter: 'V', shiftId: 'shf-2' });
    const byModule = await auditService.list({ module: 'CLASSES' });
    expect(byModule.items.every((a) => a.module === 'CLASSES')).toBe(true);
    expect(byModule.items[0]?.action).toBe('class.create');
    const byActor = await auditService.list({ actorId: 'stf-homeroom-7a', limit: 100 });
    expect(byActor.items.length).toBeGreaterThan(0);
    expect(byActor.items.every((a) => a.actorId === 'stf-homeroom-7a')).toBe(true);
    const future = await auditService.list({ from: '2999-01-01' });
    expect(future.pagination.total).toBe(0);
    const all = await auditService.exportRows({});
    expect(all.length).toBe(getTables().audit.length);
    expect((await auditService.actors()).length).toBeGreaterThan(1);
  });

  it('sinf rahbari audit jurnalini ko\'rmaydi', async () => {
    loginAs('HOMEROOM');
    await expect(auditService.list()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('audit farqi (oldin/keyin)', () => {
  it('o\'zgargan, qo\'shilgan va o\'zgarmagan maydonlarni ajratadi', () => {
    const rows = diffValues({ name: '7-A', room: '207', meta: { a: 1 } }, { name: '7-A', room: '208', meta: { a: 2 }, extra: true });
    const byField = Object.fromEntries(rows.map((r) => [r.field, r.kind]));
    expect(byField).toEqual({ name: 'same', room: 'changed', 'meta.a': 'changed', extra: 'added' });
  });

  it('yaratish/o\'chirish/tafsilotsiz yozuvni aniqlaydi', () => {
    expect(auditShape(null, { a: 1 })).toBe('create');
    expect(auditShape({ a: 1 }, null)).toBe('delete');
    expect(auditShape({ a: 1 }, { a: 2 })).toBe('update');
    expect(auditShape(null, null)).toBe('none');
    expect(diffValues({ a: 1 }, null)).toEqual([{ field: 'a', before: 1, after: undefined, kind: 'removed' }]);
    expect(diffValues(null, 'x')).toEqual([{ field: 'value', before: undefined, after: 'x', kind: 'added' }]);
  });

  it('haqiqiy servis yozuvi o\'qiladigan farq beradi', async () => {
    freshDb();
    loginAs('DIRECTOR');
    await staffService.setActive('stf-t-2', false);
    const entry = getTables().audit.at(-1);
    expect(diffValues(entry?.before, entry?.after)).toEqual([{ field: 'active', before: true, after: false, kind: 'changed' }]);
  });
});

const auditRow = (id: string, at: string, patch: Partial<AuditLog> = {}): AuditLog => ({
  id,
  at,
  actorId: 'stf-admin',
  actorName: 'Toshmatov Sardor Akmalovich',
  module: 'SETTINGS',
  action: 'test.row',
  entityId: null,
  summary: id,
  before: null,
  after: null,
  ...patch,
});

describe('audit: aralash vaqt formatlari (mahalliy va UTC)', () => {
  // UTC+5: UTC satri va mahalliy satr tartibi farq qiladigan zona.
  const originalTz = process.env.TZ;
  beforeAll(() => {
    process.env.TZ = 'Asia/Tashkent';
  });
  afterAll(() => {
    process.env.TZ = originalTz;
  });
  beforeEach(freshDb);

  it('haqiqiy vaqt bo\'yicha saralaydi (satr bo\'yicha emas)', async () => {
    // Mahalliy 20:00 va UTC'da yozilgan mahalliy 22:00 (= "17:00Z") — keyingisi yangiroq.
    const later = new Date(2030, 0, 1, 22, 0, 0).toISOString();
    transact((t) => {
      t.audit.push(auditRow('aud-local-20', '2030-01-01T20:00:00'), auditRow('aud-utc-22', later));
    });
    loginAs('DIRECTOR');
    const page = await auditService.list({ module: 'SETTINGS', limit: 2 });
    expect(page.items.map((a) => a.id)).toEqual(['aud-utc-22', 'aud-local-20']);
    const asc = await auditService.list({ module: 'SETTINGS', sortBy: 'at', sortDir: 'asc', limit: 500 });
    expect(asc.items.at(-1)?.id).toBe('aud-utc-22');
  });

  it('sana filtri mahalliy kalendar sanasi bo\'yicha ishlaydi', async () => {
    // Mahalliy 1-yanvar 02:00 → UTC'da hali 31-dekabr.
    const earlyUtc = new Date(2030, 0, 1, 2, 0, 0).toISOString();
    expect(earlyUtc.startsWith('2029-12-31')).toBe(true);
    transact((t) => {
      t.audit.push(auditRow('aud-early', earlyUtc), auditRow('aud-local', '2030-01-01T23:59:00'), auditRow('aud-next', '2030-01-02T00:00:00'));
    });
    loginAs('ADMIN');
    const day = await auditService.list({ from: '2030-01-01', to: '2030-01-01', limit: 500 });
    expect(day.items.map((a) => a.id).sort()).toEqual(['aud-early', 'aud-local']);
    const before = await auditService.list({ to: '2029-12-31', limit: 500 });
    expect(before.items.some((a) => a.id === 'aud-early')).toBe(false);
  });
});

describe('audit: Bola ovozi yozuvlari yashirin', () => {
  beforeEach(freshDb);

  it('direktor va admin CARE yozuvlarini ro\'yxat, xodimlar va eksportda ko\'rmaydi', async () => {
    transact((t) => {
      t.audit.push(
        auditRow('aud-care', '2030-01-01T10:00:00', { module: 'CARE', actorId: 'stf-care-only', actorName: 'Faqat Care', summary: 'Murojaat yopildi' }),
      );
    });
    for (const role of ['DIRECTOR', 'ADMIN'] as const) {
      loginAs(role);
      const all = await auditService.list({ limit: 500 });
      expect(all.items.some((a) => a.module === 'CARE')).toBe(false);
      expect((await auditService.list({ module: 'CARE' })).pagination.total).toBe(0);
      expect((await auditService.list({ search: 'Murojaat yopildi' })).pagination.total).toBe(0);
      expect((await auditService.exportRows({})).some((a) => a.module === 'CARE')).toBe(false);
      expect((await auditService.actors()).some((a) => a.id === 'stf-care-only')).toBe(false);
    }
  });
});
