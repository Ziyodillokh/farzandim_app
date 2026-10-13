// ─────────────────────────────────────────────────────────────────────
// Do'kon tekshiruvchilari (Apple / Google) uchun demo oila kodlari
// ─────────────────────────────────────────────────────────────────────
//
// Avval faqat BITTA kod (`PLAY_REVIEW_FAMILY_CODE`) bor edi. Apple va
// Google bitta koddan foydalansa, bir do'kon tekshiruvchisining ulanishi
// ikkinchisining qurilmasini jimgina uzib qo'yardi (App Store audit F7).
// Endi bir nechta kod qo'llab-quvvatlanadi — har do'konga O'Z demo profili:
//   PLAY_REVIEW_FAMILY_CODE=12345          (eski, vergul bilan ro'yxat ham bo'ladi)
//   APP_REVIEW_FAMILY_CODES=12345,67890    (yangi, vergul bilan ajratilgan)
// Ikkalasi birlashtiriladi. Kod uzunligi oila kodi bilan bir xil (5).

export const FAMILY_CODE_LENGTH = 5;

/** Vergul bilan ajratilgan qiymatlardan yaroqli (5 belgili) kodlar to'plami. */
export function parseReviewFamilyCodes(
  ...rawValues: Array<string | undefined>
): ReadonlySet<string> {
  const codes = rawValues
    .filter((v): v is string => typeof v === 'string' && v.length > 0)
    .flatMap((v) => v.split(','))
    .map((c) => c.trim())
    .filter((c) => c.length === FAMILY_CODE_LENGTH);
  return new Set(codes);
}

/** Kod env'dagi demo (reviewer) kodlardan birimi. */
export function isReviewFamilyCode(
  familyCode: string,
  env: Record<string, string | undefined> = process.env,
): boolean {
  return parseReviewFamilyCodes(
    env.PLAY_REVIEW_FAMILY_CODE,
    env.APP_REVIEW_FAMILY_CODES,
  ).has(familyCode);
}
