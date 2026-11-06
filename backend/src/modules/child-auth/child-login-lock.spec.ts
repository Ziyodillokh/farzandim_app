import { FAILURE_WINDOW_MS, LOCK_MS, MAX_FAILED_LOGINS } from './child-auth.constants';
import {
  CLEAN_LOGIN_STATE,
  GhostLoginLimiter,
  LoginFailureState,
  lockRemainingSeconds,
  registerFailure,
} from './child-login-lock';

const MIN = 60_000;
const T0 = new Date('2026-11-09T09:00:00.000Z');
const at = (ms: number) => new Date(T0.getTime() + ms);

/** `n` ta ketma-ket xato; har biri `stepMs` farq bilan. */
function failTimes(n: number, stepMs = 1_000, from: LoginFailureState = CLEAN_LOGIN_STATE): LoginFailureState {
  let state = from;
  for (let i = 0; i < n; i++) state = registerFailure(state, at(i * stepMs));
  return state;
}

describe('registerFailure', () => {
  it('does not lock before the fifth wrong password', () => {
    const state = failTimes(MAX_FAILED_LOGINS - 1);

    expect(state.failedLogins).toBe(4);
    expect(state.lockedUntil).toBeNull();
    expect(lockRemainingSeconds(state, at(5_000))).toBe(0);
  });

  it('locks for 15 minutes on the fifth wrong password within the window and clears the counter', () => {
    const state = failTimes(MAX_FAILED_LOGINS);

    expect(state.lockedUntil).toEqual(at((MAX_FAILED_LOGINS - 1) * 1_000 + LOCK_MS));
    expect(state.failedLogins).toBe(0);
    expect(state.failedWindowStartedAt).toBeNull();
    expect(lockRemainingSeconds(state, at(4_000))).toBe(15 * 60);
  });

  it('does not change a locked state (attempts while locked are not counted)', () => {
    const locked = failTimes(MAX_FAILED_LOGINS);

    expect(registerFailure(locked, at(10_000))).toBe(locked);
    expect(registerFailure(locked, at(5 * MIN))).toBe(locked);
  });

  it('starts a new window when the previous one ended more than 15 minutes ago', () => {
    const first = failTimes(4);
    const next = registerFailure(first, at(FAILURE_WINDOW_MS + 10_000));

    expect(next.failedLogins).toBe(1);
    expect(next.failedWindowStartedAt).toEqual(at(FAILURE_WINDOW_MS + 10_000));
    expect(next.lockedUntil).toBeNull();
  });

  it('counts five failures spread over the window as one lock, but spread over longer — not', () => {
    // 1-xato 0:00, qolgan to'rttasi 14:59 gacha -> blok
    let state = registerFailure(CLEAN_LOGIN_STATE, at(0));
    for (const minute of [3, 6, 9, 14]) state = registerFailure(state, at(minute * MIN));
    expect(state.lockedUntil).not.toBeNull();

    // Har 4 daqiqada bitta xato: oyna birinchi xatodan 15 daqiqada tugaydi -> 5-xato bloklamaydi
    let slow: LoginFailureState = CLEAN_LOGIN_STATE;
    for (let i = 0; i < 5; i++) slow = registerFailure(slow, at(i * 4 * MIN));
    expect(slow.lockedUntil).toBeNull();
    expect(slow.failedLogins).toBeLessThan(MAX_FAILED_LOGINS);
  });

  it('treats an expired lock as unlocked and starts counting from one again', () => {
    const locked = failTimes(MAX_FAILED_LOGINS);
    const later = at(4_000 + LOCK_MS + 1_000);

    expect(lockRemainingSeconds(locked, later)).toBe(0);
    const next = registerFailure(locked, later);
    expect(next.failedLogins).toBe(1);
    expect(next.lockedUntil).toBeNull();
  });
});

describe('lockRemainingSeconds', () => {
  it('rounds up to whole seconds and is never zero while locked', () => {
    const state = { lockedUntil: at(1_200) };

    expect(lockRemainingSeconds(state, at(0))).toBe(2);
    expect(lockRemainingSeconds(state, at(1_199))).toBe(1);
    expect(lockRemainingSeconds(state, at(1_200))).toBe(0);
    expect(lockRemainingSeconds({ lockedUntil: null }, at(0))).toBe(0);
  });
});

describe('GhostLoginLimiter (mavjud bo\'lmagan loginlar uchun xotiradagi blok)', () => {
  it('behaves exactly like a real credential: 429 from the fifth failure on, for 15 minutes', () => {
    const ghost = new GhostLoginLimiter();
    let lastRemaining = 0;
    for (let i = 0; i < MAX_FAILED_LOGINS; i++) {
      ghost.recordFailure('nobody.x00', at(i * 1_000));
      lastRemaining = ghost.lockRemainingSeconds('nobody.x00', at(i * 1_000));
    }

    expect(lastRemaining).toBe(15 * 60);
    expect(ghost.lockRemainingSeconds('nobody.x00', at(14 * MIN))).toBeGreaterThan(0);
    expect(ghost.lockRemainingSeconds('nobody.x00', at(4_000 + LOCK_MS + 1))).toBe(0);
  });

  it('tracks logins independently', () => {
    const ghost = new GhostLoginLimiter();
    for (let i = 0; i < MAX_FAILED_LOGINS; i++) ghost.recordFailure('one.a11', at(i));

    expect(ghost.lockRemainingSeconds('one.a11', at(10))).toBeGreaterThan(0);
    expect(ghost.lockRemainingSeconds('two.b22', at(10))).toBe(0);
  });

  it('is bounded: stale entries are evicted first, and locked ones survive', () => {
    const ghost = new GhostLoginLimiter(3);
    // 'locked' 10:00 da bloklanadi -> 25:00 gacha; 'stale' 0:00 dagi bitta xato (oynasi 15:00 da tugagan).
    for (let i = 0; i < MAX_FAILED_LOGINS; i++) ghost.recordFailure('locked.a1', at(10 * MIN + i));
    ghost.recordFailure('stale.b2', at(0));
    ghost.recordFailure('fresh.c3', at(16 * MIN));
    expect(ghost.size).toBe(3);

    // 4-yozuv sig'maydi: 'stale' chiqib ketadi, bloklangan va yangi saqlanadi.
    ghost.recordFailure('another.d4', at(17 * MIN));

    expect(ghost.size).toBe(3);
    expect(ghost.lockRemainingSeconds('locked.a1', at(17 * MIN))).toBeGreaterThan(0);
    expect(ghost.lockRemainingSeconds('stale.b2', at(17 * MIN))).toBe(0);
  });

  it('never grows beyond its capacity even if every entry is still active', () => {
    const ghost = new GhostLoginLimiter(5);
    for (let i = 0; i < 50; i++) ghost.recordFailure(`user.${i}`, at(i));

    expect(ghost.size).toBe(5);
  });
});
