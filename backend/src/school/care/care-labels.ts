// Bola ovozi bildirishnomalari uchun mavzu yorliqlari (ism, sinf yoki matn YO'Q).

export type Localized = { uz: string; ru: string };

export const CARE_TOPIC_LABELS: Record<string, Localized> = {
  LEARNING: { uz: 'O\'qish', ru: 'Учёба' },
  PEERS: { uz: 'Tengdoshlar', ru: 'Сверстники' },
  BULLYING: { uz: 'Masxara / tazyiq', ru: 'Насмешки / давление' },
  FAMILY: { uz: 'Oila', ru: 'Семья' },
  EMOTIONS: { uz: 'Kayfiyat', ru: 'Настроение' },
  SAFETY: { uz: 'Xavfsizlik', ru: 'Безопасность' },
  OTHER: { uz: 'Boshqa', ru: 'Другое' },
};

/** Eskalatsiya bildirishnomasi ostidagi izoh (xodim ko'radi). */
export const ESCALATED_SUBJECT: Localized = {
  uz: 'Muddatida ochilmadi — sizga o\'tkazildi',
  ru: 'Не открыто в срок — передано вам',
};
