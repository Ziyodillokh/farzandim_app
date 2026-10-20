import type { ClassActivity, LearningAssignment, LearningMaterial, SchoolClass } from '@/data/contracts';
import { unitHash } from '@/lib/rng';
import { addDays, isoWeekday, weekStart } from '../calendar';
import { FIXED_STAFF } from './people';

export function buildMaterials(): LearningMaterial[] {
  const m = (id: string, kind: LearningMaterial['kind'], title: string, subject: LearningMaterial['subject'], grades: number[], durationMin: number, questions = 0): LearningMaterial => ({
    id, kind, title, subject, grades, durationMin, questions,
  });
  return [
    m('mat-1', 'AUDIOBOOK', 'Alpomish (bolalar uchun moslashtirilgan)', 'LITERATURE', [3, 4, 5, 6], 48),
    m('mat-2', 'AUDIOBOOK', 'Shum bola — G\'afur G\'ulom', 'LITERATURE', [6, 7, 8], 95),
    m('mat-3', 'AUDIOBOOK', 'O\'tkan kunlar — Abdulla Qodiriy', 'LITERATURE', [9, 10, 11], 540),
    m('mat-4', 'VIDEO', 'Kasrlar: oddiy tushuntirish', 'MATH', [5, 6], 12),
    m('mat-5', 'VIDEO', 'Kvadrat tenglamalar — diskriminant', 'MATH', [8, 9], 18),
    m('mat-6', 'VIDEO', 'Amir Temur davlati', 'HISTORY', [7, 8], 22),
    m('mat-7', 'VIDEO', 'Fotosintez qanday ishlaydi?', 'BIOLOGY', [6, 7], 10),
    m('mat-8', 'VIDEO', 'Python: birinchi dastur', 'IT', [7, 8, 9, 10, 11], 25),
    m('mat-9', 'VIDEO', 'Present Perfect — misollar bilan', 'ENGLISH', [6, 7, 8, 9], 14),
    m('mat-10', 'TEST', 'Kasrlar — 10 savol', 'MATH', [5, 6], 15, 10),
    m('mat-11', 'TEST', 'Ingliz tili: Present Perfect', 'ENGLISH', [6, 7, 8, 9], 12, 10),
    m('mat-12', 'TEST', 'O\'zbekiston geografiyasi', 'GEOGRAPHY', [7, 8], 10, 8),
    m('mat-13', 'TEST', 'Ona tili: so\'z turkumlari', 'NATIVE', [5, 6, 7], 10, 10),
    m('mat-14', 'TEST', 'Mantiqiy masalalar', 'MATH', [3, 4, 5], 12, 8),
    m('mat-15', 'AUDIOBOOK', 'Ertaklar to\'plami — Xalq og\'zaki ijodi', 'LITERATURE', [1, 2, 3, 4], 35),
    m('mat-16', 'VIDEO', 'Alifbo qo\'shig\'i va harflar', 'NATIVE', [1, 2], 8),
  ];
}

export function buildAssignments(baseIso: string): LearningAssignment[] {
  const due = (days: number) => addDays(baseIso, days);
  return [
    { id: 'asg-1', materialId: 'mat-10', classIds: ['cls-7a'], dueDate: due(3), note: 'Nazorat ishidan oldin takrorlash', createdAt: `${due(-1)}T18:10:00`, byStaffId: FIXED_STAFF.homeroom7a },
    { id: 'asg-2', materialId: 'mat-2', classIds: ['cls-7a', 'cls-7b'], dueDate: due(10), note: 'Sinfdan tashqari o\'qish', createdAt: `${due(-3)}T15:00:00`, byStaffId: FIXED_STAFF.admin },
    { id: 'asg-3', materialId: 'mat-5', classIds: ['cls-9a', 'cls-9b'], dueDate: due(5), note: '', createdAt: `${due(-2)}T11:00:00`, byStaffId: FIXED_STAFF.admin },
    { id: 'asg-4', materialId: 'mat-8', classIds: ['cls-10a', 'cls-10b', 'cls-11a'], dueDate: due(14), note: 'Informatika to\'garagi uchun', createdAt: `${due(-5)}T10:30:00`, byStaffId: FIXED_STAFF.admin },
    { id: 'asg-5', materialId: 'mat-15', classIds: ['cls-2a', 'cls-2b', 'cls-3a'], dueDate: due(7), note: 'Ota-ona bilan birga tinglash', createdAt: `${due(-4)}T13:00:00`, byStaffId: FIXED_STAFF.admin },
  ];
}

/** Yopiq (yakshanbasi o'tgan) haftalar soni; ularga joriy, tugallanmagan hafta qo'shiladi. */
export const CLOSED_WEEKS = 6;

/**
 * 6 yopiq hafta + joriy (tugallanmagan) hafta. Joriy hafta faollari — o'tgan kunlar ulushida
 * (dushanba — eng kam); uning natijalari panelda ko'rsatilmaydi, faqat faollar soni.
 */
export function buildActivity(classes: SchoolClass[], sizes: Map<string, number>, baseIso: string): ClassActivity[] {
  const out: ClassActivity[] = [];
  const thisWeek = weekStart(baseIso);
  const weekProgress = isoWeekday(baseIso) / 7;
  for (let w = CLOSED_WEEKS; w >= 0; w--) {
    const start = addDays(thisWeek, -7 * w);
    for (const cls of classes) {
      const size = sizes.get(cls.id) ?? 25;
      const engagement = 0.45 + unitHash(cls.id, 'eng') * 0.35 + (CLOSED_WEEKS - w) * 0.015;
      const active = Math.round(size * Math.min(0.95, engagement) * (w === 0 ? weekProgress : 1));
      out.push({
        classId: cls.id,
        weekStart: start,
        activeStudents: active,
        completedTasks: Math.round(active * (2.2 + unitHash(cls.id, start, 'tasks') * 2.4)),
        avgScore: Math.round(62 + unitHash(cls.id, start, 'score') * 28),
        donPoints: Math.round(active * (38 + unitHash(cls.id, start, 'don') * 40)),
      });
    }
  }
  return out;
}
