// Bola ilovasida o'quvchi kodini kiritish: 6 raqamli maydon kichik, shuning uchun tanlab topishga qarshi FAQAT
// XATO urinishlar sanaladi — bola profili bo'yicha 15 daqiqada 5 ta, bitta IP bo'yicha 60 ta (maktab Wi-Fi'si / NAT ortida
// ko'p bola bor). Limit to'lgach
// to'g'ri kod ham 429 `LOCKED` oladi (`retryAfterSeconds` bilan). Muvaffaqiyatli kiritish limitni yemaydi.
// Backend bitta instance — xotira yetarli (`FailureLimiter` bilan bir xil yondashuv).

import { Injectable } from '@nestjs/common';
import { CodeInvalidException, locked } from './link-errors';
import { KeyedMutex } from './keyed-mutex';
import { FailureLimiter } from './redeem-limiter';

export const LINK_WINDOW_MS = 15 * 60_000;
export const CHILD_FAILURES = 5;
export const IP_FAILURES = 60;

const MS_IN_SECOND = 1000;

@Injectable()
export class LinkAttemptLimiter {
  private readonly byChild = new FailureLimiter(CHILD_FAILURES, LINK_WINDOW_MS);
  private readonly byIp = new FailureLimiter(IP_FAILURES, LINK_WINDOW_MS);
  private readonly mutex = new KeyedMutex();

  /**
   * Bitta urinish: bola va IP bo'yicha ketma-ket (parallel so'rovlar limitni aylanib o'ta olmaydi) —
   * bloklangan bo'lsa 429 `LOCKED`, aks holda `run` bajariladi va `CODE_INVALID` xatosi hisobga qo'shiladi.
   */
  guarded<T>(childId: string, ip: string, run: () => Promise<T>): Promise<T> {
    return this.mutex.runExclusive([childKey(childId), ipKey(ip)], async () => {
      const wait = this.retryAfterSeconds(childId, ip);
      if (wait > 0) throw locked(wait);
      try {
        return await run();
      } catch (err) {
        if (err instanceof CodeInvalidException) this.fail(childId, ip);
        throw err;
      }
    });
  }

  /** Bloklangan bo'lsa — qolgan soniya (kamida 1), aks holda 0. */
  retryAfterSeconds(childId: string, ip: string, now = Date.now()): number {
    const ms = Math.max(this.byChild.retryAfterMs(childKey(childId), now), this.byIp.retryAfterMs(ipKey(ip), now));
    return ms > 0 ? Math.max(1, Math.ceil(ms / MS_IN_SECOND)) : 0;
  }

  fail(childId: string, ip: string, now = Date.now()): void {
    this.byChild.fail(childKey(childId), now);
    this.byIp.fail(ipKey(ip), now);
  }

  /** Barcha hisobni tozalaydi (testlar uchun). */
  reset(): void {
    this.byChild.clear();
    this.byIp.clear();
  }
}

const childKey = (childId: string) => `child:${childId}`;
const ipKey = (ip: string) => `ip:${ip}`;
