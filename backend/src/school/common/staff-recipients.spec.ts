import { SchoolStaffRole } from '@prisma/client';
import { SCHOOL_ROLES } from '../auth/permissions';
import { rolesWith, staffWithPermission } from './staff-recipients';

interface FakeStaff {
  id: string;
  schoolId: string;
  role: SchoolStaffRole;
  active: boolean;
  classes: string[];
}

/** `schoolStaff.findMany` ni DB kabi filtrlaydigan soxta baza (schoolId, active, role in). */
function fakeDb(staff: FakeStaff[]) {
  const findMany = jest.fn(
    async ({ where }: { where: { schoolId: string; active: boolean; role: { in: SchoolStaffRole[] } } }) =>
      staff
        .filter((s) => s.schoolId === where.schoolId && s.active === where.active && where.role.in.includes(s.role))
        .map((s) => ({ id: s.id, role: s.role, classes: s.classes.map((classId) => ({ classId })) })),
  );
  return { db: { schoolStaff: { findMany } } as never, findMany };
}

const STAFF: FakeStaff[] = [
  { id: 'director', schoolId: 's1', role: 'DIRECTOR', active: true, classes: [] },
  { id: 'admin', schoolId: 's1', role: 'ADMIN', active: true, classes: [] },
  { id: 'admin-off', schoolId: 's1', role: 'ADMIN', active: false, classes: [] },
  { id: 'homeroom-a', schoolId: 's1', role: 'HOMEROOM', active: true, classes: ['class-a'] },
  { id: 'homeroom-b', schoolId: 's1', role: 'HOMEROOM', active: true, classes: ['class-b'] },
  { id: 'teacher-a', schoolId: 's1', role: 'TEACHER', active: true, classes: ['class-a'] },
  { id: 'duty', schoolId: 's1', role: 'DUTY', active: true, classes: [] },
  { id: 'psych', schoolId: 's1', role: 'PSYCHOLOGIST', active: true, classes: [] },
  { id: 'other-admin', schoolId: 's2', role: 'ADMIN', active: true, classes: [] },
];

const ids = (recipients: Array<{ id: string }>) => recipients.map((r) => r.id).sort();

/** Rollar jadvalini testda vaqtincha o'zgartiradi. */
function withPermissions(role: SchoolStaffRole, permissions: string[]): () => void {
  const definition = SCHOOL_ROLES[role] as unknown as { permissions: string[] };
  const original = definition.permissions;
  definition.permissions = permissions;
  return () => {
    definition.permissions = original;
  };
}

describe('rolesWith', () => {
  it('lists the roles that hold the permission in the role matrix', () => {
    expect(rolesWith('students.manage').sort()).toEqual(['ADMIN', 'DIRECTOR']);
    expect(rolesWith('attendance.kiosk').sort()).toEqual(['ADMIN', 'DUTY']);
  });
});

describe('staffWithPermission', () => {
  const restores: Array<() => void> = [];
  afterEach(() => {
    while (restores.length) restores.pop()!();
  });

  it('returns the active whole-school staff who hold the permission, whatever the class (DIRECTOR, ADMIN)', async () => {
    const { db } = fakeDb(STAFF);

    expect(ids(await staffWithPermission(db, 's1', 'students.manage', 'class-a'))).toEqual(['admin', 'director']);
    expect(ids(await staffWithPermission(db, 's1', 'students.manage', 'class-b'))).toEqual(['admin', 'director']);
    expect(ids(await staffWithPermission(db, 's1', 'students.manage', null))).toEqual(['admin', 'director']);
  });

  it('carries the role of every recipient', async () => {
    const { db } = fakeDb(STAFF);

    const recipients = await staffWithPermission(db, 's1', 'students.manage', 'class-a');

    expect(recipients.find((r) => r.id === 'director')?.role).toBe('DIRECTOR');
    expect(recipients.find((r) => r.id === 'admin')?.role).toBe('ADMIN');
  });

  it('never returns a homeroom teacher who lacks the permission', async () => {
    const { db } = fakeDb(STAFF);

    const recipients = await staffWithPermission(db, 's1', 'students.manage', 'class-a');

    expect(ids(recipients)).not.toContain('homeroom-a');
  });

  it('asks only for active staff of the given school and only for roles that hold the permission', async () => {
    const { db, findMany } = fakeDb(STAFF);

    await staffWithPermission(db, 's1', 'students.manage', 'class-a');

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { schoolId: 's1', active: true, role: { in: expect.arrayContaining(['DIRECTOR', 'ADMIN']) } } }),
    );
    expect(findMany.mock.calls[0]![0].where.role.in).toHaveLength(2);
  });

  it('excludes inactive staff and the staff of other schools', async () => {
    const { db } = fakeDb(STAFF);

    const recipients = await staffWithPermission(db, 's1', 'students.manage', 'class-a');

    expect(ids(recipients)).not.toContain('admin-off');
    expect(ids(recipients)).not.toContain('other-admin');
  });

  it('includes a class-scoped role granted the permission ONLY for the class it covers', async () => {
    restores.push(withPermissions('HOMEROOM', [...SCHOOL_ROLES.HOMEROOM.permissions, 'students.manage']));
    const { db } = fakeDb(STAFF);

    expect(ids(await staffWithPermission(db, 's1', 'students.manage', 'class-a'))).toEqual(['admin', 'director', 'homeroom-a']);
    expect(ids(await staffWithPermission(db, 's1', 'students.manage', 'class-b'))).toEqual(['admin', 'director', 'homeroom-b']);
    expect(ids(await staffWithPermission(db, 's1', 'students.manage', 'class-c'))).toEqual(['admin', 'director']);
  });

  it('a student without a class is covered only by whole-school roles', async () => {
    restores.push(withPermissions('HOMEROOM', [...SCHOOL_ROLES.HOMEROOM.permissions, 'students.manage']));
    restores.push(withPermissions('TEACHER', [...SCHOOL_ROLES.TEACHER.permissions, 'students.manage']));
    const { db } = fakeDb(STAFF);

    expect(ids(await staffWithPermission(db, 's1', 'students.manage', null))).toEqual(['admin', 'director']);
  });

  it('follows the matrix for any role (not hard-coded names): a teacher granted the permission is included for their class', async () => {
    restores.push(withPermissions('TEACHER', [...SCHOOL_ROLES.TEACHER.permissions, 'students.manage']));
    const { db } = fakeDb(STAFF);

    expect(ids(await staffWithPermission(db, 's1', 'students.manage', 'class-a'))).toEqual(['admin', 'director', 'teacher-a']);
  });

  it('returns nobody when no role holds the permission', async () => {
    restores.push(withPermissions('DIRECTOR', []));
    restores.push(withPermissions('ADMIN', []));
    const { db, findMany } = fakeDb(STAFF);

    expect(await staffWithPermission(db, 's1', 'students.manage', 'class-a')).toEqual([]);
    expect(findMany).not.toHaveBeenCalled();
  });
});
