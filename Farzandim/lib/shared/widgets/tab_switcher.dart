import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Pill-shaped tab switcher — bir nechta variantdan birini tanlash uchun.
///
/// Faol tab oq fonli "siljiydigan" indikator bilan belgilanadi (200ms,
/// `easeInOut`). Matn rangi va og'irligi ham yumshoq o'zgaradi.
///
/// Foydalanish:
/// ```dart
/// TabSwitcher(
///   tabs: const ['Telefon raqam', 'Elektron pochta'],
///   activeIndex: _activeTab,
///   onChanged: (i) => setState(() => _activeTab = i),
/// )
/// ```
class TabSwitcher extends StatelessWidget {
  /// `TabSwitcher` konstruktor.
  const TabSwitcher({
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
    super.key,
  });

  /// Tab matnlari ro'yxati.
  final List<String> tabs;

  /// Hozir tanlangan tab indeksi (0 dan boshlanadi).
  final int activeIndex;

  /// Tab bosilganda chaqiriladi (yangi indeks bilan).
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusPill);
    const animationDuration = Duration(milliseconds: 200);

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: borderRadius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabs.length;
          return Stack(
            children: [
              // ─── Siljiydigan oq indikator ───
              AnimatedPositioned(
                duration: animationDuration,
                curve: Curves.easeInOut,
                left: tabWidth * activeIndex,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: borderRadius,
                  ),
                ),
              ),

              // ─── Tab tap targets + matnlar ───
              Row(
                children: List.generate(tabs.length, (i) {
                  final isActive = i == activeIndex;
                  return Expanded(
                    child: GestureDetector(
                      // Bo'sh joydagi bosishlarni ham qabul qiladi.
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: animationDuration,
                          style: AppTextStyles.bodyS.copyWith(
                            color: isActive
                                ? AppColors.background
                                : AppColors.textSecondary,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w500,
                          ),
                          child: Text(tabs[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
