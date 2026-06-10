// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — ROUTE NOMLARI (Route name constants)
// ─────────────────────────────────────────────────────────────────────
//
// Hech bir joyda string sifatida `'/sign-in'` yozilmaydi. Faqat shu yerdan:
//
//   context.go(AppRoutes.signIn);
//   GoRoute(path: AppRoutes.signIn, builder: ...);
//
// Nega? Tipo'larning oldini olish (`'/sing-in'` bilan ish bilmay qoladi),
// rename qilish oson (faqat shu joyda o'zgartirish), IDE autocomplete.

/// Farzandim ilovasidagi barcha route'lar.
class AppRoutes {
  AppRoutes._();

  /// Bosh sahifa — Welcome ekran (auth qilmagan foydalanuvchilar uchun).
  ///
  /// Auth state'ga qarab redirect Bosqich 1.5'da qo'shiladi: kirgan
  /// foydalanuvchilar darhol `dashboard`'ga yo'naltiriladi.
  static const String welcome = '/';

  /// Birinchi ochilish — til tanlash ekrani (3 til). Til tanlanmaguncha
  /// boshqa sahifaga o'tib bo'lmaydi; tanlangach saqlanadi va qayta chiqmaydi.
  static const String languageSelect = '/language';

  /// Telegram Login WebView — Backend bilan auth (Sprint 4.4).
  /// Firebase phone OTP'dan migrate qilingan yangi auth.
  static const String telegramLogin = '/login-telegram';

  /// Akkauntga kirish — email/telefon + parol.
  static const String signIn = '/sign-in';

  /// Ro'yxatdan o'tish — telefon/email tab + parol.
  static const String signUp = '/sign-up';

  /// Parolni tiklash (hozircha UI stub — backend keyin ulanadi).
  static const String forgotPassword = '/forgot-password';

  /// Akkauntga qo'shilish — boshqa qurilmaga QR orqali ulanish.
  static const String addAccount = '/add-account';

  /// Asosiy ekran — auth qilingan foydalanuvchilar uchun.
  static const String dashboard = '/dashboard';

  /// Yangi bola qo'shish formi.
  static const String addChild = '/add-child';

  /// Oila kodi ekrani — Bola qo'shilgandan keyin shu ekranga o'tiladi.
  /// `:childId` — qaysi bolaning kodi ko'rsatilishi kerak.
  ///
  /// Path navigatsiyasi uchun [familyCodePath]'dan foydalaning
  /// (string interpolation o'rniga).
  static const String familyCodePattern = '/family-code/:childId';

  /// Berilgan `childId` uchun haqiqiy path qaytaradi.
  ///
  /// Misol: `familyCodePath('abc123')` → `/family-code/abc123`.
  static String familyCodePath(String childId) => '/family-code/$childId';

  /// Bildirishnomalar ekrani.
  static const String notifications = '/notifications';

  /// Sozlamalar ekrani (asosiy menyu).
  static const String settings = '/settings';

  /// Ilova haqida.
  static const String settingsAbout = '/settings/about';

  /// Profil tahrirlash (Bosqich 7.3).
  static const String settingsProfile = '/settings/profile';

  /// Faol sessiyalar — login qilingan qurilmalar (Sprint 7).
  static const String settingsSessions = '/settings/sessions';

  /// Qo'llab-quvvatlash chati (Sprint 7).
  static const String support = '/support';

  /// Bolalarni boshqarish ro'yxati (Bosqich 7.2).
  static const String settingsChildren = '/settings/children';

  /// Hisobni butunlay o'chirish (Sprint 2.2 — Play Market mandatory).
  static const String settingsDeleteAccount = '/settings/delete-account';

  /// Maxfiylik siyosati (Sprint 2.5 — Play Market / COPPA / ZRU-547).
  static const String legalPrivacyPolicy = '/legal/privacy-policy';

  /// Foydalanish shartlari (Sprint 2.5).
  static const String legalTermsOfService = '/legal/terms-of-service';

  /// Bola ma'lumotlarini tahrirlash (Bosqich 7.2).
  static const String editChildPattern = '/edit-child/:id';

  /// Berilgan bola id'si uchun edit path qaytaradi.
  static String editChildPath(String id) => '/edit-child/$id';

  /// Bola joylashuvini xaritada ko'rsatish.
  /// `:childId` — qaysi bola tanlanadi (ixtiyoriy — yo'q bo'lsa
  /// birinchi bola).
  static const String locationPattern = '/location/:childId';

  /// Berilgan `childId` uchun haqiqiy path qaytaradi.
  ///
  /// Misol: `locationPath('abc123')` → `/location/abc123`.
  static String locationPath(String childId) => '/location/$childId';

  /// Bola harakat tarixi (Sprint 4) — Polyline xaritada.
  /// `:childId` — qaysi bolaning tarixi ko'rsatiladi.
  static const String locationHistoryPattern = '/location/:childId/history';

  /// Berilgan bola id'si uchun harakat tarixi path.
  static String locationHistoryPath(String childId) =>
      '/location/$childId/history';

  /// Bola uchun geo-zonalar ro'yxati.
  /// `:childId` — qaysi bolaning zonalari (per-child).
  static const String geoZonesPattern = '/geo-zones/:childId';

  /// Berilgan bola id'si uchun zonalar ro'yxati path.
  static String geoZonesPath(String childId) => '/geo-zones/$childId';

  /// Bola uchun yangi geo-zona qo'shish formi.
  static const String geoZonesAddPattern = '/geo-zones/:childId/add';

  /// Berilgan bola id'si uchun yangi zona qo'shish path.
  static String geoZonesAddPath(String childId) => '/geo-zones/$childId/add';

  /// Geo-zonani tahrirlash.
  /// `:childId` — qaysi bolaning zonasi.
  /// `:id` — qaysi zona tahrirlanadi.
  static const String geoZonesEditPattern = '/geo-zones/:childId/edit/:id';

  /// Berilgan bola va zona id uchun haqiqiy edit path qaytaradi.
  static String geoZonesEditPath(String childId, String id) =>
      '/geo-zones/$childId/edit/$id';

  // ─── Quick Actions (Bosqich 5) ──────────────────────────────────

  /// Qurilma sozlamalari.
  static const String qaDevicePattern = '/quick-actions/device/:childId';

  /// Berilgan bola id'si uchun qurilma sozlamalari path.
  static String qaDevicePath(String childId) =>
      '/quick-actions/device/$childId';

  /// Bola qurilmasidagi ilova ruxsatlari (Device Settings ichidan).
  static const String appPermissionsPattern =
      '/quick-actions/permissions/:childId';

  /// Berilgan bola id'si uchun ilova ruxsatlari path.
  static String appPermissionsPath(String childId) =>
      '/quick-actions/permissions/$childId';

  /// Bitta ruxsat uchun ilovalar ro'yxati ("Kamera uchun ruxsatlar").
  static const String permissionAppsPattern =
      '/quick-actions/permissions/:childId/:permission';

  /// Berilgan bola + ruxsat uchun ilovalar ro'yxati path.
  static String permissionAppsPath(String childId, String permission) =>
      '/quick-actions/permissions/$childId/$permission';

  /// Bola bilan ovozli xabar chati (Telegram-style, per child).
  ///
  /// Dashboard'dagi bola karta'sidagi "Ovoz xabarlari" tugmasi shu
  /// route'ga olib boradi — to'g'ridan-to'g'ri o'sha bola chatiga.
  static const String qaVoicePattern = '/quick-actions/voice/:childId';

  /// Berilgan bola id'si uchun chat path.
  static String qaVoicePath(String childId) => '/quick-actions/voice/$childId';

  /// Barcha bolalar bilan ovozli xabarlar list ekrani (global,
  /// childId yo'q). Telegram chat list uslubida — har bola
  /// preview + unread badge.
  static const String voiceMessages = '/voice-messages';

  /// Bola ilovalari foydalanish statistikasi (App Restrictions feature).
  /// `:childId` — qaysi bolaning statistikasi (per-child).
  static const String appRestrictionsPattern = '/app-restrictions/:childId';

  /// Berilgan bola id'si uchun App Restrictions path.
  static String appRestrictionsPath(String childId) =>
      '/app-restrictions/$childId';

  /// "Qurilma cheklovlari" — ilova limitlari ekrani (Figma 1:1).
  /// `:childId` — qaysi bolaning cheklovlari.
  static const String appLimitsPattern = '/app-limits/:childId';

  /// Berilgan bola id'si uchun App Limits path.
  static String appLimitsPath(String childId) => '/app-limits/$childId';

  /// Bola jadvali (Schedules feature — Firestore CRUD).
  /// `:childId` — qaysi bolaning jadvallari (per-child).
  static const String schedulesPattern = '/schedules/:childId';

  /// Berilgan bola id'si uchun jadvallar list path.
  static String schedulesPath(String childId) => '/schedules/$childId';

  /// Haftalik hisobot (qadam + ekran vaqti + ilovalar).
  static const String weeklyReportPattern = '/weekly-report/:childId';

  /// Berilgan bola id'si uchun haftalik hisobot path.
  static String weeklyReportPath(String childId) => '/weekly-report/$childId';

  /// Bola yutuqlari (Gamification — Sprint 4.4.6).
  static const String childAchievementsPattern = '/achievements/:childId';
  static String childAchievementsPath(String childId) =>
      '/achievements/$childId';

  /// SOS alerts list (Sprint 4.4.15).
  static const String sosAlerts = '/sos-alerts';

  /// Photo requests list per child (Sprint 4.4.16).
  static const String photoRequestsPattern = '/photo-requests/:childId';
  static String photoRequestsPath(String childId) => '/photo-requests/$childId';

  /// Feedback inbox per child (Sprint 4.4.17).
  static const String feedbackInboxPattern = '/feedback/:childId';
  static String feedbackInboxPath(String childId) => '/feedback/$childId';

  // Sprint 4.4.34: alohida /video-chat ekran olib tashlandi.
  // Video xabarlar voice chat ichida Telegram-style yumaloq bubble.

  /// Pair requests per child (Sprint 4.4.25).
  static const String pairRequestsPattern = '/pair-requests/:childId';
  static String pairRequestsPath(String childId) => '/pair-requests/$childId';
}
