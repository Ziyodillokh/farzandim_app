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
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Toast turi — ikona va aksent rangini belgilaydi.
enum AppToastType { success, error, info, warning }

/// Premium top toast — `Overlay` orqali ko'rsatiladi (Scaffold shart emas).
class AppToast {
  AppToast._();

  static OverlayEntry? _current;

  /// Tezkor yordamchilar.
  static void success(BuildContext context, String message) =>
      show(context, message, type: AppToastType.success);
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
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.type,
    required this.duration,
    required this.onClosed,
  });

  final String message;
  final AppToastType type;
  final Duration duration;
  final VoidCallback onClosed;

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
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _c,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _c.forward();
    // Avtomatik yopilish.
    Future<void>.delayed(widget.duration, _close);
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
        AppToastType.success => (color: AppColors.success, icon: Icons.check_circle_rounded),
        AppToastType.error => (color: AppColors.error, icon: Icons.error_rounded),
        AppToastType.warning => (color: AppColors.warning, icon: Icons.warning_amber_rounded),
        AppToastType.info => (color: AppColors.info, icon: Icons.info_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final media = MediaQuery.of(context);
    return Positioned(
      top: media.padding.top + AppDimensions.sm,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
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
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusL),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: AppColors.isDark ? 0.45 : 0.12,
                            ),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Tur ikonasi — past-alpha tint doira ichida.
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: s.color.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(s.icon, color: s.color, size: 22),
                          ),
                          const SizedBox(width: AppDimensions.md),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: AppTextStyles.bodyM.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
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
