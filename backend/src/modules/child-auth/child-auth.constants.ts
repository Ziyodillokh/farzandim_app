// Kirish (K1): bola login/parol, sessiyalar va tiklash so'rovlari uchun umumiy konstantalar.
// Qiymatlar `docs/KIRISH-AUTH-API.md` kontrakti bilan bir xil.

/** Login: kichik lotin harf bilan boshlanadi, jami 4–24 belgi (harf, raqam, nuqta, pastki chiziq). */
export const CHILD_LOGIN_PATTERN = /^[a-z][a-z0-9._]{3,23}$/;
/** So'rovdagi login uzunligi chegarasi (formatdan qat'i nazar — katta kirishni rad etish uchun). */
export const LOGIN_INPUT_MAX = 64;

export const CREDENTIAL_BCRYPT_ROUNDS = 12;

/** Vaqtinchalik parol: chalkashadigan belgilarsiz (i, l, o, 0, 1) 8 ta belgi. */
export const TEMP_PASSWORD_ALPHABET = 'abcdefghjkmnpqrstuvwxyz23456789';
export const TEMP_PASSWORD_LENGTH = 8;

/** Bola tanlagan parol: 8–64 belgi (bcrypt 72 bayt bilan chegaralanadi). */
export const PASSWORD_MIN_LENGTH = 8;
export const PASSWORD_MAX_LENGTH = 64;
export const PASSWORD_MAX_BYTES = 72;
export const PASSWORD_INPUT_MAX = 200;

/** Bir login uchun 15 daqiqada 5 ta xato parol — 15 daqiqaga bloklanadi. */
export const MAX_FAILED_LOGINS = 5;
export const FAILURE_WINDOW_MS = 15 * 60_000;
export const LOCK_MS = 15 * 60_000;
/** Mavjud bo'lmagan loginlar uchun xotiradagi "soya" blok jadvali chegarasi. */
export const GHOST_LIMITER_MAX_ENTRIES = 10_000;

/** Bir foydalanuvchida bir vaqtda ko'pi bilan shuncha LOGIN sessiyasi. */
export const MAX_LOGIN_SESSIONS = 3;
export const LOGIN_SESSION_KIND = 'LOGIN';

export const SETUP_TOKEN_TTL_SECONDS = 15 * 60;
export const SETUP_TOKEN_AUDIENCE = 'farzandim-child-setup';
export const SETUP_TOKEN_PURPOSE = 'child-setup';

/** Tiklash so'rovi: bola uchun sutkada 3 ta ta'sirli so'rov (qolgani jim — xabar yuborilmaydi). */
export const RECOVERY_EFFECTS_PER_CHILD_PER_DAY = 3;
/** Eskirgan tiklash so'rovlari shuncha kundan keyin o'chiriladi. */
export const RECOVERY_RETENTION_DAYS = 30;

export const CHILD_UNPAIRED_EVENT = 'child:unpaired';
export const CHILD_RECOVERY_PUSH_TYPE = 'CHILD_RECOVERY_REQUEST';
/** `SchoolStaffNotification.kind` — maktab xodimlariga. */
export const CHILD_RECOVERY_NOTIFICATION_KIND = 'CHILD_RECOVERY_REQUEST';
/** Saqlangan xodim bildirishnomasining barqaror id'si (tozalash uchun). */
export const childRecoveryNotificationId = (requestId: string) => `child-recovery:${requestId}`;

export const EDUCATION_LANGUAGES = ['uz', 'ru', 'kaa'] as const;
export type EducationLanguage = (typeof EDUCATION_LANGUAGES)[number];

export const DAY_MS = 24 * 60 * 60 * 1000;
