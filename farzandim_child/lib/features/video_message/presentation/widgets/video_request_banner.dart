// ─────────────────────────────────────────────────────────────────────
// VideoRequestBanner — Parent video so'raganda Dashboard banner
// ─────────────────────────────────────────────────────────────────────
//
// `activeVideoRequestProvider` orqali real-time obuna. So'rov bor bo'lsa
// butun row tap bilan ochiladi: tap → `markAsRecording` + recording
// ekraniga o'tish. So'rov yo'q yoki expired bo'lsa SizedBox.shrink.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/video_message/presentation/providers/video_request_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VideoRequestBanner extends ConsumerWidget {
  const VideoRequestBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRequest = ref.watch(activeVideoRequestProvider);

    return activeRequest.when(
      data: (request) {
        if (request == null) return const SizedBox.shrink();
        return _Banner(requestId: request.id);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Banner extends ConsumerWidget {
  const _Banner({required this.requestId});

  final String requestId;

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(videoRequestRepositoryProvider);
    if (repo != null) {
      try {
        await repo.markAsRecording(requestId);
      } catch (_) {
        // Status update fail bo'lsa ham recording'ga o'tamiz —
        // upload tugagach `markAsCompleted` to'g'ri yoziladi.
      }
    }
    if (!context.mounted) return;
    context.push('/video-recording?requestId=$requestId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _onTap(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              // ignore: deprecated_member_use
              AppColors.primary.withOpacity(0.2),
              // ignore: deprecated_member_use
              AppColors.primary.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: AppColors.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.video,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'videoMessage.requestTitle'.tr(),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'videoMessage.requestSubtitle'.tr(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(AppIcons.forward, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
