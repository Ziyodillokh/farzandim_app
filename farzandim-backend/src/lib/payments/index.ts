// To'lov tizimi — umumiy eksport nuqtasi (Sprint 6 — P0 monetizatsiya).
//
// Provayder-agnostik arxitektura: Payme / Click / Uzum Bank.
// Kalitlar .env'da yo'q bo'lsa provayder o'chiq turadi; kiritilгач avtomatik
// yoqiladi (service restart kerak). Mantiq (Subscription aktivlashtirish,
// idempotent webhook) provayderdan mustaqil.

export * from './types';
export * from './service';
export * from './registry';
