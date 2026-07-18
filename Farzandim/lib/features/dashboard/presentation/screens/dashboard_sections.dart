part of 'dashboard_screen.dart';

// ════════════════════════ HEADER ════════════════════════

/// Tepa qism — markaziy avatar (yashil online nuqta) + ism + qurilma/batareya,
/// chap-tepada Messenger, o'ng-tepada bildirishnoma. Orqada nozik ko'k yog'du
/// va jinsga qarab tarqoq ikonalar (o'g'il=mototsikl, qiz=kapalak).
class _Header extends ConsumerWidget {
  const _Header({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    // Har 30s "puls" — `isLiveOnline` (DateTime.now() asosli getter) vaqt
    // o'tishi bilan qayta hisoblansin. Avval hech kim bu tick'ni watch
    // qilmasdi → bola offline bo'lganda ham nuqta yashil "muzlab" qolardi
    // (list o'zgarmagani uchun rebuild bo'lmasdi).
    ref.watch(statusTickProvider);
    final online = child.isLiveOnline;
    final battery = child.deviceInfo?.batteryLevel;
    final device = (child.deviceModel != null && child.deviceModel!.isNotEmpty)
        ? child.deviceModel!
        : (child.deviceInfo?.deviceModel ?? '—');
    final scatter = child.gender == Gender.female
        ? 'assets/icons/scatter_butterfly.svg'
        : 'assets/icons/scatter_moto.svg';

    return SizedBox(
      // Balandlik kamaytirildi (300→250) — profil bilan pastdagi widgetlar
      // orasidagi bo'shliq ~28px bo'lib, ekranga ko'proq ma'lumot sig'adi.
      height: 250,
      width: double.infinity,
      child: Stack(
        children: [
          // Nozik ko'k yog'du (avatar ortida).
          const Align(
            alignment: Alignment(0, -0.45),
            child: IgnorePointer(child: _HeaderGlow()),
          ),
          // Tarqoq dekorativ ikonalar (jinsga qarab) — MARKAZDA (avatar
          // atrofida) ko'rinadi, chetlarga tomon radial fade bilan asta-sekin
          // YO'Q bo'ladi (dizayner: "pattern avatar atrofida bo'lsa yetadi,
          // chetlari qorayib yo'qolsin").
          Positioned.fill(
            child: IgnorePointer(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const RadialGradient(
                  center: Alignment(0, -0.28),
                  radius: 0.72,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0.0, 0.34, 1.0],
                ).createShader(rect),
                child: Stack(
                  children: [
                    for (final s in _scatterSpots)
                      Align(
                        alignment: s.$1,
                        child: Opacity(
                          opacity: s.$2,
                          child: SvgPicture.asset(
                            scatter,
                            width: 16,
                            height: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Messenger (chap-tepa).
          Positioned(
            top: 26,
            left: 16,
            child: _HeaderButton(
              icon: SvgPicture.asset(
                'assets/icons/ic_chat.svg',
                width: 20,
                height: 20,
              ),
              onTap: () => context.push(AppRoutes.chatList),
            ),
          ),
          // Bildirishnoma (o'ng-tepa) + o'qilmagan qizil nuqta.
          Positioned(
            top: 26,
            right: 16,
            child: _HeaderButton(
              icon: SvgPicture.asset(
                'assets/icons/ic_bell.svg',
                width: 18,
                height: 20,
              ),
              showDot: unread > 0,
              onTap: () => NotificationsSheet.show(context),
            ),
          ),
          // Markaziy profil.
          Positioned(
            top: 30,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Qora dumaloq border (gradientli) + uning ustida avatar.
                // Kichraytirildi (avatar 116→104, ramka 134→120) — dizayner
                // talabi (~100–110px).
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1A1F26),
                  ),
                  child: Center(
                    child: Stack(
                      children: [
                        ChildAvatar(child: child, size: 104, showBorder: false),
                        Positioned(
                          right: 5,
                          bottom: 5,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: online ? _online : _dim,
                              border: Border.all(
                                color: const Color(0xFF0B1119),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  child.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _unb(24, ls: -0.7),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        device,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _pop(14, c: _dim),
                      ),
                    ),
                    if (battery != null) ...[
                      const SizedBox(width: 8),
                      const _Dot(),
                      const SizedBox(width: 8),
                      Icon(_batteryIcon(battery), size: 16, color: _dim),
                      const SizedBox(width: 2),
                      Text('$battery%', style: _pop(14, c: _dim)),
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

/// Tarqoq ikonalar joylashuvi (fraksion alignment + opacity) — butun header
/// bo'ylab kichik va xira (barcha telefonlarda bir xil).
const List<(Alignment, double)> _scatterSpots = [
  (Alignment(-0.62, -0.62), 0.14),
  (Alignment(0.62, -0.74), 0.14),
  (Alignment(-0.84, -0.86), 0.08),
  (Alignment(0.86, -0.5), 0.08),
  (Alignment(-0.34, -0.94), 0.06),
  (Alignment(0.34, -0.96), 0.06),
  (Alignment(-0.74, 0.04), 0.1),
  (Alignment(0.78, -0.02), 0.1),
  (Alignment(-0.46, 0.34), 0.06),
  (Alignment(0.52, 0.3), 0.06),
  (Alignment(0.9, 0.28), 0.05),
  (Alignment(-0.9, 0.3), 0.05),
];

/// Nozik ko'k radial yog'du (avatar ortida).
class _HeaderGlow extends StatelessWidget {
  const _HeaderGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      height: 230,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [_blue.withValues(alpha: 0.22), const Color(0x00216BFF)],
          stops: const [0, 0.72],
        ),
      ),
    );
  }
}

IconData _batteryIcon(int level) {
  if (level >= 90) return SolarIconsBold.batteryFull;
  if (level >= 60) return SolarIconsBold.batteryHalf;
  if (level >= 40) return SolarIconsBold.batteryHalf;
  if (level >= 15) return SolarIconsBold.batteryLow;
  return SolarIconsBold.batteryLow;
}

/// Kichik kulrang ajratuvchi nuqta (qurilma/batareya orasida).
class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: _dim),
    );
  }
}

/// 44x44 header tugma (chat/bell SVG ikonkasi bilan).
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final Widget icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0x17FFFFFF),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _cardBorder),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            icon,
            if (showDot)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF3B3B),
                    border: Border.all(color: _bg, width: 1.2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════ SHISHA YUZA (secondary) ════════════════════════

/// Parvoz "secondary shisha" yuzasi (kontent o'lchamida) — pastki tugmalar
/// uchun (onboarding'dagi shisha tugma bilan bir xil til).
class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.radius = 999});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0x1FFFFFFF), Color(0x08FFFFFF)],
              ),
              border: Border.all(color: const Color(0x33FFFFFF), width: 1.2),
              borderRadius: br,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ KARTA KONTEYNERI ════════════════════════

/// Umumiy karta — flat shisha (oq 7% + nozik chegara + radius 24).
class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.minHeight,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(_radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: br, child: content);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: br,
        border: Border.all(color: _cardBorder),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight ?? 0),
        child: ClipRRect(
          borderRadius: br,
          child: Material(color: Colors.transparent, child: content),
        ),
      ),
    );
  }
}

// ════════════════════════ LOCATION CARD ════════════════════════

/// Bola hozir qayerda — geo-zona nomi yoki ko'cha (childPlaceProvider).
class _LocationCard extends ConsumerWidget {
  const _LocationCard({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(childPlaceProvider(child.id));
    final inZone = place.zoneName != null;
    final title = place.zoneName ?? 'dashboard.outdoors'.tr();
    final sub = place.street;
    // Bola OS'da joylashuv ruxsatini o'chirgan bo'lsa — "yoqishni so'rash".
    final locationOff = child.deviceInfo?.locationPermission == false;

    final card = _Card(
      onTap: () => context.push(AppRoutes.locationPath(child.id)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            inZone ? SolarIconsBold.home : SolarIconsBold.mapPoint,
            size: 26,
            color: Colors.white.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _unb(16, ls: -0.5),
                ),
                if (sub != null && sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(14, c: _dim),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            SolarIconsBold.altArrowRight,
            size: 22,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ],
      ),
    );

    if (!locationOff) return card;

    // Joylashuv o'chiq — karta ostida ogohlantirish + "yoqishni so'rash".
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              SolarIconsBold.dangerTriangle,
              size: 15,
              color: Color(0xFFFBBF24),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'location.enableRequest.offTitle'.tr(),
                style: _pop(12.5, c: const Color(0xFFFBBF24)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RequestLocationButton(childId: child.id, dense: true),
      ],
    );
  }
}

// ════════════════════════ EKRAN VAQTI KARTASI ════════════════════════

class _ScreenTimeCard extends ConsumerWidget {
  const _ScreenTimeCard({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = ref.watch(todayScreenTimeMsProvider(childId));
    final usage = ref.watch(todayUsageProvider(childId)).valueOrNull;
    // Faqat real ma'lumot — bola ilovasi yubormaguncha bo'sh holat.
    final apps = (usage?.filteredApps ?? const <AppUsageEntry>[])
        .take(3)
        .toList();
    // Bo'sh holatning ANIQ sababini ko'rsatish uchun bola holati (ulangan +
    // foydalanish ruxsati). "Ulanganda ko'rinadi" xabari bola allaqachon
    // ulangan bo'lsa noto'g'ri edi — endi haqiqiy sabab ko'rsatiladi.
    final child = ref.watch(childByIdProvider(childId));

    return _Card(
      minHeight: 220,
      onTap: () => context.push(AppRoutes.appRestrictionsPath(childId)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('dashboard.screenTimeLabel'.tr(), style: _pop(14, c: _dim)),
              const SizedBox(height: 2),
              Text(_fmtScreenTime(ms), style: _unb(22, ls: -0.6)),
            ],
          ),
          const SizedBox(height: 12),
          if (apps.isEmpty)
            Text(_screenTimeEmptyMsg(child), style: _pop(13, c: _dim))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < apps.length; i++) ...[
                  Row(
                    children: [
                      _AppIcon(app: apps[i]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${i + 1}. ${apps[i].appName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _pop(14),
                        ),
                      ),
                    ],
                  ),
                  if (i < apps.length - 1) const _Divider(),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Ekran vaqti kartasi bo'sh bo'lganda ANIQ sababni qaytaradi.
/// Ulanmagan → "Qurilma ulanmagan"; ulangan+ruxsatsiz → ruxsat so'rovi;
/// ulangan+ruxsat bor/noma'lum → "Ma'lumot yig'ilmoqda".
String _screenTimeEmptyMsg(Child? child) {
  if (child == null || !child.isConnected) {
    return 'dashboard.noDevice'.tr();
  }
  if (child.deviceInfo?.usagePermission == false) {
    return 'dashboard.screenTimeNoUsagePerm'.tr();
  }
  return 'dashboard.screenTimeCollecting'.tr();
}

String _fmtScreenTime(int ms) {
  if (ms <= 0) return '0 min';
  final totalMin = ms ~/ 60000;
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (h > 0) return '${h}s $m min';
  return '$m min';
}

/// 24px dumaloq ilova ikonkasi (URL → base64 → harf fallback).
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app});

  final AppUsageEntry app;

  @override
  Widget build(BuildContext context) {
    final url = app.iconUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _letter(),
        ),
      );
    }
    final b64 = app.iconBase64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(b64),
            width: 24,
            height: 24,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {
        // base64 buzuq — harf fallback.
      }
    }
    return _letter();
  }

  Widget _letter() {
    final ch = app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?';
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: _cardBg),
      child: Text(ch, style: _pop(11, w: FontWeight.w600)),
    );
  }
}

/// Nozik gorizontal ajratuvchi (karta ichidagi qatorlar orasida).
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    // Ko'rinarli ajratuvchi (dizayner: qatorlar orasi aniq ajralsin,
    // "rowlarda adashmaslik uchun"). Oq ~8% → ~14%.
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(height: 1, child: ColoredBox(color: Color(0x24FFFFFF))),
    );
  }
}

// ════════════════════════ XP / REYTING KARTASI ════════════════════════

class _XpCard extends ConsumerWidget {
  const _XpCard({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(childProfileProvider(child.id)).valueOrNull;
    // "DON balansi" kartasi — HAQIQIY DON (donBalance), `xp` EMAS. Avval `xp`
    // o'qilardi, shuning uchun qadam/video kabi DON-only mukofotlar (xpDelta=0)
    // bu yerda ko'rinmasdi ("DON qo'shilmayapti" shikoyati). Endi donBalance.
    final don = profile?.donBalance ?? 0;
    final lb = ref.watch(
      leaderboardProvider((childId: child.id, period: 'all', region: null)),
    );
    final rows = _leaderboardWindow(lb, child.id);

    return _Card(
      minHeight: 220,
      padding: const EdgeInsets.all(12),
      onTap: () => context.push(AppRoutes.childAchievementsPath(child.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('dashboard.donBalance'.tr(), style: _pop(14, c: _dim)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _fmtNumber(don),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _unb(22, ls: -0.6),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('DON', style: _pop(12, w: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text('dashboard.leaderboardEmpty'.tr(), style: _pop(13, c: _dim))
          else
            Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _LeaderboardRow(
                    entry: rows[i],
                    isMe: rows[i].childId == child.id,
                  ),
                  if (i < rows.length - 1) const _Divider(),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Bola atrofidagi reyting qatorlari (yuqori-bola-quyi), maks 3 ta.
List<LeaderboardEntry> _leaderboardWindow(LeaderboardState lb, String childId) {
  if (lb.initialLoading || lb.error) return const [];
  final all = lb.entries;
  if (all.isEmpty) {
    final me = lb.currentChild;
    return me != null ? [me] : const [];
  }
  final idx = all.indexWhere((e) => e.childId == childId);
  if (idx >= 0) {
    // Doim 3 qatorli oyna (bola markazda, chetlarda ham 3 ta) — 1-rasmdagidek
    // to'liq to'ldirilgan reyting, yuqorida katta bo'sh joy qolmasin.
    if (all.length <= 3) return all;
    var start = idx - 1;
    final maxStart = all.length - 3;
    if (start < 0) start = 0;
    if (start > maxStart) start = maxStart;
    return all.sublist(start, start + 3);
  }
  final out = <LeaderboardEntry>[];
  final me = lb.currentChild;
  if (me != null) out.add(me);
  for (final e in all) {
    if (out.length >= 3) break;
    if (e.childId != childId) out.add(e);
  }
  out.sort((a, b) => a.rank.compareTo(b.rank));
  return out.take(3).toList();
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.isMe});

  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    // Har bola uchun rasm (proxy) → default avatar (jingalak). Avval faqat
    // joriy bola avatar ko'rsatardi, boshqalari HARF edi (nomuvofiq).
    return Row(
      children: [
        RankingAvatar(
          childId: entry.childId,
          size: 24,
          gender: entry.gender,
          age: entry.age,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${entry.rank}. ${entry.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _pop(
              14,
              w: isMe ? FontWeight.w500 : FontWeight.w400,
              c: isMe ? const Color(0xFF508AFF) : Colors.white,
            ),
          ),
        ),
        // Bola qatorini belgilovchi ko'rsatkich — CHAPGA, bola ismiga qarab
        // ("sizning bolangiz shu yerda" degani). Dizayner talabi.
        if (isMe)
          Icon(
            SolarIconsBold.altArrowLeft,
            size: 16,
            color: const Color(0xFF508AFF).withValues(alpha: 0.8),
          ),
      ],
    );
  }
}

String _fmtNumber(int n) {
  // Minglikni bo'shliq bilan ajratish (1 250).
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ════════════════════════ KUNLIK QADAMLAR / RIVOJLANISH ════════════════════════
// Hafta kunlari qisqartmalari (Dushanba…Yakshanba).
const List<String> _kWeekLabels = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];

/// Bir hafta-kuni holati: bajarilgan / olov (streak) / muzlatilgan / bo'sh.
enum _DayState { done, fire, freeze, empty }

/// Kunlik qadamlar kartasi — nishon + "bugun / 10 000" + hafta trekeri.
/// REAL: backend `/weekly-report` steps (bola ilovasi yuboradi).
class _StepsCard extends ConsumerWidget {
  const _StepsCard({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklyStepsProvider(childId)).valueOrNull;
    const goal = 10000;
    final now = DateTime.now();
    String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
    final byDay = <String, int>{
      for (final d in weekly?.days ?? const <DailySteps>[])
        key(d.date): d.steps,
    };
    final steps = byDay[key(now)] ?? 0;
    // Joriy hafta (Du..Ya): qadam bo'lgan kun = done, qolgani empty.
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final days = [
      for (var i = 0; i < 7; i++)
        ((byDay[key(monday.add(Duration(days: i)))] ?? 0) > 0)
            ? _DayState.done
            : _DayState.empty,
    ];
    return _Card(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/icons/ic_steps.png', width: 44, height: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('dashboard.dailySteps'.tr(), style: _pop(14, c: _dim)),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(_fmtNumber(steps), style: _unb(22, ls: -0.6)),
                        Text(
                          ' / ${_fmtNumber(goal)}',
                          style: _unb(15, ls: -0.4, c: _dim),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(SolarIconsBold.altArrowRight, size: 20, color: _dim),
            ],
          ),
          const SizedBox(height: 16),
          _WeekTracker(states: days),
        ],
      ),
    );
  }
}

/// Kunlik rivojlanish (streak) kartasi — olovli nishon + "N kun" + hafta.
/// REAL: `childProfileProvider.streakDays` (backend gamification).
class _StreakCard extends ConsumerWidget {
  const _StreakCard({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(childProfileProvider(childId)).valueOrNull;
    final streak = profile?.streakDays ?? 0;
    // Joriy hafta (Du..Ya): streak oynasidagi kunlar olov, qolgani bo'sh.
    final now = DateTime.now();
    final todayIdx = now.weekday - 1; // 0=Du
    final days = [
      for (var i = 0; i < 7; i++)
        (i <= todayIdx && (todayIdx - i) < streak)
            ? _DayState.fire
            : _DayState.empty,
    ];
    return _Card(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/icons/badge_streak.png',
                width: 52,
                height: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'dashboard.dailyStreak'.tr(),
                      style: _pop(14, c: _dim),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'dashboard.streakDays'.tr(
                        namedArgs: {'count': '$streak'},
                      ),
                      style: _unb(22, ls: -0.6),
                    ),
                  ],
                ),
              ),
              const Icon(SolarIconsBold.altArrowRight, size: 20, color: _dim),
            ],
          ),
          const SizedBox(height: 16),
          _WeekTracker(states: days),
        ],
      ),
    );
  }
}

/// 7 kunlik gorizontal treker — har kun rounded PILL (kapsula) ichida.
/// Ikkala karta (qadamlar + rivojlanish) bir xil pill uslubini ishlatadi.
class _WeekTracker extends StatelessWidget {
  const _WeekTracker({required this.states});

  final List<_DayState> states;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          Expanded(
            child: _DayCircle(label: _kWeekLabels[i], state: states[i]),
          ),
          if (i < 6) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// Bitta kun kapsulasi — yorliq (tepada) + holat indikatori (pastda): ko'k
/// check / olov / muzlik / bo'sh punktir. Qorong'i rounded pill ichida.
class _DayCircle extends StatelessWidget {
  const _DayCircle({required this.label, required this.state});

  final String label;
  final _DayState state;

  @override
  Widget build(BuildContext context) {
    const dot = 26.0;
    Widget indicator;
    switch (state) {
      case _DayState.done:
        indicator = const DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: _blue),
          child: Icon(Icons.check_rounded, size: 15, color: Colors.white),
        );
      case _DayState.fire:
        indicator = DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF9F1C).withValues(alpha: 0.20),
          ),
          child: const Icon(
            Icons.local_fire_department_rounded,
            size: 15,
            color: Color(0xFFFF9F1C),
          ),
        );
      case _DayState.freeze:
        indicator = DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _blue.withValues(alpha: 0.20),
          ),
          child: const Icon(
            Icons.ac_unit_rounded,
            size: 14,
            color: Color(0xFF4FA8FF),
          ),
        );
      case _DayState.empty:
        indicator = const CustomPaint(painter: _DashRingPainter());
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, maxLines: 1, style: _pop(11, w: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(width: dot, height: dot, child: indicator),
        ],
      ),
    );
  }
}

/// Bo'sh kun uchun punktir doira.
class _DashRingPainter extends CustomPainter {
  const _DashRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 0.8;
    const dashes = 12;
    const sweep = 2 * 3.14159265 / dashes;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════ AMAL KARTASI ════════════════════════

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      minHeight: 120,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: _pop(15, w: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════ BOLA QO'SHISH (shisha) ════════════════════════

class _AddChildButton extends StatelessWidget {
  const _AddChildButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.addChild),
      behavior: HitTestBehavior.opaque,
      child: _Glass(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  SolarIconsBold.addCircle,
                  size: 22,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  'dashboard.emptyState.addButton'.tr(),
                  style: _pop(16, w: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ PASTKI BAR (shisha) ════════════════════════

/// Suzuvchi pastki panel — ulangan bolalar almashtirgich + Sozlamalar
/// (ikkalasi ham Parvoz secondary shisha fonida).
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.children,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<Child> children;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Kontent nav ortida yumshoq fonga so'nadi.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0000060A), _bg, _bg],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: _Glass(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < children.length; i++)
                        _SwitcherItem(
                          child: children[i],
                          active: i == selectedIndex,
                          onTap: () => onSelect(i),
                        ),
                      // 1 yoki 2 bola bo'lsa "+" (qo'shish); 3 ta bo'lsa yo'q.
                      if (children.length < _kMaxChildren)
                        _AddSwitcherButton(
                          onTap: () => context.push(AppRoutes.addChild),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => context.push(AppRoutes.settings),
              behavior: HitTestBehavior.opaque,
              child: const _Glass(
                radius: 26,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(
                    SolarIconsBold.settings,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Almashtirgich "+" — yangi bola qo'shish (faqat bolalar < 3 bo'lganda).
class _AddSwitcherButton extends StatelessWidget {
  const _AddSwitcherButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: const Icon(
          SolarIconsBold.addCircle,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Uzun ismni chap tomonga silliq surib ko'rsatuvchi matn (marquee). Ism
/// [maxWidth]'dan kalta bo'lsa oddiy matn; uzun bo'lsa avtomatik suriladi.
class _MarqueeText extends StatefulWidget {
  const _MarqueeText({
    required this.text,
    required this.style,
    required this.maxWidth,
  });

  final String text;
  final TextStyle style;
  final double maxWidth;

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    final label = Text(
      widget.text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: widget.style,
    );
    final overflow = tp.width - widget.maxWidth;
    if (overflow <= 0) return label;

    return ClipRect(
      child: SizedBox(
        width: widget.maxWidth,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_ctrl.value);
            return Transform.translate(
              offset: Offset(-overflow * t, 0),
              child: child,
            );
          },
          child: Align(alignment: Alignment.centerLeft, child: label),
        ),
      ),
    );
  }
}

/// Almashtirgichdagi bitta bola — faol bo'lsa avatar + ism, aks holda avatar.
class _SwitcherItem extends StatelessWidget {
  const _SwitcherItem({
    required this.child,
    required this.active,
    required this.onTap,
  });

  final Child child;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: active
            ? const EdgeInsets.fromLTRB(4, 4, 14, 4)
            : const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.16) : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChildAvatar(child: child, size: 44, showBorder: false),
            if (active) ...[
              const SizedBox(width: 8),
              _MarqueeText(
                text: child.name,
                style: _pop(16, w: FontWeight.w500),
                maxWidth: 110,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
