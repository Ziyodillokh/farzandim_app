// ─────────────────────────────────────────────────────────────────────
// BlockAppsSheet — "Ilovalarni bloklash" (Parvoz, tortiladigan sheet)
// ─────────────────────────────────────────────────────────────────────
//
// Pastdan chiqadigan modal sheet: tepaga tortilsa kengayadi, pastga
// tortilsa yopiladi (DraggableScrollableSheet). 2 tab: "Ilovlarni bloklash"
// (har ilovani alohida) va "Kategoriyalarni bloklash" (Ijtimoiy/O'yinlar/...).
// Toggle'lar lokal, "Saqlash" hammasini backendga qo'llaydi (batch).
//
// Ma'lumot: ilovalar `installedAppsProvider`, blok holati
// `restrictionsProvider`, kategoriyalar `getCategories`. Saqlash:
// `blockApp`/`removeLimit` (facade) + `toggleCategory` (repo).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_icon_widget.dart';
import 'package:farzandim/features/location/presentation/providers/location_mock.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// "Ilovalarni bloklash"ni tortiladigan modal sheet sifatida ochadi.
///
/// [title] — sarlavhani almashtiradi (masalan rejim uchun "Rejimlar").
/// [showCategories] `false` bo'lsa — tab yo'q, faqat ilovalar (blok/barcha).
void showBlockAppsSheet(
  BuildContext context, {
  required String childId,
  String? title,
  bool showCategories = true,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _BlockAppsSheet(
      childId: childId,
      title: title,
      showCategories: showCategories,
    ),
  );
}

/// Drag qobig'i — tepaga/pastga tortiladi, minimumdan past tortilsa yopiladi.
class _BlockAppsSheet extends StatefulWidget {
  const _BlockAppsSheet({
    required this.childId,
    this.title,
    this.showCategories = true,
  });

  final String childId;
  final String? title;
  final bool showCategories;

  @override
  State<_BlockAppsSheet> createState() => _BlockAppsSheetState();
}

class _BlockAppsSheetState extends State<_BlockAppsSheet> {
  bool _opened = false; // ochilish tugadimi (drag-yopishni faqat shundan keyin)
  bool _dismissing = false; // qayta-qayta pop bo'lmasin

  @override
  void initState() {
    super.initState();
    // Sheet darhol 0.9'da ochiladi (0'dan animatsiya emas) — birinchi
    // frame'dan keyin "ochilgan" deb belgilaymiz, shunda drag-yopish ishlaydi.
    WidgetsBinding.instance.addPostFrameCallback((_) => _opened = true);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        if (n.extent >= 0.85) _opened = true;
        // Ochilgandan keyin minimumga yaqin tortilsa — yopamiz.
        if (_opened && !_dismissing && n.extent <= 0.46) {
          _dismissing = true;
          Navigator.of(context).maybePop();
        }
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.45,
        maxChildSize: 0.96,
        snap: true,
        snapSizes: const [0.9],
        expand: false,
        builder: (ctx, scrollController) => _BlockAppsBody(
          childId: widget.childId,
          scrollController: scrollController,
          title: widget.title,
          showCategories: widget.showCategories,
        ),
      ),
    );
  }
}

// ════════════ Sheet mazmuni ════════════

class _BlockAppsBody extends ConsumerStatefulWidget {
  const _BlockAppsBody({
    required this.childId,
    required this.scrollController,
    this.title,
    this.showCategories = true,
  });

  final String childId;
  final ScrollController scrollController;
  final String? title;
  final bool showCategories;

  @override
  ConsumerState<_BlockAppsBody> createState() => _BlockAppsBodyState();
}

class _BlockAppsBodyState extends ConsumerState<_BlockAppsBody> {
  int _tab = 0; // 0 = ilovalar, 1 = kategoriyalar
  bool _saving = false;

  List<AppCategoryInfo>? _categories;
  bool _catLoading = true;
  bool _catError = false;

  final Map<String, bool> _appLocal = {}; // packageName -> bloklanganmi
  final Map<String, bool> _catLocal = {}; // category -> bloklanganmi

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    // MOCK (UI preview): soxta kategoriyalar.
    if (kLocationMock) {
      setState(() {
        _categories = const [
          AppCategoryInfo(
            category: 'social',
            label: 'Ijtimoiy tarmoqlar',
            appCount: 12,
            blocked: true,
          ),
          AppCategoryInfo(
            category: 'games',
            label: "O'yinlar",
            appCount: 24,
            blocked: true,
          ),
          AppCategoryInfo(
            category: 'other',
            label: 'Boshqa',
            appCount: 36,
            blocked: true,
          ),
        ];
        _catLoading = false;
      });
      return;
    }
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
          // toggleCategory yangilangan ro'yxatni qaytaradi — saqlaymiz
          // (apps loop xato bersa, retry eskirgan holatni yubormasin).
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
      Navigator.of(context).pop();
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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: _bg,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title ?? 'blockApps.title'.tr(),
                textAlign: TextAlign.center,
                style: _unb(18, w: FontWeight.w700, ls: -0.4),
              ),
              const SizedBox(height: 18),
              if (widget.showCategories) ...[
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
              ],
              Expanded(
                child: (widget.showCategories && _tab == 1)
                    ? _buildCategories()
                    : _buildApps(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _SaveButton(loading: _saving, onTap: _onSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Drag ishlashi uchun har holat ham scrollController + always-scrollable.
  Widget _fill(Widget child) {
    return ListView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [SizedBox(height: 320, child: Center(child: child))],
    );
  }

  Widget _buildApps() {
    final apps = ref.watch(installedAppsProvider(widget.childId)).valueOrNull;
    final restr = ref.watch(restrictionsProvider(widget.childId)).valueOrNull;
    // Ikkalasini ham kutamiz — aks holda bloklangan ilova bir lahza OFF.
    if (apps == null || restr == null) return _fill(const _Loading());
    if (apps.isEmpty) return _fill(_Empty('blockApps.emptyApps'.tr()));
    final orig = <String, bool>{};
    for (final r in restr) {
      orig[r.packageName] = r.isBlocked;
    }
    bool isBlocked(AppUsageEntry e) =>
        _appLocal[e.packageName] ?? (orig[e.packageName] ?? false);
    final blocked = [
      for (final e in apps)
        if (isBlocked(e)) e,
    ];
    final unblocked = [
      for (final e in apps)
        if (!isBlocked(e)) e,
    ];

    return ListView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      children: [
        // ── Bloklangan ilovalar (qizil minus → blokdan chiqarish) ──
        if (blocked.isNotEmpty) ...[
          _SectionTitle('blockApps.blockedSection'.tr()),
          const SizedBox(height: 10),
          _GroupCard(
            children: [
              for (final e in blocked)
                _AppRow(
                  entry: e,
                  blocked: true,
                  onTap: () =>
                      setState(() => _appLocal[e.packageName] = false),
                ),
            ],
          ),
          const SizedBox(height: 22),
        ],
        // ── Barcha ilovalar (yashil plus → bloklash) ──
        _SectionTitle('blockApps.allSection'.tr()),
        const SizedBox(height: 10),
        if (unblocked.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: _Empty('blockApps.allSection'.tr()),
          )
        else
          _GroupCard(
            children: [
              for (final e in unblocked)
                _AppRow(
                  entry: e,
                  blocked: false,
                  onTap: () =>
                      setState(() => _appLocal[e.packageName] = true),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCategories() {
    if (_catLoading) return _fill(const _Loading());
    if (_catError) return _fill(_Empty('blockApps.loadError'.tr()));
    // appCount>0 (ilovasi bor) YOKI bloklangan — bo'sh-bloklangan ham
    // ko'rinib, uni o'chirish imkoni qolsin.
    final cats = (_categories ?? const <AppCategoryInfo>[])
        .where((c) => c.appCount > 0 || c.blocked)
        .toList();
    if (cats.isEmpty) return _fill(_Empty('blockApps.emptyCategories'.tr()));
    return ListView.separated(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
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

/// Bo'lim sarlavhasi ("Bloklangan ilovalar" / "Barcha ilovalar").
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: _pop(14, c: _dim)),
    );
  }
}

/// Bir nechta qatorni bitta yumaloq kartaga guruhlaydi (orasida nozik chiziq).
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 14,
                endIndent: 14,
                color: Colors.white.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }
}

/// Ilova qatori — dumaloq ikon + nom + minus (bloklangan) / plus (barcha).
class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.entry,
    required this.blocked,
    required this.onTap,
  });

  final AppUsageEntry entry;
  final bool blocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 40,
              height: 40,
              child: AppIconWidget(
                packageName: entry.packageName,
                iconUrl: entry.iconUrl,
                iconBase64: entry.iconBase64,
                size: 40,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              entry.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _unb(15),
            ),
          ),
          const SizedBox(width: 10),
          _ActionCircle(blocked: blocked, onTap: onTap),
        ],
      ),
    );
  }
}

/// O'ng tarafdagi harakat tugmasi — qizil minus (blokdan chiqarish) yoki
/// yashil plus (bloklash).
class _ActionCircle extends StatelessWidget {
  const _ActionCircle({required this.blocked, required this.onTap});

  final bool blocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = blocked ? const Color(0xFFE5484D) : _green;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(
          blocked ? Icons.remove_rounded : Icons.add_rounded,
          size: 19,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ════════════ Holatlar ════════════

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: _blue),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: _pop(14, c: _dim),
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
