import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { PREF_PREFIX } from '@/lib/prefs';
import { __setClockForTests, type ClockState, getClockState, isStaleScenario, SCENARIO_END_MINUTE, scenarioEnded } from '../clock';

/** Node'da localStorage yo'q — sozlamalar uchun xotiradagi o'rinbosar. */
function memoryStorage(): Storage {
  const map = new Map<string, string>();
  return {
    get length() {
      return map.size;
    },
    clear: () => map.clear(),
    getItem: (k) => map.get(k) ?? null,
    key: (i) => [...map.keys()][i] ?? null,
    removeItem: (k) => void map.delete(k),
    setItem: (k, v) => void map.set(k, String(v)),
  };
}

const MINUTE = 60_000;
const DAY = 24 * 60 * MINUTE;
// Dushanba 2026-10-12, 20:30 (kechqurun — standart holat ssenariy).
const NOW = new Date(2026, 9, 12, 20, 30).getTime();

function scenario(partial: Partial<ClockState>): ClockState {
  return { mode: 'SCENARIO', speed: 10, scenarioDate: '2026-10-12', scenarioStartMinute: 7 * 60 + 45, realStartedAt: NOW, epoch: 5, ...partial };
}

describe('demo soati: eskirgan ssenariy', () => {
  it('bugun boshlangan ssenariy eskirmagan', () => {
    expect(isStaleScenario(scenario({}), NOW)).toBe(false);
  });

  it('o\'tgan haftadagi ssenariy (kecha yoki undan oldin boshlangan) — eskirgan', () => {
    expect(isStaleScenario(scenario({ scenarioDate: '2026-10-05', realStartedAt: NOW - 7 * DAY }), NOW)).toBe(true);
  });

  it('dushanba tunda: juma ssenariysi (yakshanba boshlangan) eskirmagan, payshanba — eskirgan', () => {
    const mondayNight = new Date(2026, 9, 12, 0, 5).getTime();
    const sundayLate = new Date(2026, 9, 11, 23, 55).getTime();
    const friday = scenario({ scenarioDate: '2026-10-09', realStartedAt: sundayLate, speed: 1 });
    expect(isStaleScenario(friday, mondayNight)).toBe(false);
    expect(isStaleScenario({ ...friday, scenarioDate: '2026-10-08' }, mondayNight)).toBe(true);
  });

  it('19:00 da 10 daqiqadan ko\'p turib qolgan — eskirgan; 5 daqiqa — yo\'q', () => {
    const atEnd = (minutesAgo: number) =>
      scenario({ speed: 60, scenarioStartMinute: SCENARIO_END_MINUTE - 60, realStartedAt: NOW - MINUTE - minutesAgo * MINUTE });
    expect(isStaleScenario(atEnd(5), NOW)).toBe(false);
    expect(isStaleScenario(atEnd(11), NOW)).toBe(true);
  });

  it('haqiqiy vaqt rejimi hech qachon eskirmaydi', () => {
    expect(isStaleScenario({ ...scenario({ scenarioDate: '2020-01-01', realStartedAt: 0 }), mode: 'REAL' }, NOW)).toBe(false);
  });
});

describe('demo soati: yuklash va 19:00 holati', () => {
  beforeEach(() => {
    vi.stubGlobal('window', { localStorage: memoryStorage() });
    vi.useFakeTimers();
    vi.setSystemTime(NOW);
    __setClockForTests(null);
  });

  afterEach(() => {
    __setClockForTests(null);
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it('saqlangan eskirgan ssenariy yuklanganda yangi ertalab (yangi epoch) boshlanadi', () => {
    const stale = scenario({ scenarioDate: '2026-10-01', realStartedAt: NOW - 11 * DAY, epoch: 3 });
    window.localStorage.setItem(`${PREF_PREFIX}clock`, JSON.stringify(stale));
    const state = getClockState();
    expect(state.scenarioDate).toBe('2026-10-12');
    expect(state.epoch).not.toBe(3);
    expect(state.realStartedAt).toBe(NOW);
    expect(JSON.parse(window.localStorage.getItem(`${PREF_PREFIX}clock`) ?? '{}').epoch).toBe(state.epoch);
  });

  it('yangi ssenariy saqlanadi va o\'zgarmaydi', () => {
    const fresh = scenario({ epoch: 9, realStartedAt: NOW - 5 * MINUTE });
    window.localStorage.setItem(`${PREF_PREFIX}clock`, JSON.stringify(fresh));
    expect(getClockState().epoch).toBe(9);
  });

  it('scenarioEnded: 19:00 da true, undan oldin false', () => {
    __setClockForTests(scenario({ speed: 60, scenarioStartMinute: SCENARIO_END_MINUTE - 30, realStartedAt: NOW }));
    expect(scenarioEnded()).toBe(false);
    vi.setSystemTime(NOW + 31 * 1000);
    expect(scenarioEnded()).toBe(true);
    __setClockForTests({ mode: 'REAL' });
    expect(scenarioEnded()).toBe(false);
  });
});
