// ─────────────────────────────────────────────────────────────────────
// ScanAccountScreen — kirish sahifasida "Akkauntga qo'shilish" → QR skaner
// ─────────────────────────────────────────────────────────────────────
//
// Yangi qurilma mas'ul qurilmaning QR kodini skanerlaydi → device-link
// redeem → parent tokenlari → onLoggedIn → router dashboard'ga o'tadi.
// Maks 2 qurilma (backend hal qiladi). Kamera ruxsati mobile_scanner
// tomonidan so'raladi (AndroidManifest'da CAMERA bor).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/auth/data/repositories/device_link_repository.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// QR skaner orqali ikkinchi qurilma sifatida kirish.
class ScanAccountScreen extends ConsumerStatefulWidget {
  /// `ScanAccountScreen` konstruktor.
  const ScanAccountScreen({super.key});

  @override
  ConsumerState<ScanAccountScreen> createState() => _ScanAccountScreenState();
}

class _ScanAccountScreenState extends ConsumerState<ScanAccountScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || _loading) return;
    final raw = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (raw == null || raw.isEmpty) return;

    _handled = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _controller.stop();

    try {
      final session = await ref.read(deviceLinkRepositoryProvider).redeem(raw);
      await ref
          .read(backendAuthProvider.notifier)
          .onLoggedIn(session.tokens, session.user);
      // Router AuthAuthenticated → dashboard'ga o'tadi; skanerni yopamiz.
      if (mounted) unawaited(Navigator.of(context).maybePop());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(e);
      });
      _handled = false;
      // Qayta skanerlash uchun kamerani qayta yoqamiz.
      await _controller.start();
    }
  }

  String _friendly(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 401) return 'QR kod yaroqsiz yoki muddati tugagan';
      if (code == null) return "Internet aloqasi yo'q. Qayta urinib ko'ring";
      return 'Xatolik yuz berdi ($code)';
    }
    if (e is FormatException) return "QR kod noto'g'ri";
    return 'Skanerlashda xatolik';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AuthBackButton(),
        title: Text(
          'auth.signIn.signUpButton'.tr(), // "Akkauntga qo'shilish"
          style: AppTextStyles.headlineL.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) =>
                _CameraError(error: error),
          ),

          // Skaner ramkasi (markazda).
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              ),
            ),
          ),

          // Pastki yo'riqnoma + xato.
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.lg,
                0,
                AppDimensions.lg,
                AppDimensions.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.md),
                      margin: const EdgeInsets.only(bottom: AppDimensions.md),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusM),
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyM.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Text(
                    'Asosiy qurilmadagi QR kodni ramka ichiga joylang',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyM.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    "Faol seanslar → Boshqa hisob qo'shish orqali ko'rsatiladi",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyS.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_loading)
            ColoredBox(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kamera ochilmasa / ruxsat berilmasa.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white54,
                size: 56,
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                'Kamera ochilmadi. Sozlamalardan kamera ruxsatini bering.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyM.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
