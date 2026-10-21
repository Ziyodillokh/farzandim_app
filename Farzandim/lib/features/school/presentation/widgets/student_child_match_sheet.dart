// ─────────────────────────────────────────────────────────────────────
// StudentChildMatchSheet — maktab o'quvchisi ↔ ilovadagi farzand
// ─────────────────────────────────────────────────────────────────────
//
// Taklif kodi kiritilgach (moslanmagan o'quvchilar uchun), dashboard
// kartasidan va maktab sahifasidan ochiladi. Bir nechta o'quvchi bo'lsa —
// ketma-ket ("1 / 2").
//   - NONE: farzand tanlanadi ("Saqlash") yoki "Keyinroq";
//   - ME: joriy farzand belgilangan — boshqasiga almashtirish yoki
//     "Hech biri" bilan moslashni olib tashlash;
//   - OTHER: faqat o'qish uchun (oilaning boshqa a'zosi moslagan);
//   - farzand yo'q: "Farzand qo'shish" — varaq `true` qaytaradi va bola
//     qo'shish ekranini chaqiruvchi ochadi.
// Farzandlar — ilovadagi ro'yxat (endigina qo'shilgani ham) + maktab
// javobidagilar. Xatodan keyin ro'yxat qayta o'qiladi: eskirgan bo'lishi
// mumkin (o'quvchini boshqa a'zo moslagan, aloqa uzilgan).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

part 'student_child_match_parts.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF0B1016);
const _blue = Color(0xFF216BFF);
const _dim = Color(0x8CFFFFFF); // oq 55%
const _optionBg = Color(0x0FFFFFFF); // oq 6%
const _optionBorder = Color(0x1AFFFFFF); // oq 10%
const _chipBg = Color(0xFF1B2128);

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: -0.4,
  height: 1.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Moslash varag'ini ochadi. [studentIds] — ko'rsatiladigan o'quvchilar
/// (tartib bilan); [links] da yo'qlari tashlanadi. Varaq yopilganda tugaydi.
///
/// `true` — farzand yo'q va ota-ona "Farzand qo'shish"ni bosdi: bola
/// qo'shish ekranini CHAQIRUVCHI ochadi (o'z navigatsiyasi bilan
/// to'qnashmasin — masalan taklif kodi sahifasi o'zini yopadi).
Future<bool> showStudentChildMatchSheet(
  BuildContext context, {
  required SchoolLinks links,
  required List<String> studentIds,
}) async {
  final known = {for (final student in links.students) student.id};
  final ids = List<String>.unmodifiable(studentIds.where(known.contains));
  if (ids.isEmpty) return false;
  final addChild = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _MatchSheet(links: links, studentIds: ids),
  );
  return addChild ?? false;
}

/// Varaqdagi tanlov; `childId: null` — "hech biri" (moslashni olib tashlash).
@immutable
class _Choice {
  const _Choice(this.childId);

  final String? childId;

  @override
  bool operator ==(Object other) =>
      other is _Choice && other.childId == childId;

  @override
  int get hashCode => childId.hashCode;
}

class _MatchSheet extends ConsumerStatefulWidget {
  const _MatchSheet({required this.links, required this.studentIds});

  final SchoolLinks links;
  final List<String> studentIds;

  @override
  ConsumerState<_MatchSheet> createState() => _MatchSheetState();
}

class _MatchSheetState extends ConsumerState<_MatchSheet> {
  late SchoolLinks _links = widget.links;
  int _index = 0;
  _Choice? _choice;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _choice = _initialChoice(_studentAt(0));
  }

  LinkedStudent? _studentAt(int index) {
    if (index >= widget.studentIds.length) return null;
    final id = widget.studentIds[index];
    return _links.students.firstWhereOrNull((s) => s.id == id);
  }

  /// Moslangan (ME) o'quvchida joriy farzand oldindan belgilanadi.
  static _Choice? _initialChoice(LinkedStudent? student) {
    final childId = student?.childId;
    return childId == null ? null : _Choice(childId);
  }

  /// Ro'yxatda hali bor keyingi o'quvchi indeksi (yo'q → `null`).
  int? get _nextIndex {
    for (var i = _index + 1; i < widget.studentIds.length; i++) {
      if (_studentAt(i) != null) return i;
    }
    return null;
  }

  /// Keyingi o'quvchiga o'tadi; qolmasa varaq yopiladi.
  void _advance() {
    final next = _nextIndex;
    if (next == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index = next;
      _choice = _initialChoice(_studentAt(next));
    });
  }

  Future<void> _save(LinkedStudent student) async {
    final choice = _choice;
    if (choice == null || _saving) return;
    if (choice.childId == student.childId) {
      _advance();
      return;
    }
    setState(() => _saving = true);
    final result = await ref
        .read(schoolActionsProvider.notifier)
        .setChild(studentId: student.id, childId: choice.childId);
    if (!mounted) return;
    setState(() => _saving = false);
    final fresh = result.data;
    if (fresh == null) {
      AppToast.error(context, result.error ?? 'errors.generic'.tr());
      await _reload();
      return;
    }
    AppToast.success(
      context,
      choice.childId == null
          ? 'school.match.removed'.tr()
          : 'school.match.saved'.tr(),
    );
    _links = fresh;
    _advance();
  }

  /// Xatodan keyin ro'yxat eskirgan bo'lishi mumkin — yangisini o'qiymiz.
  /// O'quvchi endi yo'q bo'lsa keyingisiga o'tiladi.
  Future<void> _reload() async {
    try {
      final fresh = await ref.read(schoolLinksProvider.future);
      if (!mounted) return;
      _links = fresh;
      final student = _studentAt(_index);
      if (student == null) {
        _advance();
        return;
      }
      setState(() => _choice = _initialChoice(student));
    } on Object catch (e) {
      // Xato foydalanuvchiga toast bilan ko'rsatilgan; eski ro'yxat qoladi.
      debugPrint('[school] match reload: $e');
    }
  }

  /// Farzand yo'q — varaq `true` bilan yopiladi (bola qo'shishni
  /// chaqiruvchi ochadi).
  void _addChild() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    final student = _studentAt(_index);
    if (student == null) return const SizedBox.shrink();
    final appChildren = ref.watch(childrenListProvider);
    final options = mergeMatchChildren([
      for (final child in appChildren) ChildRef(id: child.id, name: child.name),
    ], _links.children);
    final total = widget.studentIds.length;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: ColoredBox(
        color: _bg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Handle(),
                const SizedBox(height: 16),
                if (total > 1) ...[
                  Text(
                    'school.match.progress'.tr(
                      namedArgs: {
                        'current': '${_index + 1}',
                        'total': '$total',
                      },
                    ),
                    textAlign: TextAlign.center,
                    style: _pop(13, c: _dim),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  'school.match.title'.tr(
                    namedArgs: {'student': student.fullName},
                  ),
                  textAlign: TextAlign.center,
                  style: _unb(18),
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitle(student),
                  textAlign: TextAlign.center,
                  style: _pop(13, c: _dim),
                ),
                const SizedBox(height: 18),
                ..._body(student, options),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Maktab nomi · 7-A sinf".
  String _subtitle(LinkedStudent student) {
    final school = _links.linkOfStudent(student.id)?.school.displayName;
    return [
      if (school != null && school.isNotEmpty) school,
      if (student.className.isNotEmpty)
        'school.classLabel'.tr(namedArgs: {'name': student.className}),
    ].join(' · ');
  }

  List<Widget> _body(LinkedStudent student, List<ChildRef> options) {
    if (student.isMatchedByOther) {
      return [
        _InfoBox(
          icon: SolarIconsBold.usersGroupRounded,
          text: 'school.match.linkedByOther'.tr(),
        ),
        const SizedBox(height: 20),
        ParvozSecondaryButton(
          label: _nextIndex == null ? 'common.close'.tr() : 'common.next'.tr(),
          onPressed: _advance,
        ),
      ];
    }
    if (options.isEmpty) {
      return [
        _InfoBox(
          icon: SolarIconsBold.userPlus,
          text: 'school.match.noChildren'.tr(),
        ),
        const SizedBox(height: 20),
        ParvozPrimaryButton(
          label: 'school.match.addChild'.tr(),
          onPressed: _addChild,
          showArrow: false,
        ),
        const SizedBox(height: 4),
        _LaterButton(onTap: _advance),
      ];
    }
    final elsewhere = studentsByOtherChild(_links, student.id);
    final choice = _choice;
    return [
      Text(
        'school.match.explain'.tr(),
        textAlign: TextAlign.center,
        style: _pop(13.5, c: _dim),
      ),
      const SizedBox(height: 14),
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final child in options) ...[
                _Option(
                  leading: _ChildBadge(childId: child.id, name: child.name),
                  title: child.name,
                  hint: _hintFor(elsewhere[child.id]),
                  selected: choice == _Choice(child.id),
                  onTap: _saving
                      ? null
                      : () => setState(() => _choice = _Choice(child.id)),
                ),
                const SizedBox(height: 8),
              ],
              // Moslashni olib tashlash — faqat allaqachon moslanganda.
              if (student.isMatchedToMine)
                _Option(
                  leading: const _NoneBadge(),
                  title: 'school.match.none'.tr(),
                  selected: choice == const _Choice(null),
                  onTap: _saving
                      ? null
                      : () => setState(() => _choice = const _Choice(null)),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      ParvozPrimaryButton(
        label: 'school.match.save'.tr(),
        onPressed: () => _save(student),
        enabled: choice != null && choice != _initialChoice(student),
        loading: _saving,
        showArrow: false,
      ),
      const SizedBox(height: 4),
      _LaterButton(onTap: _saving ? null : _advance),
    ];
  }

  /// "Hozir: Karimov Aziz" — farzand boshqa o'quvchiga moslangan bo'lsa.
  static String? _hintFor(LinkedStudent? other) => other == null
      ? null
      : 'school.match.currentlyWith'.tr(namedArgs: {'student': other.fullName});
}
