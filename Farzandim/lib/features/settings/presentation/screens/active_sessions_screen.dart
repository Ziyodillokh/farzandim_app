// "Faol sessiyalar" ekrani (Parvoz dizayni) — login qilingan qurilmalarni
// ko'rish va boshqalarni uzoqdan tugatish. "Asosiy sessiya" (joriy qurilma,
// o'chirilmaydi) + "Qolgan sessiyalar" (qizil savat bilan tugatiladi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/settings/data/models/user_session.dart';
import 'package:farzandim/features/settings/presentation/providers/sessions_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal, Parvoz) ════════════
const _bg = Color(0xFF00060A);
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x14FFFFFF);
const _tile = Color(0xFFEDEEF0); // qurilma ikon-tayli (och)
const _tileIcon = Color(0xFF20262E); // tayl ichidagi ikon (to'q)
const _label = Color(0xCCFFFFFF); // bo'lim sarlavhasi (oq 80%)
const _dim = Color(0x99FFFFFF); // oq 60%
const _dim2 = Color(0x80FFFFFF); // oq 50% — meta
const _red = Color(0xFFFF453A); // tugatish (savat)
const _blue = Color(0xFF216BFF); // yog'du / progress

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.45,
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
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.4);

/// Faol sessiyalar ekrani.
class ActiveSessionsScreen extends ConsumerWidget {
  /// `ActiveSessionsScreen` konstruktor.
  const ActiveSessionsScreen({this.needRemoval = false, super.key});

  /// 3-qurilma kirish so'rovi tasdiqlangach — tepada "bitta qurilmani
  /// chiqaring" banneri ko'rsatiladi.
  final bool needRemoval;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const _BlueGlow(),
          SafeArea(
            child: Column(
              children: [
                _Header(onBack: () => context.pop()),
                const SizedBox(height: 6),
                if (needRemoval) const _RemovalBanner(),
                Expanded(
                  child: sessionsAsync.when(
                    loading: () => const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: _blue,
                        ),
                      ),
                    ),
                    error: (_, __) => _ErrorState(
                      onRetry: () =>
                          ref.read(sessionsProvider.notifier).refresh(),
                    ),
                    data: (sessions) => _SessionsList(sessions: sessions),
                  ),
                ),
                _AddAccountButton(
                  onTap: () => context.push(AppRoutes.addAccount),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════ "Bitta qurilmani chiqaring" banneri ════════════
// 3-qurilma so'rovi tasdiqlangach ko'rsatiladi: seans bo'shatilishi kerak.
class _RemovalBanner extends StatelessWidget {
  const _RemovalBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blue.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yangi qurilma tasdiqlandi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Uning kirishi uchun quyidagilardan bitta '
                  'qurilmani chiqarib yuboring.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12.5,
                    height: 1.35,
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

// ════════════ Fon: ko'k porlash ════════════
class _BlueGlow extends StatelessWidget {
  const _BlueGlow();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: -20,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: SizedBox(
            width: 360,
            height: 300,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x4D216BFF), Color(0x00216BFF)],
                  stops: [0, 0.72],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════ Sarlavha ════════════
class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _SquareBackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                'settings.sessions.title'.tr(),
                style: _unb(20, w: FontWeight.w500, ls: -0.6),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// Rounded-square orqa tugma (rasm 4 — leaderboard uslubida).
class _SquareBackButton extends StatelessWidget {
  const _SquareBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder),
        ),
        child: const Icon(
          SolarIconsOutline.arrowLeft,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ════════════ Ro'yxat ════════════
class _SessionsList extends ConsumerWidget {
  const _SessionsList({required this.sessions});

  final List<UserSession> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessions.isEmpty) {
      return _EmptyState(
        onRefresh: () => ref.read(sessionsProvider.notifier).refresh(),
      );
    }

    UserSession? current;
    final others = <UserSession>[];
    for (final s in sessions) {
      if (s.isCurrent && current == null) {
        current = s;
      } else {
        others.add(s);
      }
    }

    return RefreshIndicator(
      color: _blue,
      backgroundColor: _card,
      onRefresh: () => ref.read(sessionsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        children: [
          if (current != null) ...[
            const _SectionLabel('settings.sessions.yourSession'),
            const SizedBox(height: 10),
            _SessionCard(session: current),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionLabel('settings.sessions.otherSessions'),
            const SizedBox(height: 10),
            for (final s in others) ...[
              _SessionCard(
                session: s,
                onRevoke: () =>
                    ref.read(sessionsProvider.notifier).revoke(s.id),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.textKey);
  final String textKey;

  @override
  Widget build(BuildContext context) {
    return Text(
      textKey.tr(),
      style: _pop(14, w: FontWeight.w500, c: _label),
    );
  }
}

// ════════════ Sessiya kartasi ════════════
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, this.onRevoke});

  final UserSession session;

  /// `null` → asosiy sessiya (tugatish tugmasi yo'q).
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          _DeviceTile(session: session),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _unb(15),
                ),
                const SizedBox(height: 5),
                Text(
                  _subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(12.5, c: _dim2),
                ),
              ],
            ),
          ),
          if (onRevoke != null) ...[
            const SizedBox(width: 8),
            _TrashButton(onTap: () => _confirmRevoke(context)),
          ],
        ],
      ),
    );
  }

  /// "Toshkent • 12.06.2026" — joylashuv • sana.
  String _subtitle() {
    final loc =
        session.locationLabel ?? 'settings.sessions.unknownLocation'.tr();
    final date = session.lastSeenAt ?? session.createdAt;
    if (date == null) return loc;
    return '$loc  •  ${_formatDate(date)}';
  }

  Future<void> _confirmRevoke(BuildContext context) async {
    final ok = await _showEndSessionConfirm(
      context,
      title: 'settings.sessions.revokeConfirmTitle'.tr(),
      content: 'settings.sessions.revokeConfirmContent'.tr(),
    );
    if (ok && context.mounted) {
      onRevoke!.call();
      AppToast.success(context, 'settings.sessions.endedSnack'.tr());
    }
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.session});
  final UserSession session;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    if (session.isIos) {
      icon = SolarIconsBold.iPhone;
    } else if (session.isWeb) {
      icon = SolarIconsBold.global;
    } else {
      icon = SolarIconsBold.smartphone;
    }
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: _tileIcon, size: 24),
    );
  }
}

class _TrashButton extends StatelessWidget {
  const _TrashButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Icon(
            SolarIconsBold.trashBinMinimalistic,
            color: _red,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ════════════ "Hisob qo'shish" tugmasi ════════════
class _AddAccountButton extends StatelessWidget {
  const _AddAccountButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: ParvozSecondaryButton(
        label: 'settings.sessions.addAccount'.tr(),
        leading: const Icon(
          SolarIconsBold.qrCode,
          size: 20,
          color: Colors.white,
        ),
        onPressed: onTap,
      ),
    );
  }
}

// ════════════ Bo'sh / xato holatlari ════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _blue,
      backgroundColor: _card,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.26),
          Icon(
            SolarIconsBold.devices,
            color: Colors.white.withValues(alpha: 0.3),
            size: 58,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'settings.sessions.empty'.tr(),
              textAlign: TextAlign.center,
              style: _pop(14, c: _dim),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            SolarIconsBold.cloudCross,
            color: Colors.white.withValues(alpha: 0.3),
            size: 50,
          ),
          const SizedBox(height: 14),
          Text('settings.sessions.loadError'.tr(), style: _pop(14, c: _dim)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'settings.sessions.retry'.tr(),
              style: _pop(14, w: FontWeight.w600, c: _blue),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════ Yordamchilar ════════════

/// "dd.MM.yyyy" — intl'siz qo'lda format (local time).
String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

/// Tasdiq dialogi (dark). `true` — tugatish, `false` — bekor.
Future<bool> _showEndSessionConfirm(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoTheme(
      data: const CupertinoThemeData(brightness: Brightness.dark),
      child: CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(content),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('settings.sessions.confirmYes'.tr()),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('settings.sessions.confirmNo'.tr()),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
