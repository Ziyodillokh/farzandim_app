import type { HhMm, Id, IsoDate, IsoWeekday } from './common';

export type School = {
  id: Id;
  name: string;
  shortName: string;
  city: string;
  address: string;
  phone: string;
  /** data:image/... yoki null — null bo'lsa bosh harflar ko'rsatiladi. */
  logo: string | null;
  academicYear: string; // "2026–2027"
  /** Kelgan vaqt smena boshidan shuncha daqiqa kech bo'lsa — "kechikdi". */
  lateAfterMinutes: number;
  quarters: Array<{ no: 1 | 2 | 3 | 4; start: IsoDate; end: IsoDate }>;
};

export type BellPeriodKind = 'LESSON' | 'BREAK';
export type BellPeriod = { no: number; start: HhMm; end: HhMm; kind: BellPeriodKind };

export type Shift = {
  id: Id;
  name: string; // "1-smena"
  start: HhMm;
  end: HhMm;
  weekdays: IsoWeekday[];
  periods: BellPeriod[];
};

export type SchoolClass = {
  id: Id;
  grade: number; // 1..11
  letter: string; // "A"
  name: string; // "7-A"
  shiftId: Id;
  homeroomStaffId: Id | null;
  room: string;
};

export type Holiday = { id: Id; date: IsoDate; name: string };
