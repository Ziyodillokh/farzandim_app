// ─────────────────────────────────────────────────────────────────────
// Tarif (plan) funksiyalari katalogi — monetizatsiya modeli bo'yicha.
// ─────────────────────────────────────────────────────────────────────
//
// Tarif yaratishda admin shu funksiyalarni yoqib/o'chiradi (moderator
// ruxsatlari kabi). Tanlangan KALITLAR `plan.features` (String[]) ga
// saqlanadi. Ota-ona shu tarifni sotib olsa — shu funksiyalar yoqiladi
// (enforcement keyingi bosqichda).

export interface PlanFeature {
  key: string;
  label: string;
}

export interface PlanFeatureGroup {
  group: string;
  features: PlanFeature[];
}

/// Funksiyalar daraja (tier) bo'yicha guruhlangan — monetizatsiya modelidagi
/// ustunlar tartibida. Har daraja avvalgisini o'z ichiga oladi (presetlarda).
export const PLAN_FEATURE_GROUPS: PlanFeatureGroup[] = [
  {
    group: 'Asosiy (Free)',
    features: [
      { key: 'app_trial', label: "Ilovani sinab ko'rish" },
      { key: 'basic_profile', label: 'Asosiy profil' },
      { key: 'screen_time_stats', label: 'Umumiy ekran vaqti statistikasi' },
      { key: 'sos', label: 'SOS' },
      { key: 'messenger', label: 'Messenjer' },
      { key: 'step_counter', label: 'Qadam hisoblagich (bola app)' },
    ],
  },
  {
    group: 'Basic',
    features: [
      { key: 'screen_time_limit', label: 'Ekran vaqti limiti' },
      { key: 'basic_geolocation', label: 'Asosiy geolokatsiya' },
      { key: 'app_install_restriction', label: "Ilova o'rnatishni cheklash" },
      { key: 'weekly_report', label: 'Haftalik hisobot' },
    ],
  },
  {
    group: 'Standard',
    features: [
      { key: 'realtime_geolocation', label: 'Real-time geolokatsiya' },
      { key: 'per_app_time_limit', label: "Ilovalar bo'yicha vaqt cheklovi" },
      { key: 'paid_contests', label: 'Pulli konkurslar' },
      { key: 'ai_recommendations', label: 'AI tavsiya' },
    ],
  },
  {
    group: 'Premium',
    features: [
      { key: 'connect_3_children', label: '3 tagacha bola ulash' },
      { key: 'dual_device_control', label: "2 qurilmadan bir vaqtda nazorat" },
    ],
  },
];

/// Barcha funksiya kalitlari (tekis ro'yxat).
export const ALL_PLAN_FEATURE_KEYS: string[] = PLAN_FEATURE_GROUPS.flatMap(
  (g) => g.features.map((f) => f.key),
);

const _LABEL_BY_KEY: Record<string, string> = Object.fromEntries(
  PLAN_FEATURE_GROUPS.flatMap((g) => g.features.map((f) => [f.key, f.label])),
);

/// Kalitdan o'qiladigan nom (topilmasa kalitning o'zi — eski erkin matnlar
/// bilan orqaga moslik uchun).
export function planFeatureLabel(key: string): string {
  return _LABEL_BY_KEY[key] ?? key;
}

/// Daraja bo'yicha tayyor to'plamlar (kumulyativ) — daraja tanlanganda
/// avtomatik belgilanadi (monetizatsiya modelidagidek).
const _FREE = PLAN_FEATURE_GROUPS[0].features.map((f) => f.key);
const _BASIC = PLAN_FEATURE_GROUPS[1].features.map((f) => f.key);
const _STANDARD = PLAN_FEATURE_GROUPS[2].features.map((f) => f.key);
const _PREMIUM = PLAN_FEATURE_GROUPS[3].features.map((f) => f.key);

export const TIER_FEATURE_PRESETS: Record<string, string[]> = {
  free: [..._FREE],
  basic: [..._FREE, ..._BASIC],
  standard: [..._FREE, ..._BASIC, ..._STANDARD],
  premium: [..._FREE, ..._BASIC, ..._STANDARD, ..._PREMIUM],
};
