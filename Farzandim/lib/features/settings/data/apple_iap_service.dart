// Apple StoreKit (in_app_purchase) product ID'lari + xarid yordamchisi.
//
// App Store 3.1.1: iOS'da raqamli obuna FAQAT Apple IAP orqali sotilishi
// SHART (tashqi Click to'lovi iOS'da rad etiladi). Android'da esa Click
// (backend checkout) ishlatiladi — bu fayl faqat iOS uchun.
//
// Oqim: forPlan() -> product id -> InAppPurchase.buyNonConsumable ->
// purchaseStream natijasi -> backend /payments/apple/verify (kvitansiyani
// tekshiradi, entitlement beradi) -> completePurchase. "Restore purchases"
// tugmasi Apple talabiga ko'ra MAJBURIY.

/// App Store Connect'dagi auto-renewable subscription product ID'lari.
///
/// MUHIM: bu qiymatlar App Store Connect'da yaratilgan obuna mahsulotlari
/// bilan AYNAN bir xil bo'lishi shart, aks holda `queryProductDetails`
/// mahsulotni topmaydi.
class AppleProductIds {
  const AppleProductIds._();

  /// Standart — oylik.
  static const String standardMonthly = 'com.farzandim.parent.standard.monthly';

  /// Standart — yillik.
  static const String standardYearly = 'com.farzandim.parent.standard.yearly';

  /// Premium — oylik.
  static const String premiumMonthly = 'com.farzandim.parent.premium.monthly';

  /// Premium — yillik.
  static const String premiumYearly = 'com.farzandim.parent.premium.yearly';

  /// `queryProductDetails` uchun barcha ID'lar.
  static const Set<String> all = <String>{
    standardMonthly,
    standardYearly,
    premiumMonthly,
    premiumYearly,
  };

  /// Tarif darajasi (`entitlementTier`) + oylik/yillik → product id.
  /// Noma'lum tarif (masalan `free`) uchun `null`.
  static String? forPlan(String entitlementTier, {required bool yearly}) {
    switch (entitlementTier) {
      case 'standard':
        return yearly ? standardYearly : standardMonthly;
      case 'premium':
        return yearly ? premiumYearly : premiumMonthly;
      default:
        return null;
    }
  }
}
