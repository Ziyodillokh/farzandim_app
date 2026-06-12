import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/auth/data/repositories/device_link_repository.dart';
import 'package:farzandim/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Akkauntga qo'shilish — ikkinchi qurilmani ulash uchun QR kod (mas'ul).
///
/// "Faol sessiyalar" → "Boshqa hisob qo'shish" orqali ochiladi. Backend'dan
/// qisqa muddatli device-link kod olinadi va QR ko'rsatiladi. Yangi qurilma
/// kirish sahifasida "Akkauntga qo'shilish" → kamera bilan shu QR'ni
/// skanerlab, ikkinchi qurilma sifatida kiradi.
class AddAccountScreen extends ConsumerStatefulWidget {
  /// `AddAccountScreen` konstruktor.
  const AddAccountScreen({super.key});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen>
    with SingleTickerProviderStateMixin {
  String? _payload; // QR ichidagi device-link payload (null = yuklanmoqda)
  int _secondsLeft = 0;
  Timer? _timer;
  bool _loading = true;
  String? _error;
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _create();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spin.dispose();
    super.dispose();
  }

  /// Backend'dan yangi device-link kod oladi va QR + sanoqni boshlaydi.
  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final link = await ref.read(deviceLinkRepositoryProvider).create();
      if (!mounted) return;
      _payload = link.qrPayload;
      _secondsLeft = link.expiresInSec;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (_secondsLeft <= 1) {
          setState(() => _secondsLeft = 0);
          t.cancel();
        } else {
          setState(() => _secondsLeft -= 1);
        }
      });
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'auth.addAccount.createFailed'.tr();
      });
    }
  }

  String get _formattedTime {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  bool get _expired => _secondsLeft == 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AuthBackButton(),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.sm,
            AppDimensions.lg,
            AppDimensions.xl,
          ),
          child: Column(
            children: [
              const SizedBox(height: AppDimensions.sm),

              // ─── QR / loading / error ───
              if (_loading)
                SizedBox(
                  height: 260,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else if (_error != null) ...[
                const SizedBox(height: AppDimensions.xl),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyM.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: AppDimensions.md),
                TextButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('auth.addAccount.refresh'.tr()),
                  style: TextButton.styleFrom(foregroundColor: kAuthLinkColor),
                ),
                const SizedBox(height: AppDimensions.xl),
              ] else ...[
                _QrCard(
                  token: _payload ?? '',
                  expired: _expired,
                  onRefresh: _create,
                ),
                const SizedBox(height: AppDimensions.lg),

                // ─── Sanoq taymer ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: _expired
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Text(
                      _expired
                          ? 'auth.addAccount.expired'.tr()
                          : '${'auth.addAccount.expiresIn'.tr()}: '
                              '$_formattedTime',
                      style: AppTextStyles.bodyM.copyWith(
                        color: _expired
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.md),

                // ─── Status: kutilmoqda / yangilash ───
                if (_expired)
                  TextButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text('auth.addAccount.refresh'.tr()),
                    style: TextButton.styleFrom(
                      foregroundColor: kAuthLinkColor,
                      textStyle: AppTextStyles.bodyM.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RotationTransition(
                        turns: _spin,
                        child: const Icon(
                          Icons.sync_rounded,
                          size: 18,
                          color: kAuthLinkColor,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Text(
                        'auth.addAccount.waiting'.tr(),
                        style: AppTextStyles.bodyM.copyWith(
                          color: kAuthLinkColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],

              const SizedBox(height: AppDimensions.xl),

              // ─── Yo'riqnoma ───
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'auth.addAccount.instructionsTitle'.tr(),
                  style: AppTextStyles.headlineL.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.10),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),

              _InstructionsCard(
                steps: [
                  'auth.addAccount.step1'.tr(),
                  'auth.addAccount.step2'.tr(),
                  'auth.addAccount.step3'.tr(),
                  'auth.addAccount.step4'.tr(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oq fonli QR karta — markazda yurak overlay. Muddati tugasa xiralashadi.
class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.token,
    required this.expired,
    required this.onRefresh,
  });

  final String token;
  final bool expired;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F6),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: expired ? 0.25 : 1,
              child: QrImageView(
                data: token,
                size: 220,
                backgroundColor: const Color(0xFFF4F4F6),
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF111114),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF111114),
                ),
              ),
            ),

            // Markazdagi yurak (Figma).
            if (!expired)
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.favorite_rounded,
                  size: 26,
                  color: Color(0xFF111114),
                ),
              ),

            // Muddati tugasa — yangilash overlay.
            if (expired)
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRefresh,
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    decoration: const BoxDecoration(
                      color: Color(0xFF111114),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Yo'riqnoma kartasi — raqamlangan qadamlar (to'q fon).
class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: AppColors.divider, indent: 20),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.lg,
                vertical: AppDimensions.md,
              ),
              child: Row(
                children: [
                  Text(
                    '${i + 1}.',
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: AppTextStyles.bodyM,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
