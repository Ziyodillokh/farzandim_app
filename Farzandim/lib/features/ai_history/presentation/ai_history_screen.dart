// ─────────────────────────────────────────────────────────────────────
// AiHistoryScreen (Parent) — bola AI suhbat tarixi (#70)
// ─────────────────────────────────────────────────────────────────────
//
// Ota-ona faqat o'qiydi. Flagged (xavfsizlik filtri ishlagan) xabarlar
// ajratib ko'rsatiladi + yuqorida soni. Ijobiy/shaffoflik ohangi.

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/ai_history/data/ai_history_repository.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AiHistoryScreen extends ConsumerWidget {
  const AiHistoryScreen({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aiHistoryProvider(childId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(onBack: () => context.pop()),
              Expanded(
                child: async.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => _Empty(
                    text: "Tarixni yuklab bo'lmadi.",
                    onRetry: () => ref.invalidate(aiHistoryProvider(childId)),
                  ),
                  data: (h) {
                    if (h.messages.isEmpty) {
                      return const _Empty(
                        text: "Hozircha AI suhbat yo'q.",
                      );
                    }
                    return Column(
                      children: [
                        _FlaggedBanner(count: h.flaggedCount),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(aiHistoryProvider(childId));
                              await ref.read(
                                aiHistoryProvider(childId).future,
                              );
                            },
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                              itemCount: h.messages.length,
                              itemBuilder: (_, i) =>
                                  _Bubble(message: h.messages[i]),
                            ),
                          ),
                        ),
                      ],
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
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: onBack,
          ),
          Expanded(
            child: Center(
              child: Text(
                'Faro suhbati',
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

class _FlaggedBanner extends StatelessWidget {
  const _FlaggedBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final ok = count == 0;
    final color = ok ? AppColors.success : AppColors.warning;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.verified_user_outlined : Icons.shield_outlined,
              size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok
                  ? "Suhbat xavfsiz — belgilangan xabar yo'q."
                  : '$count ta xabar xavfsizlik filtri tomonidan belgilangan '
                      '(sariq bilan ajratilgan).',
              style: AppTextStyles.bodyS.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bg = message.flagged
        ? AppColors.warning.withValues(alpha: 0.15)
        : (isUser
            ? AppColors.primary.withValues(alpha: 0.14)
            : AppColors.surface);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: message.flagged
              ? Border.all(color: AppColors.warning.withValues(alpha: 0.55))
              : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUser ? 'Bola' : 'Faro',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message.flagged) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.shield_outlined,
                      size: 13, color: AppColors.warning),
                  const SizedBox(width: 2),
                  Text(
                    'Belgilangan',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.warning,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              message.text,
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 60, color: AppColors.textTertiary),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Qayta urinish')),
          ],
        ],
      ),
    );
  }
}
