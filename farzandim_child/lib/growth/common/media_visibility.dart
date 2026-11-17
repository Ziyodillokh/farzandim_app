// Audiokitob va videodarslar — egasi qarori bilan (2026-11-07) platformaning
// hech bir joyida ko'rsatilmaydi: kutubxona, maktab topshiriqlari, DON
// tarixi, nishonlar, bildirishnomalar va push havolalari. Kod joyida;
// qaytarish uchun `true`.
const kShowAudioVideo = false;

/// Audio / videoga olib boradigan manzillar (eski v4 va v5 kutubxonasi).
const _mediaRoutePrefixes = [
  '/videos',
  '/video-player',
  '/watch-history',
  '/liked-videos',
  '/audiobooks',
  '/audiobook-detail',
  '/audio-player',
  '/content',
  '/books',
  '/oqish/kutubxona',
];

/// Manzil audio / video bo'limiga olib boradimi (yashirin paytda — `true`).
bool isHiddenMediaRoute(String? route) {
  if (kShowAudioVideo || route == null) return false;
  final path = route.split('?').first;
  return _mediaRoutePrefixes.any((p) => path == p || path.startsWith('$p/'));
}
