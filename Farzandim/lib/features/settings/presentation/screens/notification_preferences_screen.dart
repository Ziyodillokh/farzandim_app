// ─────────────────────────────────────────────────────────────────────
// NotificationPreferencesScreen — eslatma sozlamalari (#66/#67/#77)
// ─────────────────────────────────────────────────────────────────────
//
// Ota-ona bola uchun dars/test, sport/sog'lom va kontent eslatmalarini
// yoqadi/o'chiradi va tinch soatlarni (tun) belgilaydi. GET/PUT orqali.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/settings/data/repositories/backend_notification_preference_repository.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({required this.childId, super.key});

  final String childId;

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  NotificationPreferences? _prefs;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ref
          .read(backendNotificationPreferenceRepositoryProvider)
          .get(widget.childId);
      if (mounted) setState(() => _prefs = p);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _save({bool? study, bool? health, bool? content}) async {
    await _run(
      (repo) => repo.update(
        widget.childId,
        studyNudge: study,
        healthNudge: health,
        contentReminder: content,
      ),
    );
  }

  Future<void> _saveQuiet(String? from, String? to) async {
    await _run(
      (repo) => repo.setQuietHours(widget.childId, from: from, to: to),
    );
  }

  Future<void> _run(
    Future<NotificationPreferences> Function(
      BackendNotificationPreferenceRepository repo,
    )
    action,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await action(
        ref.read(backendNotificationPreferenceRepositoryProvider),
      );
      if (mounted) setState(() => _prefs = updated);
    } catch (_) {
      if (mounted) AppToast.error(context, 'notificationPrefs.saveError'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickQuiet() async {
    final p = _prefs;
    if (p == null) return;
    final from = await showTimePicker(
      context: context,
      initialTime: _parse(p.quietFrom) ?? const TimeOfDay(hour: 22, minute: 0),
      helpText: 'notificationPrefs.quietStartHelp'.tr(),
    );
    if (from == null || !mounted) return;
    final to = await showTimePicker(
      context: context,
      initialTime: _parse(p.quietTo) ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: 'notificationPrefs.quietEndHelp'.tr(),
    );
    if (to == null) return;
    await _saveQuiet(_fmt(from), _fmt(to));
  }

  TimeOfDay? _parse(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(onBack: () => context.pop()),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final p = _prefs;
    if (p == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.md,
        AppDimensions.lg,
        AppDimensions.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bolaga yuboriladigan ijobiy eslatmalar. Kuniga cheklangan, '
            'tinch soatlarda yuborilmaydi.',
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.md),
          _ToggleCard(
            icon: SolarIconsBold.book,
            color: const Color(0xFF60A5FA),
            title: 'notificationPrefs.studyTitle'.tr(),
            subtitle: 'notificationPrefs.studySubtitle'.tr(),
            value: p.studyNudge,
            onChanged: _saving ? null : (v) => _save(study: v),
          ),
          _ToggleCard(
            icon: SolarIconsBold.running,
            color: const Color(0xFF4ADE80),
            title: 'notificationPrefs.healthTitle'.tr(),
            subtitle: 'notificationPrefs.healthSubtitle'.tr(),
            value: p.healthNudge,
            onChanged: _saving ? null : (v) => _save(health: v),
          ),
          _ToggleCard(
            icon: SolarIconsBold.clapperboard,
            color: const Color(0xFF7C6FE0),
            title: 'notificationPrefs.contentTitle'.tr(),
            subtitle: 'notificationPrefs.contentSubtitle'.tr(),
            value: p.contentReminder,
            onChanged: _saving ? null : (v) => _save(content: v),
          ),
          const SizedBox(height: AppDimensions.sm),
          _QuietCard(
            prefs: p,
            onEdit: _saving ? null : _pickQuiet,
            onClear: _saving || !p.hasQuietHours
                ? null
                : () => _saveQuiet(null, null),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(
                SolarIconsOutline.arrowLeft,
                color: AppColors.textPrimary,
              ),
              onPressed: onBack,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'notificationPrefs.headerTitle'.tr(),
                style: AppTextStyles.headlineL.copyWith(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: SettingsCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyM.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            AppSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _QuietCard extends StatelessWidget {
  const _QuietCard({
    required this.prefs,
    required this.onEdit,
    required this.onClear,
  });

  final NotificationPreferences prefs;
  final VoidCallback? onEdit;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final label = prefs.hasQuietHours
        ? '${prefs.quietFrom} – ${prefs.quietTo}'
        : 'notificationPrefs.notSet'.tr();
    return SettingsCard(
      onTap: onEdit,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              SolarIconsBold.moonSleep,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'notificationPrefs.quietHours'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (prefs.hasQuietHours && onClear != null)
            IconButton(
              icon: Icon(
                SolarIconsBold.closeCircle,
                color: AppColors.textTertiary,
              ),
              onPressed: onClear,
            )
          else
            Icon(SolarIconsBold.altArrowRight, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
