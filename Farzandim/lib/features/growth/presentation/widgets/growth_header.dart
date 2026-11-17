// ─────────────────────────────────────────────────────────────────────
// growth_header — Growth sahifasi tepasi
// ─────────────────────────────────────────────────────────────────────
//
// Bola kartasi (avatar, ism, sinf va fanlar, "O'zgartirish"), 7/30 kunlik
// davr almashtirgich va izohli karta (test yo'q / sinf tanlanmagan).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/growth/data/models/learning_profile.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/growth/presentation/growth_view_models.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _chipBg = Color(0xFF1B2128);
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF); // oq 60%
const _pillBg = Color(0x1AFFFFFF); // oq 10%

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.45);

/// "5-sinf · Matematika, Ingliz tili" (profil yo'q — bo'sh satr).
String _profileLine(LearningProfile? profile) {
  if (profile == null) return '';
  final grade = 'growth.profile.gradeValue'.tr(
    namedArgs: {'grade': '${profile.grade}'},
  );
  final subjects = [
    for (final s in profile.subjects)
      if (s != LearningSubject.unknown) s.labelKey.tr(),
  ].join(', ');
  return subjects.isEmpty ? grade : '$grade · $subjects';
}

/// Bola: avatar, ism, sinf va fanlar + "O'zgartirish" (profil bor bo'lsa).
class GrowthChildHeader extends ConsumerWidget {
  const GrowthChildHeader({
    required this.childId,
    required this.profile,
    required this.onEdit,
    super.key,
  });

  final String childId;
  final LearningProfile? profile;

  /// `null` — tugma ko'rsatilmaydi (xulosa hali yuklanmagan).
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(childByIdProvider(childId));
    final line = _profileLine(profile);
    final onEdit = this.onEdit;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          if (child != null)
            ChildAvatar(child: child, size: 44, showBorder: false)
          else
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: _chipBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                SolarIconsBold.graphUp,
                size: 22,
                color: Colors.white,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  child?.name ?? 'growth.title'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(16, w: FontWeight.w600),
                ),
                if (line.isNotEmpty)
                  Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(12.5, c: _dim),
                  ),
              ],
            ),
          ),
          if (onEdit != null && profile != null) ...[
            const SizedBox(width: 8),
            _SmallPill(label: 'growth.editProfile'.tr(), onTap: onEdit),
          ],
        ],
      ),
    );
  }
}

/// Kichik shisha pill-tugma ("O'zgartirish").
class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _pillBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label, style: _pop(13, w: FontWeight.w500)),
        ),
      ),
    );
  }
}

/// 7 / 30 kun almashtirgich (segment pill).
class GrowthPeriodToggle extends StatelessWidget {
  const GrowthPeriodToggle({
    required this.days,
    required this.onChanged,
    super.key,
  });

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'growth.periodLabel'.tr(),
      container: true,
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          children: [
            for (final period in kGrowthPeriods)
              Expanded(
                child: _Segment(
                  label: growthPeriodLabelKey(period).tr(),
                  selected: period == days,
                  onTap: () => onChanged(period),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: selected ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _blue : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: _pop(
              14,
              w: FontWeight.w500,
              c: selected ? Colors.white : _dim,
            ),
          ),
        ),
      ),
    );
  }
}

/// Izohli karta: ikon, sarlavha, matn va (ixtiyoriy) asosiy tugma.
class GrowthNoticeCard extends StatelessWidget {
  const GrowthNoticeCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: _chipBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _pop(15.5, w: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: _pop(13, c: _dim),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            ParvozPrimaryButton(
              label: actionLabel,
              onPressed: onAction,
              showArrow: false,
            ),
          ],
        ],
      ),
    );
  }
}
