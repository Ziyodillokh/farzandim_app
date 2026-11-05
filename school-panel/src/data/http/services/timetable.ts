import type { ClassTimetable } from '@/data/contracts';
import type { timetableService } from '@/data/mock/services/timetable';
import { http } from '../client';

type Timetable = typeof timetableService;
const BASE = '/school/timetable/classes';
const id = (v: string) => encodeURIComponent(v);

/** Dars jadvali: `GET` o'qiydi, `PUT` haftani to'liq almashtiradi (noto'g'ri davr/kun/takror — 400). */
export const timetableHttp: Timetable = {
  get: (classId) => http<ClassTimetable>('GET', `${BASE}/${id(classId)}`),
  save: (classId, input) => http<ClassTimetable>('PUT', `${BASE}/${id(classId)}`, { body: input }),
};
