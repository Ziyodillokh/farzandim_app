// ─────────────────────────────────────────────────────────────────────
// DeleteAccountRow — "Ulanishni uzish va ma'lumotlarni o'chirish"
// ─────────────────────────────────────────────────────────────────────
//
// Sozlamalar oxiridagi xavfli (qizil) qator. Tasdiqlash oynasidan keyin
// `AccountDeletion.deleteAndDisconnect()` chaqiriladi; server xatosida
// aniq xabar ko'rsatiladi va hech narsa o'zgarmaydi. Muvaffaqiyatda router
// bolani boshlang'ich ekranga o'zi olib boradi (pairing/rozilik holati).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/account/presentation/providers/account_deletion_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

const _card = Color(0xFF181C22);
const _sheetBg = Color(0xFF15181E);
const _danger = Color(0xFFFF5A5F);
const _dim = Color(0x99FFFFFF);
const _glass = Color(0x14FFFFFF);
const _glassBorder = Color(0x24FFFFFF);

class DeleteAccountRow extends ConsumerStatefulWidget {
  const DeleteAccountRow({super.key});

  @override
  ConsumerState<DeleteAccountRow> createState() => _DeleteAccountRowState();
}

class _DeleteAccountRowState extends ConsumerState<DeleteAccountRow> {
  bool _isDeleting = false;

  Future<void> _onTap() async {
    if (_isDeleting) return;
    HapticFeedback.selectionClick();
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDeleteDialog(),
    );
    if (isConfirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(accountDeletionProvider).deleteAndDisconnect();
      // Muvaffaqiyat: pairing/rozilik holati o'zgardi — router o'zi
      // boshlang'ich ekranga o'tkazadi, bu widget unmount bo'ladi.
    } catch (e) {
      debugPrint('[Settings] hisobni o\'chirish xato: $e');
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.deleteAccountError'.tr()),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isDeleting ? null : _onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 14),
        padding: const EdgeInsets.fromLTRB(18, 15, 14, 15),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _danger.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(
              SolarIconsBold.trashBinMinimalistic,
              color: _danger,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.deleteAccount'.tr(),
                    style: GoogleFonts.unbounded(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _danger,
                      letterSpacing: -0.2,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'settings.deleteAccountSub'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: _dim,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (_isDeleting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: _danger,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tasdiqlash oynasi — nima o'chishini aniq aytadi. `true` — o'chirish.
class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _sheetBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'settings.deleteAccountConfirmTitle'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.unbounded(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'settings.deleteAccountConfirmBody'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: _dim,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _DialogButton(
              label: 'settings.deleteAccountConfirmButton'.tr(),
              color: _danger,
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            _DialogButton(
              label: 'common.cancel'.tr(),
              color: _glass,
              hasBorder: true,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.hasBorder = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: hasBorder ? Border.all(color: _glassBorder) : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
