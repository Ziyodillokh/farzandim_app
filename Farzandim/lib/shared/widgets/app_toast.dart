// ─────────────────────────────────────────────────────────────────────
// AppToast — premium yuqori (top) toast/xabar
// ─────────────────────────────────────────────────────────────────────
//
// Standart Material SnackBar (pastda, qora, theme'ga moslashmagan) o'rniga.
// iOS-uslubidagi banner: yuqoridan silliq tushadi, light/dark'ga moslashadi,
// tur (success/error/info/warning) bo'yicha ikona+rang, yumshoq soya.
//
// Foydalanish:
// ```dart
// AppToast.success(context, 'Saqlandi');
// AppToast.info(context, 'Tez orada qo'shiladi');
// AppToast.error(context, 'Xatolik yuz berdi');
// // yoki: AppToast.show(context, '...', type: AppToastType.warning);
// ```
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

/// Toast turi — ikona va aksent rangini belgilaydi.
enum AppToastType { success, error, info, warning }

// Parvoz toast tokenlari — chat va boshqa yangi ekranlar bilan bir xil.
// Avval AppColors.surface (teal #203A43) + AppColors.info (och ko'k #60A5FA)
// ishlatilardi — Parvoz'ning neytral-qora foni yonida "eski" ko'rinardi.
const _pBlue = Color(0xFF216BFF);
const _pSurfaceDark = Color(0xFF1C232B);
const _pBorderDark = Color(0x1FFFFFFF);

/// Premium top toast — `Overlay` orqali ko'rsatiladi (Scaffold shart emas).
class AppToast {
  AppToast._();

  static OverlayEntry? _current;

  /// Tezkor yordamchilar.
  static void success(BuildContext context, String message) =>
      show(context, message);
  static void error(BuildContext context, String message) =>
      show(context, message, type: AppToastType.error);
  static void info(BuildContext context, String message) =>
      show(context, message, type: AppToastType.info);
  static void warning(BuildContext context, String message) =>
      show(context, message, type: AppToastType.warning);

  /// Toast ko'rsatish. Avvalgi toast bo'lsa almashtiriladi.
  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.success,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Avvalgisini darhol olib tashlaymiz (navbat hosil bo'lmasin).
    _current?.remove();
    _current = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastView(
        message: message,
        type: type,
        duration: duration,
        onClosed: () {
          if (_current == entry) {
            entry.remove();
            _current = null;
          }
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  /// Doimiy (spinner bilan) status toast — masalan "Video tayyorlanmoqda…".
  /// O'zi yopilmaydi: qaytgan `AppToastHandle.dismiss()` chaqiring. Ko'rinish
  /// oddiy toast bilan BIR XIL (faqat ikona o'rniga aylanuvchi indikator).
  static AppToastHandle loading(BuildContext context, String message) {
    final handle = AppToastHandle._();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return handle;

    _current?.remove();
    _current = null;

    late OverlayEntry entry;
    void removeSelf() {
      if (_current == entry) {
        entry.remove();
        _current = null;
      }
    }

    entry = OverlayEntry(
      builder: (_) => _ToastView(
        message: message,
        type: AppToastType.info, // loading → ko'k aksent
        duration: null, // doimiy — o'zi yopilmaydi
        spinner: true,
        onClosed: removeSelf,
      ),
    );
    _current = entry;
    overlay.insert(entry);
    handle._dismiss = removeSelf;
    return handle;
  }
}

/// `AppToast.loading()` qaytaradigan tutqich — `dismiss()` bilan yopiladi.
class AppToastHandle {
  AppToastHandle._();

  VoidCallback? _dismiss;

  void dismiss() {
    _dismiss?.call();
    _dismiss = null;
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.type,
    required this.duration,
    required this.onClosed,
    this.spinner = false,
  });

  final String message;
  final AppToastType type;

  /// `null` — doimiy (o'zi yopilmaydi; `AppToast.loading` uchun).
  final Duration? duration;
  final VoidCallback onClosed;

  /// `true` — ikona o'rniga aylanuvchi indikator (loading).
  final bool spinner;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _c,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _c.forward();
    // Avtomatik yopilish — faqat `duration` berilgan bo'lsa (loading doimiy).
    final d = widget.duration;
    if (d != null) Future<void>.delayed(d, _close);
  }

  Future<void> _close() async {
    if (!mounted) return;
    await _c.reverse();
    widget.onClosed();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  ({Color color, IconData icon}) get _style => switch (widget.type) {
    AppToastType.success => (
      color: AppColors.success,
      icon: SolarIconsBold.checkCircle,
    ),
    AppToastType.error => (
      color: AppColors.error,
      icon: SolarIconsBold.dangerCircle,
    ),
    AppToastType.warning => (
      color: AppColors.warning,
      icon: SolarIconsBold.dangerTriangle,
    ),
    AppToastType.info => (
      // Parvoz ko'k (avval AppColors.info #60A5FA — och, eski).
      color: _pBlue,
      icon: SolarIconsBold.infoCircle,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final media = MediaQuery.of(context);
    final isDark = AppColors.isDark;
    return Positioned(
      // Status bar ostidan aniq bo'shliq (avval sm — juda tepada, kesilgandek
      // ko'rinardi).
      top: media.padding.top + AppDimensions.md,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Align(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.lg,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: _close,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.md,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        // Parvoz neytral-qora (teal surface o'rniga); light
                        // rejimда oq.
                        color: isDark ? _pSurfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusL,
                        ),
                        border: Border.all(
                          color: isDark
                              ? _pBorderDark
                              : const Color(0xFFE5E9EF),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.45 : 0.12,
                            ),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Tur ikonasi (yoki loading spinner) — past-alpha
                          // tint doira ichida.
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: s.color.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: widget.spinner
                                ? Padding(
                                    padding: const EdgeInsets.all(9),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        s.color,
                                      ),
                                    ),
                                  )
                                : Icon(s.icon, color: s.color, size: 22),
                          ),
                          const SizedBox(width: AppDimensions.md),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
