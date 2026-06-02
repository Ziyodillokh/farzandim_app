import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class AdminPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.pageTitle),
            const SizedBox(height: AppSpacing.xxs),
            Text(subtitle, style: AppTextStyles.pageSubtitle),
          ],
        ),
        if (trailing != null) ...[trailing!],
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.sectionTitle);
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Duration duration;
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(AppSpacing.sm),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const AppPrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: onPressed, child: Text(label));
  }
}

class AppDangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const AppDangerButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const AppSecondaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

class AppFilterDropdown extends StatelessWidget {
  final String hint;
  final String selectedValue;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;
  final Widget? prefix;
  const AppFilterDropdown({
    super.key,
    required this.hint,
    required this.selectedValue,
    required this.items,
    this.onChanged,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String>(
        initialValue: items.any((e) => e.value == selectedValue)
            ? selectedValue
            : items.first.value,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          prefixIcon: prefix,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String hint;
  final Color accent;
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.hint,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        height: 126,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: AppTextStyles.statTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: AppTextStyles.statValue),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.trending_up, size: 14, color: accent),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 12,
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final double? width;
  const SearchField({
    super.key,
    this.hintText = 'Qidiruv',
    this.controller,
    this.onChanged,
    this.width = 320,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
    if (width != null) {
      return SizedBox(width: width, child: field);
    }
    return field;
  }
}

class FilterBar extends StatelessWidget {
  final List<Widget> children;
  const FilterBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizing) {
        if (!sizing.isDesktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: w,
                  ),
                )
                .toList(),
          );
        }
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: children,
        );
      },
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final bool good;
  const StatusBadge({super.key, required this.label, required this.good});

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final pending = lower.contains('kutil') || lower.contains('pending');
    final tone = pending
        ? AppColors.warning
        : (good ? AppColors.success : AppColors.danger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class RoleBadge extends StatelessWidget {
  final String label;
  const RoleBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final isChild = label.toLowerCase().contains('bola');
    final bg = isChild ? const Color(0xFF0EA5E9) : const Color(0xFF6366F1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isChild ? const Color(0xFF0369A1) : const Color(0xFF4338CA),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class AppTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  const AppTable({
    super.key,
    required this.columns,
    required this.rows,
    this.dataRowMinHeight = 48,
    this.dataRowMaxHeight = 56,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.backgroundAlt),
          headingRowHeight: 56,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 64,
          horizontalMargin: AppSpacing.sm,
          columnSpacing: AppSpacing.md,
          headingTextStyle: AppTextStyles.tableHeader,
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }
}

class AppPagination extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const AppPagination({
    super.key,
    required this.page,
    required this.totalPages,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: onPrev, child: const Text('Oldingi')),
        const SizedBox(width: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: AppColors.border),
          ),
          child: Text('$page / $totalPages'),
        ),
        const SizedBox(width: AppSpacing.xs),
        TextButton(onPressed: onNext, child: const Text('Keyingisi')),
      ],
    );
  }
}

class EmptyStateView extends StatelessWidget {
  final String title;
  final String subtitle;
  const EmptyStateView({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 42,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(title, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle, style: AppTextStyles.pageSubtitle),
        ],
      ),
    );
  }
}
