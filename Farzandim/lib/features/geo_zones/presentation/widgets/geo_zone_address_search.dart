// ─────────────────────────────────────────────────────────────────────
// Manzil qidirish varag'i (Parvoz dizayn) — geo-zona qo'shishда.
// ─────────────────────────────────────────────────────────────────────
//
// Layout:
//   ┌ handle ────────────────────────────────────────────────
//   │ "Manzil qidirish"                                [×]
//   │ ┌─────────────────────────────────────────────────┐
//   │ │ 🔍  Masjid, maktab, ko'cha nomi...             │  ← ko'k glow fokus
//   │ └─────────────────────────────────────────────────┘
//   │ [ Masjid ] [ Maktab ] [ Bog' ] [ Kasalxona ]        ← shortcut chip'lar
//   │
//   │ ─ Natijalar / bo'sh holat ───
//   └───────────────────────────────────────────────────────
//
// Debounce (350ms) + race himoyasi (so'rov navbat raqami) — eski javob
// yangi so'rov ustidan yozib qo'ymaydi.
//
// Natijalar kategoriya ikoni bilan chiqadi (masjid → gumbaz, maktab →
// daftar, bog' → daraxt, kasalxona → yurak, ko'cha → yo'l, va h.k.).

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
const _fieldBgFocused = Color(0xFF232B34);
const _blue = Color(0xFF216BFF);
const _border = Color(0x1AFFFFFF); // oq 10%
const _borderFocused = Color(0x66216BFF); // ko'k 40%
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

/// Shortcut chip — foydalanuvchi tez-tez qidiradigan joy toifalari.
/// Tap qilinsa: matn maydoniga yoziladi + qidiruv ishga tushadi.
class _CategoryShortcut {
  const _CategoryShortcut(this.icon, this.label, this.query);
  final IconData icon;
  final String label;
  final String query;
}

const _kShortcuts = <_CategoryShortcut>[
  _CategoryShortcut(SolarIconsBold.buildings, 'Masjid', 'masjid'),
  _CategoryShortcut(SolarIconsBold.mapPointSchool, 'Maktab', 'maktab'),
  _CategoryShortcut(SolarIconsBold.leaf, "Bog'", "bog'"),
  _CategoryShortcut(
    SolarIconsBold.mapPointHospital,
    'Kasalxona',
    'kasalxona',
  ),
  _CategoryShortcut(SolarIconsBold.shop, "Do'kon", "do'kon"),
];

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
  // ham, kelган HTTP javob ham `gen != _gen` bo'lsa tashlanadi — eski/uchувчi
  // so'rov hech qачон yangi holat ustidan yozmaydi (race-safe).
  int _gen = 0;
  List<PlaceSuggestion> _results = const [];
  bool _loading = false;
  bool _searched = false; // kamida bir marta so'rov yuborildimi

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // Fokus o'zgarganda border rangini yangilash uchun.
      if (mounted) setState(() {});
    });
  }

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

  /// Shortcut chip'dan so'rov: matn maydonini to'ldirib, darhol qidiradi.
  void _runShortcut(String query) {
    HapticFeedback.selectionClick();
    _controller.text = query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    final gen = ++_gen;
    setState(() => _loading = true);
    _runSearch(query, gen);
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
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'geoZoneEdit.search.title'.tr(),
                      style: _unb(20),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 40,
                      height: 40,
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
            // Shortcut chip'lar — faqat matn hali bo'sh bo'lsa ko'rinadi
            // (natija/yuklanish paytida joy egallamasin).
            if (_controller.text.trim().length < kMinSearchChars) ...[
              const SizedBox(height: 14),
              _ShortcutRow(onTap: _runShortcut),
            ],
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
        icon: SolarIconsOutline.mapArrowSquare,
        title: 'geoZoneEdit.search.prompt'.tr(),
        subtitle: 'Yaqin joylarni chiqarish uchun manzilni yozing yoki '
            'yuqoridagi tugmalarni bosing.',
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
                  const Divider(height: 1, color: _border, indent: 68),
              itemBuilder: (context, i) {
                // `place`ни bir marta ushlab qolamiz — onTap bosilганда jonli
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
        title: 'geoZoneEdit.search.noResults'.tr(),
        subtitle: "Boshqa so'z bilan urinib ko'ring.",
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
    final hasFocus = focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: hasFocus ? _fieldBgFocused : _fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus ? _borderFocused : _border,
          width: hasFocus ? 1.5 : 1,
        ),
        boxShadow: hasFocus
            ? const [
                BoxShadow(
                  color: Color(0x33216BFF),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            SolarIconsOutline.magnifier,
            size: 20,
            color: hasFocus ? _blue : _dim,
          ),
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

// ════════════ Kategoriya shortcut qatori ════════════

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kShortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = _kShortcuts[i];
          return _ShortcutChip(shortcut: s, onTap: () => onTap(s.query));
        },
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({required this.shortcut, required this.onTap});

  final _CategoryShortcut shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(shortcut.icon, size: 16, color: _blue),
            const SizedBox(width: 6),
            Text(
              shortcut.label,
              style: _pop(13, w: FontWeight.w600),
            ),
          ],
        ),
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
    final (icon, tint) = _iconForKind(place.kind);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // Kategoriyaga qarab ikon.
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: tint),
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
                    style: _pop(15, w: FontWeight.w600),
                  ),
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: 3),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _fieldBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _fmtDistance(place.distanceMeters),
                style: _pop(11.5, w: FontWeight.w600, c: _dim),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kategoriyaga mos ikon + rang. Palet fon bilan yaxshi kontrastda.
  static (IconData, Color) _iconForKind(PlaceKind k) {
    switch (k) {
      case PlaceKind.school:
        return (SolarIconsBold.mapPointSchool, const Color(0xFFFFB020));
      case PlaceKind.mosque:
        return (SolarIconsBold.buildings, const Color(0xFF22C55E));
      case PlaceKind.park:
        return (SolarIconsBold.leaf, const Color(0xFF34D399));
      case PlaceKind.hospital:
        return (SolarIconsBold.mapPointHospital, const Color(0xFFEF4444));
      case PlaceKind.restaurant:
        return (SolarIconsBold.chefHat, const Color(0xFFF97316));
      case PlaceKind.shop:
        return (SolarIconsBold.shop, const Color(0xFFA78BFA));
      case PlaceKind.street:
        return (SolarIconsBold.mapPointWave, const Color(0xFF60A5FA));
      case PlaceKind.city:
        return (SolarIconsBold.buildings, const Color(0xFF60A5FA));
      case PlaceKind.other:
        return (SolarIconsBold.mapPoint, _blue);
    }
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
  const _Hint({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 40, color: _blue),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _pop(15, w: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: _pop(13, c: _dim),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
