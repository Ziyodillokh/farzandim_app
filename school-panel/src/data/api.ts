/**
 * Ilova servislari — YAGONA kirish nuqtasi. Hozir mock (brauzer xotirasi);
 * keyin Parvoz backend'iga ulanganda shu fayl `http` servislarini qaytaradi
 * (`NEXT_PUBLIC_DATA_SOURCE=http`), UI kodi o'zgarmaydi.
 */
import { assessmentsService } from './mock/services/assessments';
import { attendanceService } from './mock/services/attendance';
import { classesService } from './mock/services/classes';
import { demoService } from './mock/services/demo';
import { schoolService } from './mock/services/school';
import { searchService } from './mock/services/search';
import { auditService, staffService } from './mock/services/staff';
import { guardiansService, studentsService } from './mock/services/students';
import { careService } from './mock/services/care';
import { commsService } from './mock/services/comms';
import { dashboardService } from './mock/services/dashboard';
import { developmentService } from './mock/services/development';
import { learningService } from './mock/services/learning';
import { notificationsService } from './mock/services/notifications';
import { parentsService } from './mock/services/parents';
import { profileService } from './mock/services/profile';
import { reportsService } from './mock/services/reports';
import { schoolModeService } from './mock/services/school-mode';

export const api = {
  school: schoolService,
  classes: classesService,
  students: studentsService,
  guardians: guardiansService,
  staff: staffService,
  audit: auditService,
  search: searchService,
  attendance: attendanceService,
  schoolMode: schoolModeService,
  comms: commsService,
  care: careService,
  learning: learningService,
  reports: reportsService,
  dashboard: dashboardService,
  profile: profileService,
  assessments: assessmentsService,
  development: developmentService,
  notifications: notificationsService,
  parents: parentsService,
  demo: demoService,
};

export type Api = typeof api;
