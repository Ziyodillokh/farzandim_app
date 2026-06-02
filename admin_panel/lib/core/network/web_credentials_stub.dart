import 'package:dio/dio.dart';

/// Native platformalar uchun no-op — `withCredentials` faqat web brauzerda
/// ma'noga ega (cross-origin cookie yuborish). [web_credentials_web.dart] ga qarang.
void applyWebCredentials(Dio dio) {}
