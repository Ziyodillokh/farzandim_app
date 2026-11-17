// ─────────────────────────────────────────────────────────────────────
// SchoolPaymentsScreen — to'lov eslatmalari va tekshiruv so'rovlari
// ─────────────────────────────────────────────────────────────────────
//
// Har eslatma — holat kartasi: keyingi sana, necha kun qolgani / bugun /
// o'tgani, oldindan to'langan oylar, to'xtatilganlik, farzandlar. Amallar:
// "To'laganman, tekshiring" (tuzilgan shakl; ochiq so'rov bo'lsa
// "tekshirilmoqda") va ma'muriyatga savol. Pastda — maktab amallari va
// so'rovlar bitta tarixda. Summa yoki qarz ataylab YO'Q. Push'dan
// (`SCHOOL_VERIFICATION_ANSWERED`): `?verification=<id>` — o'sha so'rov
// ajratiladi va unga aylantiriladi. Pull-to-refresh.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/payment_view_models.dart';
import 'package:farzandim/features/school/presentation/providers/school_payment_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/compose_launcher.dart';
import 'package:farzandim/features/school/presentation/widgets/payment_cards.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/features/school/presentation/widgets/verification_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// Tortib yangilashda spinner shundan ortiq aylanmaydi.
const Duration _refreshTimeout = Duration(seconds: 8);

class SchoolPaymentsScreen extends ConsumerStatefulWidget {
  const SchoolPaymentsScreen({this.focusVerificationId, super.key});

  /// Push'dagi so'rov (`?verification=`) — ajratib ko'rsatiladi.
  final String? focusVerificationId;

  @override
  ConsumerState<SchoolPaymentsScreen> createState() =>
      _SchoolPaymentsScreenState();
}

class _SchoolPaymentsScreenState extends ConsumerState<SchoolPaymentsScreen> {
  final _focusKey = GlobalKey();
  bool _focusScrolled = false;

  Future<void> _refresh() async {
    ref
      ..invalidate(schoolPaymentsProvider)
      ..invalidate(schoolVerificationsProvider);
    try {
      await Future.wait([
        ref.read(schoolPaymentsProvider.future),
        ref.read(schoolVerificationsProvider.future),
      ]).timeout(_refreshTimeout);
    } on TimeoutException {
      // Javob kechikdi — spinner yopiladi, kelganda ro'yxat o'zi yangilanadi.
    } on Object catch (e) {
      // Oldingi ro'yxat ekranda qoladi — sababini qisqa xabar bilan aytamiz.
      if (!mounted) return;
      AppToast.error(context, SchoolFailure.fromError(e).messageKey.tr());
    }
  }

  void _retry() {
    ref
      ..invalidate(schoolPaymentsProvider)
      ..invalidate(schoolVerificationsProvider);
  }

  Future<void> _verify(SchoolPaymentReminder reminder) async {
    if (reminder.openVerification) return;
    // Muvaffaqiyatda ro'yxatlarni amal provayderi o'zi yangilaydi.
    await showVerificationSheet(context, reminder: reminder);
  }

  void _ask(SchoolPaymentReminder reminder) {
    final studentId = reminder.children.firstOrNull?.id;
    if (studentId == null) return;
    unawaited(
      composeTo(
        context,
        ref,
        studentId: studentId,
        target: ContactTarget.administration,
        topic: ContactTopic.payment,
        prefill: 'school.payments.askAdminPrefill'.tr(),
      ),
    );
  }

  /// Push'dagi so'rovga bir marta aylantirish (karta chizilgach).
  void _scrollToFocus() {
    if (_focusScrolled) return;
    _focusScrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _focusKey.currentContext;
      if (target == null || !target.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: 0.1,
          duration: const Duration(milliseconds: 300),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final links = ref.watch(schoolLinksProvider).valueOrNull;
    final paymentsAsync = ref.watch(schoolPaymentsProvider);
    final verificationsAsync = ref.watch(schoolVerificationsProvider);
    final payments = paymentsAsync.valueOrNull;
    final verifications = verificationsAsync.valueOrNull;

    final Widget body;
    if (links != null && !links.available) {
      body = SchoolMessageView(
        icon: SolarIconsBold.squareAcademicCap,
        title: 'school.title'.tr(),
        message: 'school.errors.unavailable'.tr(),
      );
    } else if (payments == null) {
      body = paymentsAsync.hasError
          ? SchoolErrorView(error: paymentsAsync.error, onRetry: _retry)
          : const SchoolLoadingView();
    } else {
      final nothing = payments.isEmpty && (verifications?.isEmpty ?? false);
      final today = DateTime.now();
      body = RefreshIndicator(
        color: SK.blue,
        backgroundColor: SK.card,
        onRefresh: _refresh,
        child: nothing
            ? SchoolMessageView(
                icon: SolarIconsBold.billList,
                title: 'school.payments.emptyTitle'.tr(),
                message: 'school.payments.emptyBody'.tr(),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                children: [
                  for (final reminder in payments) ...[
                    PaymentStatusCard(
                      reminder: reminder,
                      status: paymentStatusOf(reminder, today),
                      school: _schoolOf(links, reminder.schoolId),
                      onVerify: () => unawaited(_verify(reminder)),
                      onAsk: reminder.children.isEmpty
                          ? null
                          : () => _ask(reminder),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (payments.isNotEmpty)
                    SchoolNote(
                      icon: SolarIconsBold.shieldCheck,
                      text: 'school.payments.info'.tr(),
                    ),
                  ..._history(payments, verificationsAsync),
                ],
              ),
      );
    }
    return SchoolScaffold(title: 'school.payments.title'.tr(), body: body);
  }

  /// Tarix bo'limi: yuklanmoqda / xato / lenta.
  List<Widget> _history(
    List<SchoolPaymentReminder> payments,
    AsyncValue<List<PaymentVerification>> async,
  ) {
    final verifications = async.valueOrNull;
    if (verifications == null) {
      if (!async.hasError) {
        return const [
          SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: SK.blue,
              ),
            ),
          ),
        ];
      }
      return [
        const SizedBox(height: 20),
        SchoolInlineError(
          message: SchoolFailure.fromError(
            async.error ?? const SchoolFailure(SchoolFailureKind.unknown),
          ).messageKey.tr(),
        ),
        const SizedBox(height: 10),
        ParvozSecondaryButton(
          label: 'common.retry'.tr(),
          onPressed: () => ref.invalidate(schoolVerificationsProvider),
        ),
      ];
    }
    final events = paymentTimeline(payments, verifications);
    final focus = widget.focusVerificationId;
    if (focus != null && events.any((e) => e.verificationId == focus)) {
      _scrollToFocus();
    }
    return [
      SkSectionLabel('school.payments.history'.tr()),
      PaymentTimeline(
        events: events,
        focusVerificationId: focus,
        focusKey: _focusKey,
      ),
    ];
  }

  static SchoolInfo? _schoolOf(SchoolLinks? links, String schoolId) => links
      ?.links
      .firstWhereOrNull((link) => link.school.id == schoolId)
      ?.school;
}
