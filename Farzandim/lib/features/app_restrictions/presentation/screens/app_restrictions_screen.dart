import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_usage_repository.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/screen_time_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ─── Parvoz "Ekran vaqti" tokenlari ───
const Color _bg = Color(0xFF00060A);
const Color _card = Color(0x12FFFFFF); // oq 7%
const Color _border = Color(0x1AFFFFFF); // oq 10%
const Color _darkCard = Color(0xFF1A1F23); // chart foni
const Color _dim = Color(0x8CFFFFFF); // oq 55%
const Color _blue = Color(0xFF216BFF);
const Color _blueMuted = Color(0x66216BFF); // o'tgan kunlar bari
const Color _red = Color(0xFFFF5A5D);
const Color _green = Color(0xFF3AE800);

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double? ls,
}) {
  return GoogleFonts.unbounded(
    fontSize: size,
    fontWeight: w,
    color: c,
    letterSpacing: ls,
    height: 1.4,
  );
}

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) {
  return GoogleFonts.poppins(
    fontSize: size,
    fontWeight: w,
    color: c,
    height: 1.5,
  );
}

/// Bugungi SOATLIK ekran vaqti (24 ta ms) — detal ekran grafigi uchun.
/// Backend `/app-usage/hourly` (barcha ilovalar `hourlyMs` yig'indisi).
/// Haftalik provider bilan bir xil polling: ekran ochiq ekan har 30 sek.
final hourlyChildUsageProvider = StreamProvider.autoDispose
    .family<List<int>, String>((ref, childId) async* {
      final isAuthed = ref.watch(
        backendAuthProvider.select((s) => s is AuthAuthenticated),
      );
      if (!isAuthed) {
        yield List<int>.filled(24, 0);
        return;
      }
      keepAliveFor(ref, const Duration(minutes: 2));
      final repo = ref.watch(backendAppUsageRepositoryProvider);
      yield* pollFetchStream<List<int>>(
        ref,
        interval: const Duration(seconds: 30),
        fetch: () => repo.getHourlyTotals(childId: childId),
      );
    });

/// Bola ekran vaqti ekrani (Parvoz dizayni) — jami + trend + KUNLIK soatlik
/// bar grafik + eng ko'p ishlatilgan ilovalar. "Nazorat siyosati" → ilova
/// cheklovlari (app-limits). Route: `/app-restrictions/:childId`.
///
/// Grafik KUNLIK: X o'qi 24 soat (0..24), Y o'qi 60 daqiqa — bugungi kun
/// davomidagi soatlik taqsimot (`hourlyChildUsageProvider`). Trend = bugun
/// vs kecha (haftalik totallardan).
class AppRestrictionsScreen extends ConsumerWidget {
  const AppRestrictionsScreen({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayMs = ref.watch(todayScreenTimeMsProvider(childId));
    final weekly = ref.watch(weeklyChildUsageProvider(childId)).valueOrNull;
    final days = [...?weekly]..sort((a, b) => a.date.compareTo(b.date));
    // Bugungi soatlik taqsimot (24 ta ms) — kunlik grafik uchun.
    final hourly =
        ref.watch(hourlyChildUsageProvider(childId)).valueOrNull ??
        List<int>.filled(24, 0);
    final apps =
        ref.watch(todayUsageProvider(childId)).valueOrNull?.filteredApps ??
        const <AppUsageEntry>[];
    final trend = _trendPercent(days, todayMs);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header: orqaga + sarlavha + spacer ──
              Row(
                children: [
                  _BackButton(onTap: () => context.pop()),
                  Expanded(
                    child: Center(
                      child: Text(
                        'dashboard.screenTimeLabel'.tr(),
                        style: _unb(22, ls: -0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
              const SizedBox(height: 16),

              // ── Jami vaqt + trend ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'dashboard.screenTimeTotal'.tr(),
                            style: _pop(14, c: _dim),
                          ),
                          const SizedBox(height: 2),
                          Text(_fmtDur(todayMs), style: _unb(28, ls: -0.8)),
                        ],
                      ),
                    ),
                    if (trend != null) _TrendChip(percent: trend),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Kunlik soatlik bar grafik (X: 24 soat, Y: 60 daqiqa) ──
              _HourlyChart(hourlyMs: hourly),
              const SizedBox(height: 4),

              // ── Eng ko'p ishlatilgan ilovalar ──
              if (apps.isNotEmpty) _AppListCard(apps: apps),
              if (apps.isNotEmpty) const SizedBox(height: 4),

              // ── Nazorat siyosati → ilova cheklovlari ──
              _PolicyButton(
                onTap: () => context.push(AppRoutes.appLimitsPath(childId)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bugun vs kecha foiz farqi (musbat = ko'paygan). Kecha ma'lumoti yo'q yoki
/// 0 bo'lsa null (trend ko'rsatilmaydi).
int? _trendPercent(List<DailyUsageTotal> days, int todayMs) {
  if (days.length < 2) return null;
  final yesterdayMs = days[days.length - 2].totalMs;
  if (yesterdayMs <= 0) return null;
  return (((todayMs - yesterdayMs) / yesterdayMs) * 100).round();
}

String _fmtDur(int ms) {
  if (ms <= 0) return '0 min';
  final totalMin = ms ~/ 60000;
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (h > 0) return '${h}s $m min';
  return '$m min';
}

// ════════════════════════ HEADER TUGMA ════════════════════════

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: const Icon(
          SolarIconsOutline.arrowLeft,
          size: 24,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ════════════════════════ TREND CHIP ════════════════════════

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    // Ko'paygan = qizil (ko'proq ekran vaqti yomon), kamaygan = yashil.
    final up = percent > 0;
    final color = up ? _red : _green;
    final icon = up
        ? SolarIconsBold.arrowRightUp
        : SolarIconsBold.arrowRightDown;
    final sign = up ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _darkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '$sign$percent% ${'dashboard.screenTimeVsYesterday'.tr()}',
            style: _pop(13, w: FontWeight.w500, c: color),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ KUNLIK SOATLIK GRAFIK ════════════════════════

/// Bugungi ekran vaqti grafigi — **X o'qi 24 soat (0..24), Y o'qi 60 daqiqa**.
/// Har bar = o'sha soatdagi ekran vaqti (daqiqa); joriy soat yorqin ko'k.
class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.hourlyMs});

  /// 24 ta ms qiymat (har soat uchun).
  final List<int> hourlyMs;

  static const double _chartH = 180;
  static const double _yAxisW = 34;
  static const int _maxMin = 60; // Y o'qi QAT'IY 60 daqiqa
  static const int _maxMs = _maxMin * 60000;

  @override
  Widget build(BuildContext context) {
    // Joriy soat (Toshkent UTC+5) — shu bar yorqin ko'k bilan belgilanadi.
    final nowHour = DateTime.now().toUtc().add(const Duration(hours: 5)).hour;

    // O'rtacha (qizil ishora chizig'i) — faqat faol soatlar bo'yicha.
    final active = hourlyMs.where((m) => m > 0).toList();
    final avgMs = active.isEmpty
        ? 0.0
        : active.reduce((a, b) => a + b) / active.length;
    final avgFromTop = (_chartH * (1 - (avgMs / _maxMs))).clamp(0.0, _chartH);

    return Container(
      height: _chartH + 78,
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 14),
      decoration: BoxDecoration(
        color: _darkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: _chartH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y-o'qi — daqiqa shkalasi (60 / 30 / 0).
                SizedBox(
                  width: _yAxisW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_maxMin}m', style: _pop(12)),
                      Text('${_maxMin ~/ 2}m', style: _pop(12)),
                      Text('0', style: _pop(12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Grafik maydoni: grid + o'rtacha chiziq + 24 ta soatlik bar.
                Expanded(
                  child: Stack(
                    children: [
                      // Gorizontal grid (tepa/o'rta/past).
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _DashLine(color: Color(0x1AFFFFFF)),
                      ),
                      const Positioned(
                        top: _chartH / 2 - 0.5,
                        left: 0,
                        right: 0,
                        child: _DashLine(color: Color(0x1AFFFFFF)),
                      ),
                      const Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _DashLine(color: Color(0x1AFFFFFF)),
                      ),
                      // O'rtacha (qizil) ishora chizig'i + yorlig'i.
                      if (active.isNotEmpty) ...[
                        Positioned(
                          top: avgFromTop,
                          left: 0,
                          right: 0,
                          child: const _DashLine(color: _red),
                        ),
                        Positioned(
                          top: (avgFromTop - 16).clamp(0.0, _chartH),
                          right: 0,
                          child: Text(
                            _avgLabel(avgMs),
                            style: _pop(11, w: FontWeight.w500, c: _red),
                          ),
                        ),
                      ],
                      // 24 ta soatlik bar (0..23).
                      Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var h = 0; h < 24; h++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  child: _Bar(
                                    heightFrac: (hourlyMs[h] / _maxMs).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                    chartH: _chartH,
                                    isToday: h == nowHour,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // X-o'qi: 0 6 12 18 24 (soat).
          Padding(
            padding: const EdgeInsets.only(left: _yAxisW + 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final h in const [0, 6, 12, 18, 24])
                  Text('$h', style: _pop(11, c: _dim)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _avgLabel(double avgMs) {
  final h = avgMs / 3600000;
  if (h >= 1) return '${h.toStringAsFixed(h >= 10 ? 0 : 1)}s';
  return '${(avgMs / 60000).round()}m';
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.heightFrac,
    required this.chartH,
    required this.isToday,
  });

  final double heightFrac;
  final double chartH;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    // Bo'sh soat (0) — ko'rinmas; aks holda min 2px "ustun".
    final h = heightFrac <= 0 ? 0.0 : (heightFrac * chartH).clamp(2.0, chartH);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: isToday ? _blue : _blueMuted,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(8),
            bottom: Radius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Punktir gorizontal chiziq (grid / o'rtacha).
class _DashLine extends StatelessWidget {
  const _DashLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final count = (c.maxWidth / 11).floor().clamp(1, 200);
        return Row(
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: 8,
                height: 1,
                margin: const EdgeInsets.only(right: 3),
                color: color,
              ),
          ],
        );
      },
    );
  }
}

// ════════════════════════ ILOVALAR RO'YXATI ════════════════════════

class _AppListCard extends StatelessWidget {
  const _AppListCard({required this.apps});

  final List<AppUsageEntry> apps;

  @override
  Widget build(BuildContext context) {
    final shown = apps.take(8).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            Row(
              children: [
                _AppIcon(app: shown[i]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${i + 1}. ${shown[i].appName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _unb(16, ls: -0.4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(shown[i].formattedTime, style: _pop(14, c: _dim)),
              ],
            ),
            if (i < shown.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: Color(0x14FFFFFF)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 36px to'rtburchak ilova ikonkasi (URL → base64 → harf fallback).
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app});

  final AppUsageEntry app;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(11);
    final url = app.iconUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: br,
        child: CachedNetworkImage(
          imageUrl: url,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _letter(br),
        ),
      );
    }
    final b64 = app.iconBase64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: br,
          child: Image.memory(
            base64Decode(b64),
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {
        // base64 buzuq — harf fallback.
      }
    }
    return _letter(br);
  }

  Widget _letter(BorderRadius br) {
    final ch = app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?';
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _card, borderRadius: br),
      child: Text(ch, style: _pop(14, w: FontWeight.w600)),
    );
  }
}

// ════════════════════════ NAZORAT SIYOSATI ════════════════════════

class _PolicyButton extends StatelessWidget {
  const _PolicyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _border),
        ),
        child: Text(
          'dashboard.screenTimePolicy'.tr(),
          style: _pop(16, w: FontWeight.w500),
        ),
      ),
    );
  }
}
