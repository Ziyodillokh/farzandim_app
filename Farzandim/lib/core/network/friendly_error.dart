import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

/// Istalgan xatodan foydalanuvchiga ko'rsatsa bo'ladigan LOKALIZATSIYALANGAN
/// xabar yasaydi (EH-08). Avval loyihada bu mantiq 3 joyda har xil imzo
/// bilan takrorlangan edi — endi bitta manba.
///
/// Tartib:
/// 1. Backend xabari — NestJS exception filter `{ message: string | [] }`
///    qaytaradi; bo'lsa o'shani ko'rsatamiz (backend o'zbekcha yozadi).
/// 2. Javob umuman kelmagan (`response == null`) — internet yo'q.
/// 3. 401/403 — sessiya/ruxsat xabarlari.
/// 4. Aks holda chaqiruvchining `fallback`i yoki umumiy xabar.
///
/// `.tr()` kalitlari `assets/translations/*.json` dagi `errors.*` guruhida.
String friendlyError(Object error, {String? fallback}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
    if (error.response == null) return 'errors.noInternet'.tr();
    final code = error.response?.statusCode;
    if (code == 401) return 'errors.sessionExpired'.tr();
    if (code == 403) return 'errors.forbidden'.tr();
  }
  return fallback ?? 'errors.generic'.tr();
}
