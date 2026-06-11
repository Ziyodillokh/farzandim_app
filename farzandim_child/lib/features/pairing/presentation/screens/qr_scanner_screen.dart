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

import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

void _qrLog(String msg) {
  // Browser console + IDE devlog'da ko'rinadi.
  // ignore: avoid_print
  print('[QR] $msg');
  developer.log(msg, name: 'QR');
}

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  // Mobile qurilmalar uchun back kamera (QR uzoqroqdan ko'rinadi); desktop/web
  // brauzerda ko'pincha faqat front kamera bo'ladi → kIsWeb'da front tanlanadi.
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: kIsWeb ? CameraFacing.front : CameraFacing.back,
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
    _qrLog('initState: kIsWeb=$kIsWeb, controller created');
    _ensureCameraPermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ensureCameraPermission() async {
    if (kIsWeb) {
      _qrLog(
        'ensureCameraPermission: kIsWeb=true → kamera ruxsati o\'tkazib '
        'yuboriladi (Web paste UI ishlatiladi)',
      );
      setState(() => _cameraGranted = true);
      return;
    }
    var status = await Permission.camera.status;
    _qrLog('ensureCameraPermission: initial status=$status');
    if (status.isDenied || status.isRestricted || status.isLimited) {
      status = await Permission.camera.request();
      _qrLog('ensureCameraPermission: after request status=$status');
    }
    if (!mounted) return;
    setState(() => _cameraGranted = status.isGranted);
    if (status.isGranted) {
      try {
        await _controller.start();
        _qrLog('ensureCameraPermission: controller.start() OK');
      } catch (e) {
        _qrLog('ensureCameraPermission: controller.start() ERROR: $e');
      }
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    await _processRawToken(raw);
  }

  /// QR'dan kelgan yoki qo'lda kiritilgan matnni token sifatida tekshirib
  /// `/auth/repair-redeem` chaqiradi. `farzandim:repair:` prefiksli to'liq
  /// QR matni ham, to'g'ridan-to'g'ri token ham qabul qilinadi.
  Future<void> _processRawToken(String raw) async {
    _qrLog('processRawToken: raw="${raw.length > 50 ? '${raw.substring(0, 50)}...' : raw}" '
        '(len=${raw.length}), processing=$_processing');
    if (_processing) {
      _qrLog('processRawToken: SKIP — already processing');
      return;
    }

    final trimmed = raw.trim();
    String? token;
    if (trimmed.startsWith('farzandim:repair:')) {
      token = trimmed.substring('farzandim:repair:'.length);
      _qrLog('processRawToken: format=farzandim:repair:, token len=${token.length}');
    } else if (trimmed.length >= 16 && trimmed.length <= 64) {
      token = trimmed;
      _qrLog('processRawToken: format=plain, token len=${token.length}');
    } else {
      _qrLog('processRawToken: format=UNKNOWN — len=${trimmed.length}');
    }

    if (token == null || token.isEmpty) {
      _qrLog('processRawToken: token NULL or empty — show error');
      setState(() => _status = 'QR kod tanilmadi. To\'g\'ri kodni skanerlang.');
      return;
    }

    setState(() {
      _processing = true;
      _status = 'Ulanmoqda...';
    });
    _qrLog('processRawToken: → POST /auth/repair-redeem');

    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.post<Map<String, dynamic>>(
        '/auth/repair-redeem',
        data: <String, dynamic>{
          'token': token,
          'platform': kIsWeb ? 'web' : 'mobile',
        },
      );
      _qrLog('processRawToken: ← backend statusCode=${res.statusCode}');

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
      _qrLog('processRawToken: DioException — '
          'status=${e.response?.statusCode}, body=${e.response?.data}, '
          'message=${e.message}');
      final msg = _friendlyError(e);
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = msg;
      });
    } catch (e, st) {
      _qrLog('processRawToken: unexpected error: $e\n$st');
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
    _qrLog('build: kIsWeb=$kIsWeb, cameraGranted=$_cameraGranted, '
        'processing=$_processing, status=$_status');
    // Desktop/Web brauzerlarda `BarcodeDetector` qo'llab-quvvatlanmaydi yoki
    // laptop kamerasi qulay emas — manual paste UI ko'rsatamiz.
    if (kIsWeb) {
      _qrLog('build: → Web paste UI');
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
            "QR token'ni kiriting",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: _WebPasteTokenView(
          processing: _processing,
          status: _status,
          onSubmit: _processRawToken,
        ),
      );
    }

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

/// Web fallback: kamera o'rniga QR token'ni qo'lda kiritish.
/// Parent app'da QR generatsiya qilingach, "Nusxa olish" tugmasi orqali
/// token'ni clipboard'ga olish va shu yerga joylash mumkin.
class _WebPasteTokenView extends StatefulWidget {
  const _WebPasteTokenView({
    required this.processing,
    required this.status,
    required this.onSubmit,
  });

  final bool processing;
  final String? status;
  final Future<void> Function(String) onSubmit;

  @override
  State<_WebPasteTokenView> createState() => _WebPasteTokenViewState();
}

class _WebPasteTokenViewState extends State<_WebPasteTokenView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.qr_code_2, color: Colors.white70, size: 88),
            const SizedBox(height: 16),
            const Text(
              "Brauzerda kamera QR scanner mavjud emas.\n"
              "Parent ilovasidagi QR matnini shu yerga joylang.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 24),
            // Clipboard'dan tezkor paste — bola parent ilovasidan
            // "Token nusxa olish" tugmasini bosgach shu yerga avtomatik
            // joylaydi (web/desktop, mobile uchun ham qulay).
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final data =
                      await Clipboard.getData(Clipboard.kTextPlain);
                  final txt = data?.text?.trim();
                  if (txt == null || txt.isEmpty) return;
                  _controller.text = txt;
                  _controller.selection = TextSelection.collapsed(
                    offset: _controller.text.length,
                  );
                },
                icon: const Icon(
                  Icons.content_paste_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
                label: const Text(
                  'Clipboard',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _controller,
              maxLines: 3,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'farzandim:repair:... yoki to\'g\'ridan-to\'g\'ri token',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                // ignore: deprecated_member_use
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF14B8A6),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.processing
                    ? null
                    : () => widget.onSubmit(_controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: widget.processing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Ulanish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            if (widget.status != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.status!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amber, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
