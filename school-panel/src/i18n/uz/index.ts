import { attendance } from './attendance';
import { audit } from './audit';
import { auth } from './auth';
import { care } from './care';
import { classes } from './classes';
import { common } from './common';
import { dashboard } from './dashboard';
import { demo } from './demo';
import { enums } from './enums';
import { errors } from './errors';
import { learning } from './learning';
import { messages } from './messages';
import { nav } from './nav';
import { parents } from './parents';
import { profile } from './profile';
import { reminders } from './reminders';
import { reports } from './reports';
import { schoolMode } from './schoolMode';
import { settings } from './settings';
import { shell } from './shell';
import { staff } from './staff';
import { students } from './students';

export const uz = {
  common,
  nav,
  auth,
  enums,
  errors,
  shell,
  demo,
  dashboard,
  students,
  classes,
  parents,
  staff,
  attendance,
  schoolMode,
  messages,
  reminders,
  care,
  learning,
  reports,
  audit,
  settings,
  profile,
};

export type Dict = typeof uz;
