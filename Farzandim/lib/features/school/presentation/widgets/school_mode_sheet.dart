// ─────────────────────────────────────────────────────────────────────
// school_mode_sheet — School Mode eslatmasi bo'yicha yo'l-yo'riq
// ─────────────────────────────────────────────────────────────────────
//
// Push `SCHOOL_MODE_REMIND` → `/school?remind=<studentId>` → maktab sahifasi
// shu oqimni ishga tushiradi (`SchoolModeGuidance`):
//   - o'quvchi farzandga moslanmagan → moslash varag'i; moslangach keyingi
//     qadam (ulash yoki ruxsat) darhol ko'rsatiladi;
//   - bola ilovasi ulanmagan → "Bolani ilovasini ulash" varag'i;
//   - ulangan → izoh (ruxsat bola telefonida yoqiladi: iPhone — Ekran
//     vaqti, Android — Maxsus imkoniyatlar) + bola sozlamalari.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/child_management/presentation/screens/connect_child_sheet.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/school_mode_guidance.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/features/school/presentation/widgets/student_child_match_sheet.dart';
import 'package:farzandim/features/settings/presentation/plan_gate.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _blue = Color(0xFF216BFF);

/// Ilova ochilishida farzandlar ro'yxati kelishini shuncha kutamiz.
const Duration _childrenWait = Duration(seconds: 6);

/// [studentId] uchun kerakli qadamni ochadi. [context] va [ref] — maktab
/// sahifasiniki (varaqlardan keyin navigatsiya shu sahifadan qilinadi).
Future<void> showSchoolModeGuidance(
  BuildContext context,
  WidgetRef ref, {
  required SchoolLinks links,
  required String studentId,
}) async {
  final student = links.students.firstWhereOrNull((s) => s.id == studentId);
  final childId = student?.childId;
  final child = childId == null ? null : await _childFor(ref, childId);
  if (!context.mounted) return;
  switch (SchoolModeGuidance.of(student: student, child: child)) {
    case SchoolModeMissing():
      AppToast.error(context, 'school.errors.studentNotFound'.tr());
    case SchoolModeMatch(:final student):
      await _match(context, ref, links: links, student: student);
    case SchoolModeConnect(:final childId, :final child):
      await showConnectChildSheet(
        context,
        childId: childId,
        initialChild: child,
      );
    case SchoolModePermission(:final child):
      final openSettings = await showSchoolSheet<bool>(
        context,
        builder: (_) => _PermissionSheet(child: child),
      );
      if (openSettings != true || !context.mounted) return;
      await context.push(AppRoutes.childSettingsPath(child.id));
  }
}

/// Moslash varag'i; moslangach (yangi ro'yxat bilan) ulash yoki ruxsat
/// qadami. "Keyinroq" bosilsa — shu yerda to'xtaydi.
Future<void> _match(
  BuildContext context,
  WidgetRef ref, {
  required SchoolLinks links,
  required LinkedStudent student,
}) async {
  final addChild = await showStudentChildMatchSheet(
    context,
    links: links,
    studentIds: [student.id],
  );
  if (!context.mounted) return;
  if (addChild) {
    // Farzand yo'q — avval bola qo'shiladi (tarif limiti ham tekshiriladi).
    guardAddChild(context, ref);
    return;
  }
  final SchoolLinks fresh;
  try {
    fresh = await ref.read(schoolLinksProvider.future);
  } on Object catch (e) {
    // Ro'yxat kelmadi — keyingi qadam keyingi eslatmada.
    debugPrint('[school] mode guidance reload: $e');
    return;
  }
  if (!context.mounted) return;
  final matched = fresh.students.firstWhereOrNull((s) => s.id == student.id);
  if (matched?.childId == null) return;
  await showSchoolModeGuidance(
    context,
    ref,
    links: fresh,
    studentId: student.id,
  );
}

/// Farzand ilovadagi ro'yxatdan; ro'yxat hali kelmagan bo'lsa (push ilovani
/// ochgan) — qisqa kutiladi.
Future<Child?> _childFor(WidgetRef ref, String childId) async {
  final known = ref.read(childByIdProvider(childId));
  if (known != null) return known;
  try {
    final children = await ref
        .read(childrenProvider.future)
        .timeout(_childrenWait);
    return children.firstWhereOrNull((c) => c.id == childId);
  } on Object catch (e) {
    debugPrint('[school] mode guidance children: $e');
    return null;
  }
}

/// Ruxsat izohi: bola telefonida Parvoz ruxsatini yoqish. `true` — bola
/// sozlamalarini ochish.
class _PermissionSheet extends StatelessWidget {
  const _PermissionSheet({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    final args = {'child': child.name};
    final body = child.isIosDevice
        ? 'school.mode.permissionBodyIos'.tr(namedArgs: args)
        : 'school.mode.permissionBodyAndroid'.tr(namedArgs: args);
    return SchoolSheetFrame(
      title: 'school.mode.permissionTitle'.tr(),
      subtitle: child.name,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _blue,
              boxShadow: [
                BoxShadow(
                  color: ParvozColors.glow.withValues(alpha: 0.4),
                  blurRadius: 28,
                ),
              ],
            ),
            child: const Icon(
              SolarIconsBold.smartphone,
              size: 34,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          body,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14.5,
            color: Colors.white,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        SchoolNote(
          icon: SolarIconsBold.infoCircle,
          text: 'school.mode.permissionHint'.tr(),
        ),
        const SizedBox(height: 22),
        ParvozPrimaryButton(
          label: 'school.mode.openSettings'.tr(),
          onPressed: () => Navigator.of(context).pop(true),
          showArrow: false,
        ),
        const SizedBox(height: 4),
        SchoolTextButton(
          label: 'school.mode.gotIt'.tr(),
          onTap: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
