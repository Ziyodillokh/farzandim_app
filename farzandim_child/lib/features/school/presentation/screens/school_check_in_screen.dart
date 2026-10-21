// ─────────────────────────────────────────────────────────────────────
// SchoolCheckInScreen — davomat QR'i (`/school/check-in`)
// ─────────────────────────────────────────────────────────────────────
//
// Bola maktab kirish nuqtasidagi (kiosk) QR kodni skanerlaydi → server
// kirishni (IN) yoki dars tugagach chiqishni (OUT) qayd etadi va ota-onaga
// xabar yuboradi; takroriy skanerlash — NONE ("allaqachon belgilangan").
// Kiosk kodi har 30 soniyada almashadi:
//   • EXPIRED — skanerlash o'zi davom etadi, ekrandagi yangi kod kutiladi;
//   • INVALID / NOT_ENROLLED / OUTSIDE_SCHOOL_HOURS / oflayn — tushunarli
//     xabar va "Qayta skanerlash";
//   • ota-ona ulanish QR'i yoki begona QR serverga yuborilmaydi.
// Bir vaqtda bitta so'rov (`_processing`); server rad etgan token qayta
// yuborilmaydi (iOS bir xil kodni qayta-qayta aniqlaydi). Natija chiqqach
// skaner daraxtdan olinadi — kamera to'xtaydi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/domain/kiosk_qr.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/widgets/check_in_result_view.dart';
import 'package:farzandim_child/features/school/presentation/widgets/qr_camera_view.dart';
import 'package:farzandim_child/features/school/presentation/widgets/scan_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SchoolCheckInScreen extends ConsumerStatefulWidget {
  const SchoolCheckInScreen({
    super.key,
    this.scannerBuilder = buildQrCameraView,
  });

  /// Skaner (testda — kamerasiz soxta skaner).
  final QrScannerBuilder scannerBuilder;

  @override
  ConsumerState<SchoolCheckInScreen> createState() =>
      _SchoolCheckInScreenState();
}

class _SchoolCheckInScreenState extends ConsumerState<SchoolCheckInScreen> {
  /// Server javobi kutilmoqda — yangi QR'lar e'tiborsiz qoldiriladi.
  bool _processing = false;

  /// Skaner ustidagi ogohlantirish (tarjima kaliti): eskirgan / begona QR.
  String? _noticeKey;

  CheckInResult? _result;
  SchoolErrorCode? _failure;

  /// Server rad etgan tokenlar (EXPIRED / INVALID) — qayta yuborilmaydi.
  final _rejected = <String, SchoolErrorCode>{};

  bool get _isScanning => _result == null && _failure == null;

  void _onCode(String raw) {
    if (_processing || !_isScanning) return;
    switch (parseKioskQr(raw)) {
      case KioskQrCheckIn(:final token):
        final rejected = _rejected[token];
        if (rejected == null) {
          unawaited(_submit(token));
        } else {
          _showNotice(rejected.messageKey);
        }
      case KioskQrPairing():
        _showNotice('school.errors.qrPairing');
      case KioskQrUnknown():
        _showNotice('school.errors.qrUnknown');
    }
  }

  /// Ogohlantirish — bir xil xabar takrorlanmaydi (tebranish ham bir marta).
  void _showNotice(String key) {
    if (_noticeKey == key) return;
    HapticFeedback.heavyImpact();
    setState(() => _noticeKey = key);
  }

  Future<void> _submit(String token) async {
    HapticFeedback.selectionClick();
    setState(() {
      _processing = true;
      _noticeKey = null;
    });
    try {
      final result = await ref
          .read(schoolTodayProvider.notifier)
          .checkIn(token);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _processing = false;
        _result = result;
      });
    } on SchoolException catch (e) {
      if (mounted) _reject(token, e.code);
    } catch (e, stack) {
      // Kutilmagan xato — ekran "tekshirilmoqda"da qotib qolmasin.
      debugPrint('[school] check-in: $e\n$stack');
      if (mounted) _reject(token, SchoolErrorCode.unknown);
    }
  }

  void _reject(String token, SchoolErrorCode code) {
    HapticFeedback.heavyImpact();
    final isExpired = code == SchoolErrorCode.kioskExpired;
    if (isExpired || code == SchoolErrorCode.kioskInvalid) {
      _rejected[token] = code;
    }
    setState(() {
      _processing = false;
      if (isExpired) {
        // Skanerlash davom etadi — kiosk tez orada yangi kod ko'rsatadi.
        _noticeKey = code.messageKey;
      } else {
        _failure = code;
      }
    });
  }

  void _scanAgain() => setState(() {
    _failure = null;
    _noticeKey = null;
  });

  void _close() =>
      context.canPop() ? context.pop() : context.go(SchoolRoutes.hub);

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      return CheckInResultView(result: result, onDone: _close);
    }
    final failure = _failure;
    if (failure != null) {
      return CheckInFailureView(
        code: failure,
        onScanAgain: _scanAgain,
        onClose: _close,
      );
    }
    final noticeKey = _noticeKey;
    final message = _processing
        ? 'school.checkIn.checking'
        : noticeKey ?? 'school.checkIn.hint';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          tooltip: 'common.close'.tr(),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: _close,
        ),
        title: Text(
          'school.checkIn.title'.tr(),
          style: homeText(17, weight: FontWeight.w700),
        ),
      ),
      body: widget.scannerBuilder(
        context,
        _onCode,
        ScanOverlay(
          message: message.tr(),
          processing: _processing,
          isWarning: !_processing && noticeKey != null,
        ),
      ),
    );
  }
}
