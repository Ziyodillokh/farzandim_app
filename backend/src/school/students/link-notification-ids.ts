// Ulanish so'rovlari saqlangan xodim bildirishnomalarining barqaror id'lari va turlari (upsert va tozalash uchun).
// Yengil modul: ma'lumot tozalash yo'llari (`link-purge`) shuni import qiladi.

export const LINK_REVIEW_KIND = 'LINK_REVIEW';
export const LINK_CORRECTION_KIND = 'LINK_CORRECTION';
/** 6 raqamli kod bilan ulangan, telefoni mos kelmagan ota-ona: xodim tasdig'ini kutmoqda. */
export const GUARDIAN_REVIEW_KIND = 'GUARDIAN_REVIEW';

/** Bildirishnoma bosilganda panelda ochiladigan sahifa ("Ulanish soʻrovlari"); boshqa lenta turlaridagi `href` kabi — panel yo'li. */
export const LINK_REQUESTS_HREF = '/students/link-requests';

export type LinkNotificationKind = typeof LINK_REVIEW_KIND | typeof LINK_CORRECTION_KIND | typeof GUARDIAN_REVIEW_KIND;

export const reviewNotificationId = (inviteId: string) => `link-review:${inviteId}`;
export const correctionNotificationId = (correctionId: string) => `link-correction:${correctionId}`;
export const guardianReviewNotificationId = (reviewId: string) => `guardian-review:${reviewId}`;
