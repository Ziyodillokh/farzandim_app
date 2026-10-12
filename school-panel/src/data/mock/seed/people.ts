import type { DeviceOs, Guardian, GuardianRelation, ParentLinkStatus, SchoolClass, Staff, Student } from '@/data/contracts';
import { Random } from '@/lib/rng';
import { FEMALE_NAMES, MALE_NAMES, patronymic, SURNAME_STEMS, surname, TEACHER_POSITIONS } from './names';

export type Family = { id: string; guardianIds: string[]; primaryGuardianId: string; studentIds: string[] };

export type PeopleSeed = { staff: Staff[]; students: Student[]; guardians: Guardian[]; families: Family[] };

/** Demo hisoblar bilan bog'langan qat'iy xodimlar. */
export const FIXED_STAFF = {
  director: 'stf-director',
  admin: 'stf-admin',
  homeroom7a: 'stf-homeroom-7a',
  psychologist: 'stf-psychologist',
  duty: 'stf-duty',
} as const;

function phone(rng: Random): string {
  const op = rng.pick(['90', '91', '93', '94', '95', '97', '98', '99', '88', '33']);
  const a = String(rng.int(100, 999));
  const b = String(rng.int(10, 99));
  const c = String(rng.int(10, 99));
  return `+998 ${op} ${a} ${b} ${c}`;
}

function inviteCode(rng: Random): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return Array.from({ length: 6 }, () => alphabet[rng.int(0, alphabet.length - 1)]).join('');
}

function deviceFor(rng: Random, grade: number): DeviceOs {
  const noPhone = grade <= 4 ? 0.45 : grade <= 6 ? 0.12 : 0.05;
  if (rng.bool(noPhone)) return 'NONE';
  return rng.bool(0.34) ? 'IOS' : 'ANDROID';
}

function linkStatus(rng: Random): ParentLinkStatus {
  const r = rng.float();
  if (r < 0.68) return 'LINKED';
  if (r < 0.85) return 'INVITED';
  return 'NOT_INVITED';
}

function makeStaff(id: string, fullName: string, position: string, role: Staff['role'], rng: Random, extra?: Partial<Staff>): Staff {
  return {
    id,
    fullName,
    position,
    role,
    phone: phone(rng),
    email: `${id.replace('stf-', '')}@pnm.demo.uz`,
    classIds: [],
    username: null,
    active: true,
    ...extra,
  };
}

export function buildPeople(classes: SchoolClass[], academicYear: number, baseIso: string, seed: number): PeopleSeed {
  const rng = new Random(seed);
  const staff: Staff[] = [
    makeStaff(FIXED_STAFF.director, 'Yusupova Nodira Azimovna', 'Maktab direktori', 'DIRECTOR', rng, { username: 'direktor' }),
    makeStaff(FIXED_STAFF.admin, 'Toshmatov Sardor Akmalovich', 'Direktorning o\'quv ishlari bo\'yicha o\'rinbosari', 'ADMIN', rng, {
      username: 'admin',
    }),
    makeStaff(FIXED_STAFF.psychologist, 'Sobirova Lola Baxromovna', 'Maktab psixologi', 'PSYCHOLOGIST', rng, { username: 'psixolog' }),
    makeStaff(FIXED_STAFF.duty, 'Ergashev Bobur Olimovich', 'Navbatchi administrator (kirish nuqtasi)', 'DUTY', rng, {
      username: 'navbatchi',
    }),
  ];

  // Sinf rahbarlari — har sinfga bitta; 7-A — demo hisob.
  const usedNames = new Set(staff.map((s) => s.fullName));
  const teacherName = (female: boolean): string => {
    for (;;) {
      const stem = rng.pick(SURNAME_STEMS);
      const first = rng.pick(female ? FEMALE_NAMES : MALE_NAMES);
      const father = rng.pick(MALE_NAMES).replace(/'/g, '');
      const suffix = female ? 'ovna' : 'ovich';
      const name = `${surname(stem, female)} ${first} ${father}${suffix}`;
      if (!usedNames.has(name)) {
        usedNames.add(name);
        return name;
      }
    }
  };

  for (const cls of classes) {
    const isDemo = cls.id === 'cls-7a';
    const id = isDemo ? FIXED_STAFF.homeroom7a : `stf-hr-${cls.grade}${cls.letter.toLowerCase()}`;
    const female = isDemo ? true : rng.bool(0.72);
    const position = cls.grade <= 4 ? 'Boshlang\'ich sinf o\'qituvchisi' : rng.pick(TEACHER_POSITIONS.slice(0, 11));
    const fullName = isDemo ? 'Rasulova Malika Hamidovna' : teacherName(female);
    usedNames.add(fullName);
    staff.push(
      makeStaff(id, fullName, isDemo ? 'Matematika o\'qituvchisi' : position, 'HOMEROOM', rng, {
        classIds: [cls.id],
        username: isDemo ? 'sinf7a' : null,
      }),
    );
    cls.homeroomStaffId = id;
  }

  // Fan o'qituvchilari (sinf rahbari emas).
  for (let i = 0; i < 18; i++) {
    const female = rng.bool(0.65);
    staff.push(makeStaff(`stf-t-${i + 1}`, teacherName(female), rng.pick(TEACHER_POSITIONS), 'TEACHER', rng));
  }

  // Oilalar → o'quvchilar va ota-onalar.
  const capacity = new Map(classes.map((c) => [c.id, rng.int(24, 28)]));
  const students: Student[] = [];
  const guardians: Guardian[] = [];
  const families: Family[] = [];
  const usedCodes = new Set<string>();
  let studentSeq = 0;
  let guardianSeq = 0;

  const studentCode = (): string => {
    for (;;) {
      const code = `P-${rng.int(1000, 9999)}`;
      if (!usedCodes.has(code)) {
        usedCodes.add(code);
        return code;
      }
    }
  };

  const newGuardian = (fullName: string, relation: GuardianRelation): Guardian => {
    guardianSeq += 1;
    const status = linkStatus(rng);
    const invited = status === 'INVITED';
    return {
      id: `grd-${guardianSeq}`,
      fullName,
      phone: phone(rng),
      relation,
      linkStatus: status,
      inviteCode: invited ? inviteCode(rng) : null,
      inviteExpiresAt: invited ? `${baseIso}T18:00:00.000Z` : null,
      linkedAt: status === 'LINKED' ? `${academicYear}-09-0${rng.int(2, 9)}T10:00:00.000Z` : null,
    };
  };

  const classOrder = rng.shuffle(classes);
  for (const cls of classOrder) {
    while ((capacity.get(cls.id) ?? 0) > 0) {
      const stem = rng.pick(SURNAME_STEMS);
      const fatherFirst = rng.pick(MALE_NAMES);
      const motherFirst = rng.pick(FEMALE_NAMES);
      const familyId = `fam-${families.length + 1}`;

      const famGuardians: Guardian[] = [];
      const hasMother = rng.bool(0.93);
      const hasFather = !hasMother || rng.bool(0.8);
      if (hasMother) famGuardians.push(newGuardian(`${surname(stem, true)} ${motherFirst}`, 'MOTHER'));
      if (hasFather) famGuardians.push(newGuardian(`${surname(stem, false)} ${fatherFirst}`, 'FATHER'));
      if (rng.bool(0.03)) famGuardians.push(newGuardian(`${surname(stem, true)} ${rng.pick(FEMALE_NAMES)}`, 'GRANDPARENT'));
      guardians.push(...famGuardians);

      const childCount = rng.float() < 0.6 ? 1 : rng.float() < 0.8 ? 2 : 3;
      const targets: SchoolClass[] = [cls];
      for (let k = 1; k < childCount; k++) {
        const options = classes.filter(
          (c) => (capacity.get(c.id) ?? 0) > 0 && !targets.some((t) => t.grade === c.grade) && c.id !== cls.id,
        );
        if (options.length === 0) break;
        targets.push(rng.pick(options));
      }

      const famStudentIds: string[] = [];
      for (const target of targets) {
        const left = capacity.get(target.id) ?? 0;
        if (left <= 0) continue;
        capacity.set(target.id, left - 1);
        studentSeq += 1;
        const female = rng.bool(0.49);
        const birthYear = academicYear - 6 - target.grade - (rng.bool(0.25) ? 1 : 0);
        const month = rng.int(1, 12);
        const day = rng.int(1, 28);
        const student: Student = {
          id: `stu-${studentSeq}`,
          lastName: surname(stem, female),
          firstName: rng.pick(female ? FEMALE_NAMES : MALE_NAMES),
          middleName: patronymic(fatherFirst, female),
          gender: female ? 'FEMALE' : 'MALE',
          birthDate: `${birthYear}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`,
          classId: target.id,
          device: deviceFor(rng, target.grade),
          guardianIds: famGuardians.map((g) => g.id),
          studentCode: studentCode(),
          enrolledAt: `${academicYear - (target.grade - 1)}-09-02`,
          archived: false,
        };
        students.push(student);
        famStudentIds.push(student.id);
      }

      const primary = famGuardians[0];
      if (primary && famStudentIds.length > 0) {
        families.push({ id: familyId, guardianIds: famGuardians.map((g) => g.id), primaryGuardianId: primary.id, studentIds: famStudentIds });
      }
    }
  }

  return { staff, students, guardians, families };
}
