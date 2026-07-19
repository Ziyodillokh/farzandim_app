// ─────────────────────────────────────────────────────────────────────
// Push / bildirishnoma matnlari — 3 tilda (uz / ru / en)
// ─────────────────────────────────────────────────────────────────────
//
// Har bir bildirishnoma qabul qiluvchining tiliga (`User.language`) qarab
// tarjima qilinadi. Ota-onaga ketadigan xabar — ota-ona tilida, bolaga
// ketadigan — bola tilida. Til `FcmService.getUserLang(userId)` orqali
// olinadi. `{param}` joy egalari (ism, ilova nomi, foiz, daqiqa) almashadi.
//
// Ismlar / ilova nomlari / zona nomlari — TARJIMA QILINMAYDI (o'z holicha
// {param} sifatida qo'yiladi). Faqat qat'iy matn tarjima qilinadi.

export type NotifLang = 'uz' | 'ru' | 'en';

/** `User.language` (yoki noma'lum) → qo'llab-quvvatlanadigan til. Default `uz`. */
export function toNotifLang(raw?: string | null): NotifLang {
  return raw === 'ru' || raw === 'en' ? raw : 'uz';
}

type Params = Record<string, string | number>;

const T: Record<string, Record<NotifLang, string>> = {
  // ── Batareya kam (ota-onaga) ──
  'battery.title': {
    uz: '{name} — batareya {pct}%',
    ru: '{name} — батарея {pct}%',
    en: '{name} — battery {pct}%',
  },
  'battery.body': {
    uz: 'Quvvat kam qoldi. Tezroq quvvatlash kerak.',
    ru: 'Заряд низкий. Нужно скоро зарядить.',
    en: 'Battery is low. It needs charging soon.',
  },

  // ── O'yin ochildi (ota-onaga) ──
  'game.body': {
    uz: "O'yin o'ynayapti",
    ru: 'Играет в игру',
    en: 'Playing a game',
  },

  // ── Yangi qurilma ulanish (pair) so'rovi (ota-onaga) ──
  'pairRequest.title': {
    uz: '{name} — yangi qurilma',
    ru: '{name} — новое устройство',
    en: '{name} — new device',
  },
  'pairRequest.body': {
    uz: 'Yangi qurilma oila kodi bilan ulanmoqchi. Tasdiqlang.',
    ru: 'Новое устройство хочет подключиться по семейному коду. Подтвердите.',
    en: 'A new device wants to connect using the family code. Confirm.',
  },

  // ── Akkauntga kirish (session access) so'rovi (ota-onaga) ──
  'sessionAccess.title': {
    uz: "Yangi qurilma kirish so'rovi",
    ru: 'Запрос входа с нового устройства',
    en: 'New device sign-in request',
  },
  'sessionAccess.body': {
    uz: '{label} akkauntingizga kirmoqchi. Tasdiqlaysizmi?',
    ru: '{label} хочет войти в ваш аккаунт. Подтвердить?',
    en: '{label} wants to sign in to your account. Approve?',
  },

  // ── Geo-zona kirish/chiqish (ota-onaga) ──
  'geoZone.enterTitle': {
    uz: '{name} {zone}ga kirdi',
    ru: '{name} прибыл(а): {zone}',
    en: '{name} arrived at {zone}',
  },
  'geoZone.exitTitle': {
    uz: '{name} {zone}dan chiqdi',
    ru: '{name} покинул(а): {zone}',
    en: '{name} left {zone}',
  },
  'geoZone.enterBody': {
    uz: 'Belgilangan hududga yetib keldi',
    ru: 'Прибыл(а) в указанную зону',
    en: 'Arrived at the set area',
  },
  'geoZone.exitBody': {
    uz: 'Belgilangan hududni tark etdi',
    ru: 'Покинул(а) указанную зону',
    en: 'Left the set area',
  },

  // ── Ilova cheklovi yangilandi (bolaga) ──
  'appLimit.title': {
    uz: 'Ota-onangiz cheklovni yangiladi',
    ru: 'Родитель обновил ограничение',
    en: 'Your parent updated a limit',
  },
  'appLimit.bodyOne': {
    uz: '{app} uchun vaqt chegarasi yangilandi',
    ru: 'Обновлён лимит времени для {app}',
    en: 'Time limit updated for {app}',
  },
  'appLimit.bodyFew': {
    uz: '{apps} cheklovlari yangilandi',
    ru: 'Обновлены ограничения: {apps}',
    en: 'Limits updated: {apps}',
  },
  'appLimit.bodyMany': {
    uz: '{apps} va yana {count} ta ilova cheklovi yangilandi',
    ru: 'Обновлены ограничения: {apps} и ещё {count}',
    en: 'Limits updated: {apps} and {count} more',
  },

  // ── Qurilmani chaqirish / ring (bolaga) ──
  'ring.body': {
    uz: 'Qurilma chaqirilmoqda',
    ru: 'Устройство вызывается',
    en: 'Device is ringing',
  },

  // ── Joylashuvni yoqish so'rovi (bolaga) ──
  'locationRequest.title': {
    uz: 'Joylashuvni yoqing',
    ru: 'Включите геолокацию',
    en: 'Turn on location',
  },
  'locationRequest.body': {
    uz: "Ota-onangiz joylashuvingizni ko'ra olmayapti. Iltimos, joylashuvni yoqing.",
    ru: 'Родитель не видит вашу геолокацию. Пожалуйста, включите её.',
    en: "Your parent can't see your location. Please turn it on.",
  },

  // ── Motivatsion nudge (bolaga) ──
  'nudge.study': {
    uz: "Bugun bitta test yechib ko'rchi 📚",
    ru: 'Реши сегодня один тест 📚',
    en: 'Try solving one test today 📚',
  },
  'nudge.health': {
    uz: 'Biroz harakat qilsang-chi 🏃',
    ru: 'Немного подвигайся 🏃',
    en: 'How about a little movement 🏃',
  },
  'nudge.content': {
    uz: 'Yangi videolar seni kutyapti 🎬',
    ru: 'Новые видео ждут тебя 🎬',
    en: 'New videos are waiting for you 🎬',
  },

  // ── Vaqt qo'shish (unlock) qarori (bolaga) ──
  'unlock.approved': {
    uz: "Ota-onangiz {minutes} daqiqa qo'shimcha vaqt berdi.",
    ru: 'Родитель дал вам дополнительно {minutes} мин.',
    en: 'Your parent granted you {minutes} extra minutes.',
  },
  'unlock.rejected': {
    uz: "Ota-onangiz so'rovni rad etdi.",
    ru: 'Родитель отклонил запрос.',
    en: 'Your parent declined the request.',
  },
};

/**
 * `key`ni `lang` tiliga tarjima qiladi va `{param}` joy egalarini almashtiradi.
 * Kalit topilmasa key'ning o'zini, til topilmasa `uz`ni qaytaradi (xavfsiz).
 */
export function tr(lang: NotifLang, key: string, params?: Params): string {
  const row = T[key];
  if (!row) return key;
  let s = row[lang] ?? row.uz;
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      s = s.split(`{${k}}`).join(String(v));
    }
  }
  return s;
}
