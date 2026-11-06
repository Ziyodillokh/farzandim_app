import { beforeEach, describe, expect, it } from 'vitest';

import { createFreshSnapshot, getTables, migrate } from '../db';
import { freshDb } from './helpers';

const ANCHOR = new Date(2026, 9, 12, 10);

describe('kirish demo ma\'lumotlari (seed)', () => {
  beforeEach(freshDb);

  it('ulangan o\'quvchilar, kirish ma\'lumotlari, tekshiruv kutayotganlar, tuzatish va tiklash so\'rovlari bor', () => {
    const { access, students } = getTables();
    expect(access.linkedStudentIds.length).toBeGreaterThan(50);
    expect(access.credentials.length).toBeGreaterThan(20);
    const open = access.linkRequests.filter((r) => r.status === 'OPEN');
    expect(open.filter((r) => r.kind === 'REVIEW')).toHaveLength(3);
    expect(open.filter((r) => r.kind === 'CORRECTION')).toHaveLength(2);
    expect(access.recoveryRequests.filter((r) => r.status === 'RECEIVED')).toHaveLength(2);
    const classOf = (id: string) => students.find((s) => s.id === id)?.classId;
    expect(open.filter((r) => classOf(r.studentId) === 'cls-7a').map((r) => r.kind).sort()).toEqual(['CORRECTION', 'REVIEW', 'REVIEW']);
  });

  it('tekshiruv kutayotgan o\'quvchi hali ulanmagan, tuzatish so\'rovi esa ulanganniki; kodda o\'quvchi o\'rni ishlatilgan', () => {
    const { access } = getTables();
    const linked = new Set(access.linkedStudentIds);
    for (const r of access.linkRequests.filter((x) => x.kind === 'REVIEW')) {
      expect(linked.has(r.studentId)).toBe(false);
      const code = access.inviteCodes.find((c) => c.studentId === r.studentId);
      expect(code?.studentUsedAt).toBe(r.createdAt);
      expect(Boolean(code?.parentUsedAt)).toBe(r.parentUsed);
      // Ikkala o'rin ishlatilgan kod yopiq (kontrakt K2), aks holda faol.
      expect(code?.closedAt !== null).toBe(r.parentUsed);
    }
    for (const r of access.linkRequests.filter((x) => x.kind === 'CORRECTION')) {
      expect(linked.has(r.studentId)).toBe(true);
      expect(r.reason).toBe('WRONG_SCHOOL_OR_CLASS');
      expect(r.note).toBeTruthy();
    }
  });

  it('kirish ma\'lumoti faqat ulangan o\'quvchida; loginlar noyob va kontrakt formatida', () => {
    const { access } = getTables();
    const linked = new Set(access.linkedStudentIds);
    expect(access.credentials.every((c) => linked.has(c.studentId))).toBe(true);
    const logins = access.credentials.map((c) => c.login);
    expect(new Set(logins).size).toBe(logins.length);
    expect(logins.every((l) => /^[a-z][a-z0-9._]{3,23}$/.test(l))).toBe(true);
    for (const r of getTables().access.recoveryRequests) expect(access.credentials.some((c) => c.studentId === r.studentId)).toBe(true);
  });

  it('PAROL hech qayerda saqlanmaydi', () => {
    expect(JSON.stringify(getTables().access)).not.toMatch(/temporaryPassword|passwordHash|"password"/i);
  });

  it('xodim bildirishnomalari: sinf rahbari + admin, faqat ism va sinf; havolalar tegishli sahifaga', () => {
    const stored = getTables().notifications.filter((n) => ['CHILD_RECOVERY_REQUEST', 'LINK_REVIEW', 'LINK_CORRECTION'].includes(n.kind));
    expect(stored).toHaveLength(7);
    for (const n of stored) {
      expect(n.roles).toEqual(['HOMEROOM', 'ADMIN']);
      expect(Object.keys(n.params).sort()).toEqual(['className', 'studentName']);
      expect(n.classIds).toHaveLength(1);
      expect(n.href).toMatch(n.kind === 'CHILD_RECOVERY_REQUEST' ? /^\/students\/view\?id=.+&tab=access$/ : /^\/students\/link-requests$/);
    }
  });

  it('deterministik: bir xil sana va seed — bir xil jadvallar', () => {
    expect(createFreshSnapshot(ANCHOR).tables.access).toEqual(createFreshSnapshot(ANCHOR).tables.access);
  });
});

describe('migratsiya: kirish jadvallari', () => {
  it('eski bazada jadvallar va bildirishnomalar tiklanadi; takroran ishga tushirish o\'zgartirmaydi', () => {
    const fresh = createFreshSnapshot(ANCHOR);
    const { access: _access, ...rest } = fresh.tables;
    void _access;
    const legacyNotifications = fresh.tables.notifications.filter((n) => !['CHILD_RECOVERY_REQUEST', 'LINK_REVIEW', 'LINK_CORRECTION'].includes(n.kind));
    const legacy = { ...fresh, tables: { ...rest, notifications: legacyNotifications } } as unknown as typeof fresh;

    const migrated = migrate(legacy);
    expect(migrated.tables.access).toEqual(fresh.tables.access);
    expect(migrated.tables.notifications.map((n) => n.id).sort()).toEqual(fresh.tables.notifications.map((n) => n.id).sort());
    expect(migrate(migrated)).toBe(migrated);
  });

  it('yangi baza o\'zgarmaydi (idempotent)', () => {
    const fresh = createFreshSnapshot(ANCHOR);
    expect(migrate(fresh)).toBe(fresh);
  });
});
