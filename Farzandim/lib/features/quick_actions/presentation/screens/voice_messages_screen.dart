import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/voice_message/presentation/providers/voice_message_providers.dart';
import 'package:farzandim/features/voice_message/presentation/screens/voice_chat_screen.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bolalar ro'yxati — Telegram chat list uslubida.
///
/// Har bola tile: avatar, ism, oxirgi xabar preview, vaqt, qizil
/// unread badge. Tap → o'sha bola `VoiceChatScreen`.
class VoiceMessagesScreen extends ConsumerWidget {
  /// `VoiceMessagesScreen` konstruktor.
  const VoiceMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);
    // Stream'lar real-time — invalidate qilsa qayta subscribe bo'ladi
    // (pull-to-refresh UX uchun foydalanuvchi tasdiq oladi).
    Future<void> onRefresh() async {
      ref
        ..invalidate(latestVoiceMessageProvider)
        ..invalidate(unreadVoiceMessagesProvider)
        ..invalidate(sortedChildrenForVoiceProvider);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(onBack: () => context.pop()),
              Expanded(
                child: childrenAsync.when(
                  data: (children) => children.isEmpty
                      ? const _NoChildren()
                      : _ChildrenList(onRefresh: onRefresh),
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.lg),
                      child: Text(
                        'voiceMessages.errorPrefix'.tr(
                          namedArgs: {'error': '$e'},
                        ),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
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
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
              ),
              onPressed: onBack,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'voiceMessages.headerTitle'.tr(),
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

class _NoChildren extends StatelessWidget {
  const _NoChildren();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.child_care,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'voiceMessages.noChildren'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildrenList extends ConsumerWidget {
  const _ChildrenList({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Saralangan ro'yxat: yangi xabar bor bolalar yuqorida.
    final children = ref.watch(sortedChildrenForVoiceProvider);

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: children.length,
        separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 80),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.textSecondary.withValues(alpha: 0.1),
          ),
        ),
        itemBuilder: (_, i) => _ChildVoiceTile(child: children[i]),
      ),
    );
  }
}

class _ChildVoiceTile extends ConsumerWidget {
  const _ChildVoiceTile({required this.child});

  final Child child;

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'voiceMessages.relativeTime.justNow'.tr();
    if (diff.inMinutes < 60) {
      return 'voiceMessages.relativeTime.minutes'.tr(
        namedArgs: {'minutes': '${diff.inMinutes}'},
      );
    }
    if (diff.inHours < 24) {
      return 'voiceMessages.relativeTime.hours'.tr(
        namedArgs: {'hours': '${diff.inHours}'},
      );
    }
    return 'voiceMessages.relativeTime.days'.tr(
      namedArgs: {'days': '${diff.inDays}'},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestVoiceMessageProvider(child.id));
    final unreadAsync = ref.watch(unreadVoiceMessagesProvider(child.id));

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => VoiceChatScreen(childId: child.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm + 4,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ChildAvatar(
                  child: child,
                  size: 56,
                  showBorder: false,
                ),
                unreadAsync.when(
                  data: (count) {
                    if (count == 0) return const SizedBox.shrink();
                    return Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusPill,
                          ),
                          border: Border.all(
                            color: AppColors.backgroundBottom,
                            width: 2,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: AppTextStyles.label.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          child.name,
                          style: AppTextStyles.bodyM.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      latestAsync.when(
                        data: (latest) {
                          if (latest == null) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            _relativeTime(latest.createdAt),
                            style: AppTextStyles.bodyS.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  latestAsync.when(
                    data: (latest) {
                      if (latest == null) {
                        return Text(
                          'voiceMessages.noMessages'.tr(),
                          style: AppTextStyles.bodyS.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        );
                      }
                      final senderText = latest.sender == 'parent'
                          ? 'voiceMessages.youPrefix'.tr()
                          : '';
                      final durationText =
                          'voiceMessages.durationSeconds'.tr(
                        namedArgs: {
                          'seconds': '${latest.durationSeconds}',
                        },
                      );
                      return Row(
                        children: [
                          Icon(
                            Icons.mic,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppDimensions.xs),
                          Expanded(
                            child: Text(
                              '$senderText$durationText',
                              style: AppTextStyles.bodyS.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => Text(
                      'voiceMessages.loading'.tr(),
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    error: (_, __) => Text(
                      'voiceMessages.error'.tr(),
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
