// ─────────────────────────────────────────────────────────────────────
// PairRequestsScreen — Pending pair-request'lar ro'yxati (4.4.25)
// ─────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:farzandim/core/network/friendly_error.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/pair_requests/data/models/pair_request.dart';
import 'package:farzandim/features/pair_requests/data/repositories/backend_pair_request_repository.dart';
import 'package:farzandim/features/pair_requests/presentation/providers/pair_request_providers.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PairRequestsScreen extends ConsumerWidget {
  const PairRequestsScreen({required this.childId, super.key});
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(childByIdProvider(childId));
    final childName = child?.name ?? 'Bola';
    final requestsAsync = ref.watch(pendingPairRequestsProvider(childId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(childName: childName),
              Expanded(
                child: requestsAsync.when(
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
                        ref.invalidate(pendingPairRequestsProvider(childId));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.lg,
                          vertical: AppDimensions.md,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) =>
                            _RequestTile(request: list[i], childId: childId),
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
                "$childName — Pair so'rovlar",
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

class _RequestTile extends ConsumerStatefulWidget {
  const _RequestTile({required this.request, required this.childId});
  final PairRequest request;
  final String childId;

  @override
  ConsumerState<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<_RequestTile> {
  Timer? _timer;
  Duration _left = Duration.zero;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _left = widget.request.timeLeft;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = widget.request.timeLeft);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    final ok = await ref
        .read(backendPairRequestRepositoryProvider)
        .approve(childId: widget.childId, requestId: widget.request.id);
    if (!mounted) return;
    ref.invalidate(pendingPairRequestsProvider(widget.childId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Tasdiqlandi' : 'Tasdiqlash xato'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Rad etilsinmi?',
          style: AppTextStyles.headlineL.copyWith(fontSize: 18),
        ),
        content: Text(
          'Bola yangi qurilmadan ulana olmaydi. Ishonchingiz komilmi?',
          style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Bekor qilish',
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Rad etish',
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    final ok = await ref
        .read(backendPairRequestRepositoryProvider)
        .reject(childId: widget.childId, requestId: widget.request.id);
    if (!mounted) return;
    ref.invalidate(pendingPairRequestsProvider(widget.childId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Rad etildi' : 'Rad etish xato'),
        backgroundColor: ok ? AppColors.warning : AppColors.error,
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  String _formatLeft(Duration d) {
    if (d <= Duration.zero) return "Muddati o'tdi";
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _left <= Duration.zero;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: SettingsCard(
        accent: AppColors.secondary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SettingsIconChip(
                  icon: Icons.phone_iphone_rounded,
                  accent: AppColors.secondary,
                  size: 44,
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yangi qurilma',
                        style: AppTextStyles.bodyM.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.request.deviceLabel,
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            if (widget.request.appVersion != null)
              _InfoRow(
                icon: Icons.app_settings_alt,
                label: 'Ilova',
                value: widget.request.appVersion!,
              ),
            if (widget.request.ipAddress != null)
              _InfoRow(
                icon: Icons.public,
                label: 'IP',
                value: widget.request.ipAddress!,
              ),
            _InfoRow(
              icon: Icons.timer_outlined,
              label: 'Muddat',
              value: _formatLeft(_left),
              valueColor: isExpired ? AppColors.error : AppColors.accent,
            ),
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy || isExpired ? null : _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Rad etish'),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _busy || isExpired ? null : _approve,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      'Tasdiqlash',
                      style: AppTextStyles.bodyM.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyS.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              "Pair so'rovlar yo'q",
              style: AppTextStyles.headlineL.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              "Bola yangi qurilmadan ulanmoqchi bo'lganda shu yerda "
              "paydo bo'ladi.",
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
