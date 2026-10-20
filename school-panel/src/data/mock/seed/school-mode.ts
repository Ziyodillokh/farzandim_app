import type { DeviceState, EmergencyState, SchoolModeException, SchoolModePolicy, Student } from '@/data/contracts';
import { Random } from '@/lib/rng';
import { FIXED_STAFF } from './people';
import { SHIFT_1, SHIFT_2 } from './structure';

export function buildPolicies(): SchoolModePolicy[] {
  return [
    {
      id: 'pol-1',
      name: 'Dars vaqti — asosiy tartib',
      blockedCategories: ['GAME', 'SOCIAL', 'VIDEO'],
      allowedApps: [
        { id: 'app-parvoz', name: 'Parvoz Growth', category: 'EDU' },
        { id: 'app-kundalik', name: 'Kundalik.com', category: 'EDU' },
        { id: 'app-duolingo', name: 'Duolingo', category: 'EDU' },
        { id: 'app-khan', name: 'Khan Academy', category: 'EDU' },
        { id: 'app-calc', name: 'Kalkulyator', category: 'OTHER' },
        { id: 'app-dict', name: 'Lug\'at (Uz–En–Ru)', category: 'EDU' },
      ],
      alwaysAllowCalls: true,
      shiftIds: [SHIFT_1, SHIFT_2],
      enabled: true,
      relaxDuringBreaks: false,
    },
  ];
}

export function buildDevices(students: Student[], seed: number, nowIso: string): DeviceState[] {
  const rng = new Random(seed + 7);
  return students.map((s) => {
    if (s.device === 'NONE') return { studentId: s.id, status: 'NO_PHONE', lastSeenAt: null };
    const r = rng.float();
    const noPermission = s.device === 'IOS' ? 0.11 : 0.06;
    const status = r < noPermission ? 'NO_PERMISSION' : r < noPermission + 0.05 ? 'OFFLINE' : 'APPLIED';
    return { studentId: s.id, status, lastSeenAt: status === 'OFFLINE' ? null : nowIso };
  });
}

export function buildExceptions(students: Student[], baseIso: string): SchoolModeException[] {
  const pick = (classId: string, index: number) => students.filter((s) => s.classId === classId)[index];
  const items: Array<[Student | undefined, string, string, string]> = [
    [pick('cls-7a', 3), 'Shifokor tavsiyasi: qand miqdorini kuzatish ilovasi doim ochiq bo\'lishi kerak', '07:30', '18:00'],
    [pick('cls-9b', 5), 'Olimpiadaga tayyorgarlik — onlayn mashg\'ulot (informatika)', '10:00', '11:35'],
    [pick('cls-11a', 2), 'Universitet qabul komissiyasi bilan videoqo\'ng\'iroq', '11:40', '12:25'],
  ];
  return items
    .filter((item): item is [Student, string, string, string] => Boolean(item[0]))
    .map(([student, reason, from, until], i) => ({
      id: `exc-${i + 1}`,
      studentId: student.id,
      classId: student.classId,
      from: `${baseIso}T${from}:00`,
      until: `${baseIso}T${until}:00`,
      reason,
      byStaffId: i === 0 ? FIXED_STAFF.homeroom7a : FIXED_STAFF.admin,
      revokedAt: null,
    }));
}

export const INITIAL_EMERGENCY: EmergencyState = {
  active: false,
  scope: 'SCHOOL',
  classIds: [],
  reason: '',
  byStaffId: null,
  at: null,
};
