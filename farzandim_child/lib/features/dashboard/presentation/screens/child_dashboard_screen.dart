// ─────────────────────────────────────────────────────────────────────
// ChildDashboardScreen — "Asosiy" (Figma "Main" 1:1, Parvoz ko'k)
// ─────────────────────────────────────────────────────────────────────
//
// Tuzilishi (Figma Design6):
//   • Header: "Asosiy" (Unbounded Medium 24) + chat + bildirishnoma (rounded
//     kvadrat tugmalar, oq 10% fon)
//   • 3 stat chip GURUHLANGAN pill (assimetrik burchak) + rangli glow:
//     🔥 streak (amber) | 👟 qadamlar (ko'k) | 🪙 DON (yashil)
//   • "Yangi testlar" banner — solid #173654 + "Batafsil" + test rasmi
//   • "Yangi kitoblar" karta (3 muqova + 250 DON)
//   • "Trend videolar" gorizontal lenta (thumbnail #173654)
//
// Real ma'lumot: gamificationProfileProvider (don/streak), todayStepsProvider,
// recommendedBooksProvider, topVideosProvider, activeContestsProvider,
// unreadNotificationsCountProvider. Backend bo'sh bo'lsa PREVIEW kartalar.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/notifications/presentation/screens/notifications_screen.dart';
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/uninstall_protection_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/app_update/presentation/widgets/update_banner.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audio_player_provider.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_banner_carousel.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_conditions_sheet.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/location/presentation/widgets/location_enable_modal.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════ Figma tokenlar ════════════
const _bg = Color(0xFF00060A); // sahifa foni
const _blue = Color(0xFF216BFF); // brend / DON badge / glow
const _glass = Color(0x14FFFFFF); // karta foni — oq ~8%
const _glassBorder = Color(0x24FFFFFF); // karta chegarasi — oq ~14%
const _dim = Color(0x99FFFFFF); // oq 60%
const _muted = Color(0xFFA6A8A9); // xira kulrang (ko'rishlar)
const _amber = Color(0xFFFFAE00); // streak
const _stepsBlue = Color(0xFF66B3FF); // qadamlar
const _coinGreen = Color(0xFF41DD7A); // DON tanga
const _panel = Color(0xFF173654); // banner / video thumbnail solid
const _videoBg = Color(0xFF0E141C); // video yuklanayotgandagi neytral fon

// ── Header ikonlari: Figma Make'dagi AYNAN SVG (Solar "Chat Round Line" /
// "Bell Bing", Bold). Font glif o'rniga vektor — piksel-aniq mos keladi. ──
const _chatRoundLineSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">'
    '<path fill-rule="evenodd" clip-rule="evenodd" fill="#FFFFFF" '
    'd="M10 20C15.5228 20 20 15.5228 20 10C20 4.47715 15.5228 0 10 0C4.47715 0 0 '
    '4.47715 0 10C0 11.5997 0.37562 13.1116 1.04346 14.4525C1.22094 14.8088 '
    '1.28001 15.2161 1.17712 15.6006L0.58151 17.8267C0.32295 18.793 1.20701 '
    '19.677 2.17335 19.4185L4.39939 18.8229C4.78393 18.72 5.19121 18.7791 '
    '5.54753 18.9565C6.88837 19.6244 8.4003 20 10 20ZM6 11.25C5.58579 11.25 5.25 '
    '11.5858 5.25 12C5.25 12.4142 5.58579 12.75 6 12.75H11.5C11.9142 12.75 12.25 '
    '12.4142 12.25 12C12.25 11.5858 11.9142 11.25 11.5 11.25H6ZM5.25 8.5C5.25 '
    '8.0858 5.58579 7.75 6 7.75H14C14.4142 7.75 14.75 8.0858 14.75 8.5C14.75 '
    '8.9142 14.4142 9.25 14 9.25H6C5.58579 9.25 5.25 8.9142 5.25 8.5Z"/></svg>';

const _bellBingSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 20">'
    '<path fill="#FFFFFF" d="M5.35179 18.2418C6.19288 19.311 7.51418 20 9 '
    '20C10.4858 20 11.8071 19.311 12.6482 18.2418C10.2264 18.57 7.77357 18.57 '
    '5.35179 18.2418Z"/>'
    '<path fill-rule="evenodd" clip-rule="evenodd" fill="#FFFFFF" '
    'd="M15.7491 7.7041V7C15.7491 3.13401 12.7274 0 9 0C5.27256 0 2.25087 '
    '3.13401 2.25087 7V7.7041C2.25087 8.54909 2.00972 9.37517 1.5578 '
    '10.0782L0.450359 11.8012C-0.561176 13.3749 0.211046 15.5139 1.97036 '
    '16.0116C6.57274 17.3134 11.4273 17.3134 16.0296 16.0116C17.789 15.5139 '
    '18.5612 13.3749 17.5496 11.8012L16.4422 10.0782C15.9903 9.37517 15.7491 '
    '8.54909 15.7491 7.7041ZM9 3.25C9.41421 3.25 9.75 3.58579 9.75 4V8C9.75 '
    '8.41421 9.41421 8.75 9 8.75C8.58579 8.75 8.25 8.41421 8.25 8V4C8.25 3.58579 '
    '8.58579 3.25 9 3.25Z"/></svg>';

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w700,
  Color c = Colors.white,
  double ls = -0.5,
}) => GoogleFonts.unbounded(
  fontSize: s,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.2,
);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.4);

String _fmtNum(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

String _fmtViews(int v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return '$v';
}

/// Bola bosh ekrani — "Asosiy".
class ChildDashboardScreen extends ConsumerStatefulWidget {
  /// `ChildDashboardScreen` konstruktor.
  const ChildDashboardScreen({super.key});

  @override
  ConsumerState<ChildDashboardScreen> createState() =>
      _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen>
    with WidgetsBindingObserver {
  Timer? _autoRefreshTimer;

  /// GPS "yoqing" modali shu sessiyada ko'rsatildimi (spam bo'lmasin —
  /// xizmat yoqilgach `false`ga qaytadi, keyingi o'chishda yana so'raladi).
  bool _locationModalShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_guardPermissions);
    Future.microtask(_guardLocationService);
    Future.microtask(_updateStreak);
    // Qadamni ochilishda darhol yangilaymiz (telefon soniga yaqin bo'lsin).
    Future.microtask(() {
      final stepSvc = ref.read(stepCounterServiceProvider);
      if (stepSvc != null) unawaited(stepSvc.syncNow());
    });
    // "O'chirishni taqiqlash" — app ochilganda siyosatni qo'llaymiz (kerak
    // bo'lsa Device Admin dialogini ko'rsatamiz — foreground shart).
    Future.microtask(() => _syncUninstallProtection(allowPrompt: true));
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      // Bola Sozlamadan GPS'ni yoqib qaytgan bo'lishi mumkin — qayta tekshiramiz
      // (yoqilgan bo'lsa modal qayta chiqmaydi, o'chiq bo'lsa bir marta so'raymiz).
      unawaited(_guardLocationService());
    }
  }

  void _refresh() {
    if (!mounted) return;
    // Qadamni telefon soniga yaqinlashtirish — Health Connect'dan HAQIQIY
    // jamini darhol tortamiz (davriy 5 daqiqani kutmasdan). onStepsUpdated
    // UI keshini yangilaydi, quyidagi invalidate esa yangi qiymatni ko'rsatadi.
    final stepSvc = ref.read(stepCounterServiceProvider);
    if (stepSvc != null) unawaited(stepSvc.syncNow());
    ref
      ..invalidate(todayStepsProvider)
      ..invalidate(backendContestsProvider);
    // Deaktivatsiya (ota-ona o'chirsa) darhol; faollashtirish dialogi YO'Q
    // (loop bo'lmasin — dialog faqat app ochilganda, initState'da).
    unawaited(_syncUninstallProtection(allowPrompt: false));
  }

  /// "O'chirishni taqiqlash" siyosatini backend'dan o'qib qo'llaydi. Bola
  /// admin'ni o'chirgan bo'lsa (native bayroq) — ota-onaga xabar yuboradi.
  Future<void> _syncUninstallProtection({required bool allowPrompt}) async {
    final childId = ref.read(pairingStateProvider).childId;
    if (childId == null) return;
    final repo = ref.read(backendDevicePolicyRepositoryProvider);
    final policy = await repo.getDevicePolicy(childId);
    await uninstallProtectionService.apply(
      policy.blockUninstall,
      allowPrompt: allowPrompt,
    );
    // Bola himoyani o'chirgan bo'lsa → ota-onaga "himoya o'chirildi" push.
    final deactivated = await uninstallProtectionService
        .consumeDeactivatedFlag();
    if (deactivated) {
      unawaited(repo.reportUninstallGuardDisabled(childId));
    }
  }

  Future<void> _updateStreak() async {
    final pairing = ref.read(pairingStateProvider);
    final parentUid = pairing.parentUid;
    final childId = pairing.childId;
    if (parentUid == null || childId == null) return;
    try {
      await ref
          .read(xpServiceProvider)
          .updateStreakOnDailyOpen(parentUid: parentUid, childId: childId);
    } catch (_) {}
  }

  Future<void> _guardPermissions() async {
    if (kIsWeb) return;
    final usageService = UsageStatsService();
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    final usageGranted = await usageService.hasPermission();
    final overlayGranted = await usageService.hasOverlayPermission();
    final allGranted =
        batteryStatus.isGranted && usageGranted && overlayGranted;
    if (!allGranted && mounted) context.go('/permission-setup');
  }

  /// GPS xizmati (qurilma-darajada) O'CHIQ bo'lsa — bolaga "Joylashuvni yoqing"
  /// modalini DARHOL ko'rsatadi (ota-ona push'ini kutmasdan). Joylashuv RUXSATI
  /// yo'q bo'lsa tegmaymiz — u onboarding/permission oqimining ishi.
  Future<void> _guardLocationService() async {
    if (kIsWeb) return;
    final perm = await Geolocator.checkPermission();
    final granted = perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
    if (!granted) return;
    if (await Geolocator.isLocationServiceEnabled()) {
      // Yoqilgan — keyingi o'chishda yana so'ray olishimiz uchun flagni
      // tozalaymiz.
      _locationModalShown = false;
      return;
    }
    // OTA-ONAGA XABAR: bola joylashuvni o'chirdi. Ota-ona push oladi va
    // u yerdan "Joylashuvni yoqishni so'rash"ni bosa oladi.
    unawaited(_reportLocationDisabled());
    if (_locationModalShown || !mounted) return;
    _locationModalShown = true;
    await LocationEnableModal.show(context);
  }

  /// "Joylashuv o'chirildi" xabarini ota-onaga yuboradi — 6 SOATDA BIR MARTA.
  ///
  /// Throttle shart: aks holda bola GPS'ni o'chirib qo'ysa, har ilova
  /// ochilishida/qaytishida ota-onaga push ketardi (spam).
  Future<void> _reportLocationDisabled() async {
    final childId = ref.read(pairingStateProvider).childId;
    if (childId == null || childId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'location.disabledReportedAt';
      final last = prefs.getInt(key) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < const Duration(hours: 6).inMilliseconds) return;
      await prefs.setInt(key, now);
      await ref
          .read(backendDevicePolicyRepositoryProvider)
          .reportLocationDisabled(childId);
    } catch (e) {
      debugPrint('reportLocationDisabled xato: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairing = ref.watch(pairingStateProvider);
    if (!pairing.isPaired) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      bottomNavigationBar: const ChildBottomNavigation(),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _blue,
          backgroundColor: _panel,
          onRefresh: () async => _refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 18, 16, 122 + bottomInset),
            children: const [
              UpdateBanner(),
              _Header(),
              SizedBox(height: 14),
              _StatChipsRow(),
              SizedBox(height: 8),
              _Banner(),
              SizedBox(height: 10),
              _AudiobooksSection(),
              SizedBox(height: 14),
              _VideosSection(),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════ Header: "Asosiy" + chat + bell ════════════

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    return Row(
      children: [
        Expanded(
          child: Text(
            'nav.home'.tr(),
            style: _unb(24, w: FontWeight.w600, ls: -0.72),
          ),
        ),
        _SquareIconButton(
          svg: _chatRoundLineSvg,
          onTap: () => context.push('/chats'),
        ),
        const SizedBox(width: 12),
        _SquareIconButton(
          svg: _bellBingSvg,
          showDot: unread > 0,
          onTap: () => showNotificationsSheet(context),
        ),
      ],
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.svg,
    required this.onTap,
    this.showDot = false,
  });

  final String svg;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _glass,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: 22,
              height: 22,
              child: SvgPicture.string(svg, fit: BoxFit.contain),
            ),
          ),
          if (showDot)
            Positioned(
              right: 10,
              top: 8,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF1616),
                  shape: BoxShape.circle,
                  border: Border.all(color: _bg, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════ 3 stat chip GURUHLANGAN (streak / qadamlar / DON) ════════════

class _StatChipsRow extends ConsumerWidget {
  const _StatChipsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // DON/STREAK — HAQIQIY manba backend `ChildProfile` (Prisma), Firestore
    // EMAS. `gamificationProfileProvider` (Firestore) — qadam/audiokitob/
    // test kabi real mukofotlar hech qachon yozilmaydigan eski/o'lik oqim,
    // shu sababli bu yerda DON deyarli doim noto'g'ri/0 ko'rinardi. Backend
    // real-time (WS `profile:updated`) — `backendGamificationProvider`.
    final backend = ref.watch(backendGamificationProvider).valueOrNull;
    final profile = ref.watch(gamificationProfileProvider).valueOrNull;
    // PREVIEW: real qiymat 0 bo'lsa Figma'dagi namuna (bola faollik boshlagach
    // avtomatik realga almashadi).
    final rawStreak = backend?.streak ?? profile?.streak ?? 0;
    final rawDon = backend?.don ?? profile?.don ?? 0;
    final rawSteps = ref.watch(todayStepsProvider).valueOrNull ?? 0;
    final streak = rawStreak > 0 ? rawStreak : 7;
    // DON — REAL qiymat (bola gamifikatsiyada yiqqan). Mock (1250) OLIB
    // TASHLANDI: bola app'da DON hamma joyda real ko'rinsin.
    final don = rawDon;
    // Qadam REAL — preview yo'q (ota-ona bilan mos bo'lishi uchun).
    final steps = rawSteps;

    const outer = Radius.circular(24);
    const inner = Radius.circular(12);
    // Chiplar bosilsa Statistika sahifasi ochiladi.
    return GestureDetector(
      onTap: () => context.push('/statistics'),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              tint: _amber,
              radii: const BorderRadius.only(
                topLeft: outer,
                bottomLeft: outer,
                topRight: inner,
                bottomRight: inner,
              ),
              icon: const Icon(
                Icons.local_fire_department_rounded,
                size: 26,
                color: _amber,
              ),
              value: 'statistics.daysCount'.tr(namedArgs: {'days': '$streak'}),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _StatChip(
              tint: _stepsBlue,
              radii: const BorderRadius.all(inner),
              icon: Image.asset(
                'assets/icons/ic_steps.png',
                width: 26,
                height: 26,
              ),
              value: _fmtNum(steps),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _StatChip(
              tint: _coinGreen,
              radii: const BorderRadius.only(
                topRight: outer,
                bottomRight: outer,
                topLeft: inner,
                bottomLeft: inner,
              ),
              icon: const Icon(
                Icons.monetization_on_rounded,
                size: 26,
                color: _coinGreen,
              ),
              value: _fmtNum(don),
              trailing: const _DonBadge(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonBadge extends StatelessWidget {
  const _DonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('DON', style: _pop(9, w: FontWeight.w700)),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.tint,
    required this.radii,
    required this.icon,
    required this.value,
    this.trailing,
  });

  final Color tint;
  final BorderRadius radii;
  final Widget icon;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _glass,
        borderRadius: radii,
        border: Border.all(color: _glassBorder),
      ),
      child: Stack(
        children: [
          // Rangli glow orb (ikon ortida).
          Positioned(left: -4, top: -4, child: _GlowOrb(color: tint)),
          Positioned(right: -10, bottom: -12, child: _GlowOrb(color: tint)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                icon,
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: _unb(15, w: FontWeight.w600, ls: -0.48),
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 4),
                      trailing!,
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Yumshoq rangli glow (stat ikon / banner bezagi ortida).
class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

// ════════════ "Yangi testlar" — test banner karuseli ════════════

class _Banner extends ConsumerWidget {
  const _Banner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeContestsProvider);
    if (active.isEmpty) return const _EmptyTestsBanner();
    // Faol testlar karuseli — markazda bitta, chetlar peek, har 5s avto.
    return TestBannerCarousel(
      tests: active,
      onTap: (t) => _openTest(context, t),
    );
  }

  void _openTest(BuildContext context, ContestModel c) {
    // Karuselda faqat FAOL testlar — shartlar sheet → quiz.
    HapticFeedback.selectionClick();
    showTestConditionsSheet(
      context,
      c,
      (contest) => context.push('/contest-quiz', extra: contest),
    );
  }
}

/// Faol test yo'q — "tez orada" fallback banner (bosilsa Testlar sahifasi).
class _EmptyTestsBanner extends StatelessWidget {
  const _EmptyTestsBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/contests'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 164,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _glassBorder),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: 18,
              child: Opacity(
                opacity: 0.9,
                child: Image.asset(
                  'assets/icons/ic_tests.png',
                  width: 128,
                  height: 128,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 120, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'dashboard.newTests'.tr(),
                    style: _unb(20, w: FontWeight.w600, ls: -0.6),
                  ),
                  const SizedBox(height: 4),
                  Text('dashboard.newTestsSoon'.tr(), style: _pop(14, c: _dim)),
                  const Spacer(),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _glass,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _glassBorder),
                    ),
                    child: Text(
                      'common.details'.tr(),
                      style: _pop(12, w: FontWeight.w500),
                    ),
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

// ════════════ "Yangi audiokitoblar" ════════════

class _AudiobooksSection extends ConsumerWidget {
  const _AudiobooksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Admin paneldan yuklangan eng oxirgi 3 ta audiokitob (dinamik).
    final books = ref.watch(newestAudiobooksProvider).take(3).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'dashboard.newAudiobooks'.tr(),
            onTap: () => context.push('/audiobooks'),
          ),
          const SizedBox(height: 16),
          if (books.isEmpty)
            // PREVIEW: backend'da audiokitob yo'q — namunaviy muqovalar.
            const Row(
              children: [
                Expanded(
                  child: _MockBookCard(
                    title: 'Buyuk\nsarguzasht',
                    color: Color(0xFFD96C2C),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _MockBookCard(
                    title: 'Oy sari\nparvoz',
                    color: Color(0xFF1F3A5F),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _MockBookCard(
                    title: 'Oltin\nertaklar',
                    color: Color(0xFFF2C21B),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                for (var i = 0; i < books.length; i++) ...[
                  Expanded(child: _AudiobookCard(book: books[i])),
                  if (i < books.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _AudiobookCard extends ConsumerWidget {
  const _AudiobookCard({required this.book});

  final AudiobookModel book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      // Bosilsa audiokitob o'ynatiladi (MiniAudioPlayer chiqadi).
      onTap: () => ref.read(audioPlayerProvider.notifier).play(book),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 0.74,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: book.coverUrl.isNotEmpty
                  ? Image.network(
                      book.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _CoverFallback(
                        title: book.title,
                        color: book.coverColor,
                      ),
                    )
                  : _CoverFallback(title: book.title, color: book.coverColor),
            ),
          ),
          const SizedBox(height: 8),
          _PricePill(don: book.xpReward),
        ],
      ),
    );
  }
}

/// "N DON" pill (real DON — book.xpReward) + ko'k DON badge.
class _PricePill extends StatelessWidget {
  const _PricePill({required this.don});

  final int don;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$don', style: _unb(12, w: FontWeight.w600, ls: -0.36)),
        const SizedBox(width: 4),
        const _DonBadge(),
      ],
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: _pop(11, w: FontWeight.w600),
      ),
    );
  }
}

// ════════════ "Trend videolar" ════════════

class _VideosSection extends ConsumerWidget {
  const _VideosSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(topVideosProvider);
    // Karta balandligi shrift-masshtabga moslashadi (katta masshtabda meta
    // qatori o'sganda overflow bo'lmasin): thumbnail 199 + oraliq 10 + meta.
    final ts = MediaQuery.textScalerOf(context);
    final stripH =
        209 + (ts.scale(16) * 1.4 + ts.scale(13) * 1.4 + 4).clamp(44.0, 110.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'dashboard.trendVideos'.tr(),
          onTap: () => context.push('/videos'),
        ),
        const SizedBox(height: 12),
        if (videos.isEmpty)
          // PREVIEW: backend'da video yo'q — namunaviy kartalar.
          SizedBox(
            height: stripH,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: const [
                _MockVideoCard(
                  title: 'Jamp challenge',
                  views: '169K',
                  color: Color(0xFFD64B12),
                ),
                SizedBox(width: 12),
                _MockVideoCard(
                  title: 'Multfilm olami',
                  views: '96K',
                  color: Color(0xFF2E7D5B),
                ),
                SizedBox(width: 12),
                _MockVideoCard(
                  title: 'Qiziq tajribalar',
                  views: '54K',
                  color: Color(0xFF5B4B8A),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: stripH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _VideoCard(video: videos[i]),
            ),
          ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});

  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/video-player', extra: video),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VideoThumb(
              child: video.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      video.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          ColoredBox(color: video.thumbnailColor),
                    )
                  : ColoredBox(color: video.thumbnailColor),
            ),
            const SizedBox(height: 10),
            _VideoMeta(title: video.title, views: _fmtViews(video.views)),
          ],
        ),
      ),
    );
  }
}

/// Video thumbnail — 300×199, toza rounded karta (chegara yo'q, neytral fon).
class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 199,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Neytral to'q fon (faqat rasm yuklanmaguncha ko'rinadi) — ko'k rim yo'q.
        color: _videoBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 24,
                color: Color(0xFFF9F9F9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Video meta — oq avatar + Poppins sarlavha + ko'z + ko'rishlar (#A6A8A9).
class _VideoMeta extends StatelessWidget {
  const _VideoMeta({required this.title, required this.views});

  final String title;
  final String views;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              title.isNotEmpty ? title[0].toUpperCase() : '?',
              style: _pop(16, w: FontWeight.w700, c: _bg),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(16, w: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: _muted,
                    ),
                    const SizedBox(width: 4),
                    Text(views, style: _pop(13, c: _muted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════ PREVIEW kartalar (backend bo'sh bo'lganda) ════════════

/// Namunaviy kitob muqovasi — rangli fon + nom + "250 DON" pill.
class _MockBookCard extends StatelessWidget {
  const _MockBookCard({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 0.74,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, Color.lerp(color, Colors.black, 0.35)!],
              ),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: _unb(12, w: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // PREVIEW namuna (backend kitob yo'q) — namunaviy DON.
        const _PricePill(don: 250),
      ],
    );
  }
}

/// Namunaviy video kartasi — rangli thumbnail + play + avatar + ko'rishlar.
class _MockVideoCard extends StatelessWidget {
  const _MockVideoCard({
    required this.title,
    required this.views,
    required this.color,
  });

  final String title;
  final String views;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VideoThumb(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, Color.lerp(color, Colors.black, 0.4)!],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _VideoMeta(title: title, views: views),
        ],
      ),
    );
  }
}

// ════════════ Bo'lim sarlavhasi (title + chevron) ════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: _unb(20, w: FontWeight.w600, ls: -0.6)),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 24,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}
