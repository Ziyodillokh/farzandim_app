// part of dashboard_screen — private nomlar saqlanadi (ARCH-13:
// 1300-qatorli monolit 3 faylga bo'lindi, import/vizual o'zgarish YO'Q).
part of 'dashboard_screen.dart';

// ════════════════════════ TIME CARD ════════════════════════

class _TimeCard extends ConsumerStatefulWidget {
  const _TimeCard({required this.childId, required this.blockAllInitial});

  final String childId;

  /// Backend'dagi joriy "barcha ilovalarni bloklash" holati
  /// (child.blockAllApps).
  final bool blockAllInitial;

  @override
  ConsumerState<_TimeCard> createState() => _TimeCardState();
}

class _TimeCardState extends ConsumerState<_TimeCard> {
  late bool _blocked = widget.blockAllInitial;
  bool _saving = false;
  // BUG-05: oxirgi muvaffaqiyatli saqlash vaqti — saqlashdan KEYIN ham
  // qisqa oynada eski in-flight poll-javobi (60s sikl) optimistik holatni
  // qaytarib yubormasligi uchun.
  DateTime? _lastSavedAt;

  @override
  void didUpdateWidget(_TimeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Backend yangilangach (children refetch) sinxronlash — saqlash
    // jarayonida VA undan keyingi 70s ichida (poll davri + margin)
    // foydalanuvchi tanlovini ustun qo'yamiz: eski snapshot bilan kelgan
    // javob toggle'ni "o'zi qaytarib" qo'ymasin (BUG-05).
    final recentlySaved =
        _lastSavedAt != null &&
        DateTime.now().difference(_lastSavedAt!) < const Duration(seconds: 70);
    if (!_saving &&
        !recentlySaved &&
        oldWidget.blockAllInitial != widget.blockAllInitial) {
      _blocked = widget.blockAllInitial;
    }
  }

  /// Toggle — optimistik + backend (`setBlockAllApps`) + xatoda qaytarish.
  /// Bola qurilmasi device-policy'ni o'qib barcha ilovani bloklaydi.
  Future<void> _onToggle(bool value) async {
    if (_saving) return;
    final previous = _blocked;
    setState(() {
      _blocked = value;
      _saving = true;
    });
    try {
      await ref
          .read(backendChildRepositoryProvider)
          .setBlockAllApps(widget.childId, value: value);
      _lastSavedAt = DateTime.now();
      ref.invalidate(childrenProvider);
      if (mounted) {
        AppToast.success(
          context,
          value
              ? 'dashboard.screenTime.blockAllOnSnack'.tr()
              : 'dashboard.screenTime.blockAllOffSnack'.tr(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _blocked = previous);
        AppToast.error(context, 'dashboard.screenTime.blockAllErrorSnack'.tr());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final childId = widget.childId;
    final day = ref.watch(todayUsageProvider(childId)).valueOrNull;
    // FAQAT foydalanuvchi ilovalari (system/launcher/orqa-fon emas) — ikonka
    // qatori uchun. `filteredApps` system prefixlarni chiqarib tashlaydi.
    final filtered = day?.filteredApps ?? const [];
    final apps = filtered.map((a) => _AppBrief(a.appName, a.iconUrl)).toList();
    // Bugungi jami vaqt — detail "Ekran vaqti" bilan AYNI avtoritar manba
    // (server `/weekly`, system filtrlangan + Toshkent, 30 sek polling). Avval
    // bu yer per-app yig'indini alohida hisoblardi → dashboard ↔ detail farq
    // qilardi (1h7m ↔ 1h22m) va realtime emas edi.
    final weeklyAsync = ref.watch(weeklyChildUsageProvider(childId));
    final totalMs = ref.watch(todayScreenTimeMsProvider(childId));
    // Birinchi yuklash paytida "0 daq" o'rniga "—" — ma'lumot hali kelmaganda
    // noto'g'ri 0 ko'rsatib, keyin sakrab o'zgarmasligi uchun (startup "0 then
    // corrects" muammosi).
    final isFirstLoad = weeklyAsync.isLoading && !weeklyAsync.hasValue;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dashboard.screenTime.todayTitle'.tr(),
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            isFirstLoad ? '—' : _formatDuration(totalMs),
            style: AppTextStyles.headlineXL.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppDimensions.md),

          // Eng ko'p ishlatilgan ilovalar — bir-biriga KIRISHGAN (overlapping
          // facepile, rasmdagidek): 5 tagacha ilova + qolgani "+N". Ixcham,
          // tor telefonda ham overflow bermaydi.
          if (apps.isNotEmpty) _AppFacepile(apps: apps),
          const SizedBox(height: AppDimensions.md),

          // Bloklash toggle.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'dashboard.screenTime.blockAll'.tr(),
                    style: AppTextStyles.bodyS,
                  ),
                ),
                AppSwitch(
                  value: _blocked,
                  onChanged: _saving ? null : _onToggle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    if (h == 0) {
      return 'appLimits.durationMinutes'.tr(namedArgs: {'minutes': '$m'});
    }
    return 'formatters.duration'.tr(
      namedArgs: {'hours': '$h', 'minutes': '$m'},
    );
  }
}

class _AppBrief {
  const _AppBrief(this.name, this.iconUrl);
  final String name;
  final String? iconUrl;
}

/// Overlapping facepile — eng ko'p ishlatilgan ilovalar bir-biriga KIRISHGAN
/// (rasmdagidek), oxirida qolganlari "+N". Chap ikonka eng ustda turadi.
class _AppFacepile extends StatelessWidget {
  const _AppFacepile({required this.apps});

  final List<_AppBrief> apps;

  static const double _size = 40; // ikonka (ring bilan)
  static const double _step = 26; // qadam — kirishuv ~35%
  static const int _maxShown = 5; // eng ko'p ishlatilgan 5 ta

  @override
  Widget build(BuildContext context) {
    final shown = apps.take(_maxShown).toList();
    final remaining = apps.length - shown.length;
    final slots = shown.length + (remaining > 0 ? 1 : 0);
    final width = (slots - 1) * _step + _size;

    final layers = <Widget>[
      // Ilovalar TESKARI tartibda (o'ngdagisi pastda) — chap ikonka ustda.
      for (var i = shown.length - 1; i >= 0; i--)
        Positioned(
          left: i * _step,
          child: _AppIcon(iconUrl: shown[i].iconUrl, name: shown[i].name),
        ),
      // "+N" — eng o'ngda, eng ustda (to'liq ko'rinadi).
      if (remaining > 0)
        Positioned(
          left: shown.length * _step,
          child: _PlusBadge(remaining: remaining),
        ),
    ];

    return SizedBox(
      height: _size,
      width: width,
      child: Stack(clipBehavior: Clip.none, children: layers),
    );
  }
}

/// Bitta ilova ikonkasi — nozik ring (karta-tusli gap) bilan facepile uchun.
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.iconUrl, required this.name});

  final String? iconUrl;
  final String name;

  /// Ikonka diametri (ring bilan) — const klassda maydon emas, getter.
  double get size => 40;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final inner = size - 5; // 2.5px ring har tomondan
    return Container(
      width: size,
      height: size,
      // Ring — karta foni tusida: overlapping ikonkalar toza ajraladi.
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: inner,
        height: inner,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: iconUrl != null && iconUrl!.isNotEmpty
            // MEM-4: disk kesh + cheklangan dekod (memCacheWidth)
            ? CachedNetworkImage(
                imageUrl: iconUrl!,
                width: inner,
                height: inner,
                fit: BoxFit.cover,
                memCacheWidth: 128,
                errorWidget: (_, __, ___) => _fallback(letter),
              )
            : _fallback(letter),
      ),
    );
  }

  Widget _fallback(String letter) {
    return Text(
      letter,
      style: AppTextStyles.bodyS.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// "+N" badge — facepile oxiri (qolgan ilovalar soni), ikonkalar bilan bir xil
/// ring + o'lcham.
class _PlusBadge extends StatelessWidget {
  const _PlusBadge({required this.remaining});

  final int remaining;

  /// Badge diametri — ikonkalar bilan bir xil o'lcham.
  double get size => 40;

  @override
  Widget build(BuildContext context) {
    final inner = size - 5;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: inner,
        height: inner,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '+$remaining',
          style: AppTextStyles.label.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ QUICK ACTIONS ════════════════════════

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    final tiles = <QuickActionTile>[
      QuickActionTile(
        icon: Icons.smartphone,
        label: 'dashboard.quickActions.device'.tr(),
        accentColor: AppColors.info,
        onTap: () => context.push(AppRoutes.qaDevicePath(childId)),
      ),
      QuickActionTile(
        icon: Icons.telegram,
        label: 'dashboard.quickActions.messenger'.tr(),
        accentColor: AppColors.accent,
        onTap: () => context.push(AppRoutes.qaVoicePath(childId)),
      ),
      // "Ilova cheklovlari" — eski "Qurilma cheklovlari" ekrani
      // (`app_limits_screen`, Figma 1:1: 2-tab ro'yxat + `AppLimitModal`)
      // shunchaki "Ilova cheklovlari" deb nomlanadi (soat ikona, eskisidek).
      // Ortiqcha ikkinchi cheklov kartasi (Faollik) olib tashlandi — Faollik
      // endi faqat pastdagi "Foydalanish vaqti" tugmasidan ochiladi.
      QuickActionTile(
        icon: Icons.lock_clock,
        label: 'dashboard.quickActions.appRestrictions'.tr(),
        accentColor: AppColors.featurePurple,
        onTap: () => context.push(AppRoutes.appLimitsPath(childId)),
      ),
      QuickActionTile(
        icon: Icons.location_on_outlined,
        // Nomi "Joylashuv" — jonli xarita ochiladi (tarix EMAS, shuning
        // uchun eski "Harakatlanish tarixi" nomi chalg'itardi).
        label: 'dashboard.quickActions.location'.tr(),
        accentColor: AppColors.success,
        onTap: () => context.push(AppRoutes.locationPath(childId)),
      ),
      QuickActionTile(
        icon: Icons.calendar_today_outlined,
        label: 'dashboard.quickActions.schedules'.tr(),
        accentColor: AppColors.error,
        onTap: () => context.push(AppRoutes.schedulesPath(childId)),
      ),
      QuickActionTile(
        icon: Icons.insights_rounded,
        label: 'dashboard.quickActions.weeklyReport'.tr(),
        accentColor: AppColors.featureAmber,
        onTap: () => context.push(AppRoutes.weeklyReportPath(childId)),
      ),
    ];

    // `childAspectRatio` o'rniga `mainAxisExtent` — tile balandligi ekran
    // kengligiga bog'liq EMAS. Aks holda tor telefonlarda tile qisilib,
    // ikonka + 2 qatorli matn sig'may qolardi ("qisilib qolyapti" muammosi).
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 128,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) => tiles[i],
    );
  }
}
