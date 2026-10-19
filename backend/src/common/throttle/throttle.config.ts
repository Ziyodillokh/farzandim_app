import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ThrottlerOptions } from '@nestjs/throttler';

import { isReviewFamilyCode } from '../helpers/review-family-codes';

// ─────────────────────────────────────────────────────────────────────
// Nomli rate-limit'lar — YAGONA manba (AppModule `ThrottlerModule.forRoot`).
// ─────────────────────────────────────────────────────────────────────
//
// ⚠️ ThrottlerGuard ro'yxatdan o'tgan BARCHA nomli limitlarni har bir
// himoyalangan route'ga qo'llaydi (faqat `@SkipThrottle` bilan o'chiriladi).
// Shu sabab 2026-08-10 da `checkout` (5/10daq) limiti `child-pair`ga, keyin
// esa `adminLogin` (5/10daq) ham `child-pair`ga tushib, reviewer 5-urinishdan
// keyin 429 olardi (App Store audit F8). Endi har limit FAQAT o'zi `@Throttle`
// bilan e'lon qilingan route'da ishlaydi (`skipIf` pastda) — yangi nomli limit
// qo'shilsa ham boshqa route'larga "sizib" o'tmaydi.

export const THROTTLER_NAMES = {
  childPair: 'childPair',
  childPairCode: 'childPairCode',
  checkout: 'checkout',
  adminLogin: 'adminLogin',
  schoolLogin: 'schoolLogin',
} as const;

const TEN_MINUTES_MS = 600_000;

/** child-pair: bitta (haqiqiy) IP'dan 10 daqiqada max urinishlar. */
export const CHILD_PAIR_IP_LIMIT = { limit: 20, ttl: TEN_MINUTES_MS };
/**
 * child-pair: bitta OILA KODIGA 10 daqiqada max urinishlar (IP'dan qat'i
 * nazar). IP'ni almashtirib bitta kodni bosib olishga va "ALREADY_PAIRED"
 * spam'iga qarshi; demo kodni bir nechta qurilmada ulash uchun yetarli.
 */
export const CHILD_PAIR_CODE_LIMIT = { limit: 10, ttl: TEN_MINUTES_MS };
/** Uzum IB anti-fraud talabi — foydalanuvchi boshiga (CheckoutThrottlerGuard). */
export const CHECKOUT_LIMIT = { limit: 5, ttl: TEN_MINUTES_MS };
/** Admin panel parolini brute-force qilishga qarshi (IP + email). */
export const ADMIN_LOGIN_LIMIT = { limit: 5, ttl: TEN_MINUTES_MS };
/**
 * Maktab paneli kirishi (IP bo'yicha). Bitta maktabda ko'p xodim bitta
 * IP (NAT) orqali kirishi mumkin — limit kengroq; hisob darajasida esa
 * ketma-ket xatolardan keyin vaqtincha bloklanadi (SchoolAuthService).
 */
export const SCHOOL_LOGIN_LIMIT = { limit: 30, ttl: TEN_MINUTES_MS };

const THROTTLER_LIMIT_KEY = 'THROTTLER:LIMIT';
const reflector = new Reflector();

/** Route (handler yoki controller) shu nomli limitni `@Throttle` bilan e'lon qilganmi. */
export function isThrottlerDeclared(
  context: ExecutionContext,
  name: string,
): boolean {
  const declared = reflector.getAllAndOverride<unknown>(
    THROTTLER_LIMIT_KEY + name,
    [context.getHandler(), context.getClass()],
  );
  return declared !== undefined;
}

/** child-pair body'sidagi oila kodi bo'yicha kuzatuv (bo'lmasa IP). */
export function familyCodeTracker(req: Record<string, any>): string {
  const raw = (req as { body?: { familyCode?: unknown } }).body?.familyCode;
  const code = typeof raw === 'string' ? raw.trim().slice(0, 16) : '';
  return code ? `family:${code}` : `ip:${String(req.ip ?? 'unknown')}`;
}

function onlyWhereDeclared(name: string): ThrottlerOptions['skipIf'] {
  return (context: ExecutionContext) => !isThrottlerDeclared(context, name);
}

/**
 * Do'kon tekshiruvchisining demo kodi per-code limitdan ozod: aks holda
 * begona kimdir shu kod bilan 10 ta so'rov yuborib, reviewer'ni 10 daqiqaga
 * bloklab qo'yishi mumkin edi. IP bo'yicha limit baribir ishlaydi.
 */
export function isReviewCodeRequest(context: ExecutionContext): boolean {
  const body = context.switchToHttp().getRequest<{ body?: { familyCode?: unknown } }>()?.body;
  const code = typeof body?.familyCode === 'string' ? body.familyCode.trim() : '';
  return code.length > 0 && isReviewFamilyCode(code);
}

export function buildThrottlers(): ThrottlerOptions[] {
  return [
    {
      name: THROTTLER_NAMES.childPair,
      ...CHILD_PAIR_IP_LIMIT,
      skipIf: onlyWhereDeclared(THROTTLER_NAMES.childPair),
    },
    {
      name: THROTTLER_NAMES.childPairCode,
      ...CHILD_PAIR_CODE_LIMIT,
      getTracker: familyCodeTracker,
      skipIf: (context: ExecutionContext) =>
        !isThrottlerDeclared(context, THROTTLER_NAMES.childPairCode) ||
        isReviewCodeRequest(context),
    },
    {
      name: THROTTLER_NAMES.checkout,
      ...CHECKOUT_LIMIT,
      skipIf: onlyWhereDeclared(THROTTLER_NAMES.checkout),
    },
    {
      name: THROTTLER_NAMES.adminLogin,
      ...ADMIN_LOGIN_LIMIT,
      skipIf: onlyWhereDeclared(THROTTLER_NAMES.adminLogin),
    },
    {
      name: THROTTLER_NAMES.schoolLogin,
      ...SCHOOL_LOGIN_LIMIT,
      skipIf: onlyWhereDeclared(THROTTLER_NAMES.schoolLogin),
    },
  ];
}
