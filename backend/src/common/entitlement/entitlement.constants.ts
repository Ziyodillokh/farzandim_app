// ─────────────────────────────────────────────────────────────────────
// Tarif (entitlement) — daraja bo'yicha funksiyalar + limitlar
// ─────────────────────────────────────────────────────────────────────
//
// Bu — feature-enforcement uchun YAGONA MANBA (backend). Admin panel
// `admin-web/src/lib/constants/plan-features.ts` bilan SINXRON bo'lishi shart.
//
// Model: Plan.entitlementTier (free | standard | premium | vip) + Plan.features[].
// Admin plan yaratganda `features[]` ni tanlaydi (aniq). Agar bo'sh bo'lsa —
// quyidagi daraja preseti ishlatiladi. Ota-onaning AKTIV obunasi shu tarifni
// beradi (aks holda `free`).

// Funksiya guruhlari (admin katalogidagi tartibda; AI tavsiya OLIB TASHLANGAN).
const FREE_FEATURES = [
  'app_trial',
  'basic_profile',
  'screen_time_stats',
  'sos',
  'messenger',
  'step_counter',
];
const BASIC_FEATURES = [
  'screen_time_limit',
  'basic_geolocation',
  'app_install_restriction',
  'weekly_report',
];
const STANDARD_FEATURES = [
  'realtime_geolocation',
  'per_app_time_limit',
  'paid_contests',
];
const PREMIUM_FEATURES = ['connect_3_children', 'dual_device_control'];

/// entitlementTier → kumulyativ funksiyalar. "Basic" guruh alohida tarif emas —
/// u STANDARD ichiga kiradi (real tariflar: free / standard / premium).
export const TIER_FEATURES: Record<string, string[]> = {
  free: [...FREE_FEATURES],
  standard: [...FREE_FEATURES, ...BASIC_FEATURES, ...STANDARD_FEATURES],
  premium: [
    ...FREE_FEATURES,
    ...BASIC_FEATURES,
    ...STANDARD_FEATURES,
    ...PREMIUM_FEATURES,
  ],
  vip: [
    ...FREE_FEATURES,
    ...BASIC_FEATURES,
    ...STANDARD_FEATURES,
    ...PREMIUM_FEATURES,
  ],
};

/// Daraja bo'yicha maksimal BOLA soni (mahsulot qarori, 2026-07):
/// free/standard = 1 bola; premium = 3 bola ('connect_3_children').
export const TIER_MAX_CHILDREN: Record<string, number> = {
  free: 1,
  standard: 1,
  premium: 3,
  vip: 3,
};

/// Daraja bo'yicha maksimal OTA-ONA (co-parent) soni (bir oilaga):
/// free/standard = 1 (bitta ota YOKI ona); premium = 2 ('dual_device_control').
export const TIER_MAX_PARENTS: Record<string, number> = {
  free: 1,
  standard: 1,
  premium: 2,
  vip: 2,
};

export const DEFAULT_TIER = 'free';
