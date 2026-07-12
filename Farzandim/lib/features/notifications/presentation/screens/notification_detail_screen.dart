// Bitta bildirishnomaning detal sahifasi (provizor — Figma tayyor bo'lguncha).
//
// Parvoz dizayni: tepada orqa tugma + "Bildirishnoma", markazda tur ikoni
// (rangli), sarlavha, to'liq matn va meta (bola • vaqt). Pastda turga qarab
// tegishli amal tugmalari (xaritada ko'rish, cheklovlar, jadval, unlock/pair
// qarori, o'yinni bloklash, SOS qo'ng'iroq).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/utils/formatters.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:farzandim/features/notifications/presentation/widgets/unlock_decision_sheet.dart';
import 'package:farzandim/features/pair_requests/data/repositories/backend_pair_request_repository.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// ════════════ Tokenlar (lokal, Parvoz) ════════════
const _bg = Color(0xFF00060A);
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x14FFFFFF);
const _dim = Color(0x99FFFFFF); // oq 60%
const _dim2 = Color(0x66FFFFFF); // oq 40% — meta

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.45,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.35,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Bitta bildirishnoma detal sahifasi. [notification] `null` bo'lsa (masalan
/// eskirgan navigatsiya) xushmuomala "topilmadi" holati ko'rsatiladi.
class NotificationDetailScreen extends ConsumerWidget {
  /// `NotificationDetailScreen` konstruktor.
  const NotificationDetailScreen({required this.notification, super.key});

  /// Ko'rsatiladigan xabar (route `extra` orqali keladi).
  final AppNotification? notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: n == null ? const _NotFound() : _Body(notification: n),
            ),
            if (n != null) _Actions(notification: n),
          ],
        ),
      ),
    );
  }
}

// ════════════ Sarlavha ════════════
class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          ParvozBackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                'notifications.title'.tr(),
                style: _unb(20, w: FontWeight.w500, ls: -0.6),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

// ════════════ Tana (ikon + sarlavha + matn + meta) ════════════
class _Body extends StatelessWidget {
  const _Body({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final hasTitle = n.title.trim().isNotEmpty;
    final title = hasTitle ? n.title.trim() : n.message.trim();
    final body = hasTitle ? n.message.trim() : '';
    final color = n.type.color;

    final metaParts = <String>[
      if (n.childName.trim().isNotEmpty) n.childName.trim(),
      _capitalize(formatRelativeTime(n.timestamp)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(n.type.icon, size: 40, color: color),
          ),
          const SizedBox(height: 22),
          Text(title, textAlign: TextAlign.center, style: _unb(20)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: _pop(14, c: _dim),
            ),
          ],
          if (n.imageUrl != null && n.imageUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                n.imageUrl!.trim(),
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 180,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: _dim,
                      ),
                    ),
                  );
                },
                // Rasm yuklanmasa (buzuq URL / tarmoq) — jimgina yashiramiz.
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(metaParts.join(' • '), style: _pop(12, c: _dim2)),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ════════════ Amal tugmalari (turga qarab) ════════════
class _Actions extends ConsumerWidget {
  const _Actions({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttons = _buttons(context, ref, notification);
    if (buttons.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            buttons[i],
          ],
        ],
      ),
    );
  }

  List<Widget> _buttons(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) {
    final hasChild = n.childId.isNotEmpty;
    Widget primary(String label, VoidCallback onTap) =>
        ParvozPrimaryButton(label: label, onPressed: onTap, showArrow: false);
    Widget secondary(String label, VoidCallback onTap) =>
        ParvozSecondaryButton(label: label, onPressed: onTap);

    switch (n.type) {
      case NotificationType.sos:
        return [
          if (hasChild)
            primary(
              'notifications.sos.locationButton'.tr(),
              () => context.push(AppRoutes.locationPath(n.childId)),
            ),
          secondary(
            'notifications.sos.callButton'.tr(),
            () => _call(context, ref, n),
          ),
        ];
      case NotificationType.enterZone:
      case NotificationType.exitZone:
      case NotificationType.lowBattery:
      case NotificationType.offline:
      case NotificationType.online:
        return [
          if (hasChild)
            primary(
              'notifications.actions.viewOnMap'.tr(),
              () => context.push(AppRoutes.locationPath(n.childId)),
            ),
        ];
      case NotificationType.appLimit:
      case NotificationType.permissionChanged:
        return [
          if (hasChild)
            primary(
              'notifications.actions.openRestrictions'.tr(),
              () => context.push(AppRoutes.appRestrictionsPath(n.childId)),
            ),
        ];
      case NotificationType.game:
        return [
          if (hasChild)
            primary(
              'notifications.actions.openRestrictions'.tr(),
              () => context.push(AppRoutes.appRestrictionsPath(n.childId)),
            ),
          secondary(
            'notifications.blockApp'.tr(),
            () => _block(context, ref, n),
          ),
        ];
      case NotificationType.scheduleStart:
      case NotificationType.scheduleReminder:
        return [
          if (hasChild)
            primary(
              'notifications.actions.openSchedules'.tr(),
              () => context.push(AppRoutes.schedulesPath(n.childId)),
            ),
        ];
      case NotificationType.pairRequest:
        return [
          if (hasChild)
            primary(
              'notifications.review'.tr(),
              () => context.push(AppRoutes.pairRequestsPath(n.childId)),
            ),
          secondary(
            'notifications.reject'.tr(),
            () => _rejectPair(context, ref, n),
          ),
        ];
      case NotificationType.unlockRequest:
        return [
          primary(
            'notifications.actions.giveTime'.tr(),
            () => _giveTime(context, ref, n),
          ),
          secondary(
            'notifications.actions.deny'.tr(),
            () => _denyUnlock(context, ref, n),
          ),
        ];
      case NotificationType.sessionAccessRequest:
        return [
          primary(
            'notifications.review'.tr(),
            () => context.push(AppRoutes.sessionAccessApprove),
          ),
        ];
    }
  }

  // ─── SOS: bolaning raqamiga qo'ng'iroq ───
  Future<void> _call(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final child = ref.read(childByIdProvider(n.childId));
    final phone = child?.phoneNumber;
    if (phone == null || phone.trim().isEmpty) {
      AppToast.warning(context, 'notifications.sos.callNoPhone'.tr());
      return;
    }
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && context.mounted) {
      AppToast.error(context, 'notifications.sos.callFailed'.tr());
    }
  }

  // ─── O'yin: ilovani to'liq bloklash (app-limit dailyLimitMs=0) ───
  Future<void> _block(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final pkg = n.packageName;
    if (pkg == null || pkg.isEmpty || n.childId.isEmpty) return;
    final appName = n.appName ?? n.childName;
    try {
      await ref
          .read(appRestrictionRepositoryProvider)
          .blockApp(childId: n.childId, packageName: pkg, appName: appName);
      ref.read(notificationsProvider.notifier).markAsRead(n.id);
      if (context.mounted) {
        AppToast.info(
          context,
          'notifications.blockedSnack'.tr(namedArgs: {'app': appName}),
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context, 'notifications.blockError'.tr());
      }
    }
  }

  // ─── Unlock: "Vaqt ber" — qaror varag'i (rad et / 5·15·30·60) ───
  Future<void> _giveTime(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final reqId = n.unlockRequestId;
    if (reqId == null || reqId.isEmpty) return;

    final decision = await UnlockDecisionSheet.show(
      context,
      childName: n.childName,
      appName: n.appName ?? n.packageName,
      requestedMinutes: n.requestedMinutes,
      reason: n.unlockReason,
    );
    if (decision == null || !context.mounted) return;

    final ok = await ref
        .read(backendUnlockRequestRepositoryProvider)
        .decide(
          requestId: reqId,
          approve: decision.approve,
          minutes: decision.minutes,
        );
    ref.read(notificationsProvider.notifier).deleteNotification(n.id);
    if (!context.mounted) return;
    if (ok) {
      AppToast.success(
        context,
        decision.approve
            ? 'notifications.unlock.granted'.tr(
                namedArgs: {'minutes': '${decision.minutes}'},
              )
            : 'notifications.unlock.denied'.tr(),
      );
    } else {
      AppToast.error(context, 'errors.generic'.tr());
    }
    if (context.mounted) context.pop();
  }

  // ─── Unlock: "Rad et" — tez rad etish (sheet'siz) ───
  Future<void> _denyUnlock(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final reqId = n.unlockRequestId;
    if (reqId != null && reqId.isNotEmpty) {
      await ref
          .read(backendUnlockRequestRepositoryProvider)
          .decide(requestId: reqId, approve: false);
    }
    ref.read(notificationsProvider.notifier).deleteNotification(n.id);
    if (context.mounted) {
      AppToast.info(context, 'notifications.rejected'.tr());
      context.pop();
    }
  }

  // ─── Pair: "Rad etish" — so'rovni rad etish + xabarni o'chirish ───
  Future<void> _rejectPair(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final reqId = n.pairRequestId;
    if (reqId != null && n.childId.isNotEmpty) {
      await ref
          .read(backendPairRequestRepositoryProvider)
          .reject(childId: n.childId, requestId: reqId);
    }
    ref.read(notificationsProvider.notifier).deleteNotification(n.id);
    if (context.mounted) {
      AppToast.info(context, 'notifications.rejected'.tr());
      context.pop();
    }
  }
}

// ════════════ "Topilmadi" holati ════════════
class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _card,
                shape: BoxShape.circle,
                border: Border.all(color: _cardBorder),
              ),
              child: const Icon(Icons.inbox_rounded, size: 44, color: _dim),
            ),
            const SizedBox(height: 18),
            Text(
              'notifications.detail.notFound'.tr(),
              textAlign: TextAlign.center,
              style: _pop(14, c: _dim),
            ),
          ],
        ),
      ),
    );
  }
}
