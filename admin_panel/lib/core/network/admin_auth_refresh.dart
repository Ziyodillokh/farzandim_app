import 'package:dio/dio.dart';

import '../logging/app_logger.dart';
import '../ux/app_loading.dart';
import 'admin_session.dart';

/// Calls `POST /admin/auth/refresh` (no auth header). Returns new access or `null`.
Future<String?> performTokenRefresh(Dio plainDio) async {
  final refresh = AdminSession.refreshToken;
  if (refresh == null || refresh.isEmpty) {
    return null;
  }
  AppLoading.instance.begin();
  try {
    final res = await plainDio.post<Map<String, dynamic>>(
      '/admin/auth/refresh',
      data: {'refreshToken': refresh, 'refresh_token': refresh},
    );
    final map = res.data ?? {};
    final access =
        map['access_token'] as String? ?? map['accessToken'] as String?;
    final nextRefresh =
        map['refresh_token'] as String? ?? map['refreshToken'] as String? ?? refresh;
    if (access != null && access.isNotEmpty) {
      await AdminSession.setTokens(
        accessToken: access,
        refreshToken: nextRefresh,
      );
      return access;
    }
  } on DioException catch (e, st) {
    AppLogger.warning('Token refresh failed', e);
    AppLogger.debug('refresh trace', st);
  } catch (e, st) {
    AppLogger.error('Token refresh unexpected', error: e, stackTrace: st);
  } finally {
    AppLoading.instance.end();
  }
  await AdminSession.clear(cause: SessionClearCause.sessionExpired);
  return null;
}
