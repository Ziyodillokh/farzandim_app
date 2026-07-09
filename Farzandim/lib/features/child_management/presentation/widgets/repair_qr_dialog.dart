// ─────────────────────────────────────────────────────────────────────
// RepairQrDialog — bola uchun qayta ulash QR kodi (45s ichida amal qiladi)
// ─────────────────────────────────────────────────────────────────────
//
// Foydalanish holatlari (bolaning telefoni o'zgargan / app o'chgan):
//   • Bola Parvoz ilovasini o'chirib qayta o'rnatgan
//   • Telefon zavod sozlamalariga qaytarilgan
//   • Bola yangi telefon olgan / yo'qotgan
//   • FCM token / device ID o'zgargan
//
// Flow:
//   1) Parent menu'da "Qayta ulash" → bu dialog ochiladi
//   2) Backend'dan token olinadi (45s amal qiladi)
//   3) QR ko'rinadi + countdown timer
//   4) 45s ichida bola QR'ni skanerlasa → backend WS `child:repaired` event
//      yuboradi → dialog avtomatik yopiladi va success snack chiqadi
//   5) Vaqt tugasa — yangi token avtomatik so'raladi (rotation)

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/network/friendly_error.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _card = Color(0xFF12171E);
const _chipBg = Color(0xFF1B2128);
const _fieldBorder = Color(0x1FFFFFFF);
const _dim = Color(0x8CFFFFFF);
const _red = Color(0xFFFF5A5F);

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
}) => GoogleFonts.unbounded(fontSize: s, fontWeight: w, color: c, height: 1.25);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.4);

class RepairQrDialog extends ConsumerStatefulWidget {
  const RepairQrDialog({
    required this.childId,
    required this.childName,
    super.key,
  });

  final String childId;
  final String childName;

  /// To'liq telefon ekranida ochiladi (rootNavigator → bottom nav va
  /// boshqa shell'ni ham yopib qo'yadi). QR kodga maksimal joy.
  static Future<bool?> show(
    BuildContext context, {
    required String childId,
    required String childName,
  }) {
    return Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RepairQrDialog(childId: childId, childName: childName),
      ),
    );
  }

  @override
  ConsumerState<RepairQrDialog> createState() => _RepairQrDialogState();
}

class _RepairQrDialogState extends ConsumerState<RepairQrDialog> {
  String? _token;
  int _remainingSec = 0;
  String? _error;
  Timer? _ticker;
  StreamSubscription<dynamic>? _repairedSub;

  @override
  void initState() {
    super.initState();
    _fetchNewToken();
    // EH-06: bola QR'ni skanerlagach backend `child:repaired` WS event
    // yuboradi (auth.service:873) — dialog AVTOMATIK yopiladi + success
    // snack. Avval listener yo'q edi: ota-ona dialog yopilishini kutib
    // o'tiraverardi (hujjatlangan xulq ishlamasdi).
    _repairedSub = ref
        .read(socketClientProvider)
        .eventStream('child:repaired')
        .listen((data) {
          if (data is! Map) return;
          if (data['childId'] != widget.childId) return;
          if (!mounted) return;
          // Ro'yxat yangilansin (isConnected=true keladi).
          ref.read(childrenRefreshTickProvider.notifier).state++;
          AppToast.success(
            context,
            'repairQr.reconnectedSnack'.tr(
              namedArgs: {'name': widget.childName},
            ),
          );
          Navigator.of(context).pop(true);
        });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _repairedSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchNewToken() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      _token = null;
    });

    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.post<Map<String, dynamic>>(
        '/auth/child/${widget.childId}/repair-qr',
      );
      final data = res.data ?? const <String, dynamic>{};
      final token = data['token'] as String?;
      final expiresIn = (data['expiresInSec'] as num?)?.toInt() ?? 45;
      if (token == null || token.isEmpty) {
        throw Exception('repairQr.emptyTokenError'.tr());
      }
      if (!mounted) return;
      setState(() {
        _token = token;
        _remainingSec = expiresIn;
      });
      _startTicker();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e, fallback: 'errors.generic'.tr());
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'repairQr.unexpectedError'.tr(namedArgs: {'error': '$e'});
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _ticker?.cancel();
        return;
      }
      if (_remainingSec <= 1) {
        // Vaqt tugadi — yangi token so'raymiz (rotation).
        _ticker?.cancel();
        _fetchNewToken();
      } else {
        setState(() => _remainingSec--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: orqaga + sarlavha (Parvoz uslubi) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _chipBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _fieldBorder),
                      ),
                      child: const Icon(
                        SolarIconsOutline.arrowLeft,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'repairQr.title'.tr(),
                      textAlign: TextAlign.center,
                      style: _unb(20),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.childName,
                      textAlign: TextAlign.center,
                      style: _unb(22, w: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'repairQr.scanHint'.tr(),
                      textAlign: TextAlign.center,
                      style: _pop(13, c: _dim),
                    ),
                    const SizedBox(height: 24),
                    _buildQrArea(),
                    const SizedBox(height: 20),
                    _buildCountdown(),
                    const SizedBox(height: 12),
                    // Token nusxa olish — bola web/desktop ilovasida
                    // kamerasiz ulanish (matn joylash uchun).
                    _buildCopyTokenButton(),
                    const SizedBox(height: 24),
                    _buildHints(),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _chipBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _fieldBorder),
                        ),
                        child: Text(
                          'repairQr.closeButton'.tr(),
                          style: _pop(15, w: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrArea() {
    if (_error != null) {
      return _ErrorBox(message: _error!, onRetry: _fetchNewToken);
    }
    if (_token == null) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }
    // Ekran kengligiga moslab kvadrat QR. Mobil/desktop'da to'liq joy oladi.
    final size = MediaQuery.sizeOf(context);
    final qrSide = (size.width.clamp(280, 520) - 80).toDouble();
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _blue.withValues(alpha: 0.22),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: QrImageView(
          data: 'farzandim:repair:$_token',
          size: qrSide,
          backgroundColor: Colors.white,
          // ignore: deprecated_member_use
          foregroundColor: Colors.black,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
        ),
      ),
    );
  }

  Widget _buildCopyTokenButton() {
    if (_token == null) return const SizedBox.shrink();
    return Center(
      child: GestureDetector(
        onTap: () async {
          await Clipboard.setData(
            ClipboardData(text: 'farzandim:repair:$_token'),
          );
          if (!mounted) return;
          AppToast.success(context, 'repairQr.copiedSnack'.tr());
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(SolarIconsBold.copy, size: 18, color: _blue),
              const SizedBox(width: 8),
              Text(
                'repairQr.copyButton'.tr(),
                style: _pop(14, w: FontWeight.w500, c: _blue),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    final color = _remainingSec <= 10 ? _red : _blue;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(SolarIconsBold.stopwatch, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          'repairQr.timeLeft'.tr(namedArgs: {'seconds': '$_remainingSec'}),
          style: _pop(14, w: FontWeight.w600, c: color),
        ),
      ],
    );
  }

  Widget _buildHints() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'repairQr.hintsTitle'.tr(),
            style: _pop(13, w: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          _hintLine('repairQr.hint1'.tr()),
          _hintLine('repairQr.hint2'.tr()),
          _hintLine('repairQr.hint3'.tr()),
          _hintLine('repairQr.hint4'.tr()),
        ],
      ),
    );
  }

  Widget _hintLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text('• $text', style: _pop(12, c: _dim)),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        children: [
          const Icon(SolarIconsBold.dangerCircle, color: _red, size: 32),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: _pop(14)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRetry,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(SolarIconsBold.refresh, size: 18, color: _blue),
                const SizedBox(width: 8),
                Text(
                  'repairQr.retryButton'.tr(),
                  style: _pop(14, w: FontWeight.w500, c: _blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
