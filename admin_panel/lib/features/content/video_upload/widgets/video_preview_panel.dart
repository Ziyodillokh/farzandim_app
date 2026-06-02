import 'package:flutter/material.dart';

import '../picked_video.dart';
import '../video_probe_result.dart';
import '../video_upload_constants.dart';

/// Right column: faux player chrome + metadata + tips.
class VideoPreviewPanel extends StatelessWidget {
  const VideoPreviewPanel({
    super.key,
    required this.video,
    required this.probe,
    required this.manualDurationText,
  });

  final PickedVideo? video;
  final VideoProbeResult? probe;
  final String manualDurationText;

  String get _durationLabel {
    final manual = int.tryParse(manualDurationText.trim());
    if (manual != null && manual >= 0) {
      final m = manual ~/ 60;
      final s = manual % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    final sec = probe?.durationSec;
    if (sec != null && sec > 0) {
      final m = sec ~/ 60;
      final s = sec % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = video != null;
    final format = video?.format ?? '—';
    final size = video != null ? formatFileSize(video!.sizeBytes) : '—';
    final res = probe?.resolution ?? '—';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Oldindan ko‘rish',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: hasVideo
                            ? const [Color(0xFF0F172A), Color(0xFF1E293B)]
                            : const [Color(0xFFE2E8F0), Color(0xFFF1F5F9)],
                      ),
                    ),
                  ),
                  if (hasVideo)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.movie_outlined, color: Color(0xFF94A3B8), size: 48),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: hasVideo ? 0.35 : 0,
                            minHeight: 4,
                            backgroundColor: Colors.black26,
                            color: const Color(0xFF22C55E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '0:00',
                              style: TextStyle(
                                color: hasVideo ? Colors.white70 : Colors.black45,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _durationLabel == '—' ? '0:00' : _durationLabel,
                              style: TextStyle(
                                color: hasVideo ? Colors.white70 : Colors.black45,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Video ma’lumotlari',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'Format', value: format),
          _InfoRow(label: 'Hajm', value: size),
          _InfoRow(label: 'Davomiylik', value: _durationLabel == '—' ? '—' : _durationLabel),
          _InfoRow(label: 'O‘lcham', value: res),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates_outlined, color: Color(0xFF15803D), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Maslahatlar',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF14532D),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                _TipLine(text: 'Kontent bolalar uchun xavfsiz va mos bo‘lsin'),
                _TipLine(text: 'Yosh oralig‘i va kategoriya to‘g‘ri tanlansin'),
                _TipLine(text: 'Sifatli thumbnail tanlang — bosilishni oshiradi'),
                _TipLine(text: 'Obuna darajasi kontent qulflariga mos kelsin'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF166534)),
            ),
          ),
        ],
      ),
    );
  }
}
