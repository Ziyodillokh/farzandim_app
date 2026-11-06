import { ChildAuthClock } from './child-auth-clock';
import { ChildRecoveryService } from './child-recovery.service';

const T0 = new Date('2026-11-09T09:00:00.000Z');
const SCHOOL_TARGET = {
  child: { id: 'child-1', parentId: 'parent-1' },
};
const STUDENT = {
  schoolId: 'school-1',
  classId: 'class-a',
  archived: false,
  lastName: 'Aliyev',
  firstName: 'Vali',
  class: { name: '7-A' },
  school: { status: 'ACTIVE' },
};

function setup(over: { credential?: unknown; student?: unknown; staff?: unknown[]; recent?: number } = {}) {
  const calls: string[] = [];
  const tap = <T>(name: string, value: T) =>
    jest.fn(async () => {
      calls.push(name);
      return value;
    });
  const prisma = {
    childCredential: { findUnique: tap('credential', over.credential === undefined ? SCHOOL_TARGET : over.credential) },
    schoolStudent: { findUnique: tap('student', over.student === undefined ? STUDENT : over.student) },
    childRecoveryRequest: {
      count: tap('count', over.recent ?? 0),
      create: jest.fn(async () => {
        calls.push('create');
        return { id: 'req-1' };
      }),
    },
    schoolStaff: {
      findMany: jest.fn(async () => over.staff ?? [{ id: 'director', role: 'DIRECTOR', classes: [] }, { id: 'admin', role: 'ADMIN', classes: [] }]),
    },
    schoolStaffNotification: { upsert: jest.fn().mockResolvedValue({}) },
  };
  const fcm = { getUserLang: jest.fn().mockResolvedValue('uz'), sendPushToUser: jest.fn().mockResolvedValue({ sent: 1 }) };
  const audit = { log: jest.fn().mockResolvedValue(undefined) };
  const clock = new ChildAuthClock();
  clock.now = () => T0;
  const service = new ChildRecoveryService(prisma as never, fcm as never, audit as never, clock);
  return { service, prisma, fcm, audit, calls };
}

const request = (service: ChildRecoveryService, login = 'vali.k24', channel: 'PARENT' | 'SCHOOL' = 'SCHOOL') =>
  service.request({ login, channel });

describe('ChildRecoveryService.request: the school notification goes only to staff who can act', () => {
  it('stores it for the active staff holding students.manage whose scope covers the class (the resolver result)', async () => {
    const t = setup();

    await request(t.service);
    await t.service.drainEffects();

    expect(t.prisma.schoolStaff.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { schoolId: 'school-1', active: true, role: { in: expect.arrayContaining(['DIRECTOR', 'ADMIN']) } } }),
    );
    expect(t.prisma.schoolStaffNotification.upsert).toHaveBeenCalledTimes(1);
    const arg = t.prisma.schoolStaffNotification.upsert.mock.calls[0]![0] as { create: Record<string, unknown>; where: { id: string } };
    expect(arg.where.id).toBe('child-recovery:req-1');
    expect(arg.create).toMatchObject({
      schoolId: 'school-1',
      kind: 'CHILD_RECOVERY_REQUEST',
      roles: ['DIRECTOR', 'ADMIN'],
      staffIds: ['director', 'admin'],
      classIds: ['class-a'],
      params: { studentName: 'Aliyev Vali', className: '7-A' },
    });
    expect(t.fcm.sendPushToUser).not.toHaveBeenCalled();
  });

  it('a homeroom teacher of the class is a recipient only when the resolver returns them (permission granted)', async () => {
    const without = setup();
    await request(without.service);
    await without.service.drainEffects();
    const withTeacher = setup({
      staff: [
        { id: 'director', role: 'DIRECTOR', classes: [] },
        { id: 'homeroom-a', role: 'HOMEROOM', classes: [{ classId: 'class-a' }] },
        { id: 'homeroom-b', role: 'HOMEROOM', classes: [{ classId: 'class-b' }] },
      ],
    });
    // Rollar jadvalida HOMEROOM'ga ruxsat berilgan holat (resolver rollar jadvaliga qaraydi):
    const { SCHOOL_ROLES } = await import('../../school/auth/permissions');
    const def = SCHOOL_ROLES.HOMEROOM as unknown as { permissions: string[] };
    const original = def.permissions;
    def.permissions = [...original, 'students.manage'];
    try {
      await request(withTeacher.service);
      await withTeacher.service.drainEffects();
    } finally {
      def.permissions = original;
    }

    const stored = (t: typeof without) => (t.prisma.schoolStaffNotification.upsert.mock.calls[0]![0] as { create: { staffIds: string[]; roles: string[] } }).create;
    expect(stored(without).staffIds).not.toContain('homeroom-a');
    expect(stored(without).roles).not.toContain('HOMEROOM');
    expect(stored(withTeacher).staffIds).toEqual(['director', 'homeroom-a']);
    expect(stored(withTeacher).roles).toEqual(['DIRECTOR', 'HOMEROOM']);
  });

  it('falls back to the director role when nobody qualifies', async () => {
    const t = setup({ staff: [] });

    await request(t.service);
    await t.service.drainEffects();

    const created = (t.prisma.schoolStaffNotification.upsert.mock.calls[0]![0] as { create: Record<string, unknown> }).create;
    expect(created).toMatchObject({ roles: ['DIRECTOR'], staffIds: [], classIds: ['class-a'] });
  });

  it('stores no class scope for a student without a class', async () => {
    const t = setup({ student: { ...STUDENT, classId: null, class: null } });

    await request(t.service);
    await t.service.drainEffects();

    const created = (t.prisma.schoolStaffNotification.upsert.mock.calls[0]![0] as { create: Record<string, unknown> }).create;
    expect(created).toMatchObject({ classIds: [], params: { studentName: 'Aliyev Vali', className: '' } });
  });
});

describe('ChildRecoveryService.request: no enumeration', () => {
  it('runs the same database queries for an existing and an unknown login (PARENT channel)', async () => {
    const known = setup();
    const unknown = setup({ credential: null });

    await request(known.service, 'vali.k24', 'PARENT');
    await request(unknown.service, 'nobody.x00', 'PARENT');

    expect(unknown.calls).toEqual(known.calls);
  });

  it('runs the same queries for the SCHOOL channel, an unknown login and a malformed one', async () => {
    const known = setup();
    const unknown = setup({ credential: null });
    const malformed = setup({ credential: null });

    await request(known.service, 'vali.k24', 'SCHOOL');
    await request(unknown.service, 'nobody.x00', 'SCHOOL');
    await request(malformed.service, 'N o!', 'SCHOOL');

    expect(unknown.calls).toEqual(known.calls);
    expect(malformed.calls).toEqual(known.calls);
  });

  it('answers the same shape and creates a dead request (no child) for an unknown login, without any effect', async () => {
    const unknown = setup({ credential: null });

    const res = await request(unknown.service, 'nobody.x00', 'PARENT');
    await unknown.service.drainEffects();

    expect(Object.keys(res).sort()).toEqual(['pollToken', 'requestId']);
    expect(unknown.prisma.childRecoveryRequest.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ childId: null, channel: 'PARENT' }) }),
    );
    expect(unknown.fcm.sendPushToUser).not.toHaveBeenCalled();
    expect(unknown.prisma.schoolStaffNotification.upsert).not.toHaveBeenCalled();
    expect(unknown.audit.log).not.toHaveBeenCalled();
  });

  it('returns before the effects finish (a slow push does not slow an existing login down)', async () => {
    const t = setup();
    let release: () => void = () => undefined;
    t.fcm.sendPushToUser.mockImplementation(() => new Promise((resolve) => (release = () => resolve({ sent: 1 }))));

    const res = await request(t.service, 'vali.k24', 'PARENT');

    // So'rov push yakunlanmasdan qaytdi; push fonda hali kutilmoqda.
    expect(res.requestId).toBe('req-1');
    for (let i = 0; i < 50 && t.fcm.sendPushToUser.mock.calls.length === 0; i++) await new Promise((r) => setImmediate(r));
    expect(t.fcm.sendPushToUser).toHaveBeenCalledTimes(1);
    release();
    await t.service.drainEffects();
  });

  it('stops sending effects after 3 recent requests for the same child but still creates the request', async () => {
    const capped = setup({ recent: 3 });
    const open = setup({ recent: 2 });

    await request(capped.service, 'vali.k24', 'PARENT');
    await capped.service.drainEffects();
    await request(open.service, 'vali.k24', 'PARENT');
    await open.service.drainEffects();

    expect(capped.prisma.childRecoveryRequest.create).toHaveBeenCalledTimes(1);
    expect(capped.fcm.sendPushToUser).not.toHaveBeenCalled();
    expect(open.fcm.sendPushToUser).toHaveBeenCalledTimes(1);
  });

  it('falls back to the PARENT channel when the child is not linked to an active school student', async () => {
    for (const student of [null, { ...STUDENT, archived: true }, { ...STUDENT, school: { status: 'SUSPENDED' } }]) {
      const t = setup({ student });

      await request(t.service, 'vali.k24', 'SCHOOL');
      await t.service.drainEffects();

      expect(t.prisma.childRecoveryRequest.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ childId: 'child-1', channel: 'PARENT' }) }),
      );
      expect(t.fcm.sendPushToUser).toHaveBeenCalledTimes(1);
      expect(t.prisma.schoolStaffNotification.upsert).not.toHaveBeenCalled();
    }
  });
});
