// ─────────────────────────────────────────────────────────────────────
// Manzil qidirish varag'i (Parvoz dizayn) — geo-zona qo'shishда.
// ─────────────────────────────────────────────────────────────────────
//
// Deyarli to'liq ekran modal: tepada qidiruv maydoni (autofokus), pastda
// jonli taxminlar (as-you-type). Foydalanuvchi "masjid"/"maktab"/ko'cha yozadi
// → Photon (OSM) markazga yaqin joylarni qaytaradi, ENG YAQINDAN uzoqqa.
// Natijani bosса → varaq [PlaceSuggestion] bilan yopiladi (xarita o'sha joyga).
//
// Debounce (350ms) + race himoyasi (so'rov navbat raqami) — eski javob yangi
// so'rov ustidan yozib qo'ymaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/location/data/services/place_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar (lokal) ════════════
const _sheetBg = Color(0xFF12171C);
const _fieldBg = Color(0xFF1F262C);
const _blue = Color(0xFF216BFF);
const _border = Color(0x1AFFFFFF); // oq 10%
const _dim = Color(0x8CFFFFFF); // oq 55%
const _dimmer = Color(0x59FFFFFF); // oq 35%

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  height: 1.3,
  letterSpacing: -0.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.4);

/// Manzil qidirish varag'ini ochadi. Foydalanuvchi joy tanlasa
/// [PlaceSuggestion], bekor qilsa `null` qaytaradi.
Future<PlaceSuggestion?> showAddressSearch(
  BuildContext context, {
  required double centerLat,
  required double centerLng,
}) {
  return showModalBottomSheet<PlaceSuggestion>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddressSearchSheet(
      centerLat: centerLat,
      centerLng: centerLng,
    ),
  );
}

class _AddressSearchSheet extends ConsumerStatefulWidget {
  const _AddressSearchSheet({required this.centerLat, required this.centerLng});

  final double centerLat;
  final double centerLng;

  @override
  ConsumerState<_AddressSearchSheet> createState() =>
      _AddressSearchSheetState();
}

class _AddressSearchSheetState extends ConsumerState<_AddressSearchSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  // Har matn o'zgarishида oshadigan "avlod" hisoblagichi. Debounce callback
  // ham, kelган HTTP javob ham `gen != _gen` bo'lsa tashlanadi — eski/uchувчи
  // so'rov hech qачон yangi holat ustidan yozmaydi (race-safe).
  int _gen = 0;
  List<PlaceSuggestion> _results = const [];
  bool _loading = false;
  bool _searched = false; // kamida bir marta so'rov yuborildimi

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final q = value.trim();
    final gen = ++_gen; // oldingi uchувчi/kutayotgan so'rovlarni bekor qiladi
    if (q.length < kMinSearchChars) {
      setState(() {
        _results = const [];
        _loading = false;
        _searched = false;
      });
      return;
    }
    setState(() => _loading = true);
    // 350ms debounce — har harfda so'rov yubormaymiz (Photon odobi + tez UI).
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || gen != _gen) return; // yangi harf keldi → tashlaymiz
      _runSearch(q, gen);
    });
  }

  /// Foydalanuvchi klaviaturada "Qidirish"ни bosdi — debounce'ni kutmay
  /// darhol qidiramiz (kutayotgan callback `_gen` bilan bekor bo'ladi).
  void _onSubmitted(String value) {
    final q = value.trim();
    if (q.length < kMinSearchChars) return;
    final gen = ++_gen;
    setState(() => _loading = true);
    _runSearch(q, gen);
  }

  Future<void> _runSearch(String query, int gen) async {
    final results = await ref.read(placeSearchServiceProvider).search(
          query: query,
          centerLat: widget.centerLat,
          centerLng: widget.centerLng,
        );
    // Race: bu javob eng oxirgi o'zgarishga tegishli bo'lmasa — tashlaymiz.
    if (!mounted || gen != _gen) return;
    setState(() {
      _results = results;
      _loading = false;
      _searched = true;
    });
  }

  void _clear() {
    _controller.clear();
    _gen++; // uchувчi so'rovlarni bekor qilamiz
    setState(() {
      _results = const [];
      _loading = false;
      _searched = false;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    // 92% balandlik, LEKIN klaviatura ochilса container + padding ekrandan
    // oshmasin (aks holda tepa — handle/sarlavha — qirqilib qolardi).
    final maxSheet = mq.size.height * 0.92;
    final avail = mq.size.height - keyboard;
    final height = avail < maxSheet ? avail : maxSheet;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: _sheetBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: _border),
            left: BorderSide(color: _border),
            right: BorderSide(color: _border),
          ),
        ),
        child: Column(
          children: [
            // Drag handle.
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _dimmer,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Sarlavha + yopish.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'geoZoneEdit.search.title'.tr(),
                      style: _unb(18),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(
                        SolarIconsOutline.closeCircle,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Qidiruv maydoni.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SearchField(
                controller: _controller,
                focus: _focus,
                onChanged: _onChanged,
                onSubmitted: _onSubmitted,
                onClear: _clear,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    // 1) Hali yozilmagan / juda qisqa → yo'riqnoma.
    if (_controller.text.trim().length < kMinSearchChars) {
      return _Hint(
        icon: SolarIconsOutline.magnifier,
        text: 'geoZoneEdit.search.prompt'.tr(),
      );
    }
    // 2) Natijalar bor → ro'yxat (yaqindan uzoqqa). Yuklanayotgan bo'lsa
    //    ustidan ingichka indikator.
    if (_results.isNotEmpty) {
      return Column(
        children: [
          SizedBox(
            height: 2,
            child: _loading
                ? const LinearProgressIndicator(
                    color: _blue,
                    backgroundColor: Colors.transparent,
                    minHeight: 2,
                  )
                : null,
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: _results.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: _border, indent: 60),
              itemBuilder: (context, i) {
                // `place`ни bir marta ushlab qolamiz — onTap bosilganда jonli
                // `_results[i]`ни qayta o'qimasin (yangi qidiruv natijasi
                // kelib qolса stale-index/noto'g'ri joy qaytarmasин).
                final place = _results[i];
                return _ResultTile(
                  place: place,
                  onTap: () => Navigator.of(context).pop(place),
                );
              },
            ),
          ),
        ],
      );
    }
    // 3) Yuklanmoqda (natija hali yo'q).
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: _blue),
        ),
      );
    }
    // 4) So'rov yuborildi, natija yo'q → topilmadi.
    if (_searched) {
      return _Hint(
        icon: SolarIconsOutline.mapPointRemove,
        text: 'geoZoneEdit.search.noResults'.tr(),
      );
    }
    return const SizedBox.shrink();
  }
}

// ════════════ Qidiruv maydoni ════════════

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(SolarIconsOutline.magnifier, size: 20, color: _dim),
          const SizedBox(width: 10),
          Expanded(
            child: TextSelectionTheme(
              data: const TextSelectionThemeData(
                cursorColor: _blue,
                selectionHandleColor: _blue,
                selectionColor: Color(0x5C216BFF),
              ),
              child: TextField(
                controller: controller,
                focusNode: focus,
                autofocus: true,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                cursorColor: _blue,
                textInputAction: TextInputAction.search,
                style: _pop(15),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'geoZoneEdit.search.hint'.tr(),
                  hintStyle: _pop(15, c: _dimmer),
                ),
              ),
            ),
          ),
          // Tozalash (matn bo'lganda).
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: onClear,
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

// ════════════ Natija plitasi ════════════

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.place, required this.onTap});

  final PlaceSuggestion place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            // Joy ikoni.
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                SolarIconsBold.mapPoint,
                size: 21,
                color: _blue,
              ),
            ),
            const SizedBox(width: 12),
            // Nom + manzil.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(14.5, w: FontWeight.w600),
                  ),
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _pop(12.5, c: _dim),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Masofa chipi (eng yaqindan uzoqqa).
            Text(
              _fmtDistance(place.distanceMeters),
              style: _pop(12, w: FontWeight.w600, c: _dimmer),
            ),
          ],
        ),
      ),
    );
  }

  /// Masofa formati: <1km → "350 m", aks holda "1.2 km". Yaxlitlangan
  /// qiymatда tekshiramiz — 999.6 m → "1000 m" emas, "1.0 km".
  static String _fmtDistance(double meters) {
    final m = meters.round();
    if (m < 1000) return '$m m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

// ════════════ Yo'riqnoma / bo'sh holat ════════════

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: _dimmer),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: _pop(14, c: _dim)),
          ],
        ),
      ),
    );
  }
}
