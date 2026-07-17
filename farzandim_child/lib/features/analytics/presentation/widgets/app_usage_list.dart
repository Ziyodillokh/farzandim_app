// ─────────────────────────────────────────────────────────────────────
// AppUsageList — Sprint 4.4.32 real Backend usage + limit + icon
//                (Parvoz NIGHT/GLASS redizayn)
// ─────────────────────────────────────────────────────────────────────
//
// `dailyUsageProvider` + `childAppLimitsProvider` merge:
//   - Top N ilova (totalTimeMs DESC)
//   - Har ilova uchun: icon (base64 yoki Material fallback), nom,
//     foydalanish vaqti, Parent limit (agar bor) + qolgan vaqt yoki
//     limit oshganligi belgisi.
//
// LOGIKA SAQLANGAN — faqat ko'rinish parvoz night/glass tokenlar

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/analytics/data/models/app_usage_entry.dart';
import 'package:farzandim_child/features/analytics/data/repositories/backend_analytics_repository.dart';
import 'package:farzandim_child/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/shared/widgets/app_icon_memory.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppUsageList extends ConsumerWidget {
  const AppUsageList({this.limit, super.key});

  /// Top-N (null → barchasi).
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(dailyUsageProvider);
    final limitsAsync = ref.watch(childAppLimitsProvider);
    final installedAsync = ref.watch(installedAppsMapProvider);

    return Container(
      decoration: parvozGlassFlat(radius: 16),
      child: usageAsync.when(
        loading: () => const _LoadingBox(),
        error: (_, __) => _EmptyBox(text: 'analytics.dataLoadError'.tr()),
        data: (day) {
          final limits = limitsAsync.valueOrNull ?? const <AppLimit>[];
          final installed =
              installedAsync.valueOrNull ?? const <String, InstalledAppMeta>{};

          // Parent panel bilan bir xil semantika: bugun ishlatilgan ilovalar
          // + ota-ona qo'ygan cheklov bor (lekin bugun ochilmagan) ilovalar.
          // Cheklovsiz va ochilmagan ilovalar chiqarib tashlanadi.
          final merged = _mergeUsageWithLimits(
            usage: day.apps,
            limits: limits,
            installed: installed,
          );

          if (merged.isEmpty) {
            return _EmptyBox(text: 'analytics.noUsageToday'.tr());
          }

          final visible = limit != null && limit! < merged.length
              ? merged.take(limit!).toList()
              : merged;
          final limitMap = <String, AppLimit>{
            for (final l in limits) l.packageName: l,
          };
          return Column(
            children: List.generate(visible.length, (i) {
              final app = visible[i];
              final lim = limitMap[app.packageName];
              return Column(
                children: [
                  _UsageRow(app: app, limit: lim),
                  if (i < visible.length - 1)
                    const Divider(
                      color: AppColors.parvozBorderStrong,
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              );
            }),
          );
        },
      ),
    );
  }

  /// Usage + cheklov ro'yxatlarini birlashtiradi.
  ///
  /// 1. Usage'dagi har bir ilova (bugun ≥ 0 ms) ro'yxatga kiradi.
  /// 2. Cheklov bor, lekin usage'da yo'q ilovalar 0 ms bilan qo'shiladi —
  ///    parent app `combineAppData()` semantikasi bilan moslashadi.
  /// 3. Sort: foydalanish vaqti DESC, keyin ilova nomi.
  List<AppUsageEntry> _mergeUsageWithLimits({
    required List<AppUsageEntry> usage,
    required List<AppLimit> limits,
    required Map<String, InstalledAppMeta> installed,
  }) {
    final seen = <String>{};
    final result = <AppUsageEntry>[];
    final limitedPkgs = {
      for (final lim in limits)
        if (lim.isActive) lim.packageName,
    };

    for (final entry in usage) {
      // 1 daqiqadan kam ishlatilganlar ro'yxatni shishiradi — ko'rsatmaymiz.
      // Limiti borlar istisno: progress ko'rinib turishi kerak.
      if (entry.totalTimeMs < 60000 &&
          !limitedPkgs.contains(entry.packageName)) {
        continue;
      }
      seen.add(entry.packageName);
      // Real nomni installed-apps'dan ustun ko'ramiz — usage endpoint
      // bazan packageName qaytaradi.
      final meta = installed[entry.packageName];
      final realName = (meta?.appName.isNotEmpty ?? false)
          ? meta!.appName
          : entry.appName;
      result.add(
        AppUsageEntry(
          packageName: entry.packageName,
          appName: _displayName(entry.packageName, realName),
          totalTimeMs: entry.totalTimeMs,
          lastTimeUsed: entry.lastTimeUsed,
          iconBase64: entry.iconBase64 ?? meta?.iconBase64,
          iconUrl: entry.iconUrl ?? meta?.iconUrl,
        ),
      );
    }

    for (final lim in limits) {
      if (!lim.isActive) continue;
      if (seen.contains(lim.packageName)) continue;
      seen.add(lim.packageName);
      final meta = installed[lim.packageName];
      result.add(
        AppUsageEntry(
          packageName: lim.packageName,
          appName: _displayName(lim.packageName, meta?.appName ?? ''),
          totalTimeMs: 0,
          lastTimeUsed: DateTime.fromMillisecondsSinceEpoch(0),
          iconBase64: meta?.iconBase64,
          iconUrl: meta?.iconUrl,
        ),
      );
    }

    result.sort((a, b) {
      final byUsage = b.totalTimeMs.compareTo(a.totalTimeMs);
      if (byUsage != 0) return byUsage;
      return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
    });
    return result;
  }

  /// Ko'rsatiladigan nom — system/texnik paketlar (`com.sec...launcher`,
  /// `com.google.android.gms`...) o'rniga do'stona nom; noma'lum paket bo'lsa
  /// oxirgi segmentdan toza nom (`com.foo.bar` → "Bar"). Real ilova nomi bor
  /// bo'lsa o'sha qoladi.
  static String _displayName(String pkg, String rawName) {
    final clean = rawName.trim();
    // 1) Real do'stona nom (paket emas) — o'shani.
    if (clean.isNotEmpty && !clean.contains('.') && clean != pkg) {
      return clean;
    }
    // 2) Tanilgan system paketlar.
    final friendly = _systemNames[pkg.toLowerCase()];
    if (friendly != null) return friendly;
    // 3) Noma'lum paket — oxirgi segmentni tozalab, bosh harf katta.
    final src = clean.isEmpty ? pkg : clean;
    final seg = src.split('.').last.replaceAll('_', ' ').trim();
    if (seg.isEmpty) return src;
    return seg[0].toUpperCase() + seg.substring(1);
  }

  static Map<String, String> get _systemNames => {
    'com.sec.android.app.launcher': 'analytics.sysHome'.tr(),
    'com.android.launcher': 'Bosh ekran',
    'com.miui.home': 'Bosh ekran',
    'com.google.android.apps.nexuslauncher': 'Bosh ekran',
    'com.google.android.gms': 'analytics.sysGoogleServices'.tr(),
    'com.google.android.gsf': 'Google xizmatlari',
    'com.android.settings': 'analytics.sysSettings'.tr(),
    'com.android.systemui': 'analytics.sysSystem'.tr(),
    'com.android.vending': 'Play Market',
    'com.android.chrome': 'Chrome',
    'com.google.android.youtube': 'YouTube',
    'com.android.phone': 'analytics.sysPhone'.tr(),
    'com.samsung.android.dialer': 'Telefon',
    'com.google.android.dialer': 'Telefon',
    'com.android.camera': 'analytics.sysCamera'.tr(),
    'com.sec.android.app.camera': 'Kamera',
    'com.android.gallery3d': 'analytics.sysGallery'.tr(),
    'com.sec.android.gallery3d': 'Galereya',
  };
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.app, required this.limit});

  final AppUsageEntry app;
  final AppLimit? limit;

  @override
  Widget build(BuildContext context) {
    final subtitle = _buildSubtitle();
    final trailing = _buildTrailing();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _AppIcon(app: app),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.appName.isEmpty ? app.packageName : app.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.parvozText,
                  ),
                ),
                const SizedBox(height: 4),
                subtitle,
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    final lim = limit;
    if (lim == null) {
      return Text(
        app.formattedTime,
        style: const TextStyle(fontSize: 13, color: AppColors.parvozTextDim),
      );
    }

    if (lim.isFullBlock) {
      return Row(
        children: [
          Icon(AppIcons.block, size: 13, color: AppColors.error),
          SizedBox(width: 4),
          Text(
            'analytics.blockedBadge'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final usedMs = app.totalTimeMs;
    final limitMs = lim.dailyLimitMs;
    final percent = limitMs == 0 ? 0.0 : (usedMs / limitMs).clamp(0.0, 1.0);
    final remainingMs = limitMs - usedMs;
    final overLimit = remainingMs <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${app.formattedTime} / ${_formatMs(limitMs)}',
              style: TextStyle(
                fontSize: 13,
                color: overLimit ? AppColors.error : AppColors.parvozTextDim,
                fontWeight: overLimit ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (overLimit) ...[
              const SizedBox(width: 6),
              const Icon(AppIcons.warning, size: 13, color: AppColors.error),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent.toDouble(),
            minHeight: 4,
            backgroundColor: AppColors.parvozBorderStrong,
            valueColor: AlwaysStoppedAnimation<Color>(
              overLimit ? AppColors.error : AppColors.parvozGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildTrailing() {
    final lim = limit;
    if (lim == null || lim.isFullBlock) return null;
    final remainingMs = lim.dailyLimitMs - app.totalTimeMs;
    if (remainingMs <= 0) {
      return Text(
        'analytics.timeUp'.tr(),
        style: TextStyle(
          fontSize: 12,
          color: AppColors.error,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'analytics.remaining'.tr(),
          style: TextStyle(fontSize: 10, color: AppColors.parvozTextDim),
        ),
        Text(
          _formatMs(remainingMs),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.parvozGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static String _formatMs(int ms) {
    final m = ms ~/ 60000;
    final h = m ~/ 60;
    final mm = m % 60;
    if (h == 0) return '${mm}m';
    if (mm == 0) return '${h}s';
    return '${h}s ${mm}m';
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app});

  final AppUsageEntry app;

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    final radius = BorderRadius.circular(10);

    // 1. iconUrl (MinIO signed URL)
    if (app.iconUrl != null && app.iconUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          app.iconUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _Fallback(app: app, size: size),
        ),
      );
    }

    // 2. iconBase64 — cache'langan dekod + cacheWidth (jank fix).
    if (app.iconBase64 != null && app.iconBase64!.isNotEmpty) {
      return AppIconMemory(
        base64: app.iconBase64,
        size: size,
        borderRadius: radius,
        fallback: _Fallback(app: app, size: size),
      );
    }

    // 3. Fallback
    return _Fallback(app: app, size: size);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.app, required this.size});
  final AppUsageEntry app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _colorForPackage(app.packageName);
    final icon = _iconForApp(app.packageName, app.appName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.18)!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: Colors.white, size: size * 0.52)
          : Text(
              _initialsForName(
                app.appName.isEmpty ? app.packageName : app.appName,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  static String _initialsForName(String name) {
    final clean = name.split('.').last;
    if (clean.isEmpty) return '?';
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Tanilgan ilova/paket uchun Material ikon — real ikon yetib kelmaganida
  /// harf o'rniga taniqli belgi (zamonaviy ko'rinish).
  static IconData? _iconForApp(String pkg, String name) {
    final p = pkg.toLowerCase();
    final n = name.toLowerCase();
    bool has(String s) => p.contains(s) || n.contains(s);
    if (has('launcher') || has('home') || has('bosh ekran')) {
      return Icons.home_rounded;
    }
    if (has('settings') || has('sozlama') || has('parametr')) {
      return Icons.settings_rounded;
    }
    if (has('gms') || has('gsf') || has('google xizmat')) {
      return Icons.cloud_done_rounded;
    }
    if (has('systemui') || has('tizim')) return Icons.android_rounded;
    if (has('telegram')) return Icons.send_rounded;
    if (has('whatsapp')) return Icons.chat_rounded;
    if (has('instagram')) return Icons.camera_alt_rounded;
    if (has('youtube')) return Icons.play_circle_fill_rounded;
    if (has('chrome') || has('browser') || has('internet')) {
      return Icons.public_rounded;
    }
    if (has('vending') || has('play market') || has('market')) {
      return Icons.shop_rounded;
    }
    if (has('camera') || has('kamera')) return Icons.photo_camera_rounded;
    if (has('gallery') || has('galereya') || has('photos')) {
      return Icons.photo_library_rounded;
    }
    if (has('dialer') || has('phone') || has('telefon')) {
      return Icons.call_rounded;
    }
    if (has('music') || has('musiqa')) return Icons.music_note_rounded;
    if (has('game') || has('parvoz')) return Icons.sports_esports_rounded;
    return null;
  }

  /// Paket nomidan deterministik rang (hash → palette).
  static Color _colorForPackage(String pkg) {
    const palette = [
      AppColors.catIndigo,
      AppColors.catPurple,
      AppColors.catPink,
      AppColors.danger,
      AppColors.warning,
      AppColors.catEmerald,
      AppColors.catBlue,
      AppColors.catTeal,
    ];
    final hash = pkg.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(
        child: CircularProgressIndicator(color: AppColors.parvozGreen),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: AppColors.parvozTextDim),
        ),
      ),
    );
  }
}
