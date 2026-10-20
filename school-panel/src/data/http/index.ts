import type { Api } from '../api';
import { notAvailable } from './not-available';
import { classesHttp } from './services/classes';
import { profileHttp } from './services/profile';
import { schoolHttp } from './services/school';
import { auditHttp, staffHttp } from './services/staff';

/**
 * Backend (http) servislari. Hali ulanmagan nom maydonlari aniq xato beradi
 * (`notAvailable`) — modul tayyor bo'lgach shu yerga qo'shiladi.
 */
export function createHttpApi(): Api {
  return {
    school: schoolHttp,
    classes: classesHttp,
    students: notAvailable('students'),
    guardians: notAvailable('guardians'),
    staff: staffHttp,
    audit: auditHttp,
    search: notAvailable('search'),
    attendance: notAvailable('attendance'),
    schoolMode: notAvailable('schoolMode'),
    comms: notAvailable('comms'),
    care: notAvailable('care'),
    learning: notAvailable('learning'),
    reports: notAvailable('reports'),
    dashboard: notAvailable('dashboard'),
    profile: profileHttp,
    assessments: notAvailable('assessments'),
    development: notAvailable('development'),
    notifications: notAvailable('notifications'),
    parents: notAvailable('parents'),
    demo: notAvailable('demo'),
  };
}
