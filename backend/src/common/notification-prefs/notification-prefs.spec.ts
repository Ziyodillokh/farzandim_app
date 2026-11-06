import {
  DEFAULT_PREFS,
  dueReminderTimes,
  formatHhMm,
  isQuietAt,
  isValidReminderTime,
  parseHhMm,
  reminderDueNow,
  resolvePrefs,
  tashkentMinutesOfDay,
} from './notification-prefs';

describe('isValidReminderTime', () => {
  it.each(['06:00', '12:30', '18:00', '21:00'])('accepts %s (inside 06:00-21:00)', (value) => {
    expect(isValidReminderTime(value)).toBe(true);
  });

  it.each(['05:59', '21:01', '00:00', '23:59'])('rejects %s (outside the allowed range)', (value) => {
    expect(isValidReminderTime(value)).toBe(false);
  });

  it.each(['6:00', '18:0', '18-00', '1800', '24:00', '18:60', ' 18:00', '18:00 ', ''])(
    'rejects malformed value %p',
    (value) => {
      expect(isValidReminderTime(value)).toBe(false);
    },
  );

  it.each([null, undefined, 18, true, {}, ['18:00']])('rejects non-string value %p', (value) => {
    expect(isValidReminderTime(value)).toBe(false);
  });
});

describe('parseHhMm / formatHhMm', () => {
  it('parses HH:MM into minutes and formats it back', () => {
    expect(parseHhMm('18:05')).toBe(18 * 60 + 5);
    expect(formatHhMm(18 * 60 + 5)).toBe('18:05');
    expect(formatHhMm(0)).toBe('00:00');
  });

  it('accepts a one-digit hour (legacy quiet hours) but not impossible times', () => {
    expect(parseHhMm('7:30')).toBe(7 * 60 + 30);
    expect(parseHhMm('25:00')).toBeNull();
    expect(parseHhMm('10:75')).toBeNull();
    expect(parseHhMm(null)).toBeNull();
  });
});

describe('tashkentMinutesOfDay', () => {
  it('converts a UTC instant to the Tashkent (UTC+5) minute of the day', () => {
    // 13:00 UTC = 18:00 Tashkent
    expect(tashkentMinutesOfDay(new Date('2026-11-06T13:00:00Z'))).toBe(18 * 60);
  });

  it('rolls over midnight into the next Tashkent day', () => {
    // 19:30 UTC = 00:30 Tashkent (next day)
    expect(tashkentMinutesOfDay(new Date('2026-11-06T19:30:00Z'))).toBe(30);
  });
});

describe('isQuietAt', () => {
  it('detects a same-day window', () => {
    expect(isQuietAt('13:00', '15:00', 14 * 60)).toBe(true);
    expect(isQuietAt('13:00', '15:00', 15 * 60)).toBe(false);
  });

  it('detects a window that wraps past midnight', () => {
    expect(isQuietAt('22:00', '08:00', 23 * 60)).toBe(true);
    expect(isQuietAt('22:00', '08:00', 3 * 60)).toBe(true);
    expect(isQuietAt('22:00', '08:00', 12 * 60)).toBe(false);
  });

  it('is never quiet when a bound is missing, malformed or both are equal', () => {
    expect(isQuietAt(null, '08:00', 60)).toBe(false);
    expect(isQuietAt('22:00', 'bad', 23 * 60)).toBe(false);
    expect(isQuietAt('10:00', '10:00', 10 * 60)).toBe(false);
  });
});

describe('reminderDueNow', () => {
  const catchUp = 5;

  it('is due exactly at the reminder time', () => {
    expect(reminderDueNow('18:00', 18 * 60, catchUp)).toBe(true);
  });

  it('is still due within the catch-up window after the reminder time', () => {
    expect(reminderDueNow('18:00', 18 * 60 + 4, catchUp)).toBe(true);
  });

  it('is not due before the reminder time or after the catch-up window', () => {
    expect(reminderDueNow('18:00', 18 * 60 - 1, catchUp)).toBe(false);
    expect(reminderDueNow('18:00', 18 * 60 + 5, catchUp)).toBe(false);
  });

  it('is never due for an unparsable time', () => {
    expect(reminderDueNow('soon', 18 * 60, catchUp)).toBe(false);
  });
});

describe('dueReminderTimes', () => {
  it('lists the HH:MM values of the last catch-up minutes including now', () => {
    expect(dueReminderTimes(18 * 60 + 2, 5)).toEqual(['17:58', '17:59', '18:00', '18:01', '18:02']);
  });

  it('does not wrap before midnight', () => {
    expect(dueReminderTimes(2, 5)).toEqual(['00:00', '00:01', '00:02']);
  });

  it('agrees with reminderDueNow for every minute of a day', () => {
    for (let now = 0; now < 24 * 60; now += 7) {
      const listed = new Set(dueReminderTimes(now, 5));
      for (let at = 6 * 60; at <= 21 * 60; at += 1) {
        expect(listed.has(formatHhMm(at))).toBe(reminderDueNow(formatHhMm(at), now, 5));
      }
    }
  });
});

describe('resolvePrefs', () => {
  it('returns the documented defaults when there is no row', () => {
    expect(resolvePrefs(null)).toEqual({
      studyNudge: true,
      healthNudge: true,
      contentReminder: true,
      quietFrom: null,
      quietTo: null,
      homeworkReminder: true,
      schoolAnnouncements: true,
      familyMessages: true,
      dailyReminder: true,
      dailyReminderTime: '18:00',
      hideText: true,
    });
  });

  it('keeps stored values and exposes only the known fields', () => {
    const row = { hideText: false, dailyReminderTime: '07:15', id: 'x', lastStudyNudgeAt: new Date() };

    const prefs = resolvePrefs(row);

    expect(prefs.hideText).toBe(false);
    expect(prefs.dailyReminderTime).toBe('07:15');
    expect(prefs.familyMessages).toBe(true);
    expect(Object.keys(prefs).sort()).toEqual(Object.keys(DEFAULT_PREFS).sort());
  });

  it('returns a fresh object each time (defaults cannot be mutated through it)', () => {
    const first = resolvePrefs(null);
    first.hideText = false;

    expect(resolvePrefs(null).hideText).toBe(true);
    expect(DEFAULT_PREFS.hideText).toBe(true);
  });
});
