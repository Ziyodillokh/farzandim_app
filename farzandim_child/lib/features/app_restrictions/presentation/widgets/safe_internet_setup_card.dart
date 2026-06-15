// ─────────────────────────────────────────────────────────────────────
// SafeInternetSetupCard — "Xavfsiz internet" sozlash tavsiyasi (bola dashboard)
// ─────────────────────────────────────────────────────────────────────
//
// Ota-ona "Xavfsiz internet filtri"ni yoqqan, lekin bola qurilmasida xavfsiz
// DNS (Private DNS) hali sozlanmagan bo'lsa — bolaga sozlash bo'yicha qisqa
// tavsiya kartasini ko'rsatadi (faqat Android). Shart bajarilmaganda yoki
// holat hali aniqlanmagan bo'lsa o'zi yashirinadi (bo'sh joy egallamaydi).
//
// Hozircha web-filter holati va Private-DNS aniqlash ko'prigi bola tomonida
// ulanmagani uchun karta yashirin turadi (SizedBox.shrink). Plumbing (child
// device-policy'da webFilterEnabled + native DNS holati) tayyor bo'lgach shu
// yerda shart qo'shiladi va karta ko'rinadi. Shu sabab widget alohida fayl
// sifatida saqlanadi — dashboard importi buzilmaydi va kelajakda kengaytirish
// bitta joydan bo'ladi.

import 'package:flutter/material.dart';

/// Bola dashboard'idagi "Xavfsiz internet" sozlash tavsiya kartasi.
///
/// Shart bajarilmaguncha (yoki holat ulanmaguncha) ko'rinmaydi.
class SafeInternetSetupCard extends StatelessWidget {
  /// `SafeInternetSetupCard` konstruktor.
  const SafeInternetSetupCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Holat o'qish ko'prigi ulangach: faqat Android + webFilterEnabled +
    // Private DNS sozlanmagan bo'lsa tavsiya kartasi ko'rsatiladi. Hozircha
    // yashirin (bo'sh joy egallamaydi).
    return const SizedBox.shrink();
  }
}
