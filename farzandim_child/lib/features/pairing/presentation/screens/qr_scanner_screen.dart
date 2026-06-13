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

import 'package:confetti/confetti.dart';
import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  // Mobile qurilmalar uchun back kamera (QR uzoqroqdan ko'rinadi).
  // Web'da ham back camera urinib ko'ramiz: brauzer mos topa olmasa o'zi
  // istalgan kameraga fallback qiladi (mobile_scanner: facingMode "non-exact"
  // constraint sifatida yuboradi). Mobile emulation/desktop'da bu webcam'ga
  // tushadi. Front fallback _tryStartCamera'da qayta urinishda.
  // Faqat QR formati — boshqa barcode'lar (EAN/UPC) tezligini sustlashtirmasin.
  MobileScannerController _controller = _makeController(CameraFacing.back);

  static MobileScannerController _makeController(CameraFacing facing) {
    return MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: facing,
      formats: const [BarcodeFormat.qrCode],
      autoStart: false,
    );
  }

  bool _processing = false;
  String? _status;

  /// Ulanish muvaffaqiyatli tugadi — chiroyli ✓ ekrani ko'rsatiladi.
  bool _success = false;

  /// Muvaffaqiyat paytida otiladigan konfetti.
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  // Kamera holati:
  //   null — boshlanmoqda (initState)
  //   _CamState.granted — start() OK, MobileScanner ko'rsatiladi
  //   _CamState.denied — ruxsat berilmadi
  //   _CamState.error — boshqa xato (no camera, NotReadable, polyfill, ...)
  _CamState _camState = _CamState.starting;

  /// Kamera xato berganda foydalanuvchiga ko'rsatiladigan inline xabar.
  /// Token'ni qo'lda kiritish rejimiga o'tish tugmasi shu yerda chiqadi.
  String? _camError;

  /// Foydalanuvchi qo'lda paste rejimiga o'tgan bo'lsa true.
  ///
  /// **Default — `false` (kamera birinchi).** Web va mobil'da ham avval
  /// kamerani ishga tushiramiz. Web'da `mobile_scanner` ZXing back
  /// kamera bilan ishlamasa, `_tryStartCamera` avtomatik front kameraga
  /// o'tadi; u ham ishlamasa xato ekranida "Token'ni qo'lda kiritish"
  /// tugmasi paste rejimiga o'tkazadi. Appbar'dagi klaviatura ikonkasi
  /// orqali ham istalgan paytda paste rejimiga o'tish mumkin.
  bool _manualPasteMode = false;

  /// Front camera bilan qayta urinib ko'rdikmi (back fail bo'lganda).
  bool _triedFrontFallback = false;

  @override
  void initState() {
    super.initState();
    _qrLog('initState: kIsWeb=$kIsWeb, manualPaste=$_manualPasteMode');
    // Web'da default paste rejimi — kamera ishga tushirilmaydi.
    if (!_manualPasteMode) {
      _ensureCameraPermission();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ensureCameraPermission() async {
    if (kIsWeb) {
      // Web: brauzer kamera promptini mobile_scanner ichida ishga tushiramiz.
      // permission_handler web'da har doim "denied" qaytaradi — shuning uchun
      // to'g'ridan-to'g'ri controller.start() chaqiramiz. Brauzer kamera
      // ruxsati pop-up'ni getUserMedia ichida o'zi ko'rsatadi.
      await _tryStartCamera();
      return;
    }
    var status = await Permission.camera.status;
    _qrLog('ensureCameraPermission: initial status=$status');
    if (status.isDenied || status.isRestricted || status.isLimited) {
      status = await Permission.camera.request();
      _qrLog('ensureCameraPermission: after request status=$status');
    }
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _camState = _CamState.denied);
      return;
    }
    await _tryStartCamera();
  }

  /// Controller'ni ishga tushirib ko'radi. Web'da back→front fallback'i bor
  /// (desktop webcam ko'pincha "user"/front bo'ladi). Mobil'da bir urinish.
  Future<void> _tryStartCamera() async {
    if (mounted) {
      setState(() {
        _camState = _CamState.starting;
        _camError = null;
      });
    }
    _qrLog('tryStartCamera: facing=${_controller.facing}, '
        'triedFront=$_triedFrontFallback');
    try {
      await _controller.start();
      _qrLog('tryStartCamera: start() OK');
      if (!mounted) return;
      setState(() => _camState = _CamState.granted);
    } catch (e) {
      _qrLog('tryStartCamera: ERROR: $e');
      // Web'da back fail bo'lsa front bilan qayta urinib ko'ramiz.
      if (kIsWeb && !_triedFrontFallback) {
        _triedFrontFallback = true;
        _qrLog('tryStartCamera: retrying with front camera');
        await _controller.dispose();
        _controller = _makeController(CameraFacing.front);
        await _tryStartCamera();
        return;
      }
      if (!mounted) return;
      setState(() {
        _camState = _CamState.error;
        _camError = _humanizeCameraError(e);
      });
    }
  }

  /// Brauzer/OS xatolarini foydalanuvchi tushunadigan O'zbek tilidagi
  /// xabarga aylantiradi.
  String _humanizeCameraError(Object error) {
    final s = error.toString();
    if (s.contains('NotAllowedError') || s.contains('permissionDenied')) {
      return 'Kameraga ruxsat berilmadi. Brauzer manzil panelidagi qulf '
          'belgisini bosib, kamera ruxsatini yoqing.';
    }
    if (s.contains('NotFoundError') || s.contains('unsupported')) {
      return 'Qurilmangizda kamera topilmadi. QR kodni qo\'lda kiritishingiz mumkin.';
    }
    if (s.contains('NotReadableError') || s.contains('TrackStartError')) {
      return 'Kamera boshqa dastur tomonidan band. Boshqa dastur (Zoom, '
          'Meet, Camera app)'
          'ni yopib qaytadan urinib ko\'ring.';
    }
    if (s.contains('OverconstrainedError')) {
      return 'Mos kamera topilmadi. Qo\'lda kiritish rejimiga o\'ting.';
    }
    if (s.contains('SecurityError')) {
      return 'Xavfsiz ulanish kerak (HTTPS yoki localhost).';
    }
    return 'Kamerani ochib bo\'lmadi. Qaytadan urining yoki QR kodni '
        'qo\'lda kiriting.';
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

      // Chiroyli muvaffaqiyat ekrani — animatsiyali ✓ + konfetti, keyin
      // /splash markaziy router'ga (onboarding/permission'ga yo'naltiradi).
      HapticFeedback.mediumImpact();
      setState(() {
        _processing = false;
        _success = true;
      });
      _confetti.play();
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      if (!mounted) return;
      context.go('/splash');
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
    _qrLog('build: kIsWeb=$kIsWeb, camState=$_camState, '
        'processing=$_processing, status=$_status, manualPaste=$_manualPasteMode');

    // Muvaffaqiyatli ulanish — chiroyli to'liq ekran (boshqa hammasidan ustun).
    if (_success) {
      return _PairSuccessView(confetti: _confetti);
    }

    // Foydalanuvchi qo'lda paste rejimini tanlagan bo'lsa — to'g'ridan-to'g'ri
    // paste UI'ni ko'rsatamiz (kamera ishga tushirilmaydi, batareya tejaladi).
    if (_manualPasteMode) {
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
            "Token'ni qo'lda kiriting",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              tooltip: 'Kamerada skanerlash',
              icon: const Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.white),
              onPressed: () {
                setState(() => _manualPasteMode = false);
                // Kameraga qaytsak qaytadan boshlash kerak (controller stop
                // bo'lib qolgan bo'lishi mumkin).
                if (_camState != _CamState.granted) {
                  _tryStartCamera();
                }
              },
            ),
          ],
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
          // Paste rejimi — kamera ishlamasa yoki token tayyor bo'lsa.
          IconButton(
            tooltip: "Token'ni qo'lda kiritish",
            icon: const Icon(Icons.keyboard_alt_rounded, color: Colors.white),
            onPressed: () => setState(() => _manualPasteMode = true),
          ),
          // Mobil'da torch (web'da effekt bermaydi, lekin tugma bezarar).
          if (!kIsWeb)
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
      body: switch (_camState) {
        _CamState.starting => const _CameraStartingView(),
        _CamState.denied => _PermissionDeniedView(
            onRetry: _ensureCameraPermission,
            onOpenSettings: openAppSettings,
          ),
        _CamState.error => _CameraErrorView(
            message: _camError ?? 'Kamera ochilmadi',
            onRetry: () {
              _triedFrontFallback = false;
              // Yangi controller — back camera bilan boshlaymiz.
              _controller.dispose();
              _controller = _makeController(CameraFacing.back);
              _tryStartCamera();
            },
            onManualPaste: () => setState(() => _manualPasteMode = true),
          ),
        _CamState.granted => _buildScannerBody(context),
      },
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

enum _CamState { starting, granted, denied, error }

class _CameraStartingView extends StatelessWidget {
  const _CameraStartingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Kamera ochilmoqda...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({
    required this.message,
    required this.onRetry,
    required this.onManualPaste,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onManualPaste;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Kamera ochilmadi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Qaytadan urinish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5CFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onManualPaste,
                icon: const Icon(Icons.keyboard_alt_rounded),
                label: const Text("Token'ni qo'lda kiritish"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
              "Kamera ishlamasa, Parent ilovasidagi QR matnini\n"
              "shu yerga joylab ulanishingiz mumkin.",
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

// ─── Muvaffaqiyatli ulanish ekrani — animatsiyali ✓ + konfetti ──────────
class _PairSuccessView extends StatelessWidget {
  const _PairSuccessView({required this.confetti});

  final ConfettiController confetti;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF16A34A), Color(0xFF12894B), Color(0xFF0B5E36)],
          ),
        ),
        child: Stack(
          children: [
            // Konfetti — markazdan pastga otiladi.
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: confetti,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.06,
                numberOfParticles: 22,
                maxBlastForce: 22,
                minBlastForce: 8,
                gravity: 0.25,
                shouldLoop: false,
                colors: const [
                  Colors.white,
                  Color(0xFFFFE08A),
                  Color(0xFF9CE6B4),
                  Color(0xFF7AD0FF),
                ],
              ),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animatsiyali ✓ — oq doira ichida, glow bilan.
                    Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x55FFFFFF),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF16A34A),
                          size: 56,
                        ),
                      ),
                    )
                        .animate()
                        .scale(
                          duration: 500.ms,
                          curve: Curves.elasticOut,
                          begin: const Offset(0.3, 0.3),
                          end: const Offset(1, 1),
                        )
                        .fadeIn(duration: 250.ms),
                    const SizedBox(height: 28),
                    Text(
                      'Muvaffaqiyatli ulandingiz!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 280.ms, duration: 350.ms)
                        .slideY(begin: 0.25, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        "Telefoningiz ota-onangiz hisobiga bog'landi.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 420.ms, duration: 350.ms),
                    ),
                    const SizedBox(height: 36),
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    ).animate().fadeIn(delay: 600.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
