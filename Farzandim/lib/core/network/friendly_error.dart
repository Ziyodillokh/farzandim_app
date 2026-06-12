import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

/// Istalgan xatodan foydalanuvchiga ko'rsatsa bo'ladigan LOKALIZATSIYALANGAN
/// xabar yasaydi (EH-08). Avval loyihada bu mantiq 3 joyda har xil imzo
/// bilan takrorlangan edi — endi bitta manba.
///
/// Tartib:
/// 1. Backend xabari — NestJS exception filter `{ message: string | [] }`
///    qaytaradi; bo'lsa o'shani ko'rsatamiz. DIQQAT: backend hamma joyda
///    o'zbekcha yozmaydi (auth-guard/validation xabarlari inglizcha) —
///    kontekst aniq xabar talab qilsa chaqiruvchi statusni O'ZI oldin
///    tekshirsin (masalan app_limit repo 401'ni o'zi map qiladi).
/// 2. Javob umuman kelmagan (`response == null`) — internet yo'q.
/// 3. Chaqiruvchining `fallback`i — kontekstli xabar har doim status-kod
///    xabaridan ustun (login'dagi message'siz 401 "sessiya tugadi" emas,
///    "kirishda xatolik" deyilishi kerak — anonim user'da sessiya yo'q).
/// 4. 401/403 — sessiya/ruxsat xabarlari; aks holda umumiy xabar.
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
    if (code == 401) return fallback ?? 'errors.sessionExpired'.tr();
    if (code == 403) return fallback ?? 'errors.forbidden'.tr();
  }
  return fallback ?? 'errors.generic'.tr();
}
