// ─────────────────────────────────────────────────────────────────────
// EnvConfig — Backend va WebSocket URL'lar (Sprint 4.4)
// ─────────────────────────────────────────────────────────────────────

// ignore_for_file: public_member_api_docs

class EnvConfig {
  EnvConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://farzandimedu.uz',
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://farzandimedu.uz',
  );

  static const String apiPath = '/api';

  static String get apiUrl => '$apiBaseUrl$apiPath';

  /// Backend qaytargan media proxy URL'ini HAR DOIM shu ilovaning o'z
  /// `apiUrl`'iga majburlaydi.
  ///
  /// Backend URL'ni so'rov Host'i (`requestOrigin`) asosida quradi. Agar u
  /// noto'g'ri/boshqa domen bersa (masalan test vs prod, yoki nginx Host'ni
  /// uzatmasa) telefon media'ga yeta olmaydi. Biz `/content/media/...` qismini
  /// ajratib, ilova ishlatayotgan bazaga ulaymiz — domen-mustaqil, ishonchli.
  /// Tashqi havolalar (YouTube / to'g'ridan .mp4) o'zgarmaydi.
  static String resolveMediaUrl(String url) {
    const marker = '/content/media/';
    final i = url.indexOf(marker);
    if (i < 0) return url;
    return '$apiUrl${url.substring(i)}';
  }
}
