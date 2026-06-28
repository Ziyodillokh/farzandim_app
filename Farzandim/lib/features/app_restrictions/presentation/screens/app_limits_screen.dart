// ─────────────────────────────────────────────────────────────────────
// AppLimitsScreen — "Ilova cheklovlari" (Figma 1:1, dinamik)
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard "Ilova cheklovlari" (soat ikona) tugmasidan ochiladi. (Avval
// "Qurilma cheklovlari" deb nomlanardi — asli ilova cheklovlari edi, shuning
// uchun nomi to'g'rilandi.) Ikkita tab:
//   - "Hammasi"        — bola ishlatgan barcha ilovalar
//   - "Cheklov bo'yicha" — faqat limit yoki blok qo'yilgan ilovalar
// Ilova ustiga bosilsa — modal: bloklash / limit belgilash / cheksiz.
//
// Ma'lumot mavjud provayderlardan (combineAppData): usage + restrictions +
// installed apps. Hech qanday dublikat backend mantiq yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_combined.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_limit_repository.dart'
    show AppLimitException;
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_icon_widget.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/settings_card.dart';
import 'package:farzandim/shared/widgets/tab_switcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

part 'app_limits_widgets.dart';
part 'app_limit_modal.dart';

class AppLimitsScreen extends ConsumerStatefulWidget {
  const AppLimitsScreen({required this.childId, super.key});

  final String childId;

  @override
  ConsumerState<AppLimitsScreen> createState() => _AppLimitsScreenState();
}

class _AppLimitsScreenState extends ConsumerState<AppLimitsScreen> {
  late String _childId;
  int _tab = 0; // 0 = Hammasi, 1 = Cheklov bo'yicha

  @override
  void initState() {
    super.initState();
    _childId = widget.childId;
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenListProvider);
    final usageAsync = ref.watch(todayUsageProvider(_childId));
    final restrictionsAsync = ref.watch(restrictionsProvider(_childId));
    final installedAsync = ref.watch(installedAppsProvider(_childId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(title: 'appLimits.title'.tr()),
              if (children.length > 1)
                _ChildChips(
                  childIds: children.map((c) => c.id).toList(),
                  selectedId: _childId,
                  onSelect: (id) => setState(() => _childId = id),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.lg,
                  AppDimensions.sm,
                  AppDimensions.lg,
                  AppDimensions.sm,
                ),
                child: TabSwitcher(
                  tabs: ['appLimits.tabAll'.tr(), 'appLimits.tabLimited'.tr()],
                  activeIndex: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: usageAsync.when(
                  data: (usage) => restrictionsAsync.when(
                    data: (restrictions) {
                      final installed = installedAsync.valueOrNull ?? const [];
                      var apps = combineAppData(
                        usage: usage,
                        restrictions: restrictions,
                        installedApps: installed,
                      );
                      // "Cheklov bo'yicha" — faqat limit/blok qo'yilganlar.
                      if (_tab == 1) {
                        apps = apps
                            .where((a) => a.hasLimit || a.isBlocked)
                            .toList();
                      }
                      return _AppList(apps: apps, childId: _childId);
                    },
                    loading: _loading,
                    error: _error,
                  ),
                  loading: _loading,
                  error: _error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loading() =>
      Center(child: CircularProgressIndicator(color: AppColors.primary));

  Widget _error(Object e, StackTrace _) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Text(
        '$e',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
      ),
    ),
  );
}
