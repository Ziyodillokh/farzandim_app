// ─────────────────────────────────────────────────────────────────────
// UnlockDecisionSheet — ota-ona unlock so'roviga qaror beradi
// ─────────────────────────────────────────────────────────────────────
//
// Bola "qo'shimcha vaqt" so'raganda (so'ralgan daqiqa + sabab bilan) ota-ona
// shu pastki varaqda qaror beradi:
//   - "Tasdiqlash ({N} daqiqa)" → bola so'ragan miqdorni o'shancha beradi
//   - "Boshqa muddat" chiplari (5/15/30/60) → boshqa miqdor berish
//   - "Rad etish" → deny
//   - tashqariga bossa → null (bekor)
//
// Dizayn: Parvoz qora+ko'k (daily_limit_sheet.dart bilan bir xil tizim).
// Eski teal-yashil `AppColors` o'rniga lokal Parvoz tokenlari + ParvozGlass.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _card = Color(0xFF12171E);
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _dim = Color(0x8CFFFFFF); // oq 55%
const _danger = Color(0xFFFF5A5A);

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.3,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.25,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Sheet natijasi — rad etish yoki N daqiqa berish.
@immutable
class UnlockDecision {
  const UnlockDecision._(this.approve, this.minutes);
  const UnlockDecision.deny() : this._(false, null);
  const UnlockDecision.grant(int minutes) : this._(true, minutes);

  final bool approve;
  final int? minutes;
}

class UnlockDecisionSheet extends StatelessWidget {
  const UnlockDecisionSheet({
    required this.childName,
    this.appName,
    this.requestedMinutes,
    this.reason,
    super.key,
  });

  /// Qaysi bola so'rayapti (sarlavhada ko'rsatiladi).
  final String childName;

  /// APP so'rovi bo'lsa ilova nomi (bo'lmasa ekran vaqti).
  final String? appName;

  /// Bola so'ragan daqiqa (5..60). null bo'lsa eski oqim — faqat chiplar.
  final int? requestedMinutes;

  /// Bola yozgan sabab (ixtiyoriy).
  final String? reason;

  /// Varaqni ochadi; tanlangan qaror (bekor bo'lsa null) qaytadi.
  static Future<UnlockDecision?> show(
    BuildContext context, {
    required String childName,
    String? appName,
    int? requestedMinutes,
    String? reason,
  }) {
    return showModalBottomSheet<UnlockDecision>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => UnlockDecisionSheet(
        childName: childName,
        appName: appName,
        requestedMinutes: requestedMinutes,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subject = (appName != null && appName!.trim().isNotEmpty)
        ? appName!
        : 'notifications.unlock.screenTimeSubject'.tr();
    final req = requestedMinutes;
    final reasonText = reason?.trim();
    // So'ralgan miqdor bo'lsa, chiplar "boshqa muddat" sifatida shu qiymatni
    // takrorlamasin (asosiy tugmada bor).
    final chipMinutes = const [
      5,
      15,
      30,
      60,
    ].where((m) => m != req).toList(growable: false);

    final body = req != null
        ? 'notifications.unlock.requestWithMinutes'.tr(
            namedArgs: {
              'name': childName,
              'subject': subject,
              'minutes': '$req',
            },
          )
        : 'notifications.unlock.requestNoMinutes'.tr(
            namedArgs: {'name': childName, 'subject': subject},
          );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: _bg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text(
                  'notifications.unlock.sheetTitle'.tr(),
                  style: _unb(19, w: FontWeight.w700, ls: -0.4),
                ),
                const SizedBox(height: 8),
                Text(body, style: _pop(14, c: _dim)),
                // Sabab (bola yozgan bo'lsa).
                if (reasonText != null && reasonText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ReasonBox(reason: reasonText),
                ],
                const SizedBox(height: 22),
                // Asosiy amal — bola so'ragan miqdorni o'shancha tasdiqlash.
                if (req != null) ...[
                  _ApproveRequestedButton(
                    minutes: req,
                    onTap: () =>
                        Navigator.of(context).pop(UnlockDecision.grant(req)),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'notifications.unlock.otherDurationLabel'.tr(),
                    style: _pop(13, c: _dim),
                  ),
                  const SizedBox(height: 12),
                ],
                // Daqiqa variantlari (so'ralgan miqdordan boshqa muddatlar).
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final m in chipMinutes)
                      _MinuteChip(
                        minutes: m,
                        onTap: () =>
                            Navigator.of(context).pop(UnlockDecision.grant(m)),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                // Rad etish
                _DenyButton(
                  onTap: () =>
                      Navigator.of(context).pop(const UnlockDecision.deny()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bola yozgan sabab — yumshoq fon ichidagi quote.
class _ReasonBox extends StatelessWidget {
  const _ReasonBox({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(SolarIconsBold.chatRoundLine, size: 18, color: _dim),
          const SizedBox(width: 8),
          Expanded(
            child: Text(reason, style: _pop(14, c: const Color(0xF2FFFFFF))),
          ),
        ],
      ),
    );
  }
}

/// "Tasdiqlash ({N} daqiqa)" — to'liq-kenglik asosiy ko'k tugma.
class _ApproveRequestedButton extends StatelessWidget {
  const _ApproveRequestedButton({required this.minutes, required this.onTap});
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ParvozGlass(
        blue: true,
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              SolarIconsBold.checkCircle,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'notifications.unlock.approveMinutes'.tr(
                namedArgs: {'minutes': '$minutes'},
              ),
              style: _pop(16, w: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Boshqa muddat" chipi — shisha pill (ikkilamchi amal).
class _MinuteChip extends StatelessWidget {
  const _MinuteChip({required this.minutes, required this.onTap});
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _blue.withValues(alpha: 0.45)),
        ),
        child: Text(
          'notifications.unlock.minutesChip'.tr(
            namedArgs: {'minutes': '$minutes'},
          ),
          style: _pop(15, w: FontWeight.w500),
        ),
      ),
    );
  }
}

/// "Rad etish" — to'liq-kenglik qizil (danger) tugma.
class _DenyButton extends StatelessWidget {
  const _DenyButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: _danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _danger.withValues(alpha: 0.45),
            width: 1.4,
          ),
        ),
        child: Center(
          child: Text(
            'notifications.unlock.deny'.tr(),
            style: _pop(15, w: FontWeight.w600, c: _danger),
          ),
        ),
      ),
    );
  }
}
