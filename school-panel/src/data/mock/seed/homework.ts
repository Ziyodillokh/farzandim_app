import type { LearningAssignment, Student, SubmissionRecord, SubmissionStatus } from '@/data/contracts';
import { WRITTEN_MATERIAL_ID } from '@/data/schemas/learning';
import { unitHash } from '@/lib/rng';
import { addDays } from '../calendar';
import { FIXED_STAFF } from './people';

/**
 * Demo yozma vazifalar va o'quvchilar topshirgan ishlar (daftar rasmlari).
 * Hammasi deterministik: bir xil seed va sana → bir xil natija.
 */

export function buildWrittenAssignments(baseIso: string): LearningAssignment[] {
  const day = (offset: number) => addDays(baseIso, offset);
  const written = (a: Omit<LearningAssignment, 'materialId'>): LearningAssignment => ({ ...a, materialId: WRITTEN_MATERIAL_ID });
  return [
    written({
      id: 'asg-6',
      title: 'Ona tili: «Mening Vatanim» mavzusida insho',
      note: 'Daftarga chiroyli yozing: kamida 8 ta gap. Ikkala betni ham alohida suratga oling.',
      estimatedMinutes: 30,
      classIds: ['cls-7a'],
      dueDate: day(2),
      createdAt: `${day(-2)}T14:20:00`,
      byStaffId: FIXED_STAFF.homeroom7a,
    }),
    written({
      id: 'asg-7',
      title: 'Matematika: 34-mashq (kasrlarni qo\'shish)',
      note: 'Yechimni to\'liq ko\'rsating, javobni qizil ruchka bilan tagiga chizing.',
      estimatedMinutes: 25,
      classIds: ['cls-7a', 'cls-7b'],
      dueDate: day(1),
      createdAt: `${day(-1)}T09:40:00`,
      byStaffId: FIXED_STAFF.admin,
    }),
    written({
      id: 'asg-8',
      title: 'Tarix: Amir Temur haqida qisqa referat',
      note: 'Daftarning 1–2 betida, o\'z so\'zlaringiz bilan.',
      estimatedMinutes: 40,
      classIds: ['cls-7a'],
      dueDate: day(-2),
      createdAt: `${day(-9)}T13:05:00`,
      byStaffId: FIXED_STAFF.homeroom7a,
    }),
  ];
}

const COMMENTS = [
  'Ustoz, tayyor!',
  'Yozuvim chiroyli chiqmadi, kechirasiz.',
  'Qiynalib bajardim, tekshirib bering.',
  '',
  'Dadam yordam berdi.',
  '',
  'Oxirgi gapni to\'ldirolmadim.',
];

const RETURN_NOTES = [
  'Rasm xira — yorug\'roq joyda qayta suratga oling.',
  '2-bet yo\'q, ikkala betni ham yuboring.',
  'Gaplar soni yetmaydi, yana 2 ta gap qo\'shing.',
  'Yechim to\'liq emas: 3 va 4-misollar ko\'rsatilmagan.',
];

type Split = { pending: number; accepted: number; returned: number };

/** Topshiriq holatiga qarab: muddati o'tganida ko'pchilik tekshirilgan, yaqin muddatda — kutayotgan ishlar ko'p. */
function splitFor(assignment: LearningAssignment, baseIso: string): { submit: number; split: Split } {
  if (assignment.dueDate < baseIso) return { submit: 0.88, split: { pending: 0.1, accepted: 0.7, returned: 0.2 } };
  return { submit: 0.62, split: { pending: 0.6, accepted: 0.25, returned: 0.15 } };
}

function statusFor(roll: number, split: Split): SubmissionStatus {
  if (roll < split.pending) return 'SUBMITTED';
  return roll < split.pending + split.accepted ? 'ACCEPTED' : 'RETURNED';
}

/** Har bir yozma vazifa uchun sinf o'quvchilarining ~60% ishi (1–3 ta rasm) — qolganlari topshirmagan. */
export function buildSubmissions(assignments: readonly LearningAssignment[], students: readonly Student[], baseIso: string): SubmissionRecord[] {
  const records: SubmissionRecord[] = [];
  for (const assignment of assignments.filter((a) => a.materialId === WRITTEN_MATERIAL_ID)) {
    const { submit, split } = splitFor(assignment, baseIso);
    const roster = students.filter((s) => !s.archived && assignment.classIds.includes(s.classId));
    for (const student of roster) {
      if (unitHash(assignment.id, student.id, 'submit') >= submit) continue;
      const id = `sub-${assignment.id}-${student.id}`;
      const status = statusFor(unitHash(assignment.id, student.id, 'status'), split);
      const submittedDay = addDays(baseIso, -1 - Math.floor(unitHash(assignment.id, student.id, 'day') * 2));
      const hour = 15 + Math.floor(unitHash(assignment.id, student.id, 'hour') * 6);
      const minute = Math.floor(unitHash(assignment.id, student.id, 'min') * 60);
      const photoCount = 1 + Math.floor(unitHash(assignment.id, student.id, 'photos') * 3);
      const reviewed = status !== 'SUBMITTED';
      records.push({
        id,
        assignmentId: assignment.id,
        studentId: student.id,
        status,
        comment: COMMENTS[Math.floor(unitHash(id, 'comment') * COMMENTS.length)] ?? '',
        submittedAt: `${submittedDay}T${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00`,
        reviewedAt: reviewed ? `${addDays(submittedDay, 1)}T08:${String(10 + Math.floor(unitHash(id, 'rev') * 40)).padStart(2, '0')}:00` : null,
        reviewNote: status === 'RETURNED' ? (RETURN_NOTES[Math.floor(unitHash(id, 'note') * RETURN_NOTES.length)] ?? null) : null,
        photoIds: Array.from({ length: photoCount }, (_, i) => `${id}-p${i + 1}`),
      });
    }
  }
  return records;
}
