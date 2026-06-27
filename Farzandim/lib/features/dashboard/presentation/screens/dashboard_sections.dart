part of 'dashboard_screen.dart';

// ════════════════════════ HEADER ════════════════════════

/// Tepa qism — markaziy avatar (online nuqta) + ism + qurilma/batareya,
/// chap-tepada Messenger, o'ng-tepada bildirishnoma (o'qilmagan qizil nuqta).
class _Header extends ConsumerWidget {
  const _Header({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final online = child.isLiveOnline;
    final battery = child.deviceInfo?.batteryLevel;
    final device = (child.deviceModel != null && child.deviceModel!.isNotEmpty)
        ? child.deviceModel!
        : (child.deviceInfo?.deviceModel ?? '—');

    return SizedBox(
      height: 272,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Ko'k yog'du (avatar ortida).
          Positioned(
            top: -70,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _blue.withValues(alpha: 0.45),
                      const Color(0x00216BFF),
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
          ),

          // Messenger (chap-tepa).
          Positioned(
            top: 8,
            left: 16,
            child: _CircleButton(
              icon: Icons.forum_rounded,
              onTap: () => context.push(AppRoutes.qaVoicePath(child.id)),
            ),
          ),

          // Bildirishnoma (o'ng-tepa) + o'qilmagan qizil nuqta.
          Positioned(
            top: 8,
            right: 16,
            child: _CircleButton(
              icon: Icons.notifications_none_rounded,
              showDot: unread > 0,
              onTap: () => context.push(AppRoutes.notifications),
            ),
          ),

          // Markaziy profil.
          Positioned(
            top: 12,
            child: Column(
              children: [
                Stack(
                  children: [
                    ChildAvatar(child: child, size: 110, showBorder: false),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: online ? _online : _dim,
                          border: Border.all(color: _bg, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                      Icon(
                        _batteryIcon(battery),
                        size: 16,
                        color: _dim,
                      ),
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

IconData _batteryIcon(int level) {
  if (level >= 90) return Icons.battery_full_rounded;
  if (level >= 60) return Icons.battery_5_bar_rounded;
  if (level >= 40) return Icons.battery_3_bar_rounded;
  if (level >= 15) return Icons.battery_2_bar_rounded;
  return Icons.battery_1_bar_rounded;
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

/// 44x44 shisha dumaloq tugma (Messenger / bildirishnoma).
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
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
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            if (showDot)
              Positioned(
                top: 11,
                right: 11,
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

    return _Card(
      onTap: () => context.push(AppRoutes.locationPath(child.id)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            inZone ? Icons.home_rounded : Icons.location_on_rounded,
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
            Icons.chevron_right_rounded,
            size: 22,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ],
      ),
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
    final apps =
        (usage?.filteredApps ?? const <AppUsageEntry>[]).take(3).toList();

    return _Card(
      minHeight: 220,
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
            Text('—', style: _pop(14, c: _dim))
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: Color(0x14FFFFFF)),
      ),
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
    final xp = profile?.xp ?? 0;
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
              Text('dashboard.xpBalance'.tr(), style: _pop(14, c: _dim)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _fmtNumber(xp),
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
                    child: Text(
                      'XP',
                      style: _pop(12, w: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const SizedBox.shrink()
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
    final start = (idx - 1).clamp(0, all.length);
    final end = (idx + 2).clamp(0, all.length);
    return all.sublist(start, end);
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
    final ch = entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?';
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMe ? _blue.withValues(alpha: 0.25) : _cardBg,
          ),
          child: Text(ch, style: _pop(11, w: FontWeight.w600)),
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
        if (isMe)
          Icon(
            Icons.chevron_right_rounded,
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

// ════════════════════════ KUN TARTIBI (TEZ KUNDA) ════════════════════════

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('dashboard.scheduleTitle'.tr(), style: _pop(14, c: _dim)),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 30,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'dashboard.comingSoon'.tr(),
                  style: _pop(14, w: FontWeight.w500, c: _dim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ════════════════════════ AMAL KARTASI ════════════════════════

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    this.onTap,
    this.comingSoon = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return _Card(
      minHeight: 120,
      padding: const EdgeInsets.all(12),
      onTap: onTap ?? (comingSoon ? () => _soon(context) : null),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: _pop(15, w: FontWeight.w500),
            ),
            if (comingSoon) ...[
              const SizedBox(height: 4),
              Text(
                'dashboard.comingSoon'.tr(),
                style: _pop(11, c: _dim),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _soon(BuildContext context) =>
      AppToast.info(context, 'dashboard.comingSoon'.tr());
}

// ════════════════════════ BOLA QO'SHISH ════════════════════════

class _AddChildButton extends StatelessWidget {
  const _AddChildButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.addChild),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 22, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'dashboard.emptyState.addButton'.tr(),
              style: _pop(16, w: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════ PASTKI BAR ════════════════════════

/// Suzuvchi pastki panel — ulangan bolalar almashtirgich + Sozlamalar.
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
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < children.length; i++)
                      _SwitcherItem(
                        child: children[i],
                        active: i == selectedIndex,
                        onTap: () => onSelect(i),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => context.push(AppRoutes.settings),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _cardBg,
                  border: Border.all(color: _cardBorder),
                ),
                child: const Icon(
                  Icons.settings_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ],
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
              Text(
                child.name,
                style: _pop(16, w: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
