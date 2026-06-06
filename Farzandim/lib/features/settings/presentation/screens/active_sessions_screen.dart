// ─────────────────────────────────────────────────────────────────────
// ActiveSessionsScreen — Sozlamalar > Faol sessiyalar (Figma 1:1)
// ─────────────────────────────────────────────────────────────────────
//
// Backend GET /api/auth/sessions — login qilingan qurilmalar. Foydalanuvchi
// boshqa qurilmalarni uzoqdan tugata oladi (DELETE /sessions/:id) yoki
// barchasini birato'la (DELETE /sessions/others).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/settings/data/models/user_session.dart';
import 'package:farzandim/features/settings/presentation/providers/sessions_provider.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ActiveSessionsScreen extends ConsumerWidget {
  const ActiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(),
              Expanded(
                child: sessionsAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                  ),
                  error: (_, __) => _ErrorState(
                    onRetry: () =>
                        ref.read(sessionsProvider.notifier).refresh(),
                  ),
                  data: (sessions) => _SessionsList(sessions: sessions),
                ),
              ),
              const _AddAccountBar(),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
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
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'settings.sessions.title'.tr(),
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

// ════════════════════════ SESSIONS LIST ════════════════════════

class _SessionsList extends ConsumerWidget {
  const _SessionsList({required this.sessions});

  final List<UserSession> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessions.isEmpty) {
      return _EmptyState(
        onRefresh: () => ref.read(sessionsProvider.notifier).refresh(),
      );
    }

    UserSession? current;
    final others = <UserSession>[];
    for (final s in sessions) {
      if (s.isCurrent && current == null) {
        current = s;
      } else {
        others.add(s);
      }
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () => ref.read(sessionsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg,
          AppDimensions.sm,
          AppDimensions.lg,
          AppDimensions.lg,
        ),
        children: [
          if (current != null) ...[
            _SectionLabel('settings.sessions.yourSession'.tr()),
            const SizedBox(height: AppDimensions.sm),
            _SessionCard(session: current),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.md),
            _EndAllOthersButton(
              onConfirmed: () =>
                  ref.read(sessionsProvider.notifier).revokeOthers(),
            ),
            const SizedBox(height: AppDimensions.lg),
            _SectionLabel('settings.sessions.otherSessions'.tr()),
            const SizedBox(height: AppDimensions.sm),
            for (final s in others) ...[
              _SessionCard(
                session: s,
                onRevoke: () =>
                    ref.read(sessionsProvider.notifier).revoke(s.id),
              ),
              const SizedBox(height: AppDimensions.sm),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyM.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ════════════════════════ SESSION CARD ════════════════════════

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, this.onRevoke});

  final UserSession session;

  /// `null` → joriy sessiya ("Mas'ul" belgisi). Aks holda tugatish tugmasi.
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final location =
        session.locationLabel ?? 'settings.sessions.unknownLocation'.tr();
    final meta = _metaLine();

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlatformBadge(session: session),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.displayName,
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (meta != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  location,
                  style: AppTextStyles.bodyS.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          _Trailing(session: session, onRevoke: onRevoke),
        ],
      ),
    );
  }

  /// "1.2.3.4 · 13.09.2024, 15:40" — IP bo'lmasa faqat sana.
  String? _metaLine() {
    final date =
        session.lastSeenAt != null ? _formatDate(session.lastSeenAt!) : null;
    final ip = session.ipAddress;
    if (ip != null && ip.isNotEmpty && date != null) return '$ip · $date';
    return ip?.isNotEmpty == true ? ip : date;
  }
}

class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({required this.session});
  final UserSession session;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    if (session.isAndroid) {
      icon = Icons.android;
      color = AppColors.success;
    } else if (session.isIos) {
      icon = Icons.phone_iphone_rounded;
      color = AppColors.textPrimary;
    } else {
      icon = Icons.public_rounded;
      color = AppColors.info;
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({required this.session, required this.onRevoke});
  final UserSession session;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    if (onRevoke == null || session.isCurrent) {
      // Joriy qurilma — "Mas'ul".
      return Text(
        'settings.sessions.current'.tr(),
        style: AppTextStyles.bodyS.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return IconButton(
      icon: Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
      tooltip: 'settings.sessions.endSession'.tr(),
      onPressed: () => _confirmRevoke(context),
    );
  }

  Future<void> _confirmRevoke(BuildContext context) async {
    final ok = await _showEndSessionConfirm(
      context,
      title: 'settings.sessions.revokeConfirmTitle'.tr(),
      content: 'settings.sessions.revokeConfirmContent'.tr(),
    );
    if (ok && context.mounted) {
      onRevoke!.call();
      _snack(context, 'settings.sessions.endedSnack'.tr());
    }
  }
}

// ════════════════════════ END ALL OTHERS ════════════════════════

class _EndAllOthersButton extends StatelessWidget {
  const _EndAllOthersButton({required this.onConfirmed});
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _confirm(context),
        icon: Icon(Icons.back_hand_rounded,
            color: AppColors.error, size: 18),
        label: Text(
          'settings.sessions.endAllOthers'.tr(),
          style: AppTextStyles.bodyM.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final ok = await _showEndSessionConfirm(
      context,
      title: 'settings.sessions.endAllConfirmTitle'.tr(),
      content: 'settings.sessions.endAllConfirmContent'.tr(),
    );
    if (ok && context.mounted) {
      onConfirmed();
      _snack(context, 'settings.sessions.endedAllSnack'.tr());
    }
  }
}

// ════════════════════════ ADD ACCOUNT BAR ════════════════════════

class _AddAccountBar extends StatelessWidget {
  const _AddAccountBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.md,
      ),
      child: SizedBox(
        height: AppDimensions.buttonHeight,
        child: Material(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            onTap: () => context.push(AppRoutes.addAccount),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_rounded,
                      color: AppColors.background, size: 22),
                  const SizedBox(width: AppDimensions.sm),
                  Text(
                    'settings.sessions.addAccount'.tr(),
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.background,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ EMPTY / ERROR ════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.28),
          Icon(Icons.devices_other_rounded,
              color: AppColors.textTertiary, size: 56),
          const SizedBox(height: AppDimensions.md),
          Center(
            child: Text(
              'settings.sessions.empty'.tr(),
              style: AppTextStyles.bodyM
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              color: AppColors.textTertiary, size: 48),
          const SizedBox(height: AppDimensions.md),
          Text(
            'settings.sessions.loadError'.tr(),
            style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.md),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'settings.sessions.retry'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ HELPERS ════════════════════════

/// "dd.MM.yyyy, HH:mm" — intl'siz qo'lda format (local time).
String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceVariant,
      ),
    );
}

/// Figma 1:1 — iOS uslubidagi tasdiq alert'i: "Ha" (ko'k) / "Yo'q" (qizil).
/// `true` → "Ha" (yakunlash), `false` → "Yo'q"/bekor.
Future<bool> _showEndSessionConfirm(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoTheme(
      data: const CupertinoThemeData(brightness: Brightness.light),
      child: CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(content),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('settings.sessions.confirmYes'.tr()),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('settings.sessions.confirmNo'.tr()),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
