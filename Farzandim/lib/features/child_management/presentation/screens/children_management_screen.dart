// ─────────────────────────────────────────────────────────────────────
// ChildrenManagementScreen — "Bolalarim" (Parvoz dizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Sozlamalar → "Bolalarim" bosilganda ochiladi. Har bola karta: avatar +
// ism + qurilma • batareya + chevron. Pastda "+ Bola qo'shish". Karta
// bosilsa "Akkount" varag'i: ism / telefon / tug'ilgan yili (qalam →
// tahrirlash ekrani) + "Bolani qayta ulash" (ulanish varag'i).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/child_management/presentation/screens/connect_child_sheet.dart';
import 'package:farzandim/features/child_management/presentation/widgets/repair_qr_dialog.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar ════════════
const _bg = Color(0xFF00060A);
const _card = Color(0xFF12171E);
const _chipBg = Color(0xFF1B2128);
const _sheetBg = Color(0xFF0E1319);
const _fieldBorder = Color(0x1FFFFFFF);
const _dim = Color(0x8CFFFFFF);

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
}) => GoogleFonts.unbounded(fontSize: s, fontWeight: w, color: c, height: 1.25);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.4);

IconData _batteryIcon(int level) {
  if (level >= 60) return SolarIconsBold.batteryFull;
  return SolarIconsBold.batteryHalf;
}

/// Bolalar ro'yxati — sozlamalardagi "Bolalarim" bo'limi.
class ChildrenManagementScreen extends ConsumerWidget {
  /// `ChildrenManagementScreen` konstruktor.
  const ChildrenManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);
    final children = childrenAsync.valueOrNull ?? const <Child>[];

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Row(
                children: [
                  _BackButton(onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.settings);
                    }
                  }),
                  Expanded(
                    child: Text(
                      'settings.rows.children.title'.tr(),
                      textAlign: TextAlign.center,
                      style: _unb(22),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  for (final c in children) ...[
                    _ChildCard(
                      child: c,
                      onTap: () => _showAccountSheet(context, ref, c),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (children.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'dashboard.emptyState.message'.tr(),
                        textAlign: TextAlign.center,
                        style: _pop(14, c: _dim),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _AddChildButton(
                    onTap: () => context.push(AppRoutes.addChild),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Bola kartasi ════════════

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.onTap});

  final Child child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final battery = child.deviceInfo?.batteryLevel;
    final rawDevice = (child.deviceModel?.isNotEmpty ?? false)
        ? child.deviceModel!
        : (child.deviceInfo?.deviceModel ?? '');
    final clean = rawDevice.trim();
    final device = (clean.isEmpty || clean.toLowerCase().contains('null'))
        ? 'Qurilma ulanmagan'
        : clean;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _fieldBorder),
        ),
        child: Row(
          children: [
            ChildAvatar(child: child, size: 48, showBorder: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _unb(16),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          device,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _pop(13, c: _dim),
                        ),
                      ),
                      if (battery != null) ...[
                        const SizedBox(width: 6),
                        Text('•', style: _pop(13, c: _dim)),
                        const SizedBox(width: 6),
                        Icon(_batteryIcon(battery), size: 15, color: _dim),
                        const SizedBox(width: 2),
                        Text('$battery%', style: _pop(13, c: _dim)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(SolarIconsOutline.altArrowRight, size: 20, color: _dim),
          ],
        ),
      ),
    );
  }
}

// ════════════ "+ Bola qo'shish" ════════════

class _AddChildButton extends StatelessWidget {
  const _AddChildButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _fieldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 22, color: Colors.white),
            const SizedBox(width: 10),
            Text("Bola qo'shish", style: _pop(15, w: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ════════════ "Akkount" varag'i (bola kartasi bosilganda) ════════════

Future<void> _showAccountSheet(
  BuildContext context,
  WidgetRef ref,
  Child child,
) async {
  // Sheet natija qaytaradi: 'qr' | 'reconnect' — ishlov TASHQI kontekstda
  // (sheet yopilgach uning contexti o'lik bo'ladi).
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _AccountSheet(child: child),
  );
  if (action == null || !context.mounted) return;

  if (action == 'qr') {
    await RepairQrDialog.show(
      context,
      childId: child.id,
      childName: child.name,
    );
    return;
  }
  if (action == 'reconnect') {
    // Oila kodi BIR MARTALIK — bola avval ulangan bo'lsa eski kod backend
    // tomonidan rad etiladi. Shuning uchun avval YANGI kod generatsiya
    // qilamiz, keyin ulanish varag'ini yangi kod bilan ochamiz.
    final result = await ref
        .read(childActionsProvider.notifier)
        .regenerateFamilyCode(child.id);
    if (!context.mounted) return;
    if (!result.isSuccess || result.data == null) {
      AppToast.error(context, "Yangi kod yaratib bo'lmadi. Qayta urining.");
      return;
    }
    await showConnectChildSheet(
      context,
      childId: child.id,
      initialChild: child.copyWith(familyCode: result.data),
    );
  }
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet({required this.child});

  final Child child;

  /// Backend faqat yoshni saqlaydi — taxminiy tug'ilgan yil ko'rsatiladi.
  String get _birthLabel {
    if (child.age <= 0) return '—';
    final now = DateTime.now();
    return '01.01.${now.year - child.age}';
  }

  @override
  Widget build(BuildContext context) {
    final phone = (child.phoneNumber?.isNotEmpty ?? false)
        ? child.phoneNumber!
        : '—';

    void openEdit() {
      Navigator.of(context).pop();
      context.push(AppRoutes.editChildPath(child.id), extra: child);
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ColoredBox(
        color: _sheetBg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Center(
                  child: Text(
                    'settings.rows.account.title'.tr(),
                    style: _unb(18, w: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 22),
                _InfoRow(
                  label: 'Bola ismi',
                  value: child.name,
                  onEdit: openEdit,
                ),
                const SizedBox(height: 18),
                _InfoRow(
                  label: 'Telefon nomeri',
                  value: phone,
                  onEdit: openEdit,
                ),
                const SizedBox(height: 18),
                _InfoRow(
                  label: "Tug'ilgan yili",
                  value: _birthLabel,
                  onEdit: openEdit,
                ),
                const SizedBox(height: 70),
                _SheetPillButton(
                  icon: SolarIconsOutline.qrCode,
                  label: 'QR kod generatsiya',
                  onTap: () => Navigator.of(context).pop('qr'),
                ),
                const SizedBox(height: 10),
                _SheetPillButton(
                  icon: SolarIconsOutline.restart,
                  label: 'Bolani qayta ulash',
                  onTap: () => Navigator.of(context).pop('reconnect'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sarlavha + qiymat + qalam (tahrirlash) qatori.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _pop(13, c: _dim)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _unb(17, w: FontWeight.w700),
              ),
            ),
            GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(SolarIconsBold.pen, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
      ],
    );
  }
}

/// Varaq pastidagi pill tugma (QR generatsiya / qayta ulash).
class _SheetPillButton extends StatelessWidget {
  const _SheetPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _fieldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: _pop(15, w: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ════════════ Orqaga tugmasi ════════════

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _fieldBorder),
        ),
        child: const Icon(
          SolarIconsOutline.arrowLeft,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}
