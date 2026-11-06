// Bola logini brute-force'dan himoya: "15 daqiqada 5 ta xato parol -> 15 daqiqaga blok".
// Holat mashinasi sof funksiyalar bilan (vaqt `now` sifatida beriladi — soxta soat bilan sinaladi).
// Mavjud bo'lmagan loginlar uchun ham xuddi shu qoida xotirada ishlaydi ({@link GhostLoginLimiter}):
// shunda "5 urinishdan keyin 429" xatti-harakati login mavjudligini fosh qilmaydi.

import { FAILURE_WINDOW_MS, GHOST_LIMITER_MAX_ENTRIES, LOCK_MS, MAX_FAILED_LOGINS } from './child-auth.constants';

export interface LoginFailureState {
  failedLogins: number;
  /** Joriy xatolar oynasining boshlanishi (birinchi xato vaqti). */
  failedWindowStartedAt: Date | null;
  lockedUntil: Date | null;
}

export const CLEAN_LOGIN_STATE: Readonly<LoginFailureState> = Object.freeze({
  failedLogins: 0,
  failedWindowStartedAt: null,
  lockedUntil: null,
});

/** Blok tugashigacha qolgan soniyalar (>= 1), bloklanmagan bo'lsa 0. */
export function lockRemainingSeconds(state: Pick<LoginFailureState, 'lockedUntil'>, now: Date): number {
  if (!state.lockedUntil) return 0;
  const ms = state.lockedUntil.getTime() - now.getTime();
  return ms > 0 ? Math.max(1, Math.ceil(ms / 1000)) : 0;
}

/**
 * Xato parol qayd etilgandan keyingi holat. Blok davomida holat o'zgarmaydi.
 * Oyna (15 daqiqa) birinchi xatodan boshlanadi; 5-xatoda blok qo'yiladi va hisob nolga tushadi.
 */
export function registerFailure(state: LoginFailureState, now: Date): LoginFailureState {
  if (lockRemainingSeconds(state, now) > 0) return state;
  const windowOpen =
    state.failedWindowStartedAt !== null &&
    state.failedLogins > 0 &&
    now.getTime() - state.failedWindowStartedAt.getTime() <= FAILURE_WINDOW_MS;
  const failedLogins = windowOpen ? state.failedLogins + 1 : 1;
  if (failedLogins >= MAX_FAILED_LOGINS) {
    return { failedLogins: 0, failedWindowStartedAt: null, lockedUntil: new Date(now.getTime() + LOCK_MS) };
  }
  return {
    failedLogins,
    failedWindowStartedAt: windowOpen ? state.failedWindowStartedAt : now,
    lockedUntil: null,
  };
}

/** Xotiradagi hisob: mavjud bo'lmagan loginlar uchun bir xil qoida (restartda nolga tushadi). */
export class GhostLoginLimiter {
  private readonly entries = new Map<string, LoginFailureState>();

  constructor(private readonly maxEntries: number = GHOST_LIMITER_MAX_ENTRIES) {}

  lockRemainingSeconds(key: string, now: Date): number {
    const state = this.entries.get(key);
    return state ? lockRemainingSeconds(state, now) : 0;
  }

  recordFailure(key: string, now: Date): LoginFailureState {
    const next = registerFailure(this.entries.get(key) ?? CLEAN_LOGIN_STATE, now);
    this.entries.delete(key); // yangi yozuv Map oxiriga o'tadi (eng eskisi birinchi chiqadi)
    this.entries.set(key, next);
    if (this.entries.size > this.maxEntries) this.evict(now);
    return next;
  }

  get size(): number {
    return this.entries.size;
  }

  /** Avval eskirgan (oynasi tugagan, bloksiz) yozuvlar, yetmasa eng eskilari. */
  private evict(now: Date): void {
    for (const [key, state] of this.entries) {
      if (this.entries.size <= this.maxEntries) return;
      if (isIdle(state, now)) this.entries.delete(key);
    }
    for (const key of this.entries.keys()) {
      if (this.entries.size <= this.maxEntries) return;
      this.entries.delete(key);
    }
  }
}

function isIdle(state: LoginFailureState, now: Date): boolean {
  if (lockRemainingSeconds(state, now) > 0) return false;
  return !state.failedWindowStartedAt || now.getTime() - state.failedWindowStartedAt.getTime() > FAILURE_WINDOW_MS;
}
