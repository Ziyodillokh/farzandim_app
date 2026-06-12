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

// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
        builder: (_) => RepairQrDialog(
          childId: childId,
          childName: childName,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${widget.childName} muvaffaqiyatli qayta ulandi ✅'),
          backgroundColor: AppColors.success,
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
        throw Exception('Backend bo\'sh token qaytardi');
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
        _error = _friendlyError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Kutilmagan xato: $e");
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

  String _friendlyError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return "Tarmoq xatosi — qaytadan urinib ko'ring.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(
          'Qayta ulash',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.childName,
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineL.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "QR kodni bolaning telefonida skanerlang",
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              _buildQrArea(),
              const SizedBox(height: 20),
              _buildCountdown(),
              const SizedBox(height: 12),
              // Token nusxa olish — bola web/desktop ilovasida kamerasiz
              // ulanish (QR scanner o'rniga matn joylash uchun). Mobil
              // qurilmada ham foydali — yondagi qurilmaga jo'natish uchun.
              _buildCopyTokenButton(),
              const SizedBox(height: 24),
              _buildHints(),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Text(
                  'Yopish',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrArea() {
    if (_error != null) {
      return _ErrorBox(message: _error!, onRetry: _fetchNewToken);
    }
    if (_token == null) {
      return SizedBox(
        height: 320,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
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
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: QrImageView(
          data: 'farzandim:repair:$_token',
          version: QrVersions.auto,
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
      child: TextButton.icon(
        onPressed: () async {
          await Clipboard.setData(
            ClipboardData(text: 'farzandim:repair:$_token'),
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Token nusxa olindi — bola ilovasiga joylang',
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        icon: const Icon(Icons.content_copy_rounded, size: 18),
        label: const Text("Token'ni nusxa olish"),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    final color = _remainingSec <= 10 ? AppColors.error : AppColors.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.timer_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          'Qolgan vaqt: ${_remainingSec}s',
          style: AppTextStyles.bodyS.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHints() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Qaysi holatlarda ishlatiladi:',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _hintLine('Bola ilovani o\'chirib qayta o\'rnatgan'),
          _hintLine('Telefon zavod sozlamalariga qaytarilgan'),
          _hintLine('Yangi telefon olgan / almashtirgan'),
          _hintLine('Eski pairing buzilgan'),
        ],
      ),
    );
  }

  Widget _hintLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '• $text',
        style: AppTextStyles.label.copyWith(
          color: AppColors.textTertiary,
          height: 1.3,
        ),
      ),
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
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh, color: AppColors.primary),
            label: Text(
              'Qaytadan',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
