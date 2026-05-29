/**
 * Canonical plan feature keys. Must stay aligned with the Flutter Web
 * admin panel: `admin_panel/lib/features/monetization/monetization_feature_catalog.dart`.
 */
export const PLAN_FEATURE_KEYS = [
  'full_access',
  'audiobooks',
  'contests',
  'no_ads',
  'geolocation',
  'screen_time',
  'premium_analytics',
  'chat',
  'video',
  'xp',
] as const;

export type PlanFeatureKey = (typeof PLAN_FEATURE_KEYS)[number];

const FEATURE_SET = new Set<string>(PLAN_FEATURE_KEYS);

export function sanitizeFeatures(input: unknown): string[] {
  if (!Array.isArray(input)) return [];
  const seen = new Set<string>();
  for (const item of input) {
    if (typeof item !== 'string') continue;
    if (FEATURE_SET.has(item)) seen.add(item);
  }
  return Array.from(seen);
}

export const PLAN_PERIODS = ['free', 'monthly', 'yearly'] as const;
export type PlanPeriod = (typeof PLAN_PERIODS)[number];

export const ENTITLEMENT_TIERS = ['free', 'standard', 'premium'] as const;
export type EntitlementTier = (typeof ENTITLEMENT_TIERS)[number];

export const PAYMENT_METHODS = ['click', 'payme', 'uzum_bank', 'visa', 'mastercard'] as const;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

export const PROMOCODE_STATUSES = ['active', 'inactive', 'archived'] as const;
export type PromocodeStatus = (typeof PROMOCODE_STATUSES)[number];
