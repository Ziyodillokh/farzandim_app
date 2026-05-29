// ─────────────────────────────────────────────────────────────────────
// ChatInputBar — chat ekran pastida inline ovoz yozish (Telegram/WA)
// ─────────────────────────────────────────────────────────────────────
//
// Idle: o'ngda 64x64 lime green mic tugma (long-press).
// Recording: chap delete + jonli waveform + qizil mic (xuddi shu joyda).
// Upload paytida: tugma alpha 0.5 + spinner.
//
// Eslatma: Mic tugma `GestureDetector` widget tree'da DOIMO bir xil
// pozitsiyada turadi — recording boshlangach faqat atrofidagi UI
// o'zgaradi. Aks holda Flutter eski gesture subscription'ni
// yo'qotib, `onLongPressEnd` hech qachon chaqirilmaydi.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    required this.isRecording,
    required this.isUploading,
    required this.elapsedSeconds,
    required this.amplitudes,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onCancel,
    super.key,
  });

  final bool isRecording;
  final bool isUploading;
  final int elapsedSeconds;
  final List<double> amplitudes;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundBottom,
        border: Border(
          top: BorderSide(
            // ignore: deprecated_member_use
            color: AppColors.textSecondary.withOpacity(0.1),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (isRecording)
              IconButton(
                onPressed: onCancel,
                icon: const Icon(
                  AppIcons.delete,
                  color: Colors.red,
                  size: 28,
                ),
              ),
            if (isRecording)
              Expanded(
                child: _RecordingIndicator(
                  elapsedSeconds: elapsedSeconds,
                  amplitudes: amplitudes,
                ),
              )
            else
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Mikrofonni bosing — boshlash/to\'xtatish',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Sprint 4.4.5: ikkala UX (tap toggle + long press).
              // - Tap: 1-bosish boshlaydi, 2-bosish tugatadi+send
              // - Long press: WhatsApp/Telegram klassik UX (bosib turish)
              onTap: isUploading
                  ? null
                  : () {
                      if (isRecording) {
                        onLongPressEnd();
                      } else {
                        onLongPressStart();
                      }
                    },
              onLongPressStart:
                  isUploading ? null : (_) => onLongPressStart(),
              onLongPressEnd:
                  isUploading ? null : (_) => onLongPressEnd(),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: isRecording
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.catRed, AppColors.catRedDark],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isUploading
                              // ignore: deprecated_member_use
                              ? [
                                  // ignore: deprecated_member_use
                                  AppColors.primary.withOpacity(0.6),
                                  // ignore: deprecated_member_use
                                  AppColors.primary.withOpacity(0.4),
                                ]
                              : const [
                                  AppColors.catLime,
                                  AppColors.primaryHover,
                                ],
                        ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.15),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording
                              ? AppColors.catRed
                              : AppColors.primary)
                          // ignore: deprecated_member_use
                          .withOpacity(isRecording ? 0.5 : 0.4),
                      blurRadius: isRecording ? 24 : 18,
                      spreadRadius: isRecording ? 4 : 2,
                    ),
                  ],
                ),
                child: isUploading
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        ),
                      )
                    : Icon(
                        isRecording
                            ? AppIcons.stop
                            : AppIcons.mic,
                        color: isRecording
                            ? Colors.white
                            : Colors.black,
                        size: 40,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator({
    required this.elapsedSeconds,
    required this.amplitudes,
  });

  final int elapsedSeconds;
  final List<double> amplitudes;

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _format(elapsedSeconds),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 28,
              child: _InlineWaveform(amplitudes: amplitudes),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineWaveform extends StatelessWidget {
  const _InlineWaveform({required this.amplitudes});

  final List<double> amplitudes;

  @override
  Widget build(BuildContext context) {
    if (amplitudes.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: amplitudes.length,
      itemBuilder: (_, i) {
        final amp = amplitudes[amplitudes.length - 1 - i];
        final h = (amp * 28).clamp(2.0, 28.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Center(
            child: Container(
              width: 3,
              height: h,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}
