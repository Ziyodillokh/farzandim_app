import type { Api } from '../api';
import { notAvailable } from './not-available';
import { attendanceHttp } from './services/attendance';
import { careHttp } from './services/care';
import { classesHttp } from './services/classes';
import { commsHttp } from './services/comms';
import { dashboardHttp, notificationsHttp, reportsHttp, searchHttp } from './services/insights';
import { profileHttp } from './services/profile';
import { schoolHttp } from './services/school';
import { schoolModeHttp } from './services/school-mode';
import { auditHttp, staffHttp } from './services/staff';
import { guardiansHttp, parentsHttp, studentsHttp } from './services/students';

/**
 * Backend (http) servislari. Hali ulanmagan nom maydonlari aniq xato beradi
 * (`notAvailable`) — modul tayyor bo'lgach shu yerga qo'shiladi.
 */
export function createHttpApi(): Api {
  return {
    school: schoolHttp,
    classes: classesHttp,
    students: studentsHttp,
    guardians: guardiansHttp,
    staff: staffHttp,
    audit: auditHttp,
    search: searchHttp,
    attendance: attendanceHttp,
    schoolMode: schoolModeHttp,
    comms: commsHttp,
    care: careHttp,
    learning: notAvailable('learning'),
    reports: reportsHttp,
    dashboard: dashboardHttp,
    profile: profileHttp,
    assessments: notAvailable('assessments'),
    development: notAvailable('development'),
    notifications: notificationsHttp,
    parents: parentsHttp,
    demo: notAvailable('demo'),
  };
}
