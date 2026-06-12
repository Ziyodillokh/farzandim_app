// ─────────────────────────────────────────────────────────────────────
// RoundVideoRecorder — Telegram-uslubidagi yumaloq video yozish modali.
// ─────────────────────────────────────────────────────────────────────
//
// Foydalanish:
//   final xfile = await showRoundVideoRecorder(context);
//   if (xfile != null) { await upload(File(xfile.path)); }
//
// UX:
//   - To'liq ekran, qora yarim-shaffof barrier
//   - Markazda ~280x280 ClipOval kamera preview (FRONT kamera)
//   - Atrofda 30 sek circular progress
//   - Tagida "Bosib turib yozing" matni (idle), "Bekor qilish ← / Lock ↑"
//     (recording paytida)
//   - Long-press start → recording boshlanadi
//   - Drag chap → progress shkalasi bo'yicha "cancel" zonasiga o'tadi,
//     qo'yib yuborilsa upload qilinmaydi
//   - Drag yuqori → lock — qo'lni qo'yib yuborsa ham yozish davom etadi,
//     pastdagi qizil stop tugmasi bilan tugatiladi
//   - Long-press end (lock'siz) → recording tugaydi va XFile qaytadi
//   - 30 sek auto-stop → XFile avtomatik qaytadi
//
// Kamera xato (ruxsat yo'q yoki qurilmada front kamera yo'q) →
// snackbar + null qaytadi.

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Maks. yozuv davomiyligi.
const Duration _maxRecordingDuration = Duration(seconds: 30);

/// Preview doirasi diametri.
const double _previewDiameter = 280;

/// Cancel zonasi — chap tomonga shu masofadan ko'p drag → cancel.
const double _cancelDragThreshold = 80;

/// Lock zonasi — yuqoriga shu masofadan ko'p drag → lock.
const double _lockDragThreshold = 80;

/// Modal'ni ko'rsatadi va recording natijasini qaytaradi.
///
/// Qaytadi:
///   - `XFile` — muvaffaqiyatli yozildi
///   - `null` — bekor qilindi yoki xato
Future<XFile?> showRoundVideoRecorder(BuildContext context) {
  return showGeneralDialog<XFile?>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    barrierLabel: 'Round video recorder',
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) => const _RoundVideoRecorderModal(),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _RoundVideoRecorderModal extends StatefulWidget {
  const _RoundVideoRecorderModal();

  @override
  State<_RoundVideoRecorderModal> createState() =>
      _RoundVideoRecorderModalState();
}

class _RoundVideoRecorderModalState extends State<_RoundVideoRecorderModal>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initializing = true;
  String? _initError;

  bool _isRecording = false;
  bool _isLocked = false;
  Timer? _tick;
  Duration _elapsed = Duration.zero;

  // Drag tracking.
  Offset _dragStart = Offset.zero;
  double _horizontalDrag = 0;
  double _verticalDrag = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _initError = 'voiceChat.cameraPermissionSnack'.tr();
        });
        return;
      }
      // Mikrofon ham — video yozuvga kerak.
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _initError = 'voiceChat.micPermissionSnack'.tr();
        });
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _initError = 'Kamera topilmadi';
        });
        return;
      }
      // FRONT kamera (Telegram default selfie-uslubi).
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      // ResolutionPreset.low = ~352×288 — 30 sek video ~2-4 MB.
      // Backend 413 'Payload Too Large' xato'sini oldini olish uchun
      // (Telegram round video aslida ham past resolution ishlatadi).
      final controller = CameraController(
        front,
        ResolutionPreset.low,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _initError = '$e';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App background'ga ketsa kamera resursni bo'shatamiz.
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      // Recording davom etayotgan bo'lsa abort.
      if (_isRecording) {
        unawaited(_cancelRecording());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    final c = _controller;
    if (c != null) {
      // Recording aktiv bo'lsa stop (file ignore).
      if (_isRecording) {
        unawaited(c.stopVideoRecording().catchError((_) {
          // Stop xatosi — controllerni baribir dispose qilamiz.
          return XFile('');
        }));
      }
      unawaited(c.dispose());
    }
    super.dispose();
  }

  // ─── Recording lifecycle ───────────────────────────────────────────

  Future<void> _startRecording() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_isRecording) return;
    try {
      _horizontalDrag = 0;
      _verticalDrag = 0;
      await c.startVideoRecording();
      _elapsed = Duration.zero;
      _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(milliseconds: 100));
        if (_elapsed >= _maxRecordingDuration) {
          unawaited(_stopAndReturn());
        }
      });
      if (!mounted) return;
      setState(() => _isRecording = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = "Yozib bo'lmadi: $e";
      });
    }
  }

  Future<void> _stopAndReturn() async {
    final c = _controller;
    if (c == null || !_isRecording) return;
    _tick?.cancel();
    _tick = null;
    try {
      final xfile = await c.stopVideoRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isLocked = false;
      });
      // Min davomiylik 1 sek — undan kam bo'lsa snackbar va null.
      if (_elapsed.inMilliseconds < 1000) {
        try {
          await File(xfile.path).delete();
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('voiceChat.tooShortSnack'.tr())),
        );
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(context).pop(xfile);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _cancelRecording() async {
    final c = _controller;
    _tick?.cancel();
    _tick = null;
    if (c != null && _isRecording) {
      try {
        final xfile = await c.stopVideoRecording();
        try {
          await File(xfile.path).delete();
        } catch (_) {}
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isLocked = false;
    });
    Navigator.of(context).pop();
  }

  // ─── Gesture handlers ──────────────────────────────────────────────

  void _onLongPressStart(LongPressStartDetails details) {
    _dragStart = details.globalPosition;
    _horizontalDrag = 0;
    _verticalDrag = 0;
    unawaited(_startRecording());
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isRecording || _isLocked) return;
    final dx = details.globalPosition.dx - _dragStart.dx;
    final dy = details.globalPosition.dy - _dragStart.dy;
    setState(() {
      _horizontalDrag = dx; // manfiy = chap = cancel
      _verticalDrag = dy; // manfiy = yuqori = lock
    });
    // Lock zonasi (drag yuqoriga > threshold)
    if (-dy > _lockDragThreshold) {
      setState(() => _isLocked = true);
      return;
    }
    // Cancel zonasi (drag chapga > threshold) — visual feedback bilan,
    // qo'yib yuborilganda cancel.
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_isRecording) return;
    if (_isLocked) return;
    // Cancel zonasiga yetilganmi?
    if (-_horizontalDrag > _cancelDragThreshold) {
      unawaited(_cancelRecording());
      return;
    }
    unawaited(_stopAndReturn());
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // X tugma top-left (faqat idle paytda, recording'da chalg'itmaslik
            // uchun).
            if (!_isRecording)
              Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),

            // Markaziy doira + atrof UI.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_initializing)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  else if (_initError != null)
                    _buildError(_initError!)
                  else
                    _buildPreviewWithControls(),
                  const SizedBox(height: 28),
                  _buildBottomLabel(),
                ],
              ),
            ),

            // Lock paytida pastda qizil "Stop" tugma.
            if (_isLocked)
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: Center(
                  child: GestureDetector(
                    onTap: _stopAndReturn,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5252),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.stop_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.white70,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Yopish',
              style: TextStyle(color: AppColors.primary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewWithControls() {
    final progress =
        (_elapsed.inMilliseconds / _maxRecordingDuration.inMilliseconds)
            .clamp(0.0, 1.0);
    final c = _controller!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Preview + progress ring (no gesture)
        SizedBox(
          width: _previewDiameter + 24,
          height: _previewDiameter + 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Yumaloq preview.
              SizedBox(
                width: _previewDiameter,
                height: _previewDiameter,
                child: ClipOval(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: c.value.previewSize?.height ?? _previewDiameter,
                      height: c.value.previewSize?.width ?? _previewDiameter,
                      child: CameraPreview(c),
                    ),
                  ),
                ),
              ),
              // Atrofdagi progress halqa (recording paytida lime).
              SizedBox(
                width: _previewDiameter + 16,
                height: _previewDiameter + 16,
                child: CircularProgressIndicator(
                  value: _isRecording ? progress : 0,
                  strokeWidth: 5,
                  color: AppColors.primary,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              // Recording dot + timer (top-center).
              if (_isRecording)
                Positioned(
                  top: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF5252),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatElapsed(_elapsed),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!_isLocked) ...[
          const SizedBox(height: 36),
          _buildRecordButton(),
        ],
      ],
    );
  }

  /// Premium "Bosib turib yozing" tugmasi — visible long-press target.
  Widget _buildRecordButton() {
    final isActive = _isRecording;
    final dragShift = isActive && !_isLocked
        ? Offset(
            _horizontalDrag.clamp(-_cancelDragThreshold, 0.0),
            _verticalDrag.clamp(-_lockDragThreshold, 0.0),
          )
        : Offset.zero;

    final cancelIntensity = isActive
        ? (-_horizontalDrag / _cancelDragThreshold).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Visible cancel/lock hint chiplari
        if (isActive && !_isLocked)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HintChip(
                  icon: Icons.arrow_back,
                  text: 'Bekor qilish',
                  highlight: cancelIntensity > 0.3,
                ),
                _HintChip(
                  icon: Icons.arrow_upward,
                  text: 'Lock',
                  highlight: -_verticalDrag > 20,
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        // Big visible long-press record button
        Transform.translate(
          offset: dragShift,
          child: GestureDetector(
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: _onLongPressMoveUpdate,
            onLongPressEnd: _onLongPressEnd,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isActive
                      ? const [Color(0xFFFF5252), Color(0xFFE53935)]
                      : [AppColors.primary, AppColors.primaryDark],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isActive ? Colors.red : AppColors.primary)
                        .withValues(alpha: 0.45),
                    blurRadius: 24,
                    spreadRadius: isActive ? 6 : 2,
                  ),
                ],
              ),
              child: Icon(
                isActive ? Icons.fiber_manual_record : Icons.videocam_rounded,
                color: Colors.white,
                size: isActive ? 28 : 36,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomLabel() {
    if (_initError != null) return const SizedBox.shrink();
    if (_isLocked) {
      return const Text(
        'Tugatish uchun bosing',
        style: TextStyle(color: Colors.white70, fontSize: 13),
      );
    }
    if (_isRecording) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _HintChip(icon: Icons.arrow_back, text: 'Bekor qilish'),
            _HintChip(icon: Icons.arrow_upward, text: 'Lock'),
          ],
        ),
      );
    }
    return const Text(
      'Bosib turib yozing',
      style: TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final s = d.inSeconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({
    required this.icon,
    required this.text,
    this.highlight = false,
  });

  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.red.shade400.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight
              ? Colors.white.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: highlight ? Colors.white : Colors.white70,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: highlight ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight:
                  highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
