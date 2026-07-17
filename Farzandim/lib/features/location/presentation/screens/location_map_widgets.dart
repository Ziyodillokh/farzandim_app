// ARCH-13: monolit ekran fayli `part` fayllarga bo'lindi — private nomlar
// va vizual xulq o'zgarmagan, faqat fayl tashkiloti.
// REDIZAYN (Figma): top bar — "Joylashuvi" sarlavha + "qatlamlar" (geo-zona)
// ikoni; bola almashtirish sarlavhani bosib (ko'p bola bo'lsa).
part of 'location_map_screen.dart';

// ════════════════════════ TOP BAR ════════════════════════

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenListProvider);
    final hasMultiple = children.length > 1;
    return Row(
      children: [
        _NavIconButton(
          icon: SolarIconsOutline.arrowLeft,
          onTap: () => context.pop(),
        ),
        const SizedBox(width: 12),
        // Sarlavha — MARKAZDA (ikki tugma orasida). Ko'p bola bo'lsa bosib
        // bola almashtirish mumkin.
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: hasMultiple
                ? () => _openChildPicker(context, children, child)
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'Joylashuvi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: _lunb(20, w: FontWeight.w700, ls: -0.4),
                  ),
                ),
                if (hasMultiple) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    SolarIconsOutline.altArrowDown,
                    color: _dim,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Xarita / geo-zonalar — buklangan xarita ikoni (Figmadagidek).
        _NavIconButton(
          icon: SolarIconsBold.map,
          onTap: () => context.push(AppRoutes.geoZonesPath(child.id)),
        ),
      ],
    );
  }
}

/// Yumaloq-kvadrat (squircle) shisha ikon tugma — Figma top bar uslubi.
class _NavIconButton extends StatelessWidget {
  const _NavIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      // To'qroq solid-glass fon — tugmalar xarita ustida toza ko'rinsin.
      color: const Color(0xE6121C2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
        side: const BorderSide(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: Icon(icon, size: 23, color: Colors.white)),
        ),
      ),
    );
  }
}

/// Bola tanlash varag'i (ko'p bola bo'lganda sarlavhadan ochiladi).
Future<void> _openChildPicker(
  BuildContext context,
  List<Child> children,
  Child current,
) async {
  final selected = await showModalBottomSheet<Child>(
    context: context,
    backgroundColor: const Color(0xFF0A1018),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusL),
      ),
      side: BorderSide(color: _cardBorder),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Text('location.picker.title'.tr(), style: _lunb(18)),
          ),
          for (final c in children)
            ListTile(
              leading: ChildAvatar(child: c, size: 40),
              title: Text(c.name, style: _lpop(14, w: FontWeight.w600)),
              trailing: c.id == current.id
                  ? const Icon(SolarIconsBold.checkCircle, color: _blue)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(c),
            ),
          const SizedBox(height: AppDimensions.sm),
        ],
      ),
    ),
  );

  if (selected != null && selected.id != current.id && context.mounted) {
    context.pushReplacement(AppRoutes.locationPath(selected.id));
  }
}

// ════════════════════════ NO LOCATION ════════════════════════

class _NoLocationState extends StatelessWidget {
  const _NoLocationState({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              // Tepadan pastroq (yuqori chetga yopishmasin).
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.md,
                AppDimensions.md + 44,
                AppDimensions.md,
                AppDimensions.md,
              ),
              child: _TopBar(child: child),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      SolarIconsOutline.mapPointRemove,
                      size: 80,
                      color: _dim,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Text(
                      'location.noLocation.title'.tr(),
                      style: _lunb(18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      'location.noLocation.subtitle'.tr(
                        namedArgs: {'name': child.name},
                      ),
                      style: _lpop(13, c: _dim),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    // Joylashuv yo'q — bolaga "yoqishni so'rash" (backend push
                    // yuboradi, bolada modal chiqadi).
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: RequestLocationButton(childId: child.id),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════ ERROR STATE ════════════════════════

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.child, required this.error});

  final Child child;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            // Tepadan pastroq (yuqori chetga yopishmasin).
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md,
              AppDimensions.md + 44,
              AppDimensions.md,
              AppDimensions.md,
            ),
            child: _TopBar(child: child),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    SolarIconsOutline.dangerCircle,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    'location.error.title'.tr(),
                    style: AppTextStyles.headlineL.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    '$error',
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ NO CHILDREN ════════════════════════

class _NoChildrenScreen extends StatelessWidget {
  const _NoChildrenScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(SolarIconsOutline.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Text('location.noChildren'.tr(), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
