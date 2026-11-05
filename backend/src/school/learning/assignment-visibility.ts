// Bolaga ko'rinadigan topshiriqlar (ro'yxat va yozma vazifa topshirish uchun UMUMIY qoida):
// bolaning HOZIRGI sinfiga berilgan, muddati o'tganlari — oxirgi shuncha kun.

import { Prisma } from '@prisma/client';
import { addDays } from '../../common/time/tashkent';

export const OVERDUE_VISIBLE_DAYS = 7;

export function childAssignmentWhere(
  student: { schoolId: string; classId: string },
  today: string,
): Prisma.SchoolLearningAssignmentWhereInput {
  return {
    schoolId: student.schoolId,
    classIds: { has: student.classId },
    dueDate: { gte: addDays(today, -OVERDUE_VISIBLE_DAYS) },
  };
}
