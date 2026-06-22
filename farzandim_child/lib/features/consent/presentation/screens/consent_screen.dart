// ─────────────────────────────────────────────────────────────────────
// ConsentScreen — Parent Consent (App Store / Play Store compliance)
// ─────────────────────────────────────────────────────────────────────
//
// Bola ilovasi BIRINCHI marta ochilganda ko'rsatiladi. Splash dan keyin,
// /pairing dan oldin. Rozilik berilmaguncha keyingi sahifaga
// o'tib bo'lmaydi (router redirect himoyasi).
//
// "Ota-onam tasdiqlaydi" tugmasi — uzun bosish (3 sek). Bola tasodifan
// bosib qo'ymasligi va ota-ona ongli ravishda tasdiqlashi uchun.
// Bosish davomida progress ring 0 dan 1 ga to'lgani ko'rinadi.
//
// Tasdiqlangach: SharedPreferences `parent_consent_v1 = true` yoziladi,
// router avtomatik /splash → keyingi ekran (pairing yoki dashboard)ga
// o'tkazadi.

import 'dart:async';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/consent/presentation/providers/consent_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _holdDuration = Duration(seconds: 3);

  late final AnimationController _holdController;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: _holdDuration,
    )..addStatusListener(_onHoldStatus);
  }

  @override
  void dispose() {
    _holdController
      ..removeStatusListener(_onHoldStatus)
      ..dispose();
    super.dispose();
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_confirming) {
      _confirming = true;
      HapticFeedback.mediumImpact();
      unawaited(_finalize());
    }
  }

  Future<void> _finalize() async {
    await ref.read(consentStateProvider.notifier).confirm();
    // Routerning `refreshListenable` o'zgargan state'ni eshitib,
    // /consent dan keyingi marshrutga (/splash → ...) o'tkazadi.
    // Bu yerda qo'lda navigatsiya qilmaymiz — redirect ishlaydi.
  }

  void _onPressStart() {
    if (_confirming) return;
    HapticFeedback.lightImpact();
    _holdController.forward();
  }

  void _onPressEnd() {
    if (_confirming) return;
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const _ShieldBadge(color: AppColors.parvozGreen),
                      const SizedBox(height: 24),
                      const Text(
                        'Bu ilova ota-onangiz\nruxsati bilan ishlaydi',
                        style: TextStyle(
                          color: AppColors.parvozText,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Ilovani ishlatishni boshlashdan oldin ota-onangiz "
                        "quyidagi shartlarga rozi bo'lishi kerak.",
                        style: TextStyle(
                          color: AppColors.parvozTextDim,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _ConsentBullet(
                        icon: Icons.location_on_rounded,
                        title: 'Joylashuv',
                        text: 'Ilova bolaning joriy joylashuvini va '
                            'harakat tarixini ota-onaga ko\'rsatadi.',
                      ),
                      const _ConsentBullet(
                        icon: Icons.apps_rounded,
                        title: 'Ilova foydalanish',
                        text: 'Qaysi ilovalarda qancha vaqt sarflanganini '
                            'kuzatadi va ota-onaga hisobot beradi.',
                      ),
                      const _ConsentBullet(
                        icon: Icons.notifications_active_rounded,
                        title: 'Bildirishnomalar',
                        text: 'Ota-ona yuborgan xabarlar, eslatma va '
                            'SOS push-xabarlarini qabul qiladi.',
                      ),
                      const _ConsentBullet(
                        icon: Icons.shield_rounded,
                        title: 'Xavfsizlik',
                        text: "Bolaning qurilma ma'lumotlari (batareya, "
                            "model) ota-onaga yuboriladi.",
                      ),
                      const _ConsentBullet(
                        icon: Icons.lock_rounded,
                        title: 'Maxfiylik',
                        text: 'Ma\'lumotlar shifrlangan holda saqlanadi va '
                            'uchinchi shaxslarga berilmaydi.',
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _LongPressConfirmButton(
                holdAnimation: _holdController,
                onPressStart: _onPressStart,
                onPressEnd: _onPressEnd,
                confirming: _confirming,
              ),
              const SizedBox(height: 12),
              const Text(
                "Tugmani 3 sekund ushlab turing — bu ota-ona "
                "ekanligingizni tasdiqlaydi.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.parvozTextDim,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Icon(
        Icons.verified_user_rounded,
        color: color,
        size: 38,
      ),
    );
  }
}

class _ConsentBullet extends StatelessWidget {
  const _ConsentBullet({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.parvozGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.parvozGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.parvozText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.parvozTextDim,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LongPressConfirmButton extends StatelessWidget {
  const _LongPressConfirmButton({
    required this.holdAnimation,
    required this.onPressStart,
    required this.onPressEnd,
    required this.confirming,
  });

  final Animation<double> holdAnimation;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final bool confirming;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: confirming ? null : (_) => onPressStart(),
      onTapUp: confirming ? null : (_) => onPressEnd(),
      onTapCancel: confirming ? null : onPressEnd,
      child: AnimatedBuilder(
        animation: holdAnimation,
        builder: (context, _) {
          final progress = holdAnimation.value;
          return Container(
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.parvozGreen,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.parvozGreen.withValues(alpha: 0.35),
                  offset: const Offset(0, 6),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    heightFactor: 1,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      color: AppColors.parvozBlue,
                    ),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (confirming) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.parvozOnGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        confirming
                            ? 'Tasdiqlanmoqda...'
                            : 'Ota-onam tasdiqlaydi',
                        style: const TextStyle(
                          color: AppColors.parvozOnGreen,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
