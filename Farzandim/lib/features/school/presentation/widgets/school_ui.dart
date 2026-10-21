// ─────────────────────────────────────────────────────────────────────
// school_ui — maktab ekranlarining umumiy qismlari (Parvoz dizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Sahifa skeleti (fon + sarlavha + pastki tugma), markazlashgan xabar
// (bo'sh / xato / mavjud emas), yuklanish va maktab
// logosi. Tokenlar `settings_screen` bilan bir xil: fon #00060A,
// karta #1A1F23, hairline oq 12%.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _chipBg = Color(0xFF1B2128); // ikon/logo foni
const _dim = Color(0x99FFFFFF); // oq 60%

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.5,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Orqaga: stekda sahifa bo'lsa — pop; aks holda (push bosilgan yoki
/// havola orqali to'g'ridan-to'g'ri ochilgan) — dashboard.
void schoolBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.dashboard);
  }
}

/// Maktab sahifasi skeleti: fon, sarlavha, mazmun va (ixtiyoriy) pastga
/// yopishgan qism — klaviatura ochilsa uning ustida turadi.
class SchoolScaffold extends StatelessWidget {
  const SchoolScaffold({
    required this.title,
    required this.body,
    this.footer,
    super.key,
  });

  final String title;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            SchoolHeader(title: title),
            Expanded(child: body),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// Sarlavha — 56x56 orqaga tugma + markazdagi nom (sozlamalar uslubi).
class SchoolHeader extends StatelessWidget {
  const SchoolHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'common.back'.tr(),
            child: GestureDetector(
              onTap: () => schoolBack(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cardBorder),
                ),
                child: const Icon(
                  SolarIconsOutline.arrowLeft,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _unb(20, w: FontWeight.w500, ls: -0.6),
                ),
              ),
            ),
          ),
          // O'ng tomonda ko'rinmas muvozanat (sarlavha markazda tursin).
          const SizedBox(width: 56, height: 56),
        ],
      ),
    );
  }
}

/// Markazlashgan xabar: ikon doirasi + sarlavha + izoh + ixtiyoriy tugma.
/// O'zi aylantiriladi — `RefreshIndicator` ichida ham ishlaydi.
class SchoolMessageView extends StatelessWidget {
  const SchoolMessageView({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _card,
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Icon(icon, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(title, textAlign: TextAlign.center, style: _unb(18)),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: _pop(14, c: _dim),
                    ),
                  ],
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 24),
                    ParvozPrimaryButton(
                      label: actionLabel,
                      onPressed: onAction,
                      showArrow: false,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yuklash xatosi: sabab (tarmoq, server, ...) + "Qayta urinish".
/// Backend'da bo'lim yo'q (404 `code`siz) — "hozircha mavjud emas",
/// qayta urinish tugmasisiz.
class SchoolErrorView extends StatelessWidget {
  const SchoolErrorView({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = SchoolFailure.fromError(
      error ?? const SchoolFailure(SchoolFailureKind.unknown),
    );
    if (failure.isUnavailable) {
      return SchoolMessageView(
        icon: SolarIconsBold.squareAcademicCap,
        title: 'school.title'.tr(),
        message: failure.messageKey.tr(),
      );
    }
    return SchoolMessageView(
      icon: SolarIconsBold.wifiRouterMinimalistic,
      title: 'school.errorTitle'.tr(),
      message: failure.messageKey.tr(),
      actionLabel: 'common.retry'.tr(),
      onAction: onRetry,
    );
  }
}

/// Birinchi yuklanish.
class SchoolLoadingView extends StatelessWidget {
  const SchoolLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: ParvozColors.blue),
    );
  }
}

/// Maktab logosi (bir marta dekodlangan baytlar, `cacheWidth` bilan);
/// logo yo'q yoki buzuq bo'lsa — akademik qalpoq ikoni.
class SchoolLogo extends StatelessWidget {
  const SchoolLogo({required this.school, this.size = 44, super.key});

  final SchoolInfo? school;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = school?.logoBytes;
    final fallback = Icon(
      SolarIconsBold.squareAcademicCap,
      size: size * 0.5,
      color: Colors.white,
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: bytes == null
          ? fallback
          : Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
