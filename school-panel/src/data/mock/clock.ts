import type { IsoDate } from '@/data/contracts';
import { readPref, writePref } from '@/lib/prefs';
import { addDays, isoWeekday, toIsoDate } from './calendar';

/**
 * Demo soati. REAL — haqiqiy vaqt. SCENARIO — tanlangan o'quv kuni 07:45 dan
 * boshlab 1×/10×/60× tezlikda "o'tadi" (kechqurun ham ertalabki kirishlar
 * jonli ko'rinsin). Holat brauzerda eslab qolinadi.
 */
export type ClockMode = 'REAL' | 'SCENARIO';
export type ClockSpeed = 1 | 10 | 60;
export const CLOCK_SPEEDS: readonly ClockSpeed[] = [1, 10, 60];
export const SCENARIO_START_MINUTE = 7 * 60 + 45;
const SCENARIO_END_MINUTE = 19 * 60;

type ClockState = {
  mode: ClockMode;
  speed: ClockSpeed;
  scenarioDate: IsoDate;
  scenarioStartMinute: number;
  realStartedAt: number;
  /** Har "ertalabni qaytadan boshlash" — simulyator shu kunni tozalaydi. */
  epoch: number;
};

const PREF_KEY = 'clock';
type Listener = () => void;
const listeners = new Set<Listener>();
let state: ClockState | null = null;

/** Eng yaqin o'tgan (yoki bugungi) dushanba–juma kuni. */
function lastWeekday(today: IsoDate, holidays: readonly IsoDate[]): IsoDate {
  let d = today;
  for (let i = 0; i < 14; i++) {
    if (isoWeekday(d) <= 5 && !holidays.includes(d)) return d;
    d = addDays(d, -1);
  }
  return today;
}

const LIVE_DAY_START = 7 * 60;
const LIVE_DAY_END = 18 * 60;

/**
 * Birinchi ochilishda: ish kuni 07:00–18:00 bo'lsa — haqiqiy vaqt, aks holda
 * (kechqurun, dam olish) — "ertalab 07:45" ssenariysi, taqdimotda panel jonli ko'rinsin.
 */
function isLiveHours(now: Date): boolean {
  const minute = now.getHours() * 60 + now.getMinutes();
  return isoWeekday(toIsoDate(now)) <= 5 && minute >= LIVE_DAY_START && minute < LIVE_DAY_END;
}

function defaultState(): ClockState {
  const now = new Date();
  const live = isLiveHours(now);
  return {
    mode: live ? 'REAL' : 'SCENARIO',
    speed: 10,
    scenarioDate: live ? toIsoDate(now) : lastWeekday(toIsoDate(now), []),
    scenarioStartMinute: SCENARIO_START_MINUTE,
    realStartedAt: Date.now(),
    // Ssenariy yangi "kun" sifatida o'ynaladi (simulyator kaliti date#epoch).
    epoch: live ? 0 : Date.now(),
  };
}

function load(): ClockState {
  if (state) return state;
  const saved = readPref<ClockState>(PREF_KEY);
  if (saved && (saved.mode === 'REAL' || saved.mode === 'SCENARIO')) {
    state = { ...defaultState(), ...saved };
    return state;
  }
  state = defaultState();
  // Ssenariy saqlanadi — yangi tab (kiosk) va qayta yuklashda vaqt boshidan boshlanmasin.
  // Haqiqiy vaqt saqlanmaydi: keyingi ochilish kechqurun bo'lsa, yana ssenariy tanlanadi.
  if (state.mode === 'SCENARIO') writePref(PREF_KEY, state);
  return state;
}

function save(next: ClockState): void {
  state = next;
  writePref(PREF_KEY, next);
  for (const l of listeners) l();
}

function scenarioMinute(s: ClockState): number {
  const elapsed = ((Date.now() - s.realStartedAt) / 60000) * s.speed;
  return Math.min(SCENARIO_END_MINUTE, s.scenarioStartMinute + elapsed);
}

/** Demo vaqti (SCENARIO'da virtual). */
export function clockNow(): Date {
  const s = load();
  if (s.mode === 'REAL') return new Date();
  const [y, m, d] = s.scenarioDate.split('-').map(Number);
  const minute = scenarioMinute(s);
  return new Date(y ?? 2026, (m ?? 1) - 1, d ?? 1, Math.floor(minute / 60), Math.floor(minute % 60), Math.floor((minute % 1) * 60));
}

export function clockToday(): IsoDate {
  return toIsoDate(clockNow());
}

/** Kun boshidan daqiqa (kasr bilan). */
export function clockMinute(): number {
  const n = clockNow();
  return n.getHours() * 60 + n.getMinutes() + n.getSeconds() / 60;
}

export function getClockState(): Readonly<ClockState> {
  return load();
}

export function setClockMode(mode: ClockMode, holidays: readonly IsoDate[] = []): void {
  const s = load();
  if (mode === s.mode) return;
  if (mode === 'SCENARIO') {
    save({
      ...s,
      mode,
      scenarioDate: lastWeekday(toIsoDate(new Date()), holidays),
      scenarioStartMinute: SCENARIO_START_MINUTE,
      realStartedAt: Date.now(),
      epoch: s.epoch + 1,
    });
  } else {
    save({ ...s, mode });
  }
}

export function setClockSpeed(speed: ClockSpeed): void {
  const s = load();
  if (s.mode === 'SCENARIO') {
    save({ ...s, speed, scenarioStartMinute: scenarioMinute(s), realStartedAt: Date.now() });
  } else {
    save({ ...s, speed });
  }
}

export function restartMorning(holidays: readonly IsoDate[] = []): void {
  const s = load();
  save({
    ...s,
    mode: 'SCENARIO',
    scenarioDate: s.mode === 'SCENARIO' ? s.scenarioDate : lastWeekday(toIsoDate(new Date()), holidays),
    scenarioStartMinute: SCENARIO_START_MINUTE,
    realStartedAt: Date.now(),
    epoch: s.epoch + 1,
  });
}

/**
 * Boshqa tab (kiosk) soatni o'zgartirsa ("ertalabni qayta boshlash", tezlik) —
 * shu tab ham o'sha holatga o'tadi, aks holda eski epoch bilan kunni qayta tozalardi.
 */
let clockSyncBound = false;
export function bindClockSync(): void {
  if (clockSyncBound || typeof window === 'undefined') return;
  clockSyncBound = true;
  window.addEventListener('storage', (event) => {
    if (event.key !== `parvoz-school:${PREF_KEY}`) return;
    const saved = readPref<ClockState>(PREF_KEY);
    if (!saved || (saved.mode !== 'REAL' && saved.mode !== 'SCENARIO')) return;
    state = { ...defaultState(), ...saved };
    for (const l of listeners) l();
  });
}

export function subscribeClock(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

/** Faqat testlar uchun. */
export function __setClockForTests(next: Partial<ClockState> | null): void {
  state = next ? { ...defaultState(), ...next } : null;
}
