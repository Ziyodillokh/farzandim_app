// ─────────────────────────────────────────────────────────────────────
// ChildCredentialsScreen — "Kirish ma'lumotlari" (bolaning login va paroli)
// ─────────────────────────────────────────────────────────────────────
//
// Bolalarim → bola kartasi / Bola sozlamalari va push
// `CHILD_RECOVERY_REQUEST` ochadi. Holatlar:
//   - login berilmagan → tushuntirish va "Login va parol berish";
//   - berilgan → login (nusxalanadi), kim/qachon bergan, birinchi kirish
//     kutilmoqda yoki faol, oxirgi kirish, "Parolni yangilash";
//   - bolaning ochiq "parolni unutdim" so'rovlari tepada: "Parolni tiklash"
//     yoki "Rad etish".
// Vaqtinchalik parol bir marta, varaqda ko'rsatiladi (bu ekran uni ko'rmaydi).
// Backend'da bo'lim yo'q (404 `code`siz) → "hozircha mavjud emas".
// Pastga tortib yangilanadi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/child_credentials/data/credentials_failure.dart';
import 'package:farzandim/features/child_credentials/data/models/child_credentials.dart';
import 'package:farzandim/features/child_credentials/presentation/providers/child_credentials_providers.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/credentials_card.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/credentials_flows.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/credentials_ui.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/recovery_requests_section.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// Tortib yangilashda spinner shundan ortiq aylanmaydi.
const Duration _refreshTimeout = Duration(seconds: 8);

class ChildCredentialsScreen extends ConsumerWidget {
  const ChildCredentialsScreen({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(childByIdProvider(childId));
    final name = _displayName(child);
    final async = ref.watch(childCredentialsProvider(childId));

    final Widget body;
    if (async.hasValue) {
      body = RefreshIndicator(
        color: CredStyle.blue,
        backgroundColor: CredStyle.card,
        onRefresh: () => _refresh(context, ref),
        child: _Content(
          childId: childId,
          child: child,
          name: name,
          shareName: _realName(child),
          credentials: async.valueOrNull,
        ),
      );
    } else if (async.hasError) {
      body = _LoadError(error: async.error, onRetry: () => _reload(ref));
    } else {
      body = const SchoolLoadingView();
    }
    return SchoolScaffold(title: 'childCredentials.title'.tr(), body: body);
  }

  /// Bolaning haqiqiy ismi; bola yuklanmagan (push'dan sovuq start) yoki
  /// ismi bo'sh bo'lsa `null`.
  static String? _realName(Child? child) {
    final name = child?.name.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  /// Ekranda ko'rsatiladigan ism: haqiqiy ism yoki umumiy "Bola".
  static String _displayName(Child? child) =>
      _realName(child) ?? 'childCredentials.fallbackChildName'.tr();

  void _reload(WidgetRef ref) {
    ref
      ..invalidate(childCredentialsProvider(childId))
      ..invalidate(childRecoveryRequestsProvider(childId));
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    _reload(ref);
    try {
      await ref
          .read(childCredentialsProvider(childId).future)
          .timeout(_refreshTimeout);
    } on TimeoutException {
      // Javob kechikdi — spinner yopiladi, kelganda ekran o'zi yangilanadi.
    } on Object catch (error) {
      // Oldingi holat ekranda qoladi — sababini qisqa xabar bilan aytamiz.
      if (!context.mounted) return;
      final key = CredentialsFailure.fromError(error).messageKey;
      AppToast.error(context, key.tr());
    }
  }
}

/// Yuklangan holat: bola sarlavhasi, so'rovlar va asosiy karta.
class _Content extends StatelessWidget {
  const _Content({
    required this.childId,
    required this.child,
    required this.name,
    required this.shareName,
    required this.credentials,
  });

  final String childId;
  final Child? child;

  /// Ekrandagi nom (bola yuklanmagan bo'lsa umumiy "Bola").
  final String name;

  /// Bolaga yuboriladigan matndagi haqiqiy ism (noma'lum bo'lsa `null`).
  final String? shareName;
  final ChildCredentials? credentials;

  void _issue(BuildContext context) => unawaited(
    runIssueCredentialsFlow(
      context,
      childId: childId,
      childName: name,
      shareName: shareName,
    ),
  );

  void _reset(BuildContext context, {bool fromRecovery = false}) => unawaited(
    runResetCredentialsFlow(
      context,
      childId: childId,
      childName: name,
      shareName: shareName,
      fromRecovery: fromRecovery,
    ),
  );

  Future<void> _copyLogin(BuildContext context, String login) async {
    await Clipboard.setData(ClipboardData(text: login));
    if (!context.mounted) return;
    AppToast.success(context, 'childCredentials.card.loginCopied'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final current = credentials;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _ChildHeader(child: child, name: name),
        const SizedBox(height: 16),
        if (current == null)
          NoCredentialsCard(childName: name, onIssue: () => _issue(context))
        else ...[
          RecoveryRequestsSection(
            childId: childId,
            childName: name,
            onRestore: () => _reset(context, fromRecovery: true),
          ),
          CredentialsCard(
            credentials: current,
            childName: name,
            onCopyLogin: () => unawaited(_copyLogin(context, current.login)),
          ),
          const SizedBox(height: 16),
          ParvozSecondaryButton(
            label: 'childCredentials.card.reset'.tr(),
            leading: const Icon(
              SolarIconsOutline.restart,
              size: 20,
              color: Colors.white,
            ),
            onPressed: () => _reset(context),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'childCredentials.card.resetHint'.tr(),
              textAlign: TextAlign.center,
              style: CredStyle.pop(12.5, c: CredStyle.dim),
            ),
          ),
        ],
      ],
    );
  }
}

/// Qaysi bolaning ma'lumotlari ekanini ko'rsatadi (push'dan ochilganda ham).
class _ChildHeader extends StatelessWidget {
  const _ChildHeader({required this.child, required this.name});

  final Child? child;
  final String name;

  @override
  Widget build(BuildContext context) {
    final child = this.child;
    return Row(
      children: [
        if (child != null)
          ChildAvatar(child: child, size: 48, showBorder: false)
        else
          const CredIconChip(icon: SolarIconsBold.user, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CredStyle.unb(18),
          ),
        ),
      ],
    );
  }
}

/// Birinchi yuklash xatosi: bo'lim yo'q — qayta urinishsiz xabar; qolgani
/// sabab va "Qayta urinish".
class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = CredentialsFailure.fromError(
      error ?? const CredentialsFailure(CredentialsFailureKind.unknown),
    );
    if (failure.isUnavailable) {
      return SchoolMessageView(
        icon: SolarIconsBold.key,
        title: 'childCredentials.title'.tr(),
        message: failure.messageKey.tr(),
      );
    }
    return SchoolMessageView(
      icon: SolarIconsBold.wifiRouterMinimalistic,
      title: 'childCredentials.load.failedTitle'.tr(),
      message: failure.messageKey.tr(),
      actionLabel: 'common.retry'.tr(),
      onAction: onRetry,
    );
  }
}
