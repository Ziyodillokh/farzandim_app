// ─────────────────────────────────────────────────────────────────────
// SchoolPaymentsScreen — to'lov eslatmalari va tekshiruv so'rovlari
// ─────────────────────────────────────────────────────────────────────
//
// Eslatma kartalari (keyingi sana, oldindan to'langan oylar,
// to'xtatilganligi, o'quvchilar) — summa ataylab yo'q. "To'laganman,
// tekshiring" → `showVerificationSheet` (ochiq so'rov bo'lsa o'chiq).
// Pastda so'rovlar tarixi: holat va maktab javobi. Push'dan
// (`SCHOOL_VERIFICATION_ANSWERED`): `?verification=<id>` — o'sha so'rov
// ko'k hoshiyada va unga aylantiriladi. Pull-to-refresh.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/providers/school_payment_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/payment_cards.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/features/school/presentation/widgets/verification_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF1A1F23);
const _blue = Color(0xFF216BFF);

/// Tortib yangilashda spinner shundan ortiq aylanmaydi.
const Duration _refreshTimeout = Duration(seconds: 8);

TextStyle _unb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: -0.4,
  height: 1.3,
);

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
      body = RefreshIndicator(
        color: _blue,
        backgroundColor: _card,
        onRefresh: _refresh,
        child: nothing
            ? SchoolMessageView(
                icon: SolarIconsBold.billList,
                title: 'school.payments.emptyTitle'.tr(),
                message: 'school.payments.emptyBody'.tr(),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                children: [
                  for (final reminder in payments) ...[
                    PaymentReminderCard(
                      reminder: reminder,
                      school: _schoolOf(links, reminder.schoolId),
                      onVerify: () => unawaited(_verify(reminder)),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (payments.isNotEmpty)
                    SchoolNote(
                      icon: SolarIconsBold.infoCircle,
                      text: 'school.payments.note'.tr(),
                    ),
                  ..._history(verificationsAsync),
                ],
              ),
      );
    }
    return SchoolScaffold(title: 'school.payments.title'.tr(), body: body);
  }

  /// So'rovlar tarixi bo'limi: yuklanmoqda / xato / kartalar.
  List<Widget> _history(AsyncValue<List<PaymentVerification>> async) {
    final verifications = async.valueOrNull;
    if (verifications == null) {
      if (!async.hasError) {
        return const [
          SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: _blue),
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
    if (verifications.isEmpty) return const [];
    final focus = widget.focusVerificationId;
    if (verifications.any((v) => v.id == focus)) _scrollToFocus();
    return [
      const SizedBox(height: 22),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('school.verifications.title'.tr(), style: _unb(15)),
      ),
      const SizedBox(height: 10),
      for (final verification in verifications) ...[
        VerificationCard(
          key: verification.id == focus ? _focusKey : ValueKey(verification.id),
          verification: verification,
          highlighted: verification.id == focus,
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  static SchoolInfo? _schoolOf(SchoolLinks? links, String schoolId) => links
      ?.links
      .firstWhereOrNull((link) => link.school.id == schoolId)
      ?.school;
}
