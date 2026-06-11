// ─────────────────────────────────────────────────────────────────────
// InterestsEditSheet — bola sozlamalardan qiziqishlarni o'zgartiradi
// ─────────────────────────────────────────────────────────────────────
//
// Bottom sheet ko'rinishida ochiladi. Onboarding'dagi bilan bir xil
// 12 ta chip ko'rsatadi, joriy qiziqishlar tanlangan holatda. "Saqlash"
// bosilsa `childInterestsProvider.save(...)` chaqiriladi — backend'ga
// PUT yuboriladi va Books/Videos tavsiya seksiyalari yangilanadi.
//
// Foydalanish:
//   InterestsEditSheet.show(context);
// Yopilganda — saqlangan bo'lsa true, bo'lmasa null/false qaytaradi.

// ignore_for_file: public_member_api_docs

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/onboarding/data/interest_options.dart';
import 'package:farzandim_child/features/onboarding/presentation/providers/interests_provider.dart';
import 'package:farzandim_child/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InterestsEditSheet extends ConsumerStatefulWidget {
  const InterestsEditSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InterestsEditSheet(),
    );
  }

  @override
  ConsumerState<InterestsEditSheet> createState() =>
      _InterestsEditSheetState();
}

class _InterestsEditSheetState extends ConsumerState<InterestsEditSheet> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(childInterestsProvider).valueOrNull ?? const [];
    _selected = {...current};
  }

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _save() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final ok = await ref
        .read(childInterestsProvider.notifier)
        .save(_selected.toList());
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('onboarding.interests.saved'.tr()),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('onboarding.interests.saveFailed'.tr()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.85;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          constraints: BoxConstraints(maxHeight: maxH),
          decoration: const BoxDecoration(
            color: AppColors.bgPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'onboarding.interests.editTitle'.tr(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'onboarding.interests.subtitle'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 12,
                    children: [
                      for (final opt in kInterestOptions)
                        _InterestChip(
                          option: opt,
                          selected: _selected.contains(opt.id),
                          onTap: () => _toggle(opt.id),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.viewPaddingOf(context).bottom + 12,
                ),
                child: PrimaryButton(
                  text: _selected.isEmpty
                      ? 'onboarding.minSelect'.tr()
                      : 'onboarding.interests.editTitle'.tr(),
                  isLoading: _saving,
                  onPressed: _selected.isEmpty ? null : _save,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final InterestOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : AppColors.bgSurface;
    final fg = selected ? Colors.white : AppColors.textPrimary;
    final border = selected
        ? AppColors.primary
        : AppColors.primary.withValues(alpha: 0.16);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(option.icon, size: 16, color: fg),
                const SizedBox(width: 8),
                Text(
                  option.label(),
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
