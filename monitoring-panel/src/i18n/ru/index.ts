import type { DeepString } from '../types';
import type { Dict } from '../uz';

import { common } from './common';
import { nav } from './nav';
import { auth } from './auth';
import { shell } from './shell';
import { enums } from './enums';
import { errors } from './errors';
import { filters } from './filters';
import { map } from './map';
import { metrics } from './metrics';
import { insights } from './insights';
import { dashboard } from './dashboard';
import { regions } from './regions';
import { region } from './region';
import { mastery } from './mastery';
import { iq } from './iq';
import { interests } from './interests';
import { wellbeing } from './wellbeing';
import { attendance } from './attendance';
import { digital } from './digital';
import { schools } from './schools';
import { reports } from './reports';
import { methodology } from './methodology';
import { present } from './present';
import { settings } from './settings';

export const ru: DeepString<Dict> = {
  common,
  nav,
  auth,
  shell,
  enums,
  errors,
  filters,
  map,
  metrics,
  insights,
  dashboard,
  regions,
  region,
  mastery,
  iq,
  interests,
  wellbeing,
  attendance,
  digital,
  schools,
  reports,
  methodology,
  present,
  settings,
};
