// ─────────────────────────────────────────────────────────────────────
// Huquqiy havolalar — maxfiylik siyosati va hisobni o'chirish sahifasi
// ─────────────────────────────────────────────────────────────────────
//
// Rozilik ekrani VA Sozlamalar bir xil manzilni ochadi (App Store 5.1.1:
// siyosat havolasi ilova ichida doim topiladigan joyda bo'lishi kerak).

import 'package:url_launcher/url_launcher.dart';

const kPrivacyPolicyUrl = 'https://farzandimedu.uz/privacy.html';

/// Havolani tashqi brauzerda ochadi. `false` — ochilmadi (UI xabar beradi).
Future<bool> openLegalUrl(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
