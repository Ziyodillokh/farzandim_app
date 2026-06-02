import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

/// H7 — web'da cross-origin so'rovlarda cookie (HttpOnly refresh token)
/// yuborilishi va qabul qilinishi uchun `withCredentials` ni yoqadi.
/// Same-origin (production) da shart emas, lekin zararsiz.
void applyWebCredentials(Dio dio) {
  final adapter = dio.httpClientAdapter;
  if (adapter is BrowserHttpClientAdapter) {
    adapter.withCredentials = true;
  }
}
