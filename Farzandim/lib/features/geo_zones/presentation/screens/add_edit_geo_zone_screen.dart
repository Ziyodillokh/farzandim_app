import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zones_provider.dart';
import 'package:farzandim/features/geo_zones/presentation/widgets/expandable_map.dart';
import 'package:farzandim/shared/widgets/custom_text_field.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Yangi geo-zona yaratish yoki mavjudini tahrirlash.
///
/// `zoneId == null` → **add mode**. `zoneId != null` → **edit mode**
/// (boshlang'ich qiymatlar Stream'dagi keshlangan ro'yxatdan o'qiladi,
/// header'da delete tugma ko'rinadi).
///
/// **UI**:
/// - 280dp baland xarita (drag marker + tap to relocate + circle preview)
/// - Nom, ikon picker (8 ta), radius slider (50-500m)
/// - Enter/exit notification switchlari
/// - Pastda "Saqlash" (yoki "Yangilash") PrimaryButton
///
/// **Firestore (Bosqich 4.2 → migration):** `geoZoneActionsProvider`
/// orqali async yozadi. Yozilgach Stream avtomatik yangilanadi —
/// list ekran yangi zonani ko'radi.
class AddEditGeoZoneScreen extends ConsumerStatefulWidget {
  /// `AddEditGeoZoneScreen` konstruktor.
  const AddEditGeoZoneScreen({
    required this.childId,
    super.key,
    this.zoneId,
  });

  /// Qaysi bola uchun zona (per-child).
  final String childId;

  /// Tahrirlanadigan zona id'si. `null` bo'lsa add mode.
  final String? zoneId;

  @override
  ConsumerState<AddEditGeoZoneScreen> createState() =>
      _AddEditGeoZoneScreenState();
}

class _AddEditGeoZoneScreenState
    extends ConsumerState<AddEditGeoZoneScreen> {
  // Toshkent markazi — default boshlang'ich joylashuv.
  static const _defaultCenter = LatLng(41.2995, 69.2401);

  final TextEditingController _nameController = TextEditingController();

  LatLng _center = _defaultCenter;
  double _radius = 100;
  bool _notifyOnEnter = true;
  bool _notifyOnExit = true;
  String _selectedIcon = 'place';
  GeoZoneType _type = GeoZoneType.custom;

  bool get _isEditMode => widget.zoneId != null;

  bool get _isFormValid => _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      // Edit mode — Stream'dagi keshlangan zonadan boshlang'ich
      // qiymatlarni o'qiymiz. Stream hali yuklanmagan bo'lsa null —
      // build paytida `addPostFrameCallback` orqali yana urinamiz.
      _initFromExistingZone();
    }
  }

  void _initFromExistingZone() {
    final zone = ref.read(
      geoZoneByIdProvider(
        (childId: widget.childId, zoneId: widget.zoneId!),
      ),
    );
    if (zone != null) {
      _nameController.text = zone.name;
      _center = zone.center;
      _radius = zone.radiusMeters;
      _notifyOnEnter = zone.notifyOnEnter;
      _notifyOnExit = zone.notifyOnExit;
      _selectedIcon = zone.icon ?? zone.type.defaultIconName;
      _type = zone.type;
    } else {
      // Stream hali kelmagan bo'lishi mumkin — keyingi frame'da
      // qaytadan o'qib state'ni to'ldiramiz.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final z = ref.read(
          geoZoneByIdProvider(
            (childId: widget.childId, zoneId: widget.zoneId!),
          ),
        );
        if (z != null) {
          setState(() {
            _nameController.text = z.name;
            _center = z.center;
            _radius = z.radiusMeters;
            _notifyOnEnter = z.notifyOnEnter;
            _notifyOnExit = z.notifyOnExit;
            _selectedIcon = z.icon ?? z.type.defaultIconName;
            _type = z.type;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                isEditMode: _isEditMode,
                onDelete: _confirmDelete,
              ),
              const SizedBox(height: AppDimensions.sm),
              ExpandableMap(
                center: _center,
                radius: _radius,
                onCenterChanged: (newCenter) {
                  setState(() => _center = newCenter);
                },
              ),
              const SizedBox(height: AppDimensions.md),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'geoZoneEdit.mapHint'.tr(),
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg - 4),
                      _SectionTitle('geoZoneEdit.nameLabel'.tr()),
                      const SizedBox(height: AppDimensions.sm),
                      CustomTextField(
                        controller: _nameController,
                        hint: 'geoZoneEdit.nameHint'.tr(),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppDimensions.lg - 4),
                      _SectionTitle('geoZoneEdit.iconLabel'.tr()),
                      const SizedBox(height: AppDimensions.sm),
                      _IconPicker(
                        selected: _selectedIcon,
                        onSelect: (icon) =>
                            setState(() => _selectedIcon = icon),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      _RadiusSlider(
                        value: _radius,
                        onChanged: (v) => setState(() => _radius = v),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _SectionTitle('geoZoneEdit.notificationsLabel'.tr()),
                      const SizedBox(height: 12),
                      _NotificationToggles(
                        notifyOnEnter: _notifyOnEnter,
                        notifyOnExit: _notifyOnExit,
                        onEnterChanged: (v) =>
                            setState(() => _notifyOnEnter = v),
                        onExitChanged: (v) =>
                            setState(() => _notifyOnExit = v),
                      ),
                      const SizedBox(height: AppDimensions.xl),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: PrimaryButton(
                  label: _isEditMode
                      ? 'geoZoneEdit.updateButton'.tr()
                      : 'geoZoneEdit.saveButton'.tr(),
                  icon: Icons.check,
                  onPressed: _isFormValid ? _onSave : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Saqlash / o'chirish ───

  Future<void> _onSave() async {
    final notifier = ref.read(geoZoneActionsProvider.notifier);
    final name = _nameController.text.trim();

    final current = _isEditMode
        ? ref.read(
            geoZoneByIdProvider(
              (childId: widget.childId, zoneId: widget.zoneId!),
            ),
          )
        : null;

    final result = _isEditMode && current != null
        ? await notifier.updateZone(
            childId: widget.childId,
            zoneId: widget.zoneId!,
            current: current,
            name: name,
            type: _type,
            latitude: _center.latitude,
            longitude: _center.longitude,
            radiusMeters: _radius,
            notifyOnEnter: _notifyOnEnter,
            notifyOnExit: _notifyOnExit,
            icon: _selectedIcon,
          )
        : await notifier.addZone(
            childId: widget.childId,
            name: name,
            type: _type,
            latitude: _center.latitude,
            longitude: _center.longitude,
            radiusMeters: _radius,
            notifyOnEnter: _notifyOnEnter,
            notifyOnExit: _notifyOnExit,
            icon: _selectedIcon,
          );

    if (!mounted) return;
    if (result.isSuccess) {
      context.pop();
    } else {
      AppToast.error(
        context,
        'geoZoneEdit.saveErrorPrefix'.tr(
          namedArgs: {'error': '${result.error}'},
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final zone = ref.read(
      geoZoneByIdProvider(
        (childId: widget.childId, zoneId: widget.zoneId!),
      ),
    );
    if (zone == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'geoZoneEdit.deleteDialog.title'.tr(),
          style: AppTextStyles.headlineL.copyWith(fontSize: 18),
        ),
        content: Text(
          'geoZoneEdit.deleteDialog.content'.tr(
            namedArgs: {'name': zone.name},
          ),
          style: AppTextStyles.bodyS.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'geoZoneEdit.deleteDialog.cancel'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'geoZoneEdit.deleteDialog.delete'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false) || !mounted) return;

    final result = await ref.read(geoZoneActionsProvider.notifier).deleteZone(
          childId: widget.childId,
          zoneId: widget.zoneId!,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      context.pop();
    } else {
      AppToast.error(
        context,
        'geoZoneEdit.deleteErrorPrefix'.tr(
          namedArgs: {'error': '${result.error}'},
        ),
      );
    }
  }
}

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.isEditMode, required this.onDelete});

  final bool isEditMode;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.lg,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                isEditMode
                    ? 'geoZoneEdit.headerEdit'.tr()
                    : 'geoZoneEdit.headerAdd'.tr(),
                style: AppTextStyles.headlineL.copyWith(fontSize: 20),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (isEditMode)
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: AppColors.textPrimary,
                ),
                onPressed: onDelete,
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ════════════════════════ SECTION TITLE ════════════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

// ════════════════════════ ICON PICKER ════════════════════════

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: GeoZone.availableIcons.map((iconName) {
        final isSelected = iconName == selected;
        return InkWell(
          onTap: () => onSelect(iconName),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isSelected ? AppColors.primary : AppColors.surface,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              GeoZone.iconFromString(iconName),
              size: 24,
              color: isSelected
                  ? AppColors.onPrimary
                  : AppColors.textPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════ RADIUS SLIDER ════════════════════════

class _RadiusSlider extends StatelessWidget {
  const _RadiusSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'geoZoneEdit.radiusLabel'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'geoZoneEdit.radiusValue'.tr(
                namedArgs: {'meters': '${value.round()}'},
              ),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.surface,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            min: 50,
            max: 500,
            divisions: 45,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════ NOTIFICATION TOGGLES ════════════════════════

class _NotificationToggles extends StatelessWidget {
  const _NotificationToggles({
    required this.notifyOnEnter,
    required this.notifyOnExit,
    required this.onEnterChanged,
    required this.onExitChanged,
  });

  final bool notifyOnEnter;
  final bool notifyOnExit;
  final ValueChanged<bool> onEnterChanged;
  final ValueChanged<bool> onExitChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: 4,
      ),
      child: Column(
        children: [
          _ToggleRow(
            icon: Icons.login,
            iconColor: AppColors.accent,
            label: 'geoZoneEdit.notifyOnEnter'.tr(),
            value: notifyOnEnter,
            onChanged: onEnterChanged,
          ),
          Divider(color: AppColors.border, height: 1),
          _ToggleRow(
            icon: Icons.logout,
            iconColor: AppColors.error,
            label: 'geoZoneEdit.notifyOnExit'.tr(),
            value: notifyOnExit,
            onChanged: onExitChanged,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.onPrimary,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.border,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
