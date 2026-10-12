// ─────────────────────────────────────────────────────────────────────
// RoutineAppsEditor — rejimning bloklanadigan ilovalarini tahrirlash
// ─────────────────────────────────────────────────────────────────────
//
// Platformaga qarab ikki xil tahrirlagich:
//   • Android bola → ilovalar ro'yxatidan tanlash (`showRoutineAppPicker`);
//   • iPhone bola  → bitta kalit: "Shu vaqtda iPhone ilovalarini bloklash".
//     iPhone haqiqiy ilovalar ro'yxatini yubormaydi, shuning uchun rejim
//     `blockedApps`'i faqat virtual `kIosSelectionPackage` yoki bo'sh bo'ladi
//     (bola iPhone'da o'zi tanlagan ilovalar bloklanadi).
//
// Natija har doim shu rejimning `blockedApps` ro'yxati — GLOBAL (24/7)
// bloklash yozilmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/schedules/data/models/ios_routine_rules.dart';
import 'package:farzandim/features/schedules/data/models/schedule.dart';
import 'package:farzandim/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim/features/schedules/presentation/widgets/routine_app_picker.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Parvoz tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _field = Color(0xFF12171E);
const _green = Color(0xFF34C759);
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _dim = Color(0x8CFFFFFF); // oq 55%

TextStyle _unb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w700,
  color: Colors.white,
  letterSpacing: -0.4,
  height: 1.25,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.4);

/// iPhone rejimi uchun kalit: "Shu vaqtda iPhone ilovalarini bloklash".
///
/// "Rejim qo'shish" formasida ham, "Sozlash" varag'ida ham bir xil ishlatiladi.
class IosRoutineBlockSwitch extends StatelessWidget {
  /// `IosRoutineBlockSwitch` konstruktor.
  const IosRoutineBlockSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Bloklash yoqilganmi.
  final bool value;

  /// Kalit o'zgarganda chaqiriladi.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'rejimlar.iosBlockSwitch'.tr(),
                  style: _pop(15, w: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text('rejimlar.iosBlockHint'.tr(), style: _pop(12.5, c: _dim)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppSwitch(value: value, onChanged: onChanged, activeColor: _green),
        ],
      ),
    );
  }
}

/// iPhone rejimi ilovalari varag'ini ochadi. Saqlansa yangi `blockedApps`
/// (`[kIosSelectionPackage]` yoki `[]`), aks holda `null`.
Future<List<String>?> showIosRoutineAppsSheet(
  BuildContext context, {
  required List<String> initial,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) =>
        _IosRoutineAppsSheet(initialBlock: routineBlocksIosApps(initial)),
  );
}

class _IosRoutineAppsSheet extends StatefulWidget {
  const _IosRoutineAppsSheet({required this.initialBlock});

  final bool initialBlock;

  @override
  State<_IosRoutineAppsSheet> createState() => _IosRoutineAppsSheetState();
}

class _IosRoutineAppsSheetState extends State<_IosRoutineAppsSheet> {
  late bool _block = widget.initialBlock;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ColoredBox(
        color: _bg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'rejimlar.iosSheetTitle'.tr(),
                  textAlign: TextAlign.center,
                  style: _unb(18),
                ),
                const SizedBox(height: 20),
                IosRoutineBlockSwitch(
                  value: _block,
                  onChanged: (v) => setState(() => _block = v),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                  ).pop(iosRoutineBlockedApps(block: _block)),
                  behavior: HitTestBehavior.opaque,
                  child: ParvozGlass(
                    blue: true,
                    child: Text(
                      'rejimlar.save'.tr(),
                      style: _pop(16, w: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Platformaga mos tahrirlagichni ochadi: iPhone → kalit varag'i, Android →
/// ilovalar tanlagichi. Saqlanmasdan yopilsa `null`.
Future<List<String>?> showRoutineAppsEditor(
  BuildContext context, {
  required String childId,
  required bool isIos,
  required List<String> initial,
}) {
  if (isIos) return showIosRoutineAppsSheet(context, initial: initial);
  return showRoutineAppPicker(context, childId: childId, initial: initial);
}

/// Rejimning bloklanadigan ilovalarini tahrirlaydi va BACKENDga saqlaydi
/// (shu rejimning `blockedApps`'i; global bloklash emas). Natija toast bilan
/// xabar qilinadi.
///
/// iPhone'da bloklash yoqilsa rejim oynasi [kIosMinRoutineWindowMinutes]
/// daqiqadan qisqa bo'lmasligi shart — aks holda iOS uni e'tiborsiz qoldiradi,
/// shuning uchun saqlanmaydi va aniq xato ko'rsatiladi.
Future<void> editRoutineApps(
  BuildContext context,
  WidgetRef ref, {
  required String childId,
  required Schedule schedule,
  required bool isIos,
}) async {
  final result = await showRoutineAppsEditor(
    context,
    childId: childId,
    isIos: isIos,
    initial: schedule.blockedApps,
  );
  if (result == null || !context.mounted) return;

  final tooShort =
      isIos &&
      routineBlocksIosApps(result) &&
      !isRoutineWindowValidForIos(
        startHour: schedule.startHour,
        startMinute: schedule.startMinute,
        endHour: schedule.endHour,
        endMinute: schedule.endMinute,
      );
  if (tooShort) {
    AppToast.error(context, 'rejimlar.iosMinWindow'.tr());
    return;
  }

  final saved = await ref
      .read(scheduleActionsProvider.notifier)
      .updateSchedule(
        childId: childId,
        scheduleId: schedule.id,
        current: schedule,
        blockedApps: result,
      );
  if (!context.mounted) return;
  if (saved.isSuccess) {
    AppToast.success(context, 'rejimlar.updated'.tr());
  } else {
    AppToast.error(context, 'errors.generic'.tr());
  }
}
