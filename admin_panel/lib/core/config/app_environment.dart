/// Build-time environment (dev / staging / prod).
enum AppFlavor { dev, staging, prod }

class AppEnvironment {
  AppEnvironment._();

  static const String _flavorRaw = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  static AppFlavor get flavor {
    switch (_flavorRaw.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppFlavor.prod;
      case 'staging':
      case 'stage':
        return AppFlavor.staging;
      default:
        return AppFlavor.dev;
    }
  }

  /// Base URL the Flutter admin panel talks to.
  ///
  /// - Dev (local admin_panel/backend): `http://127.0.0.1:3000/api/v1`
  /// - Prod (real farzandim-backend): `https://farzandimedu.uz/api`
  ///
  /// Override via `--dart-define=API_BASE_URL=...`.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000/api/v1',
  );

  static String get backendOrigin {
    final uri = Uri.parse(apiBaseUrl);
    return uri
        .replace(path: '', query: '', fragment: '')
        .toString()
        .replaceAll(RegExp(r'/$'), '');
  }

  static bool get isDebug => flavor != AppFlavor.prod;

  static String get logLabel => 'farzandim_admin:${flavor.name}';

  /// Validates [apiBaseUrl]; production must use HTTPS.
  static void assertConfiguration() {
    final u = Uri.tryParse(apiBaseUrl);
    if (u == null || !u.hasScheme || u.host.isEmpty) {
      throw StateError('Invalid API_BASE_URL: $apiBaseUrl');
    }
    if (flavor == AppFlavor.prod && u.scheme != 'https') {
      throw StateError(
        'Production build requires https API_BASE_URL (got ${u.scheme})',
      );
    }
  }
}
