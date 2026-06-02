/// Must match [services/backend/src/modules/admin-monetization/plan-feature-catalog.ts]
class PlanFeatureOption {
  const PlanFeatureOption({required this.id, required this.labelUz});
  final String id;
  final String labelUz;
}

const kPlanFeatureOptions = <PlanFeatureOption>[
  PlanFeatureOption(id: 'full_access', labelUz: "To'liq kontent kirish"),
  PlanFeatureOption(id: 'audiobooks', labelUz: 'Audiokitoblar'),
  PlanFeatureOption(id: 'contests', labelUz: "Konkurslarda ishtirok"),
  PlanFeatureOption(id: 'no_ads', labelUz: 'Reklamasiz'),
  PlanFeatureOption(id: 'geolocation', labelUz: 'Geolokatsiya'),
  PlanFeatureOption(id: 'screen_time', labelUz: 'Screen time control'),
  PlanFeatureOption(id: 'premium_analytics', labelUz: 'Premium analytics'),
  PlanFeatureOption(id: 'chat', labelUz: 'Chat / messaging'),
  PlanFeatureOption(id: 'video', labelUz: 'Video content'),
  PlanFeatureOption(id: 'xp', labelUz: 'XP system'),
];

const kEntitlementTiers = <({String id, String label})>[
  (id: 'free', label: 'Free'),
  (id: 'standard', label: 'Standard'),
  (id: 'premium', label: 'Premium'),
];
