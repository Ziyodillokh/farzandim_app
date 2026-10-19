// ─────────────────────────────────────────────────────────────────────
// FARZANDIM CHILD — Feature flags (compile-time)
// ─────────────────────────────────────────────────────────────────────
//
// Compile-time const flag'lar. `false` qiymat tegishli UI'ni butunlay
// yashiradi (route'lar /dashboard'ga redirect bo'ladi, navigatsiya
// tab'lari ham ko'rinmaydi).
//
// Production'da `false` — chunki ushbu xususiyatlar joriy holatda mock
// data bilan ishlaydi va hali Cloud Functions tomondan to'ldirilmagan.
// Qayta yoqish uchun shu yerdagi bitta qatorni `true` qilish kifoya.

/// Content library xususiyatlari:
///   - /audiobooks (audiokitoblar)
///   - /videos (video feed)
///   - /contests (konkurslar + quiz)
///   - /ranking (reyting)
///   - /analytics (statistika)
///
/// `false` bo'lganda yuqoridagi route'lar /dashboard'ga redirect bo'ladi
/// va bottom navigation bar yashirinadi (mock data dead-end'lardan saqlash).
const bool kEnableContentLibrary = true;
