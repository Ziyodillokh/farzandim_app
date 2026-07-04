// "Qo'llab quvvatlash" — Tizim so'zlamalari qatoridan ochiladigan Parvoz
// bottom sheet. Eski ichki chat (xabar/rasm/fayl yuborish) BUTUNLAY olib
// tashlandi; endi foydalanuvchi to'g'ridan-to'g'ri support kanallariga
// (Telegram bot, telefon, email) o'tadi. Har qatorga bosilsa tegishli ilova
// ochiladi (url_launcher).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF0F141A);
const _line = Color(0x14FFFFFF); // ajratgich (oq 8%)
const _dim = Color(0x99FFFFFF); // oq 60%

// ════════════ Support kanallari (konstantalar) ════════════
const _telegramHandle = '@parvoz_bot';
const _telegramUrl = 'https://t.me/parvoz_bot';
const _phoneDisplay = '+998 94 064 00 13';
const _phoneUrl = 'tel:+998940640013';
const _emailAddress = 'parvoz_support@gmail.com';
const _emailUrl = 'mailto:parvoz_support@gmail.com';

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.4,
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

/// Qo'llab-quvvatlash varag'ini ochadi.
Future<void> showSupportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _SupportSheet(),
  );
}

class _SupportSheet extends StatelessWidget {
  const _SupportSheet();

  Future<void> _open(BuildContext context, String url) async {
    // launchUrl mos ilova topilmasa `false` qaytaradi yoki PlatformException
    // otishi mumkin — ikkalasini ham xatolik toast'i bilan hal qilamiz.
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      AppToast.error(context, 'errors.generic'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: ColoredBox(
        color: _bg,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'supportSheet.title'.tr(),
                  textAlign: TextAlign.center,
                  style: _unb(17, w: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _ContactRow(
                  label: 'supportSheet.telegram'.tr(),
                  value: _telegramHandle,
                  icon: Icons.send_rounded,
                  onTap: () => _open(context, _telegramUrl),
                ),
                _ContactRow(
                  label: 'supportSheet.phone'.tr(),
                  value: _phoneDisplay,
                  icon: Icons.call_rounded,
                  onTap: () => _open(context, _phoneUrl),
                ),
                _ContactRow(
                  label: 'supportSheet.email'.tr(),
                  value: _emailAddress,
                  icon: Icons.mail_outline_rounded,
                  onTap: () => _open(context, _emailUrl),
                  divider: false,
                ),
                const SizedBox(height: 24),
                ParvozSecondaryButton(
                  label: 'common.close'.tr(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kontakt qatori — yorliq + qiymat + o'ng tomonda ikon tugma; qatorga bosilsa
/// tegishli ilova ochiladi.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.divider = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: _pop(13, c: _dim)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _unb(16, ls: -0.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (divider) const Divider(height: 1, thickness: 1, color: _line),
        ],
      ),
    );
  }
}
