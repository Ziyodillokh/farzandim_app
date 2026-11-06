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
  schoolLink: 'schoolLink',
  dataDeletion: 'dataDeletion',
  childRecoveryLogin: 'childRecoveryLogin',
  childRecoveryIp: 'childRecoveryIp',
  childPasswordChange: 'childPasswordChange',
  childCredentialIssue: 'childCredentialIssue',
} as const;

const TEN_MINUTES_MS = 600_000;
const FIFTEEN_MINUTES_MS = 900_000;
const ONE_DAY_MS = 86_400_000;

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
/**
 * Ota-ona ilovasida maktab taklif kodini kiritish (IP bo'yicha, umumiy
 * so'rovlar). Bitta maktab Wi-Fi'sidan ko'p ota-ona kirishi mumkin — keng;
 * tanlab topishga qarshi asosiy himoya — faqat XATOLARni sanaydigan
 * foydalanuvchi / IP limiti (`ParentLinksService`) va 8 belgili kod.
 */
export const SCHOOL_LINK_LIMIT = { limit: 30, ttl: TEN_MINUTES_MS };

/**
 * Bola ma'lumotlarini o'chirish so'rovi (Men I09): foydalanuvchi boshiga (UserThrottlerGuard) sutkada
 * 3 ta so'rov — takroriy (idempotent) javoblar ham hisobga olinadi. Faqat shu route'da `@Throttle` bilan e'lon qilingan.
 */
export const DATA_DELETION_LIMIT = { limit: 3, ttl: ONE_DAY_MS };

// Bola kirishi (child-login / child-setup) uchun IP limiti bu yerda EMAS: u faqat XATO urinishlarni sanaydi (10 daqiqada 30 ta,
// muvaffaqiyatli kirish limitni yemaydi) va `modules/child-auth/child-ip-limits.ts` da. Hisob darajasidagi himoya alohida:
// 15 daqiqada 5 xato -> blok (`ChildLoginService`).

/** Kirish maʼlumotlarini tiklash so'rovi: bitta LOGIN (matn, mavjudligidan qat'i nazar) uchun sutkada 3 ta. */
export const CHILD_RECOVERY_LOGIN_LIMIT = { limit: 3, ttl: ONE_DAY_MS };
/**
 * Bola parolini almashtirish (`POST /auth/child/password`): foydalanuvchi boshiga 15 daqiqada 10 ta. O'g'irlangan access token
 * bilan joriy parolni parallel taxmin qilib bo'lmasin (har urinish bcrypt) — blok hisobi alohida (`ChildLoginAttempts`).
 */
export const CHILD_PASSWORD_CHANGE_LIMIT = { limit: 10, ttl: FIFTEEN_MINUTES_MS };
/** Ota-onaning bola kirish maʼlumotini berishi / tiklashi: foydalanuvchi boshiga 10 daqiqada 20 ta (loginlarni sinab ko'rishga qarshi). */
export const CHILD_CREDENTIAL_ISSUE_LIMIT = { limit: 20, ttl: TEN_MINUTES_MS };

/** Kirish maʼlumotlarini tiklash so'rovi: bitta IP'dan sutkada 30 ta (maktab Wi-Fi'si ortidagi ko'p bola). */
export const CHILD_RECOVERY_IP_LIMIT = { limit: 30, ttl: ONE_DAY_MS };

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

/**
 * Tiklash so'rovi tanasidagi login bo'yicha kuzatuv (bo'lmasa IP). Login MATNI sanaladi — u mavjudmi yoki
 * yo'qligidan qat'i nazar, shuning uchun 429 login mavjudligini fosh qilmaydi.
 */
export function loginTracker(req: Record<string, any>): string {
  const raw = (req as { body?: { login?: unknown } }).body?.login;
  const login = typeof raw === 'string' ? raw.trim().toLowerCase().slice(0, 64) : '';
  return login ? `login:${login}` : `ip:${String(req.ip ?? 'unknown')}`;
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
    {
      name: THROTTLER_NAMES.schoolLink,
      ...SCHOOL_LINK_LIMIT,
      skipIf: onlyWhereDeclared(THROTTLER_NAMES.schoolLink),
    },
    {
      name: THROTTLER_NAMES.dataDeletion,
      ...DATA_DELETION_LIMIT,
      skipIf: onlyWhereDeclared(THROTTLER_NAMES.dataDeletion),
    },
    {
      name: THROTTLER_NAMES.childRecoveryLogin,
      ...CHILD_RECOVERY_LOGIN_LIMIT,
      getTracker: loginTracker,
      skipIf: onlyWhereDeclared(THROTTLER_NAMES.childRecoveryLogin),
    },
    {
      name: THROTTLER_NAMES.childRecoveryIp,
      ...CHILD_RECOVERY_IP_LIMIT,
      skipIf: onlyWhereDeclared(THROTTLER_NAMES.childRecoveryIp),
    },
    {
      name: THROTTLER_NAMES.childPasswordChange,
      ...CHILD_PASSWORD_CHANGE_LIMIT,
      skipIf: onlyWhereDeclared(THROTTLER_NAMES.childPasswordChange),
    },
    {
      name: THROTTLER_NAMES.childCredentialIssue,
      ...CHILD_CREDENTIAL_ISSUE_LIMIT,
      skipIf: onlyWhereDeclared(THROTTLER_NAMES.childCredentialIssue),
    },
  ];
}
