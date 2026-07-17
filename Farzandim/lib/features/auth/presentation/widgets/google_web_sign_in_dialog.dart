// ─────────────────────────────────────────────────────────────────────
// Google web kirish oynasi — rasmiy render tugma bilan (Parvoz dark)
// ─────────────────────────────────────────────────────────────────────
//
// Web'da `signIn()` ID token bermaydi (GIS cheklovi) — shu sababli
// foydalanuvchi "Google" tugmasini bosganda kichik oyna ochilib, ichida
// Google'ning RASMIY tugmasi ko'rsatiladi. U bosilganda plugin
// `onCurrentUserChanged` orqali idToken'li akkauntni beradi — oyna
// yopilib token qaytariladi. Mobil oqimga tegilmagan.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/auth/presentation/widgets/google_render_button_stub.dart'
    if (dart.library.html) 'package:farzandim/features/auth/presentation/widgets/google_render_button_web.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Web'da Google ID token olish: avval jim urinish (avvalgi sessiya),
/// bo'lmasa rasmiy tugmali oyna. Bekor qilinsa null.
Future<String?> showGoogleWebSignInDialog(
  BuildContext context,
  GoogleSignIn google,
) async {
  // Plugin init + avvalgi sessiya bo'lsa darhol token (oynasiz).
  try {
    final silent = await google.signInSilently();
    if (silent != null) {
      final auth = await silent.authentication;
      final t = auth.idToken;
      if (t != null && t.isNotEmpty) return t;
    }
  } catch (_) {}
  if (!context.mounted) return null;

  return showDialog<String?>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _GoogleWebDialog(google: google),
  );
}

class _GoogleWebDialog extends StatefulWidget {
  const _GoogleWebDialog({required this.google});

  final GoogleSignIn google;

  @override
  State<_GoogleWebDialog> createState() => _GoogleWebDialogState();
}

class _GoogleWebDialogState extends State<_GoogleWebDialog> {
  StreamSubscription<GoogleSignInAccount?>? _sub;

  @override
  void initState() {
    super.initState();
    // Rasmiy tugma bosilib credential kelganda idToken bilan yopamiz.
    _sub = widget.google.onCurrentUserChanged.listen((account) async {
      if (account == null) return;
      final auth = await account.authentication;
      final t = auth.idToken;
      if (!mounted || t == null || t.isEmpty) return;
      Navigator.of(context).pop(t);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF12151B),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'auth.googleWeb.title'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.unbounded(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'auth.googleWeb.subtitle'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0x99FFFFFF),
              ),
            ),
            const SizedBox(height: 18),
            // Google'ning RASMIY tugmasi (faqat web'da chiziladi).
            SizedBox(height: 44, child: Center(child: googleRenderButton())),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'common.cancel'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  color: const Color(0x99FFFFFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
