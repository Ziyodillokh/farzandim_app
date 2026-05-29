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
}
