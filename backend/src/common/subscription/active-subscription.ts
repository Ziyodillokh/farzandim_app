import { Prisma } from '@prisma/client';

/**
 * "Faol obuna" sharti — YAGONA manba.
 *
 * ⚠️ NEGA ALOHIDA FAYL: bu shart kod bazasida 14 marta takrorlangan edi va
 * ularning 4 tasida `expiresAt` UNUTILGAN. Natijada admin panel muddati
 * tugagan obunani ham "faol" deb ko'rsatardi, bola ilovasiga xizmat
 * qiluvchi API esa (u `expiresAt` ni tekshiradi) o'sha foydalanuvchini
 * `free` deb hisoblardi. Ikki ko'rinish bir-biriga zid bo'lib, "mijoz
 * to'lagan, lekin kontent ko'rinmayapti" holatini tashxislab bo'lmasdi.
 *
 * Yangi joyda faol obuna kerak bo'lsa — SHU funksiyani ishlating,
 * shartni qo'lda qayta yozmang.
 *
 * Eslatma: `expiresAt: null` = MUDDATSIZ (lifetime tarif), shuning uchun
 * u ham faol hisoblanadi.
 */
export function activeSubscriptionWhere(
  now: Date = new Date(),
): Prisma.SubscriptionWhereInput {
  return {
    status: 'ACTIVE',
    OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
  };
}

/**
 * `user.subscriptions` bo'yicha filtr uchun — faol obunasi BOR/YO'Q.
 * `has=false` bepul foydalanuvchini topadi (faol obunasi yo'q).
 */
export function hasActiveSubscription(
  has: boolean,
  extra?: Prisma.SubscriptionWhereInput,
  now: Date = new Date(),
): Prisma.SubscriptionListRelationFilter {
  const where = { ...activeSubscriptionWhere(now), ...(extra ?? {}) };
  return has ? { some: where } : { none: activeSubscriptionWhere(now) };
}
