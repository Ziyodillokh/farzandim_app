// Parvoz Growth bola ilovasi: sinfining kunlik dars jadvali. Vaqtlar — smena davrlaridan;
// dam olish kuni (hafta oxiri / bayram) darslarsiz. `published` — sinfda umuman jadval bormi
// (yo'q bo'lsa ilova "jadval hali kiritilmagan" ko'rsatadi, "darslar yo'q" emas).

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { isDayKey, isoWeekday, tashkentDay } from '../../common/time/tashkent';
import { requireEnrolledStudent } from '../common/child-student';
import { invalid } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { parsePeriods } from './timetable-rules';
import { dayOffOf, lessonsForDay } from './timetable-view';
import { timetableDayQuerySchema } from './timetable.schemas';

@Injectable()
export class TimetableChildService {
  constructor(private readonly prisma: PrismaService) {}

  async day(childUserId: string, query: unknown) {
    const { date: requested } = parseOrThrow(timetableDayQuerySchema, query ?? {});
    if (requested && !isDayKey(requested)) throw invalid('date: errors.form.invalidDate');
    const student = await requireEnrolledStudent(this.prisma, childUserId);
    const date = requested ?? tashkentDay();
    const [lessons, holidayRows] = await Promise.all([
      this.prisma.schoolTimetableLesson.findMany({ where: { classId: student.classId } }),
      this.prisma.schoolHoliday.findMany({ where: { schoolId: student.schoolId, date }, select: { date: true, name: true } }),
    ]);
    const dayOff = dayOffOf(date, student.shift, new Map(holidayRows.map((h) => [h.date, h.name])));
    const weekday = isoWeekday(date);
    return {
      date,
      weekday,
      className: student.className,
      shift: { name: student.shift.name, start: student.shift.start, end: student.shift.end },
      published: lessons.length > 0,
      dayOff,
      lessons: dayOff ? [] : lessonsForDay(lessons, parsePeriods(student.shift.periods), weekday),
    };
  }
}
