// ─────────────────────────────────────────────────────────────────────
// SchoolEarlyExitsScreen — erta ketish so'rovlari
// ─────────────────────────────────────────────────────────────────────
//
// Ro'yxat (yangisi oldin; maktab xodimi kiritganlari ham — "Maktab
// kiritgan" belgisi bilan), holat: kutilmoqda / tasdiqlandi / rad etildi.
// Pastdagi "Yangi so'rov" — `showEarlyExitSheet` (bog'langan o'quvchi
// bo'lsagina). Pull-to-refresh; push `school_early_exit` shu ekranni ochadi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/utils/tashkent_time.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/providers/school_early_exit_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:farzandim/features/school/presentation/widgets/early_exit_sheet.dart';
import 'package:farzandim/features/school/presentation/widgets/school_status_chip.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF); // oq 60%

/// Tortib yangilashda spinner shundan ortiq aylanmaydi.
const Duration _refreshTimeout = Duration(seconds: 8);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

class SchoolEarlyExitsScreen extends ConsumerStatefulWidget {
  const SchoolEarlyExitsScreen({super.key});

  @override
  ConsumerState<SchoolEarlyExitsScreen> createState() =>
      _SchoolEarlyExitsScreenState();
}

class _SchoolEarlyExitsScreenState
    extends ConsumerState<SchoolEarlyExitsScreen> {
  Future<void> _refresh() async {
    // "Yangi so'rov" tugmasi bog'lanishlar ro'yxatiga bog'liq — u avval
    // yuklanmagan bo'lsa (tarmoq xatosi) shu yerda qayta so'raladi.
    ref
      ..invalidate(schoolEarlyExitsProvider)
      ..invalidate(schoolLinksProvider);
    try {
      await ref.read(schoolEarlyExitsProvider.future).timeout(_refreshTimeout);
    } on TimeoutException {
      // Javob kechikdi — spinner yopiladi, kelganda ro'yxat o'zi yangilanadi.
    } on Object catch (e) {
      // Oldingi ro'yxat ekranda qoladi — sababini qisqa xabar bilan aytamiz.
      if (!mounted) return;
      AppToast.error(context, SchoolFailure.fromError(e).messageKey.tr());
    }
  }

  Future<void> _openSheet(SchoolLinks links) async {
    // Muvaffaqiyatda ro'yxatni amal provayderi o'zi yangilaydi.
    await showEarlyExitSheet(context, links: links);
  }

  @override
  Widget build(BuildContext context) {
    final links = ref.watch(schoolLinksProvider).valueOrNull;
    final async = ref.watch(schoolEarlyExitsProvider);
    final requests = async.valueOrNull;
    final today = tashkentTodayStr();

    final Widget body;
    if (links != null && !links.available) {
      body = SchoolMessageView(
        icon: SolarIconsBold.squareAcademicCap,
        title: 'school.title'.tr(),
        message: 'school.errors.unavailable'.tr(),
      );
    } else if (requests == null) {
      body = async.hasError
          ? SchoolErrorView(
              error: async.error,
              onRetry: () => ref.invalidate(schoolEarlyExitsProvider),
            )
          : const SchoolLoadingView();
    } else {
      body = RefreshIndicator(
        color: _blue,
        backgroundColor: _card,
        onRefresh: _refresh,
        child: requests.isEmpty
            ? SchoolMessageView(
                icon: SolarIconsBold.walking,
                title: 'school.earlyExit.emptyTitle'.tr(),
                message: 'school.earlyExit.emptyBody'.tr(),
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _EarlyExitCard(request: requests[index], today: today),
              ),
      );
    }

    final canRequest =
        links != null && links.available && links.students.isNotEmpty;
    return SchoolScaffold(
      title: 'school.earlyExit.title'.tr(),
      body: body,
      footer: canRequest
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ParvozPrimaryButton(
                label: 'school.earlyExit.new'.tr(),
                onPressed: () => unawaited(_openSheet(links)),
                showArrow: false,
              ),
            )
          : null,
    );
  }
}

/// Bitta so'rov: o'quvchi, holat, vaqt, sabab, kim olib ketadi.
class _EarlyExitCard extends StatelessWidget {
  const _EarlyExitCard({required this.request, required this.today});

  final EarlyExitRequest request;
  final String today;

  @override
  Widget build(BuildContext context) {
    final when = [
      if (request.className.isNotEmpty)
        'school.classLabel'.tr(namedArgs: {'name': request.className}),
      schoolDayTimeLabel(request.date, request.time, today: today),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: request.isPending ? _blue.withValues(alpha: 0.5) : _cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.studentName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(15.5, w: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              SchoolPill(
                label: earlyExitStatusKey(request.status).tr(),
                color: earlyExitStatusColor(request.status),
              ),
            ],
          ),
          Text(when, style: _pop(13, c: _dim)),
          if (request.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(request.reason, style: _pop(14)),
          ],
          if (request.pickupBy.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'school.earlyExit.pickupLine'.tr(
                namedArgs: {'name': request.pickupBy},
              ),
              style: _pop(13, c: _dim),
            ),
          ],
          if (!request.requestedByMe) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  SolarIconsOutline.squareAcademicCap,
                  size: 16,
                  color: _dim,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'school.earlyExit.bySchool'.tr(),
                    style: _pop(12.5, c: _dim),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
