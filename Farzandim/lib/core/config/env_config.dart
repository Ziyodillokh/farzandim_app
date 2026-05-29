// ─────────────────────────────────────────────────────────────────────
// EnvConfig — backend va WebSocket URL'lar (Sprint 4.4)
// ─────────────────────────────────────────────────────────────────────
//
// Compile-time `--dart-define-from-file=env.json` orqali to'ldiriladi:
//
//   {
//     "API_BASE_URL": "https://farzandimedu.uz",
//     "WS_BASE_URL": "wss://farzandimedu.uz"
//   }
//
// Default qiymatlar production server (farzandimedu.uz). Local backend
// test qilish uchun env.json'da o'zgartiring:
//
//   "API_BASE_URL": "http://10.0.2.2:3000"  // Android emulator localhost
//   "API_BASE_URL": "http://localhost:3000" // iOS simulator / Mac
//
// Eslatma: HTTPS sertifikat — Let's Encrypt avtomatik renewal. Local
// HTTP uchun Android'da `android:usesCleartextTraffic="true"` kerak
// bo'lishi mumkin (Manifest).

// ignore_for_file: public_member_api_docs

class EnvConfig {
  EnvConfig._();

  /// Backend REST API base URL. Default: production.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://farzandimedu.uz',
  );

  /// WebSocket (Socket.io) base URL. Default: production.
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://farzandimedu.uz',
  );

  /// API path prefix — barcha REST endpoint'lar `/api` bilan boshlanadi
  /// (Backend Fastify struct: `/api/auth/*`, `/api/users/*`, ...).
  static const String apiPath = '/api';

  /// To'liq API URL: `https://farzandimedu.uz/api`.
  static String get apiUrl => '$apiBaseUrl$apiPath';
}
