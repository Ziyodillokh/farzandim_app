/**
 * Hayot yo'nalishlari: farovonlik va muammolar ("Bola ovozi", Kelajak
 * signallari, psixologga murojaatlar), davomat va raqamli odatlar.
 * Farovonlik — faqat agregat foiz va darajalar; skrining, tashxis emas.
 */
import type { Attendance, Digital, Filters, Scope, Wellbeing } from '@/data/contracts';
import * as F from '@/data/mock/model/formulas';
import type { Area } from '@/data/mock/model/engine';
import {
  APP_CATEGORIES,
  CARE_TOPICS,
  GRADES,
  MOODS,
  SCHOOL_TYPES,
  topicLevel,
  WELLBEING_TOPICS,
} from '@/data/reference/domains';
import { customSeries, customStat, customValue, metricSeries, metricStat, round, scopeArea } from './core';

const NATIONAL: Area = { kind: 'NATIONAL' };
const withFilter = (f: Filters, patch: Partial<Filters>): Filters => ({ ...f, ...patch });
const forGrade = (grade: number, fn: (c: F.Ctx) => number | null) => (c: F.Ctx) => (c.grade === grade ? fn(c) : null);

// ───────────────────────────── Farovonlik ─────────────────────────────

export function getWellbeing(scope: Scope, f: Filters): Wellbeing {
  const area = scopeArea(scope);
  const index = metricStat('wellbeing', area, f, 0);
  const surveyBase = F.surveyParticipation;
  const topics = WELLBEING_TOPICS.map((topic) => {
    const score = round(customValue(`wb:${topic}`, area, f, (c) => F.wellbeingTopic(c, topic), surveyBase), 0);
    return {
      topic,
      score,
      level: score === null ? null : topicLevel(score),
      national: round(customValue(`wb:${topic}`, NATIONAL, f, (c) => F.wellbeingTopic(c, topic), surveyBase), 0),
    };
  });
  const careTopics = CARE_TOPICS.map((topic) => ({
    key: topic,
    share: round(customValue(`ct:${topic}`, area, f, (c) => F.careTopicShares(c)[topic] * 100, F.careRequests)) ?? 0,
  })).sort((a, b) => b.share - a.share);
  const respondents = Math.round(
    metricStat('wellbeing', area, f, 0).n,
  );
  return {
    index,
    level: index.value === null ? null : topicLevel(index.value),
    topics,
    bullying: metricStat('bullying', area, f),
    support: metricStat('support', area, f),
    watch: customStat('watch', area, f, F.watchSignal, surveyBase),
    anxiety: metricStat('anxiety', area, f),
    sleep: metricStat('sleep', area, f),
    careRequests: metricStat('careRequests', area, f),
    urgentShare: round(customValue('urgent', area, f, F.urgentShare, F.careRequests)),
    careTopics,
    sos: round(customValue('sos', area, f, F.sosRate, F.parentsLinked), 2),
    safetyGap: metricStat('safetyGap', area, f),
    schoolQuality: metricStat('schoolQuality', area, f, 0),
    teacherRelation: metricStat('teacherRelation', area, f, 0),
    byGrade: GRADES.map((grade) => ({
      grade,
      wellbeing: round(customValue(`wb:g${grade}`, area, f, forGrade(grade, (c) => F.wellbeingTopic(c, 'WELLBEING')), surveyBase), 0),
      bullying: round(customValue(`bul:g${grade}`, area, f, forGrade(grade, F.bullying), surveyBase)),
      anxiety: round(customValue(`anx:g${grade}`, area, f, forGrade(grade, F.anxiety), surveyBase)),
    })),
    byGender: (['M', 'F'] as const).map((gender) => {
      const g = withFilter(f, { gender });
      return {
        gender,
        wellbeing: metricStat('wellbeing', area, g, 0).value,
        bullying: metricStat('bullying', area, g).value,
        anxiety: metricStat('anxiety', area, g).value,
      };
    }),
    trend: metricSeries('wellbeing', area, f, 0),
    bullyingTrend: metricSeries('bullying', area, f),
    respondents,
  };
}

// ───────────────────────────── Davomat ─────────────────────────────

export function getAttendance(scope: Scope, f: Filters): Attendance {
  const area = scopeArea(scope);
  const rate = metricStat('attendance', area, f);
  const late = metricStat('late', area, f);
  const leftEarly = round(customValue('ee-share', area, f, (c) => F.earlyExits(c) * 0.9)) ?? 0.9;
  let statuses: Attendance['statuses'] = null;
  if (rate.value !== null && late.value !== null) {
    const nonAttend = 100 - rate.value;
    statuses = {
      onTime: round(rate.value - late.value - leftEarly) ?? 0,
      late: late.value,
      leftEarly,
      excused: round(nonAttend * 0.3) ?? 0,
      absent: round(nonAttend * 0.7) ?? 0,
    };
  }
  return {
    rate,
    late,
    chronic: metricStat('chronic', area, f),
    statuses,
    earlyExits: customStat('ee', area, f, F.earlyExits, undefined, 2),
    byMonth: metricSeries('attendance', area, f),
    byWeekday: ([1, 2, 3, 4, 5, 6] as const).map((day) => ({
      day,
      value: rate.value === null ? null : round(rate.value + (F.WEEKDAY_FX[day - 1] ?? 0)),
    })),
    byGrade: GRADES.map((grade) => ({ grade, value: round(customValue(`att:g${grade}`, area, f, forGrade(grade, F.attendance))) })),
    bySchoolType: SCHOOL_TYPES.map((type) => ({ type, value: metricStat('attendance', area, withFilter(f, { schoolType: type })).value })),
  };
}

// ───────────────────────────── Raqamli odatlar ─────────────────────────────

export function getDigital(scope: Scope, f: Filters): Digital {
  const area = scopeArea(scope);
  const screen = metricStat('screenTime', area, f, 0);
  const base = F.deviceShare;
  const hourlyRaw = Array.from({ length: 24 }, (_, h) => customValue(`hr:${h}`, area, f, (c) => F.hourlyProfile(c)[h] ?? 0, base) ?? 0);
  const hourlyTotal = hourlyRaw.reduce((a, b) => a + b, 0) || 1;
  return {
    screenTime: screen,
    night: metricStat('night', area, f),
    schoolMode: metricStat('schoolMode', area, f),
    steps: metricStat('steps', area, f, 0),
    sleep: metricStat('sleep', area, f),
    devices: screen.n,
    schoolDay: round(customValue('sd', area, f, F.screenSchoolDay, base), 0),
    weekend: round(customValue('we', area, f, (c) => F.screenSchoolDay(c) * 1.42, base), 0),
    categories: APP_CATEGORIES.map((key) => ({
      key,
      share: round(customValue(`cat:${key}`, area, f, (c) => F.appCategoryShares(c)[key] * 100, base)) ?? 0,
    })).sort((a, b) => b.share - a.share),
    hourly: hourlyRaw.map((v) => round((v / hourlyTotal) * 100, 2) ?? 0),
    moods: MOODS.map((key) => ({
      key,
      share: round(customValue(`mood:${key}`, area, f, (c) => F.moodShares(c)[key] * 100, base)) ?? 0,
    })),
    byGrade: GRADES.map((grade) => ({
      grade,
      screenTime: round(customValue(`scr:g${grade}`, area, f, forGrade(grade, F.screenTime), base), 0),
      night: round(customValue(`ngt:g${grade}`, area, f, forGrade(grade, F.nightUse), base)),
    })),
    byGender: (['M', 'F'] as const).map((gender) => {
      const g = withFilter(f, { gender });
      return {
        gender,
        screenTime: metricStat('screenTime', area, g, 0).value,
        game: round(customValue('cat:GAME', area, g, (c) => F.appCategoryShares(c).GAME * 100, base)),
      };
    }),
    trend: customSeries('screen-trend', area, f, F.screenTime, base, 0),
  };
}
