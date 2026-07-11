// ─────────────────────────────────────────────────────────────────────
// SettingsScreen — "Tizim sozlamalari" (Figma 1:1, Parvoz night)
// ─────────────────────────────────────────────────────────────────────
//
// Profil'dagi ⚙ bosilganda ochiladi. Qatorlar (Figma):
//   Akkount            → /account-edit (Figma "Akkount sozlamalari")
//   Faol sessiyalar    → joriy qurilma paneli
//   Bildirishnomalar   → afzallik paneli (Eng muhimlar / Barchasi + Saqlash)
//   Ilova tili         → til paneli (O'zbek / Rus / English + Saqlash)
//   Qo'llab quvvatlash → aloqa paneli (Telegram / Telefon / Email + Yopish)
//   Biz haqimizda      → kompaniya/versiya oynasi
//
// LOGIKA SAQLANGAN: til (context.setLocale), versiya (package_info);
// bildirishnoma afzalligi SharedPreferences'da (notif_pref_v1).

import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Figma tokenlar ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _card = Color(0xFF181C22);
const _sheetBg = Color(0xFF15181E);
const _optionBg = Color(0xFF1E2229);
const _glass = Color(0x14FFFFFF);
const _glassBorder = Color(0x24FFFFFF);
const _dim = Color(0x99FFFFFF);
const _line = Color(0x14FFFFFF);
const _green = Color(0xFF22C55E);

/// Bildirishnoma afzalligi kaliti (SharedPreferences).
const kNotifPrefKey = 'notif_pref_v1'; // 'important' | 'all'

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w700,
  Color c = Colors.white,
  double ls = -0.3,
}) => GoogleFonts.unbounded(
  fontSize: s,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.25,
);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.4);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      // Versiya ko'rsatilmaydi.
    }
  }

  String get _langName => switch (context.locale.languageCode) {
    'ru' => 'Русский',
    'en' => 'English',
    _ => "O'zbek",
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 54, 16, 20),
              child: Row(
                children: [
                  _SquareBtn(
                    icon: Icons.arrow_back_rounded,
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/dashboard');
                      }
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Tizim sozlamalari',
                      textAlign: TextAlign.center,
                      style: _unb(18),
                    ),
                  ),
                  const SizedBox(width: 46),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                children: [
                  _SettingsRow(
                    icon: SolarIconsBold.userCircle,
                    title: 'Akkount',
                    subtitle: 'Login, parol, telefon',
                    onTap: () => context.push('/account-edit'),
                  ),
                  _SettingsRow(
                    icon: SolarIconsBold.devices,
                    title: 'Faol sessiyalar',
                    subtitle: 'Kirilgan qurilmalar',
                    onTap: _showSessionsSheet,
                  ),
                  _SettingsRow(
                    icon: SolarIconsBold.bell,
                    title: 'Bildirishnomalar',
                    subtitle: 'Qaysi xabarlar kelishi',
                    onTap: _showNotifPrefSheet,
                  ),
                  _SettingsRow(
                    icon: SolarIconsBold.global,
                    title: 'Ilova tili',
                    subtitle: _langName,
                    onTap: _showLanguageSheet,
                  ),
                  _SettingsRow(
                    icon: SolarIconsBold.handHeart,
                    title: "Qo'llab quvvatlash",
                    subtitle: 'Qayta aloqa',
                    onTap: _showSupportSheet,
                  ),
                  _SettingsRow(
                    icon: SolarIconsBold.smileCircle,
                    title: 'Biz haqimizda',
                    subtitle: 'Kompaniya haqida',
                    onTap: _showAboutDialog,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bildirishnomalar afzalligi (Figma: Eng muhimlar / Barchasi) ──
  Future<void> _showNotifPrefSheet() async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    var selected = prefs.getString(kNotifPrefKey) ?? 'important';
    if (!mounted) return;
    await _showParvozSheet(
      title: 'Bildirishnomalar',
      builder: (setSheetState) => [
        _OptionRow(
          label: 'Eng muhimlar',
          selected: selected == 'important',
          onTap: () => setSheetState(() => selected = 'important'),
        ),
        _OptionRow(
          label: 'Barchasi',
          selected: selected == 'all',
          onTap: () => setSheetState(() => selected = 'all'),
        ),
      ],
      buttonLabel: 'Saqlash',
      buttonBlue: true,
      onButton: () async {
        await prefs.setString(kNotifPrefKey, selected);
      },
    );
  }

  // ── Ilova tili (Figma: bayroq + nom, tanla → Saqlash) ──
  Future<void> _showLanguageSheet() async {
    HapticFeedback.selectionClick();
    var selected = context.locale.languageCode;
    await _showParvozSheet(
      title: 'Ilova tili',
      builder: (setSheetState) => [
        _OptionRow(
          label: "O'zbek",
          flagAsset: 'assets/icons/flag_uz.svg',
          selected: selected == 'uz',
          onTap: () => setSheetState(() => selected = 'uz'),
        ),
        _OptionRow(
          label: 'Rus',
          flagAsset: 'assets/icons/flag_ru.svg',
          selected: selected == 'ru',
          onTap: () => setSheetState(() => selected = 'ru'),
        ),
        _OptionRow(
          label: 'English',
          flagAsset: 'assets/icons/flag_gb.svg',
          selected: selected == 'en',
          onTap: () => setSheetState(() => selected = 'en'),
        ),
      ],
      buttonLabel: 'Saqlash',
      buttonBlue: true,
      onButton: () async {
        await context.setLocale(Locale(selected));
        if (mounted) setState(() {});
      },
    );
  }

  // ── Faol sessiyalar — joriy qurilma ──
  Future<void> _showSessionsSheet() async {
    HapticFeedback.selectionClick();
    var device = 'Web brauzer';
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final a = await DeviceInfoPlugin().androidInfo;
        device = '${a.brand} ${a.model}';
      }
    } catch (_) {}
    if (!mounted) return;
    await _showParvozSheet(
      title: 'Faol sessiyalar',
      builder: (_) => [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _optionBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(SolarIconsBold.smartphone, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device, style: _pop(14.5, w: FontWeight.w600)),
                    Text('Hozirgi qurilma', style: _pop(12, c: _dim)),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ],
      buttonLabel: 'Yopish',
      buttonBlue: false,
    );
  }

  // ── Qo'llab quvvatlash — aloqa kanallari (Figma) ──
  Future<void> _showSupportSheet() async {
    HapticFeedback.selectionClick();
    await _showParvozSheet(
      title: "Qo'llab quvvatlash",
      builder: (_) => [
        const _ContactRow(
          label: 'Telegram',
          value: '@parvoz_bot',
          icon: SolarIconsBold.plain,
        ),
        const _ContactRow(
          label: 'Telefon',
          value: '+998 94 064 00 13',
          icon: SolarIconsBold.phone,
        ),
        const _ContactRow(
          label: 'Email',
          value: 'parvoz_support@gmail.com',
          icon: SolarIconsBold.letter,
          last: true,
        ),
      ],
      buttonLabel: 'Yopish',
      buttonBlue: false,
    );
  }

  void _showAboutDialog() {
    HapticFeedback.selectionClick();
    showDialog<void>(
      context: context,
      builder: (_) => _InfoDialog(
        title: 'Biz haqimizda',
        body:
            "Parvoz — bolalar uchun xavfsiz ta'lim va oilaviy aloqa ilovasi."
            '${_version.isNotEmpty ? '\n\nVersiya: $_version' : ''}',
      ),
    );
  }

  /// Umumiy panel: tutqich + sarlavha + kontent + pastda tugma (Figma).
  Future<void> _showParvozSheet({
    required String title,
    required List<Widget> Function(void Function(void Function()) setState)
    builder,
    required String buttonLabel,
    required bool buttonBlue,
    Future<void> Function()? onButton,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _sheetBg,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.viewPaddingOf(ctx).bottom;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Text(title, style: _unb(16)),
                const SizedBox(height: 16),
                ...builder(setSheetState),
                const SizedBox(height: 90),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    if (onButton != null) await onButton();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: buttonBlue ? _blue : _glass,
                      borderRadius: BorderRadius.circular(999),
                      border: buttonBlue
                          ? null
                          : Border.all(color: _glassBorder),
                    ),
                    child: Text(
                      buttonLabel,
                      style: _pop(15, w: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════ Widget'lar ════════════

class _SquareBtn extends StatelessWidget {
  const _SquareBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _glass,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _glassBorder),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

/// Sozlamalar qatori — Figma karta: oq ikon + sarlavha + izoh + chevron.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(18, 15, 14, 15),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x12FFFFFF)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _unb(14.5, w: FontWeight.w600, ls: -0.2)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: _pop(12.5, c: _dim)),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel ichidagi tanlov qatori — pill karta + tanlanganda ✓ (Figma).
/// `flagAsset` berilsa nom oldida bayroq chiqadi (til tanlash).
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.flagAsset,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? flagAsset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _optionBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            if (flagAsset != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SvgPicture.asset(
                  flagAsset!,
                  width: 26,
                  height: 20,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(label, style: _unb(14, w: FontWeight.w500, ls: 0)),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Aloqa qatori — label + qiymat + ikon, pastida ingichka chiziq (Figma).
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.label,
    required this.value,
    required this.icon,
    this.last = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nusxalandi: $value'),
            backgroundColor: const Color(0xFF23303F),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: _line)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: _pop(12.5, c: _dim)),
                    const SizedBox(height: 3),
                    Text(value, style: _unb(15, w: FontWeight.w600, ls: -0.2)),
                  ],
                ),
              ),
              Icon(icon, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oddiy ma'lumot oynasi (biz haqimizda).
class _InfoDialog extends StatelessWidget {
  const _InfoDialog({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _sheetBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: _unb(17)),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: _pop(13.5, c: _dim),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _glass,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _glassBorder),
                ),
                child: Text('Yopish', style: _pop(14.5, w: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
