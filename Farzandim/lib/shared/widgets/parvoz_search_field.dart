// ─────────────────────────────────────────────────────────────────────
// ParvozSearchField — Parvoz uslubidagi qidiruv maydoni
// ─────────────────────────────────────────────────────────────────────
//
// Uzun ilova ro'yxatlari uchun ("Ilovalarni bloklash", "Kunlik vaqt
// limiti"): 100+ ilovani scroll qilib topish o'rniga nom bo'yicha
// qidiriladi. Dizayn geo-zona manzil qidiruvi bilan bir xil — 52px
// balandlik, radius 16, lupa ikonasi, matn bo'lsa tozalash tugmasi.
//
// MUHIM: ranglar QATTIQ Parvoz tokenlari (fon #00060A bo'lgan qorong'i
// varaqlar uchun). AppColors ishlatadigan (tema-sezgir, light mode ham
// bo'lishi mumkin) ekranlarda ISHLATMANG — u yerda maydon ko'rinmay
// qoladi.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

const _fieldBg = Color(0xFF12171E); // varaq kartasi bilan bir xil
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _blue = Color(0xFF216BFF);
const _dim = Color(0x8CFFFFFF); // oq 55%
const _hint = Color(0x66FFFFFF); // oq 40%

/// Ilova ro'yxatlari uchun qidiruv maydoni.
///
/// [onChanged] har harfda chaqiriladi (ro'yxat lokal filtrlanadi —
/// tarmoq so'rovi yo'q, shuning uchun debounce kerak emas).
class ParvozSearchField extends StatelessWidget {
  const ParvozSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    super.key,
  });

  /// Qidiruv matni nazoratchisi — egasi (ekran) yaratadi va dispose qiladi.
  final TextEditingController controller;

  /// Bo'sh maydondagi ko'rsatma matni.
  final String hint;

  /// Matn o'zgarganda (tozalash tugmasi ham bo'sh matn bilan chaqiradi).
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
      ),
      child: Row(
        children: [
          const Icon(SolarIconsOutline.magnifier, size: 20, color: _dim),
          const SizedBox(width: 10),
          Expanded(
            child: TextSelectionTheme(
              // Global teal emas — Parvoz ko'k kursor/belgilash.
              data: const TextSelectionThemeData(
                cursorColor: _blue,
                selectionHandleColor: _blue,
                selectionColor: Color(0x5C216BFF),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                cursorColor: _blue,
                textInputAction: TextInputAction.search,
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.white),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  // Global teal fill'ni o'chiramiz.
                  filled: false,
                  hintText: hint,
                  hintStyle: GoogleFonts.poppins(fontSize: 15, color: _hint),
                ),
              ),
            ),
          ),
          // Tozalash — faqat matn bo'lganda (setState'siz, ValueListenable).
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    SolarIconsBold.closeCircle,
                    size: 20,
                    color: _dim,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Ilova qidiruviga moslik — nom YOKI paket nomi bo'yicha (registrsiz).
///
/// Paket nomi ham tekshiriladi: ota-ona "instagram" deb yozsa, ilova
/// yorlig'i boshqacha bo'lsa ham (`com.instagram.android`) topiladi.
bool appMatchesQuery(String appName, String packageName, String query) {
  if (query.isEmpty) return true;
  return appName.toLowerCase().contains(query) ||
      packageName.toLowerCase().contains(query);
}
