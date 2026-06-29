// ─────────────────────────────────────────────────────────────────────
// BlockAppsScreen — "Ilovalarni bloklash" (Parvoz dizayn)
// ─────────────────────────────────────────────────────────────────────
//
// 2 tab: "Ilovlarni bloklash" (har ilovani alohida bloklash) va
// "Kategoriyalarni bloklash" (butun kategoriya: Ijtimoiy/O'yinlar/...).
// Toggle'lar LOKAL holatda yig'iladi, pastdagi "Saqlash" tugmasi hammasini
// backendga qo'llaydi (batch). Yangi/ulanmagan bolada ro'yxatlar bo'sh.
//
// Ma'lumot: ilovalar `installedAppsProvider`, blok holati
// `restrictionsProvider` (isBlocked), kategoriyalar `getCategories`.
// Saqlash: `blockApp`/`removeLimit` (facade) + `toggleCategory` (repo).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_icon_widget.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Parvoz tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _green = Color(0xFF34C759);
const _card = Color(0xFF12171E);
const _chipBg = Color(0xFF1B2128);
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _dim = Color(0x8CFFFFFF); // oq 55%

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
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Ilovalarni bloklash ekrani — per-app + kategoriya bloklash (batch saqlash).
class BlockAppsScreen extends ConsumerStatefulWidget {
  /// `BlockAppsScreen` konstruktor.
  const BlockAppsScreen({required this.childId, super.key});

  /// Qaysi bola uchun.
  final String childId;

  @override
  ConsumerState<BlockAppsScreen> createState() => _BlockAppsScreenState();
}

class _BlockAppsScreenState extends ConsumerState<BlockAppsScreen> {
  int _tab = 0; // 0 = ilovalar, 1 = kategoriyalar
  bool _saving = false;

  // Kategoriyalar (getCategories orqali bir marta yuklanadi).
  List<AppCategoryInfo>? _categories;
  bool _catLoading = true;
  bool _catError = false;

  // Lokal o'zgartirishlar (Saqlash bosilguncha backendga tegmaydi).
  final Map<String, bool> _appLocal = {}; // packageName -> bloklanganmi
  final Map<String, bool> _catLocal = {}; // category code -> bloklanganmi

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ref
          .read(backendAppLimitRepositoryProvider)
          .getCategories(widget.childId);
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _catLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catError = true;
        _catLoading = false;
      });
    }
  }

  Future<void> _onSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // ── Kategoriyalar diff ──
      final repo = ref.read(backendAppLimitRepositoryProvider);
      var cats = _categories ?? const <AppCategoryInfo>[];
      for (final c in cats) {
        final desired = _catLocal[c.category];
        if (desired != null && desired != c.blocked) {
          // toggleCategory yangilangan ro'yxatni qaytaradi — uni saqlaymiz
          // (apps loop xato bersa, retry eskirgan holatga qayta yubormasin).
          cats = await repo.toggleCategory(
            childId: widget.childId,
            category: c.category,
            block: desired,
          );
        }
      }
      _categories = cats;
      // ── Ilovalar diff ──
      if (_appLocal.isNotEmpty) {
        final facade = ref.read(appRestrictionRepositoryProvider);
        final restr =
            ref.read(restrictionsProvider(widget.childId)).valueOrNull;
        final orig = <String, bool>{};
        if (restr != null) {
          for (final r in restr) {
            orig[r.packageName] = r.isBlocked;
          }
        }
        final installed =
            ref.read(installedAppsProvider(widget.childId)).valueOrNull;
        final names = <String, String>{};
        if (installed != null) {
          for (final e in installed) {
            names[e.packageName] = e.appName;
          }
        }
        for (final entry in _appLocal.entries) {
          final pkg = entry.key;
          final desired = entry.value;
          if (desired == (orig[pkg] ?? false)) continue;
          if (desired) {
            await facade.blockApp(
              childId: widget.childId,
              packageName: pkg,
              appName: names[pkg] ?? pkg,
            );
          } else {
            await facade.removeLimit(
              childId: widget.childId,
              packageName: pkg,
            );
          }
        }
      }
      ref.invalidate(restrictionsProvider(widget.childId));
      if (!mounted) return;
      AppToast.success(context, 'blockApps.saved'.tr());
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final msg = e is AppLimitException
          ? e.message
          : 'blockApps.saveError'.tr();
      AppToast.error(context, msg);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Drag handle (sheet ko'rinishi).
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'blockApps.title'.tr(),
              style: _unb(18, w: FontWeight.w700, ls: -0.4),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SegmentedTabs(
                tabs: [
                  'blockApps.tabApps'.tr(),
                  'blockApps.tabCategories'.tr(),
                ],
                active: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _tab == 0 ? _buildApps() : _buildCategories(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _SaveButton(loading: _saving, onTap: _onSave),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ilovalar tab ──
  Widget _buildApps() {
    final apps = ref.watch(installedAppsProvider(widget.childId)).valueOrNull;
    final restr = ref.watch(restrictionsProvider(widget.childId)).valueOrNull;
    // Ikkalasi ham yuklanishini kutamiz — aks holda bloklangan ilovalar bir
    // lahza OFF ko'rinadi (restr kesh'siz, apps keshdan tez keladi).
    if (apps == null || restr == null) return const _Loading();
    if (apps.isEmpty) return _Empty('blockApps.emptyApps'.tr());
    final orig = <String, bool>{};
    for (final r in restr) {
      orig[r.packageName] = r.isBlocked;
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: apps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final e = apps[i];
        final blocked =
            _appLocal[e.packageName] ?? (orig[e.packageName] ?? false);
        return _AppRow(
          appName: e.appName,
          packageName: e.packageName,
          iconUrl: e.iconUrl,
          iconBase64: e.iconBase64,
          value: blocked,
          onChanged: (v) => setState(() => _appLocal[e.packageName] = v),
        );
      },
    );
  }

  // ── Kategoriyalar tab ──
  Widget _buildCategories() {
    if (_catLoading) return const _Loading();
    if (_catError) return _Empty('blockApps.loadError'.tr());
    // appCount>0 (ilovasi bor) YOKI bloklangan — bloklangan bo'sh kategoriya
    // ham ko'rinib, uni o'chirish imkoni qolsin.
    final cats = (_categories ?? const <AppCategoryInfo>[])
        .where((c) => c.appCount > 0 || c.blocked)
        .toList();
    if (cats.isEmpty) return _Empty('blockApps.emptyCategories'.tr());
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: cats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = cats[i];
        final blocked = _catLocal[c.category] ?? c.blocked;
        return _CategoryRow(
          label: c.label,
          appCount: c.appCount,
          value: blocked,
          onChanged: (v) => setState(() => _catLocal[c.category] = v),
        );
      },
    );
  }
}

// ════════════ Segment (tab) almashtirgich ════════════

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.tabs,
    required this.active,
    required this.onChanged,
  });

  final List<String> tabs;
  final int active;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final segW = (c.maxWidth - 8) / tabs.length;
        return Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _chipBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _fieldBorder),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: active == 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Container(
                  width: segW,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onChanged(i),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Text(
                            tabs[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _pop(
                              13,
                              w: i == active
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              c: i == active ? Colors.white : _dim,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════ Kartalar ════════════

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _fieldBorder),
      ),
      child: child,
    );
  }
}

/// Kategoriya qatori — nom + "N ta ilova" + yashil toggle.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.appCount,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int appCount;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _unb(16),
                ),
                const SizedBox(height: 3),
                Text(
                  'blockApps.appsCount'.tr(namedArgs: {'count': '$appCount'}),
                  style: _pop(13, c: _dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppSwitch(value: value, onChanged: onChanged, activeColor: _green),
        ],
      ),
    );
  }
}

/// Ilova qatori — ikon + nom + yashil toggle.
class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.appName,
    required this.packageName,
    required this.iconUrl,
    required this.iconBase64,
    required this.value,
    required this.onChanged,
  });

  final String appName;
  final String packageName;
  final String? iconUrl;
  final String? iconBase64;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Row(
        children: [
          AppIconWidget(
            packageName: packageName,
            iconUrl: iconUrl,
            iconBase64: iconBase64,
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _unb(15),
            ),
          ),
          const SizedBox(width: 10),
          AppSwitch(value: value, onChanged: onChanged, activeColor: _green),
        ],
      ),
    );
  }
}

// ════════════ Holatlar ════════════

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: _blue),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: _pop(14, c: _dim),
        ),
      ),
    );
  }
}

// ════════════ Saqlash tugmasi ════════════

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: ParvozGlass(
        blue: true,
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: Colors.white,
                ),
              )
            : Text('blockApps.save'.tr(), style: _pop(16, w: FontWeight.w500)),
      ),
    );
  }
}
