// Bola kirishida IP bo'yicha himoya: faqat XATO urinishlar sanaladi (10 daqiqada 30 ta), muvaffaqiyatli kirish limitni
// yemaydi — maktab Wi-Fi'sida (NAT) bir vaqtda kirayotgan ko'p bola bir-biriga xalaqit bermaydi.
//  - child-login: INVALID_CREDENTIALS va LOCKED javoblari;
//  - child-setup: faqat SETUP_TOKEN_INVALID (zaif parol, muvaffaqiyat — sanalmaydi).
// Blok tekshiruvi parol tekshiruvidan (bcrypt) OLDIN — bloklangan IP uchun og'ir ish bajarilmaydi. Parallel "portlash"
// (xatolar hali yozilmagan, hamma urinish o'tib ketadi) bitta IP'dan bir vaqtdagi 50 ta urinish bilan cheklanadi.

import { HttpException, Injectable } from '@nestjs/common';
import { ChildAuthClock } from './child-auth-clock';
import {
  CHILD_LOGIN_IP_FAILURES,
  CHILD_LOGIN_IP_IN_FLIGHT,
  CHILD_LOGIN_IP_WINDOW_MS,
  IP_LIMITER_MAX_KEYS,
} from './child-auth.constants';
import { ipRateLimited } from './child-auth.errors';
import { SlidingFailureCounter } from './sliding-failure-counter';

export type IpLimitedAction = 'login' | 'setup';

/** Javob tanasidagi `code` (HttpException'da), bo'lmasa `undefined`. */
export function errorCode(err: unknown): string | undefined {
  if (!(err instanceof HttpException)) return undefined;
  const body = err.getResponse();
  return typeof body === 'object' && body !== null ? (body as { code?: string }).code : undefined;
}

/** Qaysi xato kodlari IP bo'yicha XATO urinish hisoblanadi. */
const FAILURE_CODES: Readonly<Record<IpLimitedAction, readonly string[]>> = {
  login: ['INVALID_CREDENTIALS', 'LOCKED'],
  setup: ['SETUP_TOKEN_INVALID'],
};

@Injectable()
export class ChildAuthIpLimits {
  private readonly counters: Record<IpLimitedAction, SlidingFailureCounter> = {
    login: new SlidingFailureCounter(CHILD_LOGIN_IP_FAILURES, CHILD_LOGIN_IP_WINDOW_MS, IP_LIMITER_MAX_KEYS),
    setup: new SlidingFailureCounter(CHILD_LOGIN_IP_FAILURES, CHILD_LOGIN_IP_WINDOW_MS, IP_LIMITER_MAX_KEYS),
  };

  /** Hozir bajarilayotgan urinishlar (`action:ip` bo'yicha) — parallel portlashdan himoya. */
  private readonly inFlight = new Map<string, number>();

  constructor(private readonly clock: ChildAuthClock) {}

  /**
   * `work`ni IP limiti bilan o'raydi: bloklangan IP'ga (30 xato / 10 daqiqa yoki 50 ta parallel urinish) 429 RATE_LIMITED
   * (ish bajarilmaydi); `work` hisobga olinadigan xato bilan tugasa — shu IP uchun xato yoziladi, xato o'zgarishsiz qayta tashlanadi.
   */
  async guard<T>(action: IpLimitedAction, ip: string | undefined, work: () => Promise<T>): Promise<T> {
    const key = ip?.trim() || 'unknown';
    const counter = this.counters[action];
    const now = this.clock.now().getTime();
    if (counter.blocked(key, now)) throw ipRateLimited(counter.retryAfterSeconds(key, now));
    const flightKey = `${action}:${key}`;
    const running = this.inFlight.get(flightKey) ?? 0;
    if (running >= CHILD_LOGIN_IP_IN_FLIGHT) throw ipRateLimited(1);
    this.inFlight.set(flightKey, running + 1);
    try {
      return await work();
    } catch (err) {
      const code = errorCode(err);
      if (code && FAILURE_CODES[action].includes(code)) counter.fail(key, this.clock.now().getTime());
      throw err;
    } finally {
      const left = (this.inFlight.get(flightKey) ?? 1) - 1;
      if (left <= 0) this.inFlight.delete(flightKey);
      else this.inFlight.set(flightKey, left);
    }
  }
}
