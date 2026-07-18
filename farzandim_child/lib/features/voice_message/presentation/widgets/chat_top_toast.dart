// ─────────────────────────────────────────────────────────────────────
// ChatTopToast — yuqori (top) status toast (chat uchun)
// ─────────────────────────────────────────────────────────────────────
//
// Ota-ona ilovasidagi `AppToast` bilan BIR XIL ko'rinish: qorong'i dumaloq
// karta (#1C232B), chapda tint-doira ichida ikona/spinner, oq matn, yumshoq
// soya. Ekran tepasidan chiqadi. Barcha status xabarlari (video/ovoz
// tayyorlanmoqda / yuborildi) shu bitta ko'rinishda — avval har xil edi.
//
//   // Doimiy (spinner bilan) — keyin o'zingiz yopasiz:
//   final t = ChatTopToast.show(context, 'Video tayyorlanmoqda…', spinner: true);
//   ... ish tugadi ...
//   t.dismiss();
//
//   // Tez xabar (o'zi yo'qoladi):
//   ChatTopToast.flash(context, 'Video yuborildi', icon: Icons.check_rounded);

import 'package:flutter/material.dart';

// Parvoz status-toast tokenlari — ota-ona `AppToast` bilan bir xil.
const _toastBg = Color(0xFF1C232B);
const _toastBorder = Color(0x1FFFFFFF);
const _toastGreen = Color(0xFF22C55E); // "yuborildi" (success)
const _toastBlue = Color(0xFF216BFF); // "tayyorlanmoqda" (loading)

/// `show`/`flash` qaytaradigan tutqich — `dismiss()` bilan yopiladi.
class ChatToastHandle {
  ChatToastHandle._(this._entry);
  OverlayEntry? _entry;

  void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

class ChatTopToast {
  ChatTopToast._();

  /// Doimiy toast — `dismiss()` chaqirilguncha turadi. `spinner: true` —
  /// chap tomonda aylanuvchi indikator (yuborilmoqda/tayyorlanmoqda).
  /// `accent` berilmasa: spinner → ko'k (loading), aks holda → yashil
  /// (success). Ikona berilmasa yashil check ishlatiladi.
  static ChatToastHandle show(
    BuildContext context,
    String text, {
    bool spinner = false,
    IconData? icon,
    Color? accent,
  }) {
    final overlay = Overlay.of(context);
    final topInset = MediaQuery.of(context).padding.top + 12;
    final entry = OverlayEntry(
      builder: (_) => _ToastView(
        text: text,
        spinner: spinner,
        icon: icon,
        accent: accent ?? (spinner ? _toastBlue : _toastGreen),
        topInset: topInset,
      ),
    );
    overlay.insert(entry);
    return ChatToastHandle._(entry);
  }

  /// Tez toast — `duration` dan keyin o'zi yo'qoladi.
  static void flash(
    BuildContext context,
    String text, {
    IconData? icon,
    Color? accent,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    final handle = show(context, text, icon: icon, accent: accent);
    Future<void>.delayed(duration, handle.dismiss);
  }
}

// Ota-ona `AppToast` bilan bir xil ko'rinish: qorong'i dumaloq karta, chapda
// tint-doira ichida ikona/spinner, oq matn; tepadan silliq tushadi (fade+slide).
class _ToastView extends StatelessWidget {
  const _ToastView({
    required this.text,
    required this.spinner,
    required this.icon,
    required this.accent,
    required this.topInset,
  });

  final String text;
  final bool spinner;
  final IconData? icon;
  final Color accent;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topInset,
      left: 0,
      right: 0,
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0, end: 1),
              builder: (_, t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * -24),
                  child: child,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _toastBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _toastBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Tint-doira ichida ikona yoki spinner (AppToast bilan
                      // bir xil).
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: spinner
                            ? Padding(
                                padding: const EdgeInsets.all(9),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(accent),
                                ),
                              )
                            : Icon(
                                icon ?? Icons.check_circle_rounded,
                                color: accent,
                                size: 22,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
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
    );
  }
}
