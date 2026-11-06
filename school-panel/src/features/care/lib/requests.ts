import type { CareRequestRow } from '@/data/contracts';

/**
 * Qutidagi «Bola yozdi» nishoni uchun yangi xabarlar soni. Backend `unreadFromChild`ga bolaning hali o'qilmagan
 * BARCHA xabarlarini kiritadi — ochilmagan murojaatda bu bolaning birinchi (murojaat) xabari; u «Ochilmagan» holatida
 * allaqachon ko'rinadi. Shuning uchun ochilmagan murojaatda birinchi xabar hisobdan chiqariladi — nishon faqat
 * haqiqiy yangilikni (ochilgandan keyingi yoki qo'shimcha xabar) bildiradi.
 */
export function newChildMessages(request: Pick<CareRequestRow, 'unreadFromChild' | 'openedAt'>): number {
  return request.openedAt === null ? Math.max(0, request.unreadFromChild - 1) : request.unreadFromChild;
}
