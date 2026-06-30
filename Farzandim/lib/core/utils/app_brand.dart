// Ilova paket nomini foydalanuvchi-friendly nomga aylantiradi va
// harf-avatar uchun rang/harf beradi.
//
// Sabab: bola qurilmasi ko'pincha ilovaning haqiqiy yorlig'ini yubormaydi
// (yoki packageName'ning o'zini yuboradi) va ikonalar backend'da bo'lmasligi
// mumkin. Shu sabab ota-ona ilovasida "org.telegram.messenger" → "Telegram"
// kabi mashhur ilovalarni nomlash va noma'lumlarni chiroyli formatga
// keltirish markazlashtirilgan. Ikon yo'q bo'lsa — brend rangli harf-avatar.

import 'package:flutter/material.dart';

/// Mashhur ilovalar: packageName → ko'rinadigan nom.
const Map<String, String> _brandNames = {
  'org.telegram.messenger': 'Telegram',
  'org.thunderdog.challegram': 'Telegram X',
  'com.whatsapp': 'WhatsApp',
  'com.whatsapp.w4b': 'WhatsApp Business',
  'com.instagram.android': 'Instagram',
  'com.zhiliaoapp.musically': 'TikTok',
  'com.ss.android.ugc.trill': 'TikTok',
  'com.google.android.youtube': 'YouTube',
  'com.google.android.apps.youtube.kids': 'YouTube Kids',
  'com.facebook.katana': 'Facebook',
  'com.facebook.lite': 'Facebook Lite',
  'com.facebook.orca': 'Messenger',
  'com.snapchat.android': 'Snapchat',
  'com.twitter.android': 'X',
  'com.spotify.music': 'Spotify',
  'com.android.chrome': 'Chrome',
  'com.google.android.gm': 'Gmail',
  'com.google.android.apps.maps': 'Google Maps',
  'com.android.vending': 'Play Store',
  'com.tencent.ig': 'PUBG Mobile',
  'com.pubg.imobile': 'PUBG Mobile',
  'com.activision.callofduty.shooter': 'Call of Duty',
  'com.roblox.client': 'Roblox',
  'com.mojang.minecraftpe': 'Minecraft',
  'com.supercell.brawlstars': 'Brawl Stars',
  'com.supercell.clashofclans': 'Clash of Clans',
  'com.discord': 'Discord',
  'com.viber.voip': 'Viber',
  'ru.ok.android': 'OK',
  'com.vkontakte.android': 'VK',
  'com.yandex.browser': 'Yandex Browser',
  'com.opera.browser': 'Opera',
  'com.netflix.mediaclient': 'Netflix',
  'com.linkedin.android': 'LinkedIn',
  'com.pinterest': 'Pinterest',
  'com.reddit.frontpage': 'Reddit',
  'com.twitch.android.app': 'Twitch',
  'com.google.android.apps.photos': 'Google Photos',
  'uz.click.evolution': 'Click',
  'uz.dida.payme': 'Payme',
  'uz.uzum.bank': 'Uzum Bank',
};

/// Mashhur ilovalar uchun brend rangi (harf-avatar foni).
const Map<String, Color> _brandColors = {
  'org.telegram.messenger': Color(0xFF29A9EB),
  'org.thunderdog.challegram': Color(0xFF29A9EB),
  'com.whatsapp': Color(0xFF25D366),
  'com.whatsapp.w4b': Color(0xFF25D366),
  'com.instagram.android': Color(0xFFE1306C),
  'com.zhiliaoapp.musically': Color(0xFF222222),
  'com.ss.android.ugc.trill': Color(0xFF222222),
  'com.google.android.youtube': Color(0xFFFF0000),
  'com.google.android.apps.youtube.kids': Color(0xFFFF0000),
  'com.facebook.katana': Color(0xFF1877F2),
  'com.facebook.orca': Color(0xFF0084FF),
  'com.snapchat.android': Color(0xFFFFC400),
  'com.spotify.music': Color(0xFF1DB954),
  'com.android.chrome': Color(0xFF4285F4),
  'com.discord': Color(0xFF5865F2),
  'com.viber.voip': Color(0xFF7360F2),
  'com.netflix.mediaclient': Color(0xFFE50914),
};

/// Skip-segmentlar — paketni chiroyli nomga keltirishda o'tkazib yuboriladi.
const Set<String> _prettifySkip = {
  'android',
  'app',
  'apps',
  'mobile',
  'free',
  'pro',
  'client',
  'main',
  'release',
};

/// `packageName`'ni (va ixtiyoriy xom nom) foydalanuvchi-friendly nomga
/// aylantiradi: real yorliq > mashhur ilova xaritasi > chiroyli paket nomi.
String friendlyAppName(String packageName, [String? rawName]) {
  // 1) Xom nom haqiqiy yorliq bo'lsa (bo'sh emas, packageName emas va paket
  //    ko'rinishida emas) — o'shani ishlatamiz.
  if (rawName != null) {
    final t = rawName.trim();
    if (t.isNotEmpty && t != packageName && !_looksLikePackage(t)) {
      return t;
    }
  }
  // 2) Mashhur ilova xaritasi.
  final brand = _brandNames[packageName];
  if (brand != null) return brand;
  // 3) Aks holda paket nomidan chiroyli nom yasaymiz.
  return _prettify(packageName);
}

/// Harf-avatar foni: mashhur ilova brend rangi yoki packageName'dan
/// deterministik rang (har doim bir xil ilovaga bir xil rang).
Color appAvatarColor(String packageName) {
  final brand = _brandColors[packageName];
  if (brand != null) return brand;
  var hash = 0;
  for (var i = 0; i < packageName.length; i++) {
    hash = packageName.codeUnitAt(i) + ((hash << 5) - hash);
  }
  final hue = (hash % 360).abs().toDouble();
  return HSLColor.fromAHSL(1, hue, 0.45, 0.5).toColor();
}

/// Harf-avatar uchun bosh harf (friendly nomdan).
String appInitial(String packageName, [String? rawName]) {
  final name = friendlyAppName(packageName, rawName);
  final match = RegExp('[A-Za-z0-9А-Яа-яЎўҒғҚқҲҳ]').firstMatch(name);
  return match != null ? match.group(0)!.toUpperCase() : '?';
}

bool _looksLikePackage(String s) {
  if (s.contains(' ')) return false;
  if ('.'.allMatches(s).length >= 2) return true;
  return s.startsWith('com.') ||
      s.startsWith('org.') ||
      s.startsWith('net.') ||
      s.startsWith('io.') ||
      s.startsWith('uz.') ||
      s.startsWith('ru.');
}

String _prettify(String packageName) {
  if (packageName.isEmpty) return packageName;
  final segs = packageName.split('.').where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return packageName;
  // Oxiridan boshlab birinchi "ma'noli" segment (android/app/... o'tkaziladi).
  var seg = segs.last;
  for (var i = segs.length - 1; i >= 0; i--) {
    if (!_prettifySkip.contains(segs[i].toLowerCase())) {
      seg = segs[i];
      break;
    }
  }
  // camelCase / snake_case / kebab-case → bo'shliq, so'ng Title Case.
  final spaced = seg
      .replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ');
  final words = spaced
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''));
  return words.join(' ');
}
