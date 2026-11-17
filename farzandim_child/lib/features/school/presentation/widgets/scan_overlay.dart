// Skaner ustidagi qatlam: markazda ramka, pastda ko'rsatma yoki
// ogohlantirish (eskirgan / begona QR) va tekshirilayotganda indikator.

import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/material.dart';

class ScanOverlay extends StatelessWidget {
  const ScanOverlay({
    super.key,
    required this.message,
    this.processing = false,
    this.isWarning = false,
  });

  final String message;
  final bool processing;

  /// Ogohlantirish (sariq ramka va belgi) — oddiy ko'rsatma emas.
  final bool isWarning;

  static const frameSize = 260.0;

  @override
  Widget build(BuildContext context) {
    final accent = isWarning ? HomeColors.amber : Colors.white70;
    return SizedBox.expand(
      child: Stack(
        children: [
          Center(
            child: Container(
              width: frameSize,
              height: frameSize,
              decoration: BoxDecoration(
                border: Border.all(color: accent, width: 2),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: isWarning
                      ? Border.all(
                          color: HomeColors.amber.withValues(alpha: 0.6),
                        )
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isWarning) ...[
                      const Icon(
                        Icons.info_outline_rounded,
                        color: HomeColors.amber,
                        size: 22,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: homeText(
                          14.5,
                          weight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (processing) ...[
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
          ),
        ],
      ),
    );
  }
}
