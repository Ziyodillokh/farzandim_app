// «Qanday boshlaymiz?» (`/start`) — farzand ham, maktab ham yo'q yangi ota-ona
// uchun bir marta. Ikki yo'l: maktab bergan kod / QR bilan maktabga ulanish
// (farzandning telefoni shart emas) yoki farzand telefonini Parvoz Growth
// bilan ulash. Ikkinchisini keyin ham qo'shish mumkin; «Keyinroq» — ilova
// ochiladi, takror so'ralmaydi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/home/domain/home_landing.dart';
import 'package:farzandim/features/settings/presentation/plan_gate.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  static Future<void> _markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kHomeStartSeenKey, true);
    } on Object catch (e) {
      debugPrint('[home] start belgisi saqlanmadi: ${e.runtimeType}');
    }
  }

  Future<void> _school(BuildContext context) async {
    unawaited(HapticFeedback.selectionClick());
    await _markSeen();
    if (!context.mounted) return;
    final linked = await context.push<bool>(AppRoutes.schoolLink);
    if ((linked ?? false) && context.mounted) context.go(AppRoutes.school);
  }

  Future<void> _phone(BuildContext context, WidgetRef ref) async {
    unawaited(HapticFeedback.selectionClick());
    await _markSeen();
    if (context.mounted) guardAddChild(context, ref);
  }

  Future<void> _later(BuildContext context) async {
    await _markSeen();
    if (context.mounted) context.go(AppRoutes.school);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ParvozColors.bg,
      body: Stack(
        children: [
          const Positioned(
            top: -150,
            left: 0,
            right: 0,
            child: Center(child: ParvozTopGlow()),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              children: [
                Center(
                  child: SvgPicture.asset(
                    'assets/icons/parvoz_logo_mark.svg',
                    width: 56,
                    height: 56,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'home.start.title'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.unbounded(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'home.start.subtitle'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    color: Colors.white.withValues(alpha: .65),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                StartOptionCard(
                  icon: SolarIconsBold.squareAcademicCap,
                  color: ParvozColors.blue,
                  title: 'home.start.schoolTitle'.tr(),
                  body: 'home.start.schoolBody'.tr(),
                  points: [
                    'home.start.schoolPoint1'.tr(),
                    'home.start.schoolPoint2'.tr(),
                  ],
                  action: 'home.start.schoolAction'.tr(),
                  onTap: () => unawaited(_school(context)),
                ),
                const SizedBox(height: 14),
                StartOptionCard(
                  icon: SolarIconsBold.smartphone,
                  color: const Color(0xFF22C55E),
                  title: 'home.start.phoneTitle'.tr(),
                  body: 'home.start.phoneBody'.tr(),
                  points: [
                    'home.start.phonePoint1'.tr(),
                    'home.start.phonePoint2'.tr(),
                  ],
                  action: 'home.start.phoneAction'.tr(),
                  onTap: () => unawaited(_phone(context, ref)),
                ),
                const SizedBox(height: 18),
                Text(
                  'home.start.both'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: .5),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () => unawaited(_later(context)),
                    child: Text(
                      'home.start.later'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: .8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Katta tanlov kartasi: rangli plita, sarlavha, izoh, ikki nuqta va
/// harakat qatori. Bo'sh holatlarda ham ishlatiladi.
class StartOptionCard extends StatelessWidget {
  const StartOptionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
    this.points = const [],
    super.key,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final List<String> points;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $action',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: .16),
                  Colors.white.withValues(alpha: .04),
                ],
              ),
              border: Border.all(color: color.withValues(alpha: .35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: color.withValues(alpha: .22),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: .35),
                            blurRadius: 18,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.unbounded(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: .75),
                    height: 1.5,
                  ),
                ),
                for (final point in points) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          SolarIconsBold.checkCircle,
                          size: 16,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          point,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            color: Colors.white.withValues(alpha: .85),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: color,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        action,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
