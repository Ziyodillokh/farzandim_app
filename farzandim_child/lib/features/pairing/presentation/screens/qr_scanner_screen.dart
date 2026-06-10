// ─────────────────────────────────────────────────────────────────────
// QrScannerScreen — bola Parent app QR'ini skanerlab qayta ulanadi
// ─────────────────────────────────────────────────────────────────────
//
// Foydalanish: pairing_screen → "QR kod orqali ulash" → bu ekran.
// QR format: `farzandim:repair:{token}` (parent dialog'da generatsiya).
//
// Flow:
//   1) Kamera ruxsati so'raladi (mobile_scanner avtomatik)
//   2) QR aniqlanganda token ajratiladi
//   3) POST /api/auth/repair-redeem yuboriladi
//   4) Muvaffaqiyat → tokens saqlanadi + pairing state yangilanadi
//   5) Dashboard'ga o'tadi

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _processing = false;
  String? _status;

  // Kamera ruxsati holati: null — hali so'ralmagan, true — berildi,
  // false — rad etildi (foydalanuvchiga Sozlamalar tugmasi ko'rsatiladi).
  // Ba'zi Android OEM (Xiaomi/Realme/HONOR) qurilmalarida mobile_scanner
  // avtomatik so'ramaydi — shu sababli avval qo'lda so'raymiz.
  bool? _cameraGranted;

  @override
  void initState() {
    super.initState();
    _ensureCameraPermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ensureCameraPermission() async {
    if (kIsWeb) {
      // Web: brauzer prompt'i mobile_scanner ichida ishlaydi.
      setState(() => _cameraGranted = true);
      return;
    }
    var status = await Permission.camera.status;
    if (status.isDenied || status.isRestricted || status.isLimited) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;
    setState(() => _cameraGranted = status.isGranted);
    if (status.isGranted) {
      // Ruxsat olingach kamera'ni qo'lda boshlaymiz — ba'zi
      // qurilmalarda mobile_scanner mount paytida ruxsat yo'q
      // bo'lsa keyin avtomatik qayta urinmaydi.
      try {
        await _controller.start();
      } catch (_) {/* ignore — UI o'zi qayta urinishi mumkin */}
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;

    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // Format: `farzandim:repair:{token}` yoki to'g'ridan-to'g'ri token
    String? token;
    if (raw.startsWith('farzandim:repair:')) {
      token = raw.substring('farzandim:repair:'.length);
    } else if (raw.length >= 16 && raw.length <= 64) {
      token = raw;
    }

    if (token == null || token.isEmpty) {
      setState(() => _status = 'QR kod tanilmadi. To\'g\'ri kodni skanerlang.');
      return;
    }

    setState(() {
      _processing = true;
      _status = 'Ulanmoqda...';
    });

    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.post<Map<String, dynamic>>(
        '/auth/repair-redeem',
        data: <String, dynamic>{
          'token': token,
          'platform': kIsWeb ? 'web' : 'mobile',
        },
      );

      final data = res.data;
      if (data == null) throw Exception('Backend bo\'sh javob qaytardi');

      final access = data['accessToken'] as String?;
      final refresh = data['refreshToken'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      final child = data['child'] as Map<String, dynamic>?;

      if (access == null || refresh == null || user == null || child == null) {
        throw Exception('Backend javobida tokens yo\'q');
      }

      // Tokens saqlash
      final storage = ref.read(tokenStorageProvider);
      await storage.saveTokens(accessToken: access, refreshToken: refresh);

      // Mavjud `completeFromApprovedPair` metodini qayta ishlataman —
      // u prefs'ga yozadi, state'ni paired'ga o'tkazadi va kerakli
      // service'larni (DeviceInfo, Location, etc) ishga tushiradi.
      final ok = await ref
          .read(pairingStateProvider.notifier)
          .completeFromApprovedPair(
            parentUid: child['parentId'] as String,
            childId: child['id'] as String,
            currentUserId: user['id'] as String,
          );

      if (!mounted) return;
      if (!ok) {
        setState(() {
          _processing = false;
          _status = "Ulandi, lekin ma'lumotlar yuklanmadi. Qaytadan urinib ko'ring.";
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Muvaffaqiyatli ulandingiz!'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
      context.go('/dashboard');
    } on DioException catch (e) {
      final msg = _friendlyError(e);
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'Xato: $e';
      });
    }
  }

  String _friendlyError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return 'Tarmoq xatosi. Qaytadan urinib ko\'ring.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'QR kodni skanerlang',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (_, state, __) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: _cameraGranted == false
          ? _PermissionDeniedView(
              onRetry: _ensureCameraPermission,
              onOpenSettings: openAppSettings,
            )
          : _cameraGranted == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _buildScannerBody(context),
    );
  }

  Widget _buildScannerBody(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            // mobile_scanner ichki xato (kamera band, OEM driver, va h.k.) —
            // black screen o'rniga aniq xabar.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off,
                      color: Colors.white,
                      size: 56,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Kamera ochilmadi: ${error.errorCode.name}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await _controller.stop();
                        await _controller.start();
                      },
                      child: const Text('Qaytadan urinish'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Markazda yarim shaffof "viewfinder" frame
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        // Pastdagi status / ko'rsatma
        Positioned(
          left: 20,
          right: 20,
          bottom: 60,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _status ??
                      'Ota-ona telefonidagi QR kodni ramka ichiga to\'g\'rilang',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_processing) ...[
                  const SizedBox(height: 12),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.onRetry,
    required this.onOpenSettings,
  });

  final Future<void> Function() onRetry;
  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 72,
            ),
            const SizedBox(height: 20),
            const Text(
              'Kamera ruxsati kerak',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "QR kodni skanerlash uchun kameraga ruxsat bering. "
              "Agar oldin rad etgan bo'lsangiz, Sozlamalardan qo'lda yoqing.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => onRetry(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5CFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Ruxsat berish'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onOpenSettings(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Sozlamalarni ochish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
