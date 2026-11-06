import type { Guardian, SchoolClass, StaffNotification, Student } from '@/data/contracts';
import { hashString } from '@/lib/rng';
import { type AccessNotificationKind, recipientRoles, suggestLogin } from '../access-model';
import type { AccessTables, MockCredential, MockInviteCode, MockLinkRequest, MockRecoveryRequest } from '../access-tables';
import { addDays } from '../calendar';
import { studentName } from '../lookups';

/**
 * Kirish (5-bosqich) demo ma'lumotlari. Deterministik: bir xil `seed` va sana → bir xil natija.
 * Barcha vaqtlar "bugun" ertalabgacha (demo soati 07:45 dan oldin) — bildirishnomalar va so'rovlar darhol ko'rinadi.
 * Parollar HECH QAYERDA saqlanmaydi.
 */

const CHILD_LINKED_SHARE = 70;
const CREDENTIAL_SHARE = 55;
const INVITE_TTL_DAYS = 1;
const SEED_STAFF_ID = 'stf-admin';
const CORRECTION_NOTE = 'Men boshqa sinfda oʻqiyman — bu yerda sinf notoʻgʻri koʻrsatilgan.';

type Input = {
  students: readonly Student[];
  guardians: readonly Guardian[];
  classes: readonly SchoolClass[];
  baseIso: string;
  seed: number;
};

export type AccessSeed = { access: AccessTables; notifications: StaffNotification[] };

const byId = (a: { id: string }, b: { id: string }) => a.id.localeCompare(b.id, 'en', { numeric: true });
const percentOf = (seed: number, scope: string, id: string) => hashString(`${seed}|${scope}|${id}`) % 100;

/** `YYYY-MM-DDTHH:MM:00` — demo bazadagi mahalliy format. */
function stamp(baseIso: string, dayOffset: number, hhmm: string): string {
  return `${addDays(baseIso, dayOffset)}T${hhmm}:00`;
}

function credentialFor(student: Student, input: Input, taken: Set<string>): MockCredential {
  const { seed, baseIso } = input;
  const issuedByParent = percentOf(seed, 'issuer', student.id) < 50;
  const mustChange = percentOf(seed, 'must-change', student.id) < 20;
  const login = suggestLogin(student, taken, `${seed}|${student.id}`);
  taken.add(login);
  const issuedDaysAgo = 2 + (percentOf(seed, 'issued', student.id) % 20);
  const lastLoginDaysAgo = 1 + (percentOf(seed, 'login-day', student.id) % 3);
  const lastLoginHour = 14 + (percentOf(seed, 'login-hour', student.id) % 5);
  return {
    studentId: student.id,
    login,
    issuedBy: issuedByParent ? 'PARENT' : 'SCHOOL',
    issuedAt: stamp(baseIso, -issuedDaysAgo, '10:00'),
    mustChangePassword: mustChange,
    lastLoginAt: mustChange ? null : stamp(baseIso, -lastLoginDaysAgo, `${lastLoginHour}:${String(percentOf(seed, 'login-min', student.id) % 60).padStart(2, '0')}`),
  };
}

function inviteFor(student: Student, input: Input, taken: Set<string>, request: MockLinkRequest): MockInviteCode {
  let code = String(hashString(`${input.seed}|code|${student.id}`) % 1_000_000).padStart(6, '0');
  for (let n = 1; taken.has(code); n++) code = String((Number(code) + n) % 1_000_000).padStart(6, '0');
  taken.add(code);
  return {
    id: `inv-${student.id}`,
    studentId: student.id,
    code,
    createdAt: stamp(input.baseIso, 0, '05:30'),
    expiresAt: stamp(input.baseIso, INVITE_TTL_DAYS, '05:30'),
    studentUsedAt: request.createdAt,
    parentUsedAt: request.parentUsed ? stamp(input.baseIso, 0, '05:45') : null,
    // Ikkala o'rin ishlatilsa kod yopiladi (kontrakt K2) — «faol kod» yo'q, tekshiruv so'rovi esa ochiq qoladi.
    closedAt: request.parentUsed ? stamp(input.baseIso, 0, '05:45') : null,
    createdByStaffId: SEED_STAFF_ID,
  };
}

function classMap(classes: readonly SchoolClass[]): Map<string, SchoolClass> {
  return new Map(classes.map((c) => [c.id, c]));
}

export function buildAccess(input: Input): AccessSeed {
  const { students, guardians, baseIso, seed } = input;
  const linkedGuardians = new Set(guardians.filter((g) => g.linkStatus === 'LINKED').map((g) => g.id));
  const active = students.filter((s) => !s.archived).sort(byId);

  // Bola profiliga ulanganlar: ota-onasi Parvoz'da bo'lgan o'quvchilarning ko'pchiligi.
  const linked = active.filter((s) => s.guardianIds.some((id) => linkedGuardians.has(id)) && percentOf(seed, 'child', s.id) < CHILD_LINKED_SHARE);
  const linkedIds = new Set(linked.map((s) => s.id));

  // Tekshiruv kutayotgan ulanishlar: hali ulanmaganlar (7-A ikkita, 8-B bitta).
  const unlinked = (classId: string) => active.filter((s) => s.classId === classId && !linkedIds.has(s.id));
  const reviewStudents = [...unlinked('cls-7a').slice(0, 2), ...unlinked('cls-8b').slice(0, 1)];
  const reviewRequests: MockLinkRequest[] = reviewStudents.map((s, i) => ({
    id: `lnk-review-${s.id}`,
    kind: 'REVIEW',
    studentId: s.id,
    createdAt: stamp(baseIso, 0, ['06:10', '05:40', '06:25'][i] ?? '06:00'),
    parentUsed: i === 1,
    note: null,
    reason: null,
    status: 'OPEN',
    resolvedAt: null,
  }));

  // Tuzatish so'rovlari: ulangan o'quvchilar (7-A va 8-B).
  const correctionStudents = ['cls-7a', 'cls-8b']
    .map((classId) => linked.find((s) => s.classId === classId))
    .filter((s): s is Student => Boolean(s));
  const correctionRequests: MockLinkRequest[] = correctionStudents.map((s, i) => ({
    id: `lnk-correction-${s.id}`,
    kind: 'CORRECTION',
    studentId: s.id,
    createdAt: i === 0 ? stamp(baseIso, -1, '16:20') : stamp(baseIso, 0, '05:55'),
    parentUsed: false,
    note: CORRECTION_NOTE,
    reason: 'WRONG_SCHOOL_OR_CLASS',
    status: 'OPEN',
    resolvedAt: null,
  }));

  const loginsTaken = new Set<string>();
  const credentials = linked.filter((s) => percentOf(seed, 'credential', s.id) < CREDENTIAL_SHARE).map((s) => credentialFor(s, input, loginsTaken));

  // Parol tiklash: kirish ma'lumotli ulangan o'quvchilardan ikkitasi (biri 7-A da: sinf doirasi sinovi uchun).
  const credentialed = credentials.map((c) => linked.find((s) => s.id === c.studentId)).filter((s): s is Student => Boolean(s));
  const recoveryStudents = [credentialed.find((s) => s.classId === 'cls-7a'), credentialed.find((s) => s.classId !== 'cls-7a')]
    .filter((s): s is Student => Boolean(s))
    .filter((s, i, all) => all.indexOf(s) === i);
  const recoveryRequests: MockRecoveryRequest[] = recoveryStudents.map((s, i) => ({
    id: `rec-${s.id}`,
    studentId: s.id,
    channel: 'SCHOOL',
    status: 'RECEIVED',
    createdAt: i === 0 ? stamp(baseIso, 0, '05:50') : stamp(baseIso, -1, '18:05'),
    resolvedAt: null,
  }));

  const codesTaken = new Set<string>();
  const inviteCodes = reviewRequests.map((r) => {
    const student = reviewStudents.find((s) => s.id === r.studentId) as Student;
    return inviteFor(student, input, codesTaken, r);
  });

  const classes = classMap(input.classes);
  const notificationOf = (kind: AccessNotificationKind, id: string, student: Student, createdAt: string, href: string): StaffNotification => ({
    id: `ntf-${kind.toLowerCase().replace(/_/g, '-')}-${id}`,
    kind,
    at: createdAt,
    // Faqat amalni bajara oladigan rollarga (sinf rahbarida `students.manage` yo'q — tiklash so'rovi unga kelmaydi).
    roles: recipientRoles(kind),
    classIds: [student.classId],
    params: { studentName: studentName(student), className: classes.get(student.classId)?.name ?? '' },
    subject: null,
    href,
  });
  const studentById = (id: string) => active.find((s) => s.id === id) as Student;
  const notifications: StaffNotification[] = [
    ...reviewRequests.map((r) => notificationOf('LINK_REVIEW', r.id, studentById(r.studentId), r.createdAt, '/students/link-requests')),
    ...correctionRequests.map((r) => notificationOf('LINK_CORRECTION', r.id, studentById(r.studentId), r.createdAt, '/students/link-requests')),
    ...recoveryRequests.map((r) =>
      notificationOf('CHILD_RECOVERY_REQUEST', r.id, studentById(r.studentId), r.createdAt, `/students/view?id=${encodeURIComponent(r.studentId)}&tab=access`),
    ),
  ];

  return {
    access: {
      linkedStudentIds: linked.map((s) => s.id),
      credentials,
      inviteCodes,
      recoveryRequests,
      linkRequests: [...reviewRequests, ...correctionRequests],
    },
    notifications,
  };
}
