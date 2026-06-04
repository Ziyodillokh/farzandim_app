// ─────────────────────────────────────────────────────────────────────
// VoiceMessagesQuickCard — Dashboard'da ovozli xabarlar quick card
// ─────────────────────────────────────────────────────────────────────
//
// Mic ikon + (qizil) unread badge + 'Ovozli xabarlar' sarlavha + oxirgi
// xabar preview ('Siz: 5 sek · 3 daq oldin' yoki 'Ota-ona: ...') + ›.
// Tap → /voice-chat. Real-time stream orqali yangilanadi.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/voice_message/data/models/voice_message.dart';
import 'package:farzandim_child/features/voice_message/presentation/providers/voice_message_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VoiceMessagesQuickCard extends ConsumerWidget {
  const VoiceMessagesQuickCard({required this.childId, super.key});

  final String childId;

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'hozirgina';
    if (diff.inMinutes < 60) return '${diff.inMinutes} daq oldin';
    if (diff.inHours < 24) return '${diff.inHours} soat oldin';
    return '${diff.inDays} kun oldin';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestVoiceMessageProvider(childId));
    final unreadAsync =
        ref.watch(unreadVoiceMessagesCountProvider(childId));

    return GestureDetector(
      onTap: () => context.push('/voice-chat'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Telegram-style messenger ikon: ko'k gradient yumaloq +
                // oq paper plane. Telegram brand'ining vizual jozibasi,
                // lekin SVG path va ranglar app'ga moslashtirilgan
                // (gradient farqli — Telegram'ning aniq blue'sidan biroz
                // teal'ga moyil, paper plane'da ham folds bor).
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF37AEE2), // Telegram light blue
                        Color(0xFF1E96C8), // Telegram dark blue
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x331E96C8),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(28, 28),
                      painter: _TelegramPlanePainter(),
                    ),
                  ),
                ),
                unreadAsync.when(
                  data: (count) {
                    if (count == 0) return const SizedBox.shrink();
                    return Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Messanger',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  latestAsync.when(
                    data: (latest) => _PreviewLine(
                      latest: latest,
                      relativeTime: _relativeTime,
                    ),
                    loading: () => const Text(
                      'Yuklanmoqda...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    error: (_, __) => const Text(
                      'Xato',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              AppIcons.chevronRight,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Telegram-style paper plane CustomPainter.
///
/// Aslida Telegram'ning ikonkasi 3 ta yon va ichki "fold" chizig'ini
/// ko'rsatadigan papier-plié shaklida. SVG path bilan 1:1 chizamiz.
/// Ikon 24x24 viewBox koordinatasida — Size width'ga proporsional masshtab.
class _TelegramPlanePainter extends CustomPainter {
  const _TelegramPlanePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Outer paper plane silhouette
    // (Telegram'ning rasmiy ikon path'iga yaqin yengillashtirilgan versiya)
    final outer = Path()
      ..moveTo(2.5 * scale, 12.6 * scale) // chap pastdan
      ..lineTo(21.5 * scale, 3.4 * scale) // yuqori-o'ng burchakka
      ..lineTo(17.8 * scale, 20.6 * scale) // pastga, o'ngga
      ..lineTo(12.0 * scale, 15.5 * scale) // ichki burchak (fold)
      ..lineTo(7.8 * scale, 18.0 * scale) // pastki kichik fin
      ..lineTo(7.8 * scale, 13.9 * scale) // burchak
      ..close();
    canvas.drawPath(outer, paint);

    // Ichki "fold" chizig'i (qog'ozning ichki burchagi).
    final foldPaint = Paint()
      ..color = const Color(0xFFD0EAF7) // ozgina yengil ko'k tus
      ..style = PaintingStyle.fill;
    final fold = Path()
      ..moveTo(7.8 * scale, 13.9 * scale)
      ..lineTo(12.0 * scale, 15.5 * scale)
      ..lineTo(19.0 * scale, 6.2 * scale)
      ..lineTo(7.8 * scale, 13.9 * scale)
      ..close();
    canvas.drawPath(fold, foldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.latest,
    required this.relativeTime,
  });

  final VoiceMessage? latest;
  final String Function(DateTime) relativeTime;

  @override
  Widget build(BuildContext context) {
    if (latest == null || latest!.createdAt == null) {
      return const Text(
        "Hali xabarlar yo'q",
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      );
    }
    final senderText =
        latest!.sender == 'child' ? 'Siz' : 'Ota-ona';
    return Row(
      children: [
        const Icon(AppIcons.mic,
            size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            "$senderText: ${latest!.durationSeconds} sek · ${relativeTime(latest!.createdAt!)}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
