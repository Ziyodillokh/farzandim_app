// ─────────────────────────────────────────────────────────────────────
// ProfileScreen — "Profil" (Figma 1:1, Parvoz night)
// ─────────────────────────────────────────────────────────────────────
//
// Tuzilishi (Figma):
//   • Header: ← kvadrat tugma + markazda katta avatar + ⚙ sozlamalar;
//     orqa fonda xira skuter naqshlari (reyting sahifasidagi kabi)
//   • Ism (Unbounded) + "Qurilma • 🔋 N%" qatori
//   • 3 stat chip: 🔥 N kun / 👟 qadamlar / 💎 DON (ko'k DON pill bilan)
//   • "Yutuqlar" paneli: sarlavha + "NN/100", 3 ustunli grid —
//     olti burchakli medal (ochilgan) yoki rangli qulf (yopiq)
//
// Real: gamificationProfileProvider (don/streak/yutuqlar), todayStepsProvider,
// pairing (ism), childAvatarUrlProvider. Bo'sh bo'lsa PREVIEW (Figma raqamlari).
// LOGIKA SAQLANGAN: yangi yutuq unlock bo'lsa confetti + toast.

import 'dart:ui' show ImageFilter;

import 'package:battery_plus/battery_plus.dart';
import 'package:confetti/confetti.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/gamification/data/models/achievement.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Figma tokenlar (yangi Parvoz sahifalari bilan izchil) ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _glass = Color(0x14FFFFFF);
const _glassBorder = Color(0x24FFFFFF);
const _dim = Color(0x99FFFFFF);
const _panel = Color(0xFF10151C);
const _tile = Color(0xFF0B1017);

const _amber = Color(0xFFF2B233);
const _stepBlue = Color(0xFF3B82F6);
const _green = Color(0xFF22C55E);
const _purple = Color(0xFF8B5CF6);
const _orange = Color(0xFFF2811D);
const _red = Color(0xFFE23F32);

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w700,
  Color c = Colors.white,
  double ls = -0.4,
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
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.35);

String _fmtNum(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// Qurilma nomi + batareya foizi. Aniqlab bo'lmasa PREVIEW (Figma).
final _deviceLineProvider = FutureProvider<(String, int)>((ref) async {
  var model = 'Iphone 16 pro'; // PREVIEW (Figma)
  var battery = 98; // PREVIEW (Figma)
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final a = await DeviceInfoPlugin().androidInfo;
      model = '${a.brand} ${a.model}';
    }
  } catch (_) {}
  try {
    battery = await Battery().batteryLevel;
  } catch (_) {}
  return (model, battery);
});

/// Yutuqlar grid'i elementi (real yoki preview).
class _BadgeSpec {
  const _BadgeSpec(
    this.label,
    this.color, {
    this.icon,
    this.asset,
    this.unlocked = false,
    this.title,
    this.desc,
  });
  final String label;
  final Color color;
  final IconData? icon;

  /// Foydalanuvchi bergan tayyor medal PNG (bo'lsa, hex chizilmaydi).
  final String? asset;
  final bool unlocked;

  /// Bosilganda ochiladigan oynadagi sarlavha/tavsif.
  final String? title;
  final String? desc;
}

// PREVIEW yutuqlar — 12 katak. Bola hali hech narsa yutmagan bo'lsa HAMMASI
// QULFLANGAN ko'rinadi (avval 6 tasi hardcode `unlocked: true` edi → "hamma
// yutuq ochiq bo'lib qolgan" bug'i). Real yutuq unlock bo'lganda `else`
// shoxida katalogdan chinakam holat bilan ko'rsatiladi.
const _previewBadges = [
  _BadgeSpec(
    '1-kitob',
    _purple,
    asset: 'assets/icons/badge_book1.png',
    title: 'Birinchi kitob yakunlandi!',
    desc:
        "Tabriklaymiz! Siz birinchi kitobingizni oxirigacha o'qib, "
        "yangi yutuqni qo'lga kiritdingiz.",
  ),
  _BadgeSpec(
    '7 kun uzluksiz',
    _orange,
    asset: 'assets/icons/badge_7kun.png',
    title: '7 kun uzluksiz!',
    desc:
        "Tabriklaymiz! Siz 7 kun uzluksiz shug'ullanib, "
        "yangi yutuqni qo'lga kiritdingiz.",
  ),
  _BadgeSpec(
    'Math TOP-100',
    _green,
    asset: 'assets/icons/badge_top100.png',
    title: 'Math TOP-100!',
    desc:
        "Tabriklaymiz! Siz matematika bo'yicha eng yaxshi "
        '100 talik ichiga kirdingiz.',
  ),
  _BadgeSpec(
    '10-kitob',
    _red,
    asset: 'assets/icons/badge_book10.png',
    title: '10 ta kitob yakunlandi!',
    desc:
        "Tabriklaymiz! Siz 10 ta kitobni oxirigacha o'qib, "
        "yangi yutuqni qo'lga kiritdingiz.",
  ),
  _BadgeSpec(
    '100 kun',
    _amber,
    asset: 'assets/icons/badge_100kun.png',
    title: '100 kun uzluksiz!',
    desc:
        "Tabriklaymiz! Siz 100 kun uzluksiz shug'ullanib, "
        "yangi yutuqni qo'lga kiritdingiz.",
  ),
  _BadgeSpec(
    'Math TOP-10',
    _stepBlue,
    asset: 'assets/icons/badge_top10.png',
    title: 'Math TOP-10!',
    desc:
        "Tabriklaymiz! Siz matematika bo'yicha eng yaxshi "
        '10 talik ichiga kirdingiz.',
  ),
  _BadgeSpec(
    '7 kun uzluksiz',
    _orange,
    title: "7 kun yutug'i",
    desc:
        "Bu yutuqni qo'lga kiritish uchun siz 7 kun uzluksiz "
        "shug'ullanishingiz kerak",
  ),
  _BadgeSpec(
    'Math TOP-100',
    _green,
    title: "Math TOP-100 yutug'i",
    desc:
        "Bu yutuqni qo'lga kiritish uchun siz matematika bo'yicha "
        'TOP-100 ga kirishingiz kerak',
  ),
  _BadgeSpec(
    '1-kitob',
    _purple,
    title: "1 - kitob yutug'i",
    desc:
        "Bu yutuqni qo'lga kiritish uchun siz bitta kitobni "
        'yakunlashingiz kerak',
  ),
  _BadgeSpec(
    'Math TOP-10',
    _stepBlue,
    title: "Math TOP-10 yutug'i",
    desc:
        "Bu yutuqni qo'lga kiritish uchun siz matematika bo'yicha "
        'TOP-10 ga kirishingiz kerak',
  ),
  _BadgeSpec(
    '10-kitob',
    _purple,
    title: "10 - kitob yutug'i",
    desc:
        "Bu yutuqni qo'lga kiritish uchun siz 10 ta kitobni "
        'yakunlashingiz kerak',
  ),
  _BadgeSpec(
    '100 kun',
    _orange,
    title: "100 - kun yutug'i",
    desc:
        "Bu yutuqni qo'lga kiritish uchun siz 100 kun uzluksiz "
        "shug'ullanishingiz kerak",
  ),
];

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  List<String> _previousAchievementIds = const [];
  bool _initialLoaded = false;
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Yangi yutuq unlock bo'lsa — confetti + toast (LOGIKA SAQLANGAN).
    ref.listen(gamificationProfileProvider, (prev, next) {
      final profile = next.valueOrNull;
      if (profile == null) return;
      if (!_initialLoaded) {
        _previousAchievementIds = profile.unlockedAchievements;
        _initialLoaded = true;
        return;
      }
      final newIds = profile.unlockedAchievements
          .where((id) => !_previousAchievementIds.contains(id))
          .toList();
      if (newIds.isNotEmpty) {
        _previousAchievementIds = profile.unlockedAchievements;
        _confetti.play();
        HapticFeedback.heavyImpact();
        for (final id in newIds) {
          final a = Achievements.byId(id);
          if (a != null) _showAchievementToast(context, a);
        }
      }
    });

    final pairing = ref.watch(pairingStateProvider);
    final profile = ref.watch(gamificationProfileProvider).valueOrNull;
    final childName = pairing.childName ?? 'Akmal'; // PREVIEW (Figma)
    final avatarUrl = (pairing.childId != null && pairing.childId!.isNotEmpty)
        ? ref.watch(childAvatarUrlProvider(pairing.childId!)).valueOrNull
        : null;
    final device =
        ref.watch(_deviceLineProvider).valueOrNull ??
        ('Iphone 16 pro', 98); // PREVIEW (Figma)

    // DON va STREAK — HAQIQIY manba backend (`ChildProfile`): qadamdan kelgan
    // don (har 1000 qadam = 5 don) va faollik streak'i shu yerda. Backend
    // yuklanmagan bo'lsa (null) Firestore/preview'ga tushamiz.
    final backend = ref.watch(backendGamificationProvider).valueOrNull;
    final streak =
        backend?.streak ?? ((profile?.streak ?? 0) > 0 ? profile!.streak : 7);
    final don = backend?.don ?? ((profile?.don ?? 0) > 0 ? profile!.don : 1250);
    final rawSteps = ref.watch(todayStepsProvider).valueOrNull ?? 0;
    // Qadam REAL — preview yo'q (ota-ona bilan mos bo'lishi uchun).
    final steps = rawSteps;

    // Yutuqlar: real unlock bo'lsa katalogdan, bo'lmasa PREVIEW grid.
    final unlockedIds = profile?.unlockedAchievements ?? const <String>[];
    final List<_BadgeSpec> badges;
    final String countText;
    if (unlockedIds.isEmpty) {
      badges = _previewBadges;
      countText = '00/100';
    } else {
      final all = Achievements.all;
      badges = [
        for (final a in all)
          _BadgeSpec(
            a.titleKey.tr(),
            a.color,
            icon: a.icon,
            unlocked: unlockedIds.contains(a.id),
            title: a.titleKey.tr(),
            desc: a.descriptionKey.tr(),
          ),
      ];
      final n = badges.where((b) => b.unlocked).length;
      countText = '${n.toString().padLeft(2, '0')}/${all.length}';
    }

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              // Boshqa sahifalar bilan bir xil: kontent tepaga yopishmasin.
              padding: EdgeInsets.fromLTRB(16, 54, 16, 130 + bottomInset),
              child: Column(
                children: [
                  _Header(
                    avatarUrl: avatarUrl,
                    name: childName,
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/dashboard');
                      }
                    },
                    onSettings: () => context.push('/settings'),
                    onAvatarTap: () => context.push('/account-edit'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    childName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _unb(24),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(device.$1, style: _pop(13, c: _dim)),
                      Text('  •  ', style: _pop(13, c: _dim)),
                      const Icon(
                        Icons.battery_full_rounded,
                        size: 15,
                        color: _dim,
                      ),
                      const SizedBox(width: 2),
                      Text('${device.$2}%', style: _pop(13, c: _dim)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ── 3 stat chip (Figma) ──
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          tint: _amber,
                          icon: const Icon(
                            Icons.local_fire_department_rounded,
                            color: _amber,
                            size: 26,
                          ),
                          value: '$streak kun',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatChip(
                          tint: _stepBlue,
                          icon: Image.asset(
                            'assets/icons/ic_steps.png',
                            width: 26,
                            height: 26,
                          ),
                          value: _fmtNum(steps),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatChip(
                          tint: _green,
                          // Foydalanuvchi bergan DON ikoni.
                          icon: Image.asset(
                            'assets/icons/ic_don.png',
                            width: 26,
                            height: 26,
                          ),
                          value: _fmtNum(don),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _blue,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'DON',
                              style: _pop(9, w: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Yutuqlar paneli ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        // Saqlangan (yoqtirilgan) videolar sahifasiga o'tish.
                        GestureDetector(
                          onTap: () => context.push('/liked-videos'),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF4D6D)
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    color: Color(0xFFFF4D6D),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Saqlangan videolar',
                                    style: _unb(15),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white54,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Yutuqlar', style: _unb(16)),
                            Text(
                              countText,
                              style: _unb(14, w: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: badges.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.86,
                              ),
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () => _showBadgeSheet(context, badges[i]),
                            behavior: HitTestBehavior.opaque,
                            child: _BadgeTile(spec: badges[i]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: 1.5708,
              maxBlastForce: 20,
              minBlastForce: 8,
              emissionFrequency: 0.05,
              numberOfParticles: 25,
              gravity: 0.3,
              shouldLoop: false,
              colors: const [_blue, _amber, _orange, _green, _purple],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }

  void _showAchievementToast(BuildContext context, Achievement achievement) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: achievement.color,
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(achievement.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'gamification.achievementUnlockedTitle'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Header: ← + avatar + ⚙ (fonda xira skuterlar) ════════════

class _Header extends StatelessWidget {
  const _Header({
    required this.avatarUrl,
    required this.name,
    required this.onBack,
    required this.onSettings,
    required this.onAvatarTap,
  });

  final String? avatarUrl;
  final String name;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: Stack(
        children: [
          // Xira skuter naqshlari (Figma fonidagi kabi).
          const Positioned(top: 4, left: 66, child: _BgScooter(angle: -0.3)),
          const Positioned(
            top: 0,
            right: 84,
            child: _BgScooter(angle: 0.25, size: 20),
          ),
          const Positioned(
            bottom: 8,
            left: 24,
            child: _BgScooter(angle: 0.2, size: 22),
          ),
          const Positioned(
            bottom: 0,
            right: 30,
            child: _BgScooter(angle: -0.25, size: 24),
          ),
          const Positioned(
            top: 58,
            right: 116,
            child: _BgScooter(angle: 0.1, size: 18),
          ),
          // ← va ⚙ tugmalar.
          Align(
            alignment: Alignment.topLeft,
            child: _SquareBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
          ),
          Align(
            alignment: Alignment.topRight,
            child: _SquareBtn(icon: SolarIconsBold.settings, onTap: onSettings),
          ),
          // Markazda avatar.
          Align(
            child: GestureDetector(
              onTap: onAvatarTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x1FFFFFFF), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withValues(alpha: 0.20),
                      blurRadius: 30,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _Fallback(name: name),
                      )
                    : _Fallback(name: name),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF66B3FF),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: _unb(38, w: FontWeight.w800),
      ),
    );
  }
}

class _SquareBtn extends StatelessWidget {
  const _SquareBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _glass,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _glassBorder),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

/// Fon uchun xira, biroz burilgan skuter ikonchasi.
class _BgScooter extends StatelessWidget {
  const _BgScooter({required this.angle, this.size = 26});
  final double angle;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Icon(
        SolarIconsOutline.scooter,
        size: size,
        color: const Color(0x12FFFFFF),
      ),
    );
  }
}

// ════════════ Stat chip (🔥 / 👟 / 💎) ════════════

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.tint,
    required this.icon,
    required this.value,
    this.trailing,
  });

  final Color tint;
  final Widget icon;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        // Figma: chap-yuqoridan rang tusi kuchliroq, pastga so'nadi.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(tint.withValues(alpha: 0.26), _tile),
            Color.alphaBlend(tint.withValues(alpha: 0.06), _tile),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, maxLines: 1, style: _unb(16)),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════ Yutuq oynasi (bosilganda, Figma) ════════════

/// Nishon bosilganda EKRAN O'RTASIDA ochiladigan oyna (Figma): ochilgan
/// yutuq — tabrik, yopiq yutuq — shart matni.
void _showBadgeSheet(BuildContext context, _BadgeSpec spec) {
  HapticFeedback.selectionClick();
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF10151C),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: _BadgeSheet(spec: spec),
    ),
  );
}

class _BadgeSheet extends StatelessWidget {
  const _BadgeSheet({required this.spec});
  final _BadgeSpec spec;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Katta nishon + rangli nur ──
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Orqadagi yumshoq rangli tuman (Figma).
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: spec.color.withValues(alpha: 0.50),
                        blurRadius: 90,
                        spreadRadius: 26,
                      ),
                    ],
                  ),
                ),
                if (spec.unlocked && spec.asset != null)
                  Image.asset(spec.asset!, width: 150, height: 150)
                else if (spec.unlocked)
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: FittedBox(
                      child: _HexBadge(color: spec.color, icon: spec.icon),
                    ),
                  )
                else ...[
                  // Yopiq: xira rangli geksagon + oq qulf (Figma).
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: ClipPath(
                      clipper: _HexClipper(),
                      child: Container(
                        width: 120,
                        height: 132,
                        color: spec.color.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 44),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            spec.title ?? spec.label,
            textAlign: TextAlign.center,
            style: _unb(20),
          ),
          const SizedBox(height: 10),
          Text(
            spec.desc ?? '',
            textAlign: TextAlign.center,
            style: _pop(13.5, c: _dim),
          ),
          const SizedBox(height: 22),
          // ── Tugma: Qabul qilish / OK ──
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _glass,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _glassBorder),
              ),
              child: Text(
                spec.unlocked ? 'Qabul qilish' : 'OK',
                style: _pop(15, w: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════ Yutuq kataklari ════════════

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.spec});
  final _BadgeSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        // Katak ichida yutuq rangidagi YAQQOL nur (Figma) — markazdan
        // burchaklarga so'nadi, har katak o'z rangida ajralib turadi.
        gradient: RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 1.05,
          colors: [
            Color.alphaBlend(spec.color.withValues(alpha: 0.34), _tile),
            Color.alphaBlend(spec.color.withValues(alpha: 0.05), _tile),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (spec.unlocked && spec.asset != null)
            // Foydalanuvchi bergan tayyor medal rasmi.
            Image.asset(spec.asset!, width: 64, height: 64)
          else if (spec.unlocked)
            _HexBadge(color: spec.color, icon: spec.icon)
          else
            _LockBadge(color: spec.color),
          const SizedBox(height: 8),
          Text(
            spec.label,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: _pop(
              10.5,
              w: FontWeight.w500,
              c: spec.unlocked ? _dim : const Color(0x66FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

/// Olti burchakli medal — gradient + ichki kontur + ikon (Figma uslubi).
/// Tayyor PNG bo'lmagan (real katalog) yutuqlar uchun.
class _HexBadge extends StatelessWidget {
  const _HexBadge({required this.color, this.icon});
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(color, Colors.white, 0.35)!;
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rangli nur.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          // Tashqi geksagon (gradient).
          ClipPath(
            clipper: _HexClipper(),
            child: Container(
              width: 54,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [light, color, dark],
                ),
              ),
            ),
          ),
          // Ichki geksagon (to'qroq) — kontur effekti.
          ClipPath(
            clipper: _HexClipper(),
            child: Container(
              width: 44,
              height: 47,
              color: Color.lerp(color, Colors.black, 0.18),
            ),
          ),
          // Ikon.
          if (icon != null) Icon(icon, color: Colors.white, size: 24),
        ],
      ),
    );
  }
}

/// Yopiq yutuq — rangli yumaloq-kvadrat ichida qulf (Figma).
class _LockBadge extends StatelessWidget {
  const _LockBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        // Figma: qulf atrofida kuchli rangli bloom.
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.60),
            blurRadius: 28,
            spreadRadius: 3,
          ),
        ],
      ),
      child: const Icon(Icons.lock_rounded, color: Colors.white, size: 24),
    );
  }
}

/// Uchi tepada bo'lgan (pointy-top) olti burchak.
class _HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w / 2, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
