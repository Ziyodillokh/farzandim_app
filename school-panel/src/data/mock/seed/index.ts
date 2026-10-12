import { assignAllPortraits } from '@/lib/staff-avatar';
import { toIsoDate } from '../calendar';
import type { Tables } from '../tables';
import { buildAudit, buildEarlyExits } from './audit';
import { buildCareRequests, buildQuestions, buildSurveys } from './care';
import { buildAnnouncements, buildPayments, buildReminders, buildVerifications } from './comms';
import { buildActivity, buildAssignments, buildMaterials } from './learning';
import { buildPeople } from './people';
import { buildDevices, buildExceptions, buildPolicies, INITIAL_EMERGENCY } from './school-mode';
import { academicYearStart, buildClasses, buildHolidays, buildSchool, buildShifts } from './structure';

/**
 * Demo maktab — deterministik: bir xil `seed` va sana → bir xil ma'lumot.
 * Bugungi davomat bu yerda YARATILMAYDI — uni simulyator jonli "o'ynaydi".
 */
export function generateSeed(seed: number, now: Date): Tables {
  const baseIso = toIsoDate(now);
  const school = buildSchool(now);
  const shifts = buildShifts();
  const holidays = buildHolidays(now);
  const classes = buildClasses();
  const people = buildPeople(classes, academicYearStart(now), baseIso, seed);

  const sizes = new Map<string, number>();
  for (const s of people.students) sizes.set(s.classId, (sizes.get(s.classId) ?? 0) + 1);

  const questions = buildQuestions();
  const { surveys, responses } = buildSurveys(baseIso, classes, people.students, questions, seed);
  const payments = buildPayments(people.families, baseIso, seed);

  return {
    school,
    shifts,
    classes,
    holidays,
    staff: assignAllPortraits(people.staff),
    students: people.students,
    guardians: people.guardians,
    attendance: [],
    attendanceEvents: [],
    earlyExits: buildEarlyExits(people.students, baseIso),
    parentNotifications: [],
    policies: buildPolicies(),
    exceptions: buildExceptions(people.students, baseIso),
    devices: buildDevices(people.students, seed, now.toISOString()),
    emergency: INITIAL_EMERGENCY,
    announcements: buildAnnouncements(baseIso, people.guardians.length, seed),
    reminders: buildReminders(baseIso),
    payments,
    verifications: buildVerifications(payments, baseIso),
    careQuestions: questions,
    careSurveys: surveys,
    careResponses: responses,
    careRequests: buildCareRequests(people.students, baseIso),
    materials: buildMaterials(),
    assignments: buildAssignments(baseIso),
    activity: buildActivity(classes, sizes, baseIso),
    audit: buildAudit(people.staff, baseIso),
    sim: { date: '', processedUntilMinute: -1 },
  };
}
