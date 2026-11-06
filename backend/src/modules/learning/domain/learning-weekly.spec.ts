import { isoWeekStart, tashkentDay } from '../../../common/time/tashkent';
import { streakFromDays } from './learning-stats';
import {
  attemptDurationSeconds,
  buildWeeklyReport,
  cappedMinutes,
  MAX_ATTEMPT_MINUTES,
  WeeklyAttempt,
} from './learning-weekly';

const at = (iso: string) => new Date(iso);

/** Kun kalitidan (Toshkent) boshlanadigan urinish; [minutes] daqiqa davom etadi. */
function attempt(day: string, minutes: number, startHourUtc = 10): WeeklyAttempt {
  const startedAt = at(`${day}T${String(startHourUtc).padStart(2, '0')}:00:00.000Z`);
  return { day, startedAt, completedAt: new Date(startedAt.getTime() + minutes * 60_000) };
}

describe('isoWeekStart (Toshkent kunlari)', () => {
  it.each([
    ['2026-11-02', '2026-11-02'], // dushanba
    ['2026-11-06', '2026-11-02'], // juma
    ['2026-11-08', '2026-11-02'], // yakshanba — hafta oxiri
    ['2026-11-09', '2026-11-09'], // keyingi dushanba
    ['2026-01-01', '2025-12-29'], // yil chegarasi
    ['2024-03-03', '2024-02-26'], // kabisa yil
  ])('%s → %s', (day, monday) => {
    expect(isoWeekStart(day)).toBe(monday);
  });

  it('UTC yakshanba 19:00 dan keyin Toshkentda allaqachon dushanba (yangi hafta)', () => {
    // 2026-11-08 yakshanba 18:59 UTC = Toshkent 23:59 yakshanba; 19:00 UTC = dushanba 00:00.
    expect(isoWeekStart(tashkentDay(at('2026-11-08T18:59:59.999Z')))).toBe('2026-11-02');
    expect(isoWeekStart(tashkentDay(at('2026-11-08T19:00:00.000Z')))).toBe('2026-11-09');
  });
});

describe('attemptDurationSeconds / cappedMinutes', () => {
  it('davomiylik soniyada; completedAt yo\'q yoki manfiy bo\'lsa 0', () => {
    expect(attemptDurationSeconds(attempt('2026-11-02', 7))).toBe(420);
    expect(attemptDurationSeconds({ startedAt: at('2026-11-02T10:00:00Z'), completedAt: null })).toBe(0);
    expect(
      attemptDurationSeconds({ startedAt: at('2026-11-02T10:00:00Z'), completedAt: at('2026-11-02T09:00:00Z') }),
    ).toBe(0);
  });

  it('har urinish 60 daqiqa bilan cheklanadi', () => {
    const long = attempt('2026-11-02', 600); // 10 soat
    expect(cappedMinutes([long])).toBe(MAX_ATTEMPT_MINUTES);
    expect(cappedMinutes([long, attempt('2026-11-02', 5)])).toBe(MAX_ATTEMPT_MINUTES + 5);
    expect(cappedMinutes([attempt('2026-11-02', 60), attempt('2026-11-03', 60.5)])).toBe(120);
  });

  it('yig\'indi yaxlitlanadi (har urinish emas): 30s + 30s = 1 daqiqa', () => {
    const half = (day: string): WeeklyAttempt => ({
      day,
      startedAt: at(`${day}T10:00:00Z`),
      completedAt: at(`${day}T10:00:30Z`),
    });
    expect(cappedMinutes([half('2026-11-02'), half('2026-11-03')])).toBe(1);
    expect(cappedMinutes([half('2026-11-02')])).toBe(1); // 0.5 → 1
    expect(cappedMinutes([])).toBe(0);
  });
});

describe('streakFromDays', () => {
  const days = (...d: string[]) => new Set(d);

  it('asOf kuni yechilgan bo\'lsa shundan, bo\'lmasa kechadan hisoblanadi', () => {
    const set = days('2026-11-01', '2026-11-02', '2026-11-03');
    expect(streakFromDays(set, '2026-11-03')).toBe(3);
    expect(streakFromDays(set, '2026-11-04')).toBe(3); // bugun hali yechilmagan
    expect(streakFromDays(set, '2026-11-05')).toBe(0); // kecha ham yo'q
  });

  it('asOf dan keyingi kunlar e\'tiborga olinmaydi', () => {
    const set = days('2026-11-01', '2026-11-02', '2026-11-03', '2026-11-04', '2026-11-05');
    expect(streakFromDays(set, '2026-11-02')).toBe(2);
  });
});

describe('buildWeeklyReport', () => {
  // Bugun: juma 2026-11-06 → joriy hafta 11-02..11-08, oldingi 10-26..11-01.
  const today = '2026-11-06';

  it('ikki hafta, eskisi birinchi; sessiya/daqiqa/faol kun/streak', () => {
    const attempts = [
      // oldingi hafta: 10-27, 10-28, 10-29, 10-31 (4 faol kun), 5 sessiya
      attempt('2026-10-27', 10),
      attempt('2026-10-28', 10),
      attempt('2026-10-29', 10),
      attempt('2026-10-29', 10, 14),
      attempt('2026-10-31', 12),
      // joriy hafta: 11-02, 11-03, 11-04 (3 faol kun), 4 sessiya
      attempt('2026-11-02', 10),
      attempt('2026-11-03', 10),
      attempt('2026-11-04', 10),
      attempt('2026-11-04', 14, 15),
    ];
    const completedDays = new Set(attempts.map((a) => a.day));
    const report = buildWeeklyReport({ today, attempts, completedDays });

    expect(report.weeks).toEqual([
      // streak oldingi hafta oxirigacha (yakshanba 11-01 yo'q → shanba 10-31: faqat 1 kun, 10-30 yo'q)
      { weekStart: '2026-10-26', sessions: 5, minutes: 52, activeDays: 4, streak: 1 },
      // joriy hafta: bugun (11-06) yechilmagan → kechadan: 11-05 yo'q → 0
      { weekStart: '2026-11-02', sessions: 4, minutes: 44, activeDays: 3, streak: 0 },
    ]);
    expect(report.firstWeek).toBe(false);
  });

  it('streak hafta oxirigacha: oldingi haftadan o\'tib davom etadigan zanjir', () => {
    const attempts = ['2026-10-30', '2026-10-31', '2026-11-01', '2026-11-02', '2026-11-03'].map((d) => attempt(d, 5));
    const completedDays = new Set(attempts.map((a) => a.day));
    const { weeks } = buildWeeklyReport({ today: '2026-11-03', attempts, completedDays });
    expect(weeks[0].streak).toBe(3); // 10-30, 10-31, 11-01 (yakshanba)
    expect(weeks[1].streak).toBe(5); // bugungacha, hafta chegarasidan o'tadi
  });

  it('bugun yechilgan bo\'lsa joriy streak bugundan; yechilmagan bo\'lsa kechadan', () => {
    const days = ['2026-11-04', '2026-11-05'];
    const attempts = days.map((d) => attempt(d, 5));
    const completedDays = new Set(days);
    expect(buildWeeklyReport({ today: '2026-11-05', attempts, completedDays }).weeks[1].streak).toBe(2);
    expect(buildWeeklyReport({ today: '2026-11-06', attempts, completedDays }).weeks[1].streak).toBe(2);
    expect(buildWeeklyReport({ today: '2026-11-07', attempts, completedDays }).weeks[1].streak).toBe(0);
  });

  it('yakshanba: hafta yakshanbada tugaydi; dushanba — yangi hafta, oldingi hafta endi shu hafta', () => {
    const sunday = attempt('2026-11-08', 20);
    const monday = attempt('2026-11-09', 20);
    const attempts = [sunday, monday];
    const completedDays = new Set(['2026-11-08', '2026-11-09']);

    const onSunday = buildWeeklyReport({ today: '2026-11-08', attempts: [sunday], completedDays: new Set(['2026-11-08']) });
    expect(onSunday.weeks[1]).toMatchObject({ weekStart: '2026-11-02', sessions: 1, activeDays: 1 });

    const onMonday = buildWeeklyReport({ today: '2026-11-09', attempts, completedDays });
    expect(onMonday.weeks[0]).toMatchObject({ weekStart: '2026-11-02', sessions: 1, streak: 1 });
    expect(onMonday.weeks[1]).toMatchObject({ weekStart: '2026-11-09', sessions: 1, streak: 2 });
  });

  it('ikki hafta tashqarisidagi urinishlar sessiyaga kirmaydi, lekin streakni uzaytiradi', () => {
    const old = attempt('2026-10-20', 30);
    const mine = attempt('2026-11-05', 5);
    const completedDays = new Set(['2026-10-20', '2026-11-05']);
    const { weeks } = buildWeeklyReport({ today: '2026-11-06', attempts: [old, mine], completedDays });
    expect(weeks[0].sessions).toBe(0);
    expect(weeks[1].sessions).toBe(1);
  });

  it('firstWeek: joriy haftadan oldin yakunlangan urinish yo\'q', () => {
    const only = attempt('2026-11-03', 5);
    const first = buildWeeklyReport({ today, attempts: [only], completedDays: new Set(['2026-11-03']) });
    expect(first.firstWeek).toBe(true);
    expect(first.weeks[0]).toEqual({ weekStart: '2026-10-26', sessions: 0, minutes: 0, activeDays: 0, streak: 0 });

    // Hech qachon test yechmagan bola ham firstWeek = true
    expect(buildWeeklyReport({ today, attempts: [], completedDays: new Set() }).firstWeek).toBe(true);

    // Oldingi haftaning oxirgi kuni (yakshanba) — endi firstWeek emas
    const prevSunday = buildWeeklyReport({
      today,
      attempts: [attempt('2026-11-01', 5)],
      completedDays: new Set(['2026-11-01']),
    });
    expect(prevSunday.firstWeek).toBe(false);

    // Ikki hafta oldingi urinish ham "oldin" hisoblanadi
    expect(buildWeeklyReport({ today, attempts: [], completedDays: new Set(['2026-10-01']) }).firstWeek).toBe(false);
  });

  it('daqiqalar: 60 daqiqalik chek hafta ichida qo\'llanadi', () => {
    const attempts = [attempt('2026-11-02', 500), attempt('2026-11-03', 8)];
    const { weeks } = buildWeeklyReport({
      today,
      attempts,
      completedDays: new Set(['2026-11-02', '2026-11-03']),
    });
    expect(weeks[1].minutes).toBe(68);
    expect(weeks[1].sessions).toBe(2);
  });

  it('yil chegarasidan o\'tuvchi hafta', () => {
    const { weeks } = buildWeeklyReport({ today: '2026-01-02', attempts: [], completedDays: new Set() });
    expect(weeks.map((w) => w.weekStart)).toEqual(['2025-12-22', '2025-12-29']);
  });
});
