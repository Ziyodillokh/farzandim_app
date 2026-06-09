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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
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
      ),
    );
  }
}
