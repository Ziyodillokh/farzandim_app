// ─────────────────────────────────────────────────────────────────────
// FeedbackInboxScreen — Parent emoji feedback inbox (Sprint 4.4.17)
// ─────────────────────────────────────────────────────────────────────
//
// Bola yuborgan emoji + message ko'rsatadi. WS `feedback:received`
// orqali real-time keladi. Tap → markAsRead.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/network/friendly_error.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/formatters.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/feedback/data/repositories/backend_feedback_repository.dart';
import 'package:farzandim/features/feedback/presentation/providers/feedback_provider.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bola feedback inbox ekrani.
class FeedbackInboxScreen extends ConsumerWidget {
  /// `FeedbackInboxScreen` konstruktor.
  const FeedbackInboxScreen({required this.childId, super.key});

  /// Qaysi bola'ning feedback'lari.
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(childByIdProvider(childId));
    final childName = child?.name ?? 'feedback.fallbackChildName'.tr();
    final feedbackAsync = ref.watch(childFeedbackProvider(childId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(childName: childName),
              Expanded(
                child: feedbackAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                  error: (e, _) =>
                      Center(child: Text(friendlyError(e))),
                  data: (list) {
                    if (list.isEmpty) return const _EmptyState();
                    return RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: () async {
                        ref.invalidate(childFeedbackProvider(childId));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.lg,
                          vertical: AppDimensions.md,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) =>
                            _FeedbackTile(feedback: list[i], childId: childId),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.childName});
  final String childName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'feedback.headerTitle'.tr(namedArgs: {'name': childName}),
                style: AppTextStyles.headlineL.copyWith(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _FeedbackTile extends ConsumerWidget {
  const _FeedbackTile({required this.feedback, required this.childId});

  final Map<String, dynamic> feedback;
  final String childId;

  /// Backend emoji enum → display emoji.
  static const _emojiMap = <String, String>{
    'HAPPY': '😊',
    'EXCITED': '🤩',
    'THINKING': '🤔',
    'WINKING': '😉',
    'SAD': '😢',
    'ANGRY': '😠',
    'TIRED': '😴',
    'LOVE': '❤️',
  };

  /// Backend emoji enum → i18n kalit (render paytida .tr() qilinadi).
  static const _labelKeyMap = <String, String>{
    'HAPPY': 'feedback.moodHappy',
    'EXCITED': 'feedback.moodExcited',
    'THINKING': 'feedback.moodThinking',
    'WINKING': 'feedback.moodWinking',
    'SAD': 'feedback.moodSad',
    'ANGRY': 'feedback.moodAngry',
    'TIRED': 'feedback.moodTired',
    'LOVE': 'feedback.moodLove',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emojiKey = (feedback['emoji'] as String? ?? 'HAPPY').toUpperCase();
    final emoji = _emojiMap[emojiKey] ?? '💭';
    final label = _labelKeyMap[emojiKey]?.tr() ?? emojiKey;
    final message = (feedback['message'] as String?) ?? '';
    final isRead = feedback['isRead'] as bool? ?? false;
    final createdAt = feedback['createdAt'] as String?;
    final time = createdAt != null
        ? DateTime.tryParse(createdAt)?.toLocal()
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: SettingsCard(
        accent: AppColors.warning,
        onTap: () => _onTap(context, ref),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.bodyM.copyWith(
                          fontWeight: isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (time != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(time),
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final id = feedback['id'] as String?;
    final isRead = feedback['isRead'] as bool? ?? false;
    if (id == null || isRead) return;

    await ref.read(backendFeedbackRepositoryProvider).markAsRead(id);
    ref.invalidate(childFeedbackProvider(childId));
  }

  // ARCH-07: markaziy formatter — dublikat mantiq olib tashlandi.
  String _formatTime(DateTime dt) => formatRelativeTime(dt);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💭', style: TextStyle(fontSize: 64)),
            const SizedBox(height: AppDimensions.md),
            Text(
              'feedback.emptyTitle'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'feedback.emptySubtitle'.tr(),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
