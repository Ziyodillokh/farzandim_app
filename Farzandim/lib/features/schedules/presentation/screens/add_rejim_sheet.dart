// ─────────────────────────────────────────────────────────────────────
// AddRejimSheet — "Rejim qo'shish" (Parvoz, tortiladigan sheet)
// ─────────────────────────────────────────────────────────────────────
//
// "Rejimlar" varag'idagi "Rejim qo'shish" bosilganda ochiladi. Forma:
// rejim nomi + vaqt (dan / gacha). Vaqt maydoni bosilsa g'ildirakli
// "Vaqt belgilash" tanlagich (soat / daqiqa / AM-PM) ochiladi.
//
// Ma'lumot: `scheduleActionsProvider.addSchedule` (type = custom, har kuni).
// Mock rejimda backendga bormasdan yopiladi (UI preview).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/schedules/data/models/schedule.dart';
import 'package:farzandim/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _field = Color(0xFF12171E);
const _chipBg = Color(0xFF1B2128);
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _dim = Color(0x8CFFFFFF); // oq 55%
const _placeholder = Color(0x59FFFFFF); // oq 35%

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.3,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.25,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.4);

String _fmt(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// "Rejim qo'shish"ni modal sheet sifatida ochadi.
void showAddRejimSheet(BuildContext context, {required String childId}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _AddRejimSheet(childId: childId),
  );
}

class _AddRejimSheet extends ConsumerStatefulWidget {
  const _AddRejimSheet({required this.childId});

  final String childId;

  @override
  ConsumerState<_AddRejimSheet> createState() => _AddRejimSheetState();
}

class _AddRejimSheetState extends ConsumerState<_AddRejimSheet> {
  final _nameController = TextEditingController();
  TimeOfDay? _from;
  TimeOfDay? _to;
  bool _saving = false;

  bool get _valid =>
      _nameController.text.trim().isNotEmpty && _from != null && _to != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool isFrom}) async {
    final initial =
        (isFrom ? _from : _to) ??
        (isFrom
            ? const TimeOfDay(hour: 20, minute: 0)
            : const TimeOfDay(hour: 7, minute: 0));
    final picked = await showTimeWheel(context, initial: initial);
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _onSave() async {
    if (!_valid || _saving) return;
    final name = _nameController.text.trim();
    setState(() => _saving = true);
    final result = await ref
        .read(scheduleActionsProvider.notifier)
        .addSchedule(
          childId: widget.childId,
          title: name,
          type: ScheduleType.custom,
          weekdays: Weekday.values,
          startHour: _from!.hour,
          startMinute: _from!.minute,
          endHour: _to!.hour,
          endMinute: _to!.minute,
          reminderMinutes: 10,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      Navigator.of(context).pop();
      AppToast.success(context, 'rejimlar.saved'.tr());
    } else {
      AppToast.error(context, result.error ?? 'rejimlar.saved'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: ColoredBox(
          color: _bg,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: _DragHandle()),
                  const SizedBox(height: 14),
                  // Header: orqaga + sarlavha (markazda).
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: SolarIconsOutline.arrowLeft,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Text(
                          'rejimlar.addSchedule'.tr(),
                          textAlign: TextAlign.center,
                          style: _unb(18, w: FontWeight.w700, ls: -0.4),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 22),
                  // Rejim nomi.
                  Text('rejimlar.nameLabel'.tr(), style: _pop(14)),
                  const SizedBox(height: 10),
                  _NameField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  // Rejim vaqti (dan / gacha).
                  Text('rejimlar.timeLabel'.tr(), style: _pop(14)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          hint: 'rejimlar.from'.tr(),
                          value: _from == null ? null : _fmt(_from!),
                          onTap: () => _pick(isFrom: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeField(
                          hint: 'rejimlar.to'.tr(),
                          value: _to == null ? null : _fmt(_to!),
                          onTap: () => _pick(isFrom: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _SaveButton(
                    enabled: _valid,
                    loading: _saving,
                    onTap: _onSave,
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

// ════════════ Vaqt g'ildiragi ("Vaqt belgilash") ════════════

/// G'ildirakli vaqt tanlagichni ochadi va tanlangan `TimeOfDay`ni qaytaradi.
Future<TimeOfDay?> showTimeWheel(
  BuildContext context, {
  required TimeOfDay initial,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _TimeWheelSheet(initial: initial),
  );
}

class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.initial});

  final TimeOfDay initial;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  late int _hour12; // 1..12
  late int _minute; // 0..59
  late bool _pm;

  late final FixedExtentScrollController _hCtrl;
  late final FixedExtentScrollController _mCtrl;
  late final FixedExtentScrollController _aCtrl;

  @override
  void initState() {
    super.initState();
    final h = widget.initial.hour;
    _pm = h >= 12;
    _hour12 = h % 12 == 0 ? 12 : h % 12;
    _minute = widget.initial.minute;
    _hCtrl = FixedExtentScrollController(initialItem: _hour12 - 1);
    _mCtrl = FixedExtentScrollController(initialItem: _minute);
    _aCtrl = FixedExtentScrollController(initialItem: _pm ? 1 : 0);
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _mCtrl.dispose();
    _aCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    // 12h → 24h.
    var h = _hour12 % 12; // 12 → 0
    if (_pm) h += 12; // PM → +12 (12PM = 12, 12AM = 0)
    Navigator.of(context).pop(TimeOfDay(hour: h, minute: _minute));
  }

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
              children: [
                const Center(child: _DragHandle()),
                const SizedBox(height: 16),
                Text(
                  'rejimlar.timePickerTitle'.tr(),
                  style: _unb(18, w: FontWeight.w700, ls: -0.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Markaziy tanlov polosasi.
                      Center(
                        child: Container(
                          height: 46,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _fieldBorder),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _WheelCol(
                              controller: _hCtrl,
                              count: 12,
                              label: (i) => '${i + 1}',
                              onChanged: (v) => _hour12 = v + 1,
                            ),
                          ),
                          Expanded(
                            child: _WheelCol(
                              controller: _mCtrl,
                              count: 60,
                              label: (i) => i.toString().padLeft(2, '0'),
                              onChanged: (v) => _minute = v,
                            ),
                          ),
                          Expanded(
                            child: _WheelCol(
                              controller: _aCtrl,
                              count: 2,
                              label: (i) => i == 0 ? 'AM' : 'PM',
                              onChanged: (v) => _pm = v == 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SaveButton(enabled: true, loading: false, onTap: _confirm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bitta g'ildirak ustuni (soat / daqiqa / AM-PM).
class _WheelCol extends StatelessWidget {
  const _WheelCol({
    required this.controller,
    required this.count,
    required this.label,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int count;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 46,
      perspective: 0.004,
      diameterRatio: 1.7,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, i) => Center(
          child: Text(label(i), style: _pop(24, w: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ════════════ Umumiy widgetlar ════════════

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _fieldBorder),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: _blue,
        style: _pop(15),
        decoration: InputDecoration(
          // Global teal fill/border'ni o'chiramiz.
          filled: false,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: 'rejimlar.nameHint'.tr(),
          hintStyle: _pop(15, c: _placeholder),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.hint,
    required this.value,
    required this.onTap,
  });

  final String hint;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: _field,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _fieldBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                has ? value! : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _pop(15, c: has ? Colors.white : _placeholder),
              ),
            ),
            const Icon(SolarIconsOutline.clockCircle, size: 20, color: _dim),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: canTap ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'rejimlar.save'.tr(),
                  style: _pop(16, w: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}
