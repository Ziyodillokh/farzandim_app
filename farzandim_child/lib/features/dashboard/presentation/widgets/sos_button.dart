// ─────────────────────────────────────────────────────────────────────
// SosButton — 3 sekund ushlab turish bilan SOS yuborish
// ─────────────────────────────────────────────────────────────────────
//
// Tasodifan bosish oldini olish uchun foydalanuvchi tugmani 3 sekund
// ushlab turishi kerak. Progress ring to'lib boradi, 3 sek'da haptik
// signal va Firestore'ga yozish boshlanadi.
//
// Holatlar:
//   idle      — qizil tugma "Yordam kerak (SOS)"
//   holding   — progress ring to'lyapti
//   sending   — spinner
//   sent      — yashil ✓ "Yuborildi"
//   error     — qizil ! xato matni

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/sos/presentation/providers/sos_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SosButton extends ConsumerStatefulWidget {
  const SosButton({super.key});

  @override
  ConsumerState<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends ConsumerState<SosButton>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 3);

  late final AnimationController _progress;
  Timer? _holdTimer;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: _holdDuration,
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  void _startHold() {
    setState(() => _holding = true);
    HapticFeedback.lightImpact();
    _progress.forward(from: 0);
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdDuration, _send);
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _progress.reverse();
    if (mounted) setState(() => _holding = false);
  }

  Future<void> _send() async {
    HapticFeedback.heavyImpact();
    setState(() => _holding = false);
    await ref.read(sosStateProvider.notifier).send();

    // Sent yoki error — 4 sek'dan so'ng idle'ga qaytarish.
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        ref.read(sosStateProvider.notifier).reset();
        _progress.value = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sos = ref.watch(sosStateProvider);
    final disabled = sos.status == SosStatus.sending ||
        sos.status == SosStatus.sent;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => _startHold(),
      onTapUp: disabled ? null : (_) => _cancelHold(),
      onTapCancel: disabled ? null : _cancelHold,
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            return Stack(
              children: [
                // Pastki qatlam — qizil tugma
                _buttonSurface(sos),
                // Progress fill (chap → o'ng)
                if (_holding && _progress.value > 0)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _progress.value,
                          child: Container(
                            // ignore: deprecated_member_use
                            color: Colors.white.withOpacity(0.20),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buttonSurface(SosState sos) {
    final (Color bg, Widget child) = switch (sos.status) {
      SosStatus.sending => (
          AppColors.error,
          _Content(
            icon: null,
            label: 'dashboard.sosSending'.tr(),
            spinner: true,
          ),
        ),
      SosStatus.sent => (
          AppColors.success,
          _Content(
            icon: AppIcons.success,
            label: 'dashboard.sosSent'.tr(),
          ),
        ),
      SosStatus.error => (
          AppColors.warning,
          _Content(
            icon: AppIcons.error,
            label: 'dashboard.sosError'.tr(),
            tooltip: sos.errorMessage,
          ),
        ),
      SosStatus.idle => (
          AppColors.error,
          _Content(
            icon: Icons.emergency_share,
            label: _holding
                ? 'dashboard.sosHold'.tr(namedArgs: {'seconds': '3'})
                : 'dashboard.sosIdle'.tr(),
          ),
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.label,
    this.icon,
    this.spinner = false,
    this.tooltip,
  });

  final String label;
  final IconData? icon;
  final bool spinner;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (spinner)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.4,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 24, color: Colors.white),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: row);
    }
    return row;
  }
}
