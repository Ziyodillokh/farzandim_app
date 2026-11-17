// ─────────────────────────────────────────────────────────────────────
// RecoveryRequestsSection — bolaning "parolni unutdim" so'rovlari
// ─────────────────────────────────────────────────────────────────────
//
// Ochiq so'rovlar ro'yxati (push `CHILD_RECOVERY_REQUEST` shu ekranni
// ochadi). Har so'rovda ikki amal:
//   - "Parolni tiklash" — parolni yangilash varag'i (qurilmalardan chiqarish
//     standart yoqilgan), so'ng yangi vaqtinchalik parol;
//   - "Rad etish" — tasdiqlashdan keyin so'rov yopiladi, parol o'zgarmaydi.
// Ro'yxat yuklanmasa ham ekranning qolgan qismi ishlaydi; bo'lim backend'da
// yo'q bo'lsa yoki so'rov bo'lmasa — hech narsa ko'rsatilmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/child_credentials/data/credentials_failure.dart';
import 'package:farzandim/features/child_credentials/data/models/recovery_request.dart';
import 'package:farzandim/features/child_credentials/presentation/providers/child_credentials_providers.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/credentials_ui.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/school_status_chip.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// Ochiq so'rovlar bo'limi. [onRestore] — "Parolni tiklash" bosildi
/// (ekran parolni yangilash oqimini ochadi).
class RecoveryRequestsSection extends ConsumerStatefulWidget {
  const RecoveryRequestsSection({
    required this.childId,
    required this.childName,
    required this.onRestore,
    super.key,
  });

  final String childId;
  final String childName;
  final VoidCallback onRestore;

  @override
  ConsumerState<RecoveryRequestsSection> createState() =>
      _RecoveryRequestsSectionState();
}

class _RecoveryRequestsSectionState
    extends ConsumerState<RecoveryRequestsSection> {
  /// Rad etilayotgan so'rov (tugmada spinner, qayta bosilmaydi).
  String? _rejectingId;

  Future<void> _reject(RecoveryRequest request) async {
    if (_rejectingId != null) return;
    final confirmed = await showCredentialsConfirm(
      context,
      title: 'childCredentials.recovery.rejectTitle'.tr(),
      body: 'childCredentials.recovery.rejectBody'.tr(),
      confirmLabel: 'childCredentials.recovery.rejectConfirm'.tr(),
      cancelLabel: 'common.cancel'.tr(),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final actions = ref.read(childCredentialsActionsProvider);
    setState(() => _rejectingId = request.id);
    final CredentialsResult<void> result;
    try {
      result = await actions.rejectRecovery(widget.childId, request.id);
    } on Object {
      // Kutilmagan dastur xatosi: tugma band holatda qotib qolmasin.
      if (mounted) setState(() => _rejectingId = null);
      rethrow;
    }
    if (!mounted) return;
    setState(() => _rejectingId = null);
    if (result.isSuccess) {
      AppToast.success(context, 'childCredentials.recovery.rejected'.tr());
    } else {
      final key = result.failure?.messageKey ?? 'errors.generic';
      AppToast.error(context, key.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(childRecoveryRequestsProvider(widget.childId));
    final requests = async.valueOrNull;
    if (requests == null) {
      final error = async.error;
      final hidden = error is CredentialsFailure && error.isUnavailable;
      if (!async.hasError || hidden) return const SizedBox.shrink();
      return _LoadError(
        onRetry: () =>
            ref.invalidate(childRecoveryRequestsProvider(widget.childId)),
      );
    }
    if (requests.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'childCredentials.recovery.title'.tr(),
            style: CredStyle.unb(15),
          ),
        ),
        for (final request in requests) ...[
          RecoveryRequestTile(
            request: request,
            childName: widget.childName,
            rejecting: _rejectingId == request.id,
            onRestore: widget.onRestore,
            onReject: () => _reject(request),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Bitta so'rov kartasi: kim, qachon, kanal va ikki amal.
class RecoveryRequestTile extends StatelessWidget {
  const RecoveryRequestTile({
    required this.request,
    required this.childName,
    required this.onRestore,
    required this.onReject,
    this.rejecting = false,
    super.key,
  });

  final RecoveryRequest request;
  final String childName;
  final VoidCallback onRestore;
  final VoidCallback onReject;
  final bool rejecting;

  @override
  Widget build(BuildContext context) {
    final createdAt = request.createdAt;
    return CredCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CredIconChip(
                icon: SolarIconsBold.lockPassword,
                color: CredStyle.amber,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'childCredentials.recovery.tileTitle'.tr(
                        namedArgs: {'name': childName},
                      ),
                      style: CredStyle.unb(15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'childCredentials.recovery.tileBody'.tr(),
                      style: CredStyle.pop(13, c: CredStyle.dim),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'childCredentials.recovery.requestedAt'.tr(
                          namedArgs: {'time': schoolStampLabel(createdAt)},
                        ),
                        style: CredStyle.pop(12.5, c: CredStyle.dim),
                      ),
                    ],
                    if (request.channel == RecoveryChannel.school) ...[
                      const SizedBox(height: 8),
                      SchoolPill(
                        label: 'childCredentials.recovery.viaSchool'.tr(),
                        color: CredStyle.blue,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ParvozPrimaryButton(
            label: 'childCredentials.recovery.restore'.tr(),
            onPressed: onRestore,
            enabled: !rejecting,
            height: 50,
            showArrow: false,
          ),
          const SizedBox(height: 10),
          ParvozSecondaryButton(
            label: 'childCredentials.recovery.reject'.tr(),
            onPressed: onReject,
            enabled: !rejecting,
            height: 50,
          ),
        ],
      ),
    );
  }
}

/// So'rovlar yuklanmadi — ekranning qolgan qismi ishlayveradi.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CredCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(
              SolarIconsBold.dangerCircle,
              size: 20,
              color: CredStyle.danger,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'childCredentials.recovery.loadFailed'.tr(),
                style: CredStyle.pop(13, c: CredStyle.dim),
              ),
            ),
            // Bosiladigan joy kamida 48x48 dp, tugma sifatida o'qiladi.
            Semantics(
              container: true,
              button: true,
              onTap: onRetry,
              label: 'common.retry'.tr(),
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('recovery-retry'),
                onTap: onRetry,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'common.retry'.tr(),
                    style: CredStyle.pop(14, w: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
