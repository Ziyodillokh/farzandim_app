// ─────────────────────────────────────────────────────────────────────
// LastVideoStatusIndicator — bola yuborgan oxirgi video xabar holati
// ─────────────────────────────────────────────────────────────────────
//
// "Oxirgi video: 5 daq oldin" — Firestore real-time o'qiladi. Hech narsa
// yuborilmagan bo'lsa SizedBox.shrink (joy band qilmaydi).

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/video_message/data/models/video_message.dart';
import 'package:farzandim_child/features/video_message/presentation/providers/video_message_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LastVideoStatusIndicator extends ConsumerWidget {
  const LastVideoStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestVideoMessageProvider);

    return latest.when(
      data: (msg) {
        if (msg == null || msg.createdAt == null) {
          return const SizedBox.shrink();
        }
        return _Card(message: msg);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.message});

  final VideoMessage message;

  String _relativeTime(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 60) return 'hozirgina';
    if (diff.inMinutes < 60) return '${diff.inMinutes} daq oldin';
    if (diff.inHours < 24) return '${diff.inHours} soat oldin';
    return '${diff.inDays} kun oldin';
  }

  @override
  Widget build(BuildContext context) {
    final seen = message.status == VideoMessageStatus.seen;
    final time = _relativeTime(message.createdAt!);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              AppIcons.video,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Oxirgi video xabar',
                  style: TextStyle(
                    color: context.adaptive.textTertiary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    color: context.adaptive.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: seen
                  // ignore: deprecated_member_use
                  ? AppColors.success.withOpacity(0.15)
                  // ignore: deprecated_member_use
                  : AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  seen ? AppIcons.success : AppIcons.schedule,
                  size: 12,
                  color:
                      seen ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  seen ? "Ko'rdi" : 'Kutilmoqda',
                  style: TextStyle(
                    color:
                        seen ? AppColors.success : AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
