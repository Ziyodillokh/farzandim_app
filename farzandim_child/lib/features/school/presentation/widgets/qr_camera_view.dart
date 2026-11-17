// ─────────────────────────────────────────────────────────────────────
// QrCameraView — kamera bilan QR skanerlash (davomat kiosk kodi)
// ─────────────────────────────────────────────────────────────────────
//
// Ulanish (pairing) skaneridagi sinalgan usul (f0c8176e — Xiaomi / Realme /
// HONOR'dagi qora ekran tuzatishi), alohida nusxada:
//   • `autoStart: false`; kamera ruxsati `Permission.camera.request()` bilan
//     OLDIN so'raladi, keyin `start()`;
//   • `errorBuilder` — qora ekran o'rniga aniq xabar va "Qayta urinish";
//   • ruxsat yo'q — tushuntirish + "Sozlamalarni ochish"; Sozlamalardan
//     qaytganda ruxsat qayta tekshiriladi;
//   • kamera Ekran vaqti bilan cheklangan (iOS `restricted`: tizim oynasi
//     chiqmaydi, ilova sozlamasida kamera tugmasi ham yo'q) — ota-onadan
//     so'rash kerakligi aytiladi, ishlamaydigan tugmalar ko'rsatilmaydi;
//   • `DetectionSpeed.noDuplicates`, faqat QR, orqa kamera.
// Controller tashqaridan berilgani uchun `MobileScanner` ilova holatini
// o'zi kuzatmaydi — fonga o'tishda kamera shu yerda to'xtatiladi va
// qaytganda qayta yoqiladi. Daraxtdan olinsa (dispose) kamera to'xtaydi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Skaner quruvchisi: aniqlangan QR matni [onCode]ga beriladi, [overlay]
/// (ramka, ko'rsatma) kamera tasviri ustida chiziladi. Testlarda kamerasiz
/// soxta skaner beriladi.
typedef QrScannerBuilder =
    Widget Function(
      BuildContext context,
      ValueChanged<String> onCode,
      Widget overlay,
    );

/// Haqiqiy kamera skaneri ([QrScannerBuilder]).
Widget buildQrCameraView(
  BuildContext context,
  ValueChanged<String> onCode,
  Widget overlay,
) => QrCameraView(onCode: onCode, overlay: overlay);

class QrCameraView extends StatefulWidget {
  const QrCameraView({super.key, required this.onCode, required this.overlay});

  final ValueChanged<String> onCode;
  final Widget overlay;

  @override
  State<QrCameraView> createState() => _QrCameraViewState();
}

enum _CameraState { starting, running, denied, restricted, failed }

/// Kamera ruxsati natijasi.
enum CameraAccess {
  granted,

  /// Rad etilgan — so'rash yoki Sozlamalardan yoqish mumkin.
  denied,

  /// Ekran vaqti / qurilma boshqaruvi cheklagan — bola o'zi yoqa olmaydi.
  restricted,
}

/// Ruxsat holati → skaner nima ko'rsatadi.
CameraAccess cameraAccessOf(PermissionStatus status) {
  if (status.isGranted) return CameraAccess.granted;
  if (status.isRestricted) return CameraAccess.restricted;
  return CameraAccess.denied;
}

class _QrCameraViewState extends State<QrCameraView>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
    autoStart: false,
  );

  _CameraState _state = _CameraState.starting;

  /// `_start()` bajarilmoqda (Sozlamalardan qaytish va tugma bir vaqtda
  /// chaqirsa, ikkinchisi kutmaydi).
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_ensurePermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      if (_controller.value.isRunning) unawaited(_controller.stop());
    } else if (state == AppLifecycleState.resumed) {
      final isDenied =
          _state == _CameraState.denied ||
          _state == _CameraState.restricted ||
          _controller.value.error?.errorCode ==
              MobileScannerErrorCode.permissionDenied;
      if (isDenied) {
        // Sozlamalardan qaytdi — ruxsat (yoki cheklov) o'zgargan bo'lishi
        // mumkin.
        unawaited(_ensurePermission(request: false));
      } else if (_state == _CameraState.running) {
        unawaited(_resume());
      }
    }
  }

  /// Ruxsat → kamera. [request] `false` — faqat tekshiriladi (so'ralmaydi).
  Future<void> _ensurePermission({bool request = true}) async {
    if (kIsWeb) {
      // Brauzer ruxsatni getUserMedia ichida o'zi so'raydi
      // (permission_handler web'da doim "denied").
      await _start();
      return;
    }
    var status = await Permission.camera.status;
    if (request &&
        (status.isDenied || status.isRestricted || status.isLimited)) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;
    switch (cameraAccessOf(status)) {
      case CameraAccess.granted:
        await _start();
      case CameraAccess.denied:
        setState(() => _state = _CameraState.denied);
      case CameraAccess.restricted:
        setState(() => _state = _CameraState.restricted);
    }
  }

  Future<void> _start() async {
    if (!mounted || _isStarting) return;
    _isStarting = true;
    // `MobileScanner` vidjeti daraxtda bo'lishi shart: start() u ulanishini
    // (attach) ~500 ms kutadi — "ochilmoqda" qatlami uning ustida turadi.
    setState(() => _state = _CameraState.starting);
    try {
      await _controller.start();
      if (mounted) setState(() => _state = _CameraState.running);
    } on Exception catch (e) {
      debugPrint('[school] kamera ochilmadi: $e');
      if (mounted) setState(() => _state = _CameraState.failed);
    } finally {
      _isStarting = false;
    }
  }

  /// Ilovaga qaytganda — kamera (ruxsat bor va to'xtagan bo'lsa).
  Future<void> _resume() async {
    final value = _controller.value;
    if (!value.hasCameraPermission || value.isRunning || value.isStarting) {
      return;
    }
    try {
      await _controller.start();
    } on Exception catch (e) {
      debugPrint('[school] kamera qayta yoqilmadi: $e');
    }
  }

  /// "Ruxsat berish": butunlay rad etilgan bo'lsa tizim oynasi chiqmaydi —
  /// Sozlamalar ochiladi (qaytganda ruxsat qayta tekshiriladi).
  Future<void> _allow() async {
    if (!kIsWeb && await Permission.camera.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    await _ensurePermission();
  }

  Future<void> _retry() async {
    await _controller.stop();
    await _start();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        widget.onCode(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _CameraState.denied => _CameraPermissionView(
        onAllow: _allow,
        onOpenSettings: openAppSettings,
      ),
      _CameraState.restricted => _CameraNotice(
        icon: Icons.no_photography_outlined,
        title: 'school.checkIn.restrictedTitle'.tr(),
        body: 'school.checkIn.restrictedBody'.tr(),
      ),
      _CameraState.failed => _CameraErrorView(
        message: 'school.checkIn.cameraFailedBody'.tr(),
        onRetry: _retry,
      ),
      _CameraState.starting || _CameraState.running => Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // Ramka va ko'rsatma faqat kamera tasviri ko'ringanda.
            overlayBuilder: (context, constraints) => widget.overlay,
            errorBuilder: (context, error) =>
                error.errorCode == MobileScannerErrorCode.permissionDenied
                ? _CameraPermissionView(
                    onAllow: _allow,
                    onOpenSettings: openAppSettings,
                  )
                : _CameraErrorView(
                    message: 'school.checkIn.cameraErrorCode'.tr(
                      namedArgs: {'code': error.errorCode.name},
                    ),
                    onRetry: _retry,
                  ),
          ),
          if (_state == _CameraState.starting)
            const ColoredBox(color: Colors.black, child: _CameraStartingView()),
        ],
      ),
    };
  }
}

class _CameraStartingView extends StatelessWidget {
  const _CameraStartingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'school.checkIn.cameraStarting'.tr(),
            style: homeText(14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// Kamera xatosi — xabar va "Qayta urinish".
class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _CameraNotice(
      icon: Icons.videocam_off_rounded,
      title: 'school.checkIn.cameraFailed'.tr(),
      body: message,
      primaryLabel: 'common.retry'.tr(),
      onPrimary: () => unawaited(onRetry()),
    );
  }
}

/// Kamera ruxsati yo'q — "Ruxsat berish" va "Sozlamalarni ochish".
class _CameraPermissionView extends StatelessWidget {
  const _CameraPermissionView({
    required this.onAllow,
    required this.onOpenSettings,
  });

  final Future<void> Function() onAllow;
  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return _CameraNotice(
      icon: Icons.no_photography_outlined,
      title: 'school.checkIn.permissionTitle'.tr(),
      body: 'school.checkIn.permissionBody'.tr(),
      primaryLabel: 'common.grantPermission'.tr(),
      onPrimary: () => unawaited(onAllow()),
      secondaryLabel: 'common.openSettings'.tr(),
      onSecondary: () => unawaited(onOpenSettings()),
    );
  }
}

/// Kamera o'rnidagi izoh: belgi, sarlavha, matn va (bo'lsa) tugmalar.
class _CameraNotice extends StatelessWidget {
  const _CameraNotice({
    required this.icon,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = this.primaryLabel;
    final secondaryLabel = this.secondaryLabel;
    const padding = EdgeInsets.symmetric(vertical: 14);
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 64),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: homeText(20, weight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: homeText(14, color: Colors.white70, height: 1.4),
              ),
              if (primaryLabel != null && onPrimary != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: HomeColors.primary,
                      foregroundColor: Colors.white,
                      padding: padding,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      primaryLabel,
                      style: homeText(15, weight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: padding,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      secondaryLabel,
                      style: homeText(15, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
