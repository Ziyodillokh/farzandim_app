// "Login" — Akkount sheet'idagi login qalamidan ochiladi. Bazada alohida
// "login" maydoni YO'Q: kirish uchun EMAIL yoki TELEFON ishlatiladi. Shu bois
// bu varaq loginni tushuntiradi va email/telefonni tahrirlashga yo'naltiradi
// (ustidan tegishli tahrirlash varag'i ochiladi; saqlangach shu yerga qaytadi
// va yangilangan qiymatlar ko'rinadi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/profile/presentation/providers/profile_provider.dart';
import 'package:farzandim/features/profile/presentation/screens/contact_edit_sheet.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF0F141A);
const _line = Color(0x14FFFFFF); // ajratgich (oq 8%)
const _dim = Color(0x99FFFFFF); // oq 60%

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
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Login (kirish ma'lumotlari) varag'ini ochadi.
Future<void> showLoginEditSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _LoginEditSheet(),
  );
}

class _LoginEditSheet extends ConsumerWidget {
  const _LoginEditSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final email = (p.email ?? '').trim();
    final phone = (p.phoneNumber ?? '').trim();
    String orDash(String s) => s.isNotEmpty ? s : '—';

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
                const SizedBox(height: 14),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(
                        SolarIconsOutline.arrowLeft,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'loginEdit.title'.tr(),
                          style: _unb(17, w: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                ),
                const SizedBox(height: 18),
                Text('loginEdit.info'.tr(), style: _pop(13, c: _dim)),
                const SizedBox(height: 18),
                _InfoRow(label: 'account.email'.tr(), value: orDash(email)),
                _InfoRow(label: 'account.phone'.tr(), value: orDash(phone)),
                const SizedBox(height: 20),
                ParvozSecondaryButton(
                  label: 'loginEdit.editEmail'.tr(),
                  onPressed: () => showEmailEditSheet(context),
                ),
                const SizedBox(height: 10),
                ParvozSecondaryButton(
                  label: 'loginEdit.editPhone'.tr(),
                  onPressed: () => showPhoneEditSheet(context),
                ),
                const SizedBox(height: 10),
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

/// Yorliq + qiymat + ostida yupqa ajratgich.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(label, style: _pop(13, c: _dim)),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _unb(16, ls: -0.2),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: _line),
      ],
    );
  }
}
