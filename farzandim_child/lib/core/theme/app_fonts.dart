// Ilova shriftlarini birinchi kadrdan OLDIN yuklash.
//
// google_fonts bundle'dagi shriftlarni asinxron yuklaydi. Oldindan
// yuklanmasa birinchi kadrlar zaxira shriftda chiziladi va matn o'lchoviga
// tayanadigan joylar (masalan, kengligi fan nomiga moslashadigan plitkalar)
// noto'g'ri hisoblanadi — har xil telefonda har xil ko'rinadi.

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// Yuklash uchun ko'pi bilan shuncha kutiladi (ishga tushish sekinlashmasin).
const _preloadTimeout = Duration(seconds: 2);

/// Growth sahifalari ishlatadigan oila/og'irliklarni yuklaydi. Xato yoki
/// vaqt tugasa — jim davom etadi (shrift keyinroq o'zi yuklanadi).
Future<void> preloadAppFonts() async {
  try {
    for (final w in const [FontWeight.w700, FontWeight.w800]) {
      GoogleFonts.montserrat(fontWeight: w);
    }
    for (final w in const [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
    ]) {
      GoogleFonts.plusJakartaSans(fontWeight: w);
    }
    await GoogleFonts.pendingFonts().timeout(_preloadTimeout);
  } catch (e) {
    debugPrint('Shriftlarni oldindan yuklab bo\'lmadi: $e');
  }
}
