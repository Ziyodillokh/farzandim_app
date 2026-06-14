// ─────────────────────────────────────────────────────────────────────
// ChatTopToast — Telegram uslubidagi yuqori "pill" toast (chat uchun)
// ─────────────────────────────────────────────────────────────────────
//
// Glassmorphic (blur) yumaloq pill, ekran tepasida suzadi. Telegram'dagi
// "Saqlanmoqda…" / "Video yuborildi" kabi nozik bildirishnomalar uchun.
//
//   // Doimiy (spinner bilan) — keyin o'zingiz yopasiz:
//   final t = ChatTopToast.show(context, 'Video tayyorlanmoqda…', spinner: true);
//   ... ish tugadi ...
//   t.dismiss();
//
//   // Tez xabar (o'zi yo'qoladi):
//   ChatTopToast.flash(context, 'Video yuborildi', icon: Icons.check_rounded);

import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:farzandim_child/core/theme/app_colors.dart';

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
        accent: accent ?? AppColors.primary,
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
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: accent.withValues(alpha: 0.45),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (spinner) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else if (icon != null) ...[
                    Icon(icon, color: accent, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
