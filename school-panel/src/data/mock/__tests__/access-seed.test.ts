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

  it('tekshiruv kutayotgan o\'quvchi hali ulanmagan, tuzatish so\'rovi esa ulanganniki; kodda o\'quvchi o\'rni UNDER_REVIEW', () => {
    const { access } = getTables();
    const linked = new Set(access.linkedStudentIds);
    for (const r of access.linkRequests.filter((x) => x.kind === 'REVIEW')) {
      expect(linked.has(r.studentId)).toBe(false);
      // REVIEW id'si shaffof "<kod yozuvi>:<bola>" va kod yozuviga mos.
      const code = access.inviteCodes.find((c) => c.studentId === r.studentId);
      expect(r.id.split(':')[0]).toBe(code?.id);
      expect(code?.studentUsedAt).toBe(r.createdAt);
      expect(code?.studentConfirmedAt).toBeNull();
      expect(Boolean(code?.parentUsedAt)).toBe(r.parentLinked);
      // Ikkala o'rin ishlatilgan kod yopiq (kontrakt K2), aks holda faol.
      expect(code?.closedAt !== null).toBe(r.parentLinked);
      expect(r.childName).toBeTruthy();
    }
    for (const r of access.linkRequests.filter((x) => x.kind === 'CORRECTION')) {
      expect(linked.has(r.studentId)).toBe(true);
      expect(r.id).not.toContain(':');
      expect(r.reason).toBe('WRONG_SCHOOL_OR_CLASS');
      expect(r.note).toBeTruthy();
      expect(r.childName).toBeTruthy();
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

  it('xodim bildirishnomalari (K1 §5, K2 §7): ish qila oladigan faol xodimlarga belgilangan, faqat ism va sinf; havolalar tegishli sahifaga', () => {
    const { notifications, staff, students } = getTables();
    const stored = notifications.filter((n) => ['CHILD_RECOVERY_REQUEST', 'LINK_REVIEW', 'LINK_CORRECTION'].includes(n.kind));
    expect(stored).toHaveLength(7);
    const studentOf = (n: (typeof stored)[number]) => students.find((s) => n.classIds?.[0] === s.classId && n.params.studentName === `${s.lastName} ${s.firstName}`)!;
    for (const n of stored) {
      expect(Object.keys(n.params).sort()).toEqual(['className', 'studentName']);
      expect(n.classIds).toHaveLength(1);
      expect(n.href).toMatch(n.kind === 'CHILD_RECOVERY_REQUEST' ? /^\/students\/view\?id=.+&tab=access$/ : /^\/students\/link-requests$/);
      // Tiklash — `students.manage`: direktor va admin (sinf rahbarida yo'q). Ulanish — `guardians.link`: + o'quvchi sinfining sinf rahbari.
      const expectedStaff =
        n.kind === 'CHILD_RECOVERY_REQUEST'
          ? ['stf-admin', 'stf-director']
          : ['stf-admin', 'stf-director', staff.find((s) => s.role === 'HOMEROOM' && s.classIds.includes(studentOf(n).classId))!.id];
      expect([...(n.staffIds ?? [])].sort()).toEqual(expectedStaff.sort());
      expect(n.roles).toEqual(n.kind === 'CHILD_RECOVERY_REQUEST' ? ['DIRECTOR', 'ADMIN'] : ['DIRECTOR', 'ADMIN', 'HOMEROOM']);
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

  it('kontraktdan oldingi shakldagi kirish jadvallari (parentUsed, studentName…) qayta quriladi; eski bildirishnomalar almashtiriladi', () => {
    const fresh = createFreshSnapshot(ANCHOR);
    const oldShape = {
      ...fresh,
      tables: {
        ...fresh.tables,
        access: {
          ...fresh.tables.access,
          linkRequests: fresh.tables.access.linkRequests.map((r) => {
            const legacy: Record<string, unknown> = { ...r, parentUsed: false };
            delete legacy.childName;
            delete legacy.parentLinked;
            return legacy;
          }),
        },
        // Eski bildirishnomalar: faqat rollar (staffIds yo'q).
        notifications: fresh.tables.notifications.map((n) => (n.kind === 'LINK_REVIEW' ? { ...n, staffIds: undefined, roles: ['HOMEROOM', 'ADMIN'] as typeof n.roles } : n)),
      },
    } as unknown as typeof fresh;
    const migrated = migrate(oldShape);
    expect(migrated.tables.access).toEqual(fresh.tables.access);
    expect(migrated.tables.notifications.filter((n) => n.kind === 'LINK_REVIEW').every((n) => n.roles.includes('DIRECTOR'))).toBe(true);
    expect(migrated.tables.notifications.map((n) => n.id).sort()).toEqual(fresh.tables.notifications.map((n) => n.id).sort());
    expect(migrate(migrated)).toBe(migrated);
  });
});
