// ─────────────────────────────────────────────────────────────────────
// LearningProfileSheet — bolaning sinfi va kunlik testlar fanlari
// ─────────────────────────────────────────────────────────────────────
//
// Avval sinf (1–11), keyin shu sinfda o'qitiladigan fanlardan 1–5 tasi.
// Sinf o'zgarsa mos kelmaydigan fanlar o'zi olib tashlanadi. Saqlash
// `growthActionsProvider.saveProfile` orqali; xato varaq ichida.
// Uslub maktab varaqlari bilan bir xil (`school_sheet.dart`).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/growth/data/models/learning_profile.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/growth/presentation/growth_view_models.dart';
import 'package:farzandim/features/growth/presentation/providers/growth_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/school_form_fields.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _blue = Color(0xFF216BFF);
const _dim = Color(0x8CFFFFFF); // oq 55%
const _optionBg = Color(0x0FFFFFFF); // oq 6%
const _optionBorder = Color(0x1AFFFFFF); // oq 10%

/// Sinf tugmasi o'lchami.
const double _gradeSize = 48;

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.4);

/// Varaqni ochadi. `true` — profil saqlandi.
Future<bool> showLearningProfileSheet(
  BuildContext context, {
  required String childId,
  LearningProfile? initial,
}) async {
  final saved = await showSchoolSheet<bool>(
    context,
    builder: (_) => _LearningProfileSheet(childId: childId, initial: initial),
  );
  return saved ?? false;
}

class _LearningProfileSheet extends ConsumerStatefulWidget {
  const _LearningProfileSheet({required this.childId, this.initial});

  final String childId;
  final LearningProfile? initial;

  @override
  ConsumerState<_LearningProfileSheet> createState() =>
      _LearningProfileSheetState();
}

class _LearningProfileSheetState extends ConsumerState<_LearningProfileSheet> {
  late LearningProfileDraft _draft = LearningProfileDraft.from(widget.initial);
  bool _saving = false;
  String? _error;

  void _update(LearningProfileDraft next) => setState(() {
    _draft = next;
    _error = null;
  });

  Future<void> _save() async {
    final profile = _draft.toProfile();
    if (_saving || profile == null) return;
    if (_draft.sameAs(widget.initial)) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(growthActionsProvider.notifier)
        .saveProfile(widget.childId, profile);
    if (!mounted) return;
    if (result.isSuccess) {
      AppToast.success(context, 'growth.profile.saved'.tr());
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = result.error ?? 'errors.generic'.tr();
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final grade = _draft.grade;
    return SchoolSheetFrame(
      title: 'growth.profile.title'.tr(),
      subtitle: 'growth.profile.subtitle'.tr(),
      children: [
        SchoolFieldLabel('growth.profile.grade'.tr()),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var g = kMinLearningGrade; g <= kMaxLearningGrade; g++)
              _GradeButton(
                grade: g,
                selected: g == grade,
                onTap: _saving ? null : () => _update(_draft.withGrade(g)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: SchoolFieldLabel('growth.profile.subjects'.tr())),
            if (grade != null)
              Text(
                'growth.profile.subjectsCount'.tr(
                  namedArgs: {
                    'count': '${_draft.subjects.length}',
                    'max': '$kMaxLearningSubjects',
                  },
                ),
                style: _pop(12.5, c: _dim),
              ),
          ],
        ),
        if (grade == null)
          Text('growth.profile.pickGradeFirst'.tr(), style: _pop(13, c: _dim))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final subject in _draft.available)
                _SubjectChip(
                  subject: subject,
                  selected: _draft.isSelected(subject),
                  enabled: !_saving && _draft.canToggle(subject),
                  onTap: () => _update(_draft.toggle(subject)),
                ),
            ],
          ),
        if (grade != null && _draft.isFull) ...[
          const SizedBox(height: 12),
          SchoolNote(
            icon: SolarIconsBold.infoCircle,
            text: 'growth.profile.maxHint'.tr(
              namedArgs: {'max': '$kMaxLearningSubjects'},
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 14),
          SchoolInlineError(message: error),
        ],
        const SizedBox(height: 22),
        ParvozPrimaryButton(
          label: 'growth.profile.save'.tr(),
          onPressed: _save,
          enabled: _draft.canSave,
          loading: _saving,
          showArrow: false,
        ),
        const SizedBox(height: 4),
        SchoolTextButton(
          label: 'common.cancel'.tr(),
          onTap: _saving ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

/// Sinf raqami (dumaloq tugma).
class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.grade,
    required this.selected,
    required this.onTap,
  });

  final int grade;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'growth.profile.gradeValue'.tr(namedArgs: {'grade': '$grade'}),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: _gradeSize,
          height: _gradeSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _blue : _optionBg,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? _blue : _optionBorder),
          ),
          child: ExcludeSemantics(
            child: Text('$grade', style: _pop(15, w: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

/// Fan tanlovi (pill): tanlangani ko'k, to'lganda qolganlari xira.
class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.subject,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final LearningSubject subject;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? _blue.withValues(alpha: 0.18) : _optionBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? _blue : _optionBorder,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(
                    SolarIconsBold.checkCircle,
                    size: 16,
                    color: _blue,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  subject.labelKey.tr(),
                  style: _pop(13.5, w: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
