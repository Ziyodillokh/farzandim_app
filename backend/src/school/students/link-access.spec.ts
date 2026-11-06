import { SchoolStaffRole } from '@prisma/client';
import { SCHOOL_ROLES, SchoolPermission } from '../auth/permissions';
import { canHandleLinkRequest, LINK_REQUESTS_PERMISSION, resolveLinkRecipients, StaffCandidate } from './link-access';

const SCHOOL = 'school-1';
const CLASS_A = 'class-a';
const CLASS_B = 'class-b';

const staff = (id: string, role: SchoolStaffRole, classes: string[] = []): StaffCandidate => ({
  id,
  fullName: `${role} ${id}`,
  role,
  classes: classes.map((classId) => ({ classId })),
});

/** Jarayon ichidagi rol jadvalidan ruxsatni vaqtincha olib tashlaydi (SCHOOL_ROLES — umumiy obyekt). */
function withoutPermission(roles: SchoolStaffRole[], permission: SchoolPermission): () => void {
  const saved = roles.map((role) => [role, SCHOOL_ROLES[role].permissions] as const);
  for (const role of roles) SCHOOL_ROLES[role].permissions = SCHOOL_ROLES[role].permissions.filter((p) => p !== permission);
  return () => {
    for (const [role, permissions] of saved) SCHOOL_ROLES[role].permissions = permissions;
  };
}

describe('link request access', () => {
  let restore: (() => void) | undefined;

  afterEach(() => {
    restore?.();
    restore = undefined;
  });

  it('is gated by guardians.link, held today by the director, administrator and homeroom only', () => {
    expect(LINK_REQUESTS_PERMISSION).toBe('guardians.link');
    const holders = (Object.keys(SCHOOL_ROLES) as SchoolStaffRole[]).filter((r) => SCHOOL_ROLES[r].permissions.includes(LINK_REQUESTS_PERMISSION));
    expect(holders.sort()).toEqual(['ADMIN', 'DIRECTOR', 'HOMEROOM']);
  });

  describe('canHandleLinkRequest', () => {
    it.each([
      ['director (school wide)', staff('d', 'DIRECTOR'), CLASS_A, true],
      ['director for a student without a class', staff('d', 'DIRECTOR'), null, true],
      ['administrator (school wide)', staff('a', 'ADMIN'), CLASS_B, true],
      ['homeroom of the student class', staff('h', 'HOMEROOM', [CLASS_A]), CLASS_A, true],
      ['homeroom with several classes', staff('h', 'HOMEROOM', [CLASS_B, CLASS_A]), CLASS_A, true],
      ['homeroom of another class', staff('h', 'HOMEROOM', [CLASS_B]), CLASS_A, false],
      ['homeroom without any class', staff('h', 'HOMEROOM'), CLASS_A, false],
      ['homeroom for a student without a class', staff('h', 'HOMEROOM', [CLASS_A]), null, false],
      ['teacher of the class (no permission)', staff('t', 'TEACHER', [CLASS_A]), CLASS_A, false],
      ['duty officer (no permission)', staff('u', 'DUTY'), CLASS_A, false],
      ['psychologist (no permission)', staff('p', 'PSYCHOLOGIST'), CLASS_A, false],
    ])('%s', (_name, candidate, classId, expected) => {
      expect(canHandleLinkRequest(candidate, { schoolId: SCHOOL, classId })).toBe(expected);
    });

    it('a homeroom in scope but WITHOUT the permission cannot handle it; with the permission it can', () => {
      const homeroom = staff('h', 'HOMEROOM', [CLASS_A]);
      expect(canHandleLinkRequest(homeroom, { schoolId: SCHOOL, classId: CLASS_A })).toBe(true);

      restore = withoutPermission(['HOMEROOM'], LINK_REQUESTS_PERMISSION);

      expect(canHandleLinkRequest(homeroom, { schoolId: SCHOOL, classId: CLASS_A })).toBe(false);
      expect(canHandleLinkRequest(staff('a', 'ADMIN'), { schoolId: SCHOOL, classId: CLASS_A })).toBe(true);
    });
  });

  describe('resolveLinkRecipients', () => {
    const txWith = (rows: StaffCandidate[]) => ({ schoolStaff: { findMany: jest.fn().mockResolvedValue(rows) } });
    const student = { schoolId: SCHOOL, classId: CLASS_A };

    it('asks only for ACTIVE staff of the student school', async () => {
      const tx = txWith([]);

      await resolveLinkRecipients(tx as never, student);

      expect(tx.schoolStaff.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { schoolId: SCHOOL, active: true } }),
      );
    });

    it('picks every qualified staff member (school wide + the class homeroom) and drops the rest', async () => {
      const tx = txWith([
        staff('1', 'ADMIN'),
        staff('2', 'DIRECTOR'),
        staff('3', 'HOMEROOM', [CLASS_A]),
        staff('4', 'HOMEROOM', [CLASS_B]),
        staff('5', 'TEACHER', [CLASS_A]),
        staff('6', 'DUTY'),
        staff('7', 'PSYCHOLOGIST'),
      ]);

      const result = await resolveLinkRecipients(tx as never, student);

      expect(result).toEqual({ roles: ['ADMIN', 'DIRECTOR', 'HOMEROOM'], staffIds: ['1', '2', '3'] });
    });

    it('does not include a homeroom that lacks the permission, even when the class is in its scope', async () => {
      restore = withoutPermission(['HOMEROOM'], LINK_REQUESTS_PERMISSION);
      const tx = txWith([staff('1', 'ADMIN'), staff('3', 'HOMEROOM', [CLASS_A])]);

      const result = await resolveLinkRecipients(tx as never, student);

      expect(result).toEqual({ roles: ['ADMIN'], staffIds: ['1'] });
    });

    it('includes a homeroom that holds the permission and the class in scope', async () => {
      const tx = txWith([staff('3', 'HOMEROOM', [CLASS_A])]);

      const result = await resolveLinkRecipients(tx as never, student);

      expect(result).toEqual({ roles: ['HOMEROOM'], staffIds: ['3'] });
    });

    it('falls back to the directors when nobody holds the permission in scope', async () => {
      restore = withoutPermission(['DIRECTOR', 'ADMIN', 'HOMEROOM'], LINK_REQUESTS_PERMISSION);
      const tx = txWith([staff('1', 'ADMIN'), staff('2', 'DIRECTOR'), staff('3', 'HOMEROOM', [CLASS_A]), staff('4', 'DIRECTOR')]);

      const result = await resolveLinkRecipients(tx as never, student);

      expect(result).toEqual({ roles: ['DIRECTOR'], staffIds: ['2', '4'] });
    });

    it('treats a director as an ordinary school-wide recipient (not only a fallback) next to a homeroom of another class', async () => {
      const tx = txWith([staff('2', 'DIRECTOR'), staff('4', 'HOMEROOM', [CLASS_B])]);

      // Direktor jadvaldagi ruxsatga ega, shuning uchun fallback kerak emas — direktor oddiy oluvchi.
      expect(await resolveLinkRecipients(tx as never, student)).toEqual({ roles: ['DIRECTOR'], staffIds: ['2'] });
    });

    it('returns no recipients when there is no active qualified staff and no active director', async () => {
      const tx = txWith([staff('5', 'TEACHER', [CLASS_A]), staff('6', 'DUTY')]);

      expect(await resolveLinkRecipients(tx as never, student)).toEqual({ roles: [], staffIds: [] });
    });

    it('only school-wide handlers qualify for a student without a class', async () => {
      const tx = txWith([staff('1', 'ADMIN'), staff('3', 'HOMEROOM', [CLASS_A])]);

      expect(await resolveLinkRecipients(tx as never, { schoolId: SCHOOL, classId: null })).toEqual({ roles: ['ADMIN'], staffIds: ['1'] });
    });
  });
});
