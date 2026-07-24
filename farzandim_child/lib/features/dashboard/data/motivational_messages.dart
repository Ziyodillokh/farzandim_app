// ─────────────────────────────────────────────────────────────────────
// MotivationalMessages — kunlik motivatsion matnlar
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard'dagi "Bugungi maslahat" banner'i shu yerdan tasodifiy
// (kun raqamiga ko'ra) bittasini oladi — bir kun ichida o'zgarmaydi.

import 'package:easy_localization/easy_localization.dart';

class MotivationalMessages {
  MotivationalMessages._();

  static const List<String> messages = [
    "Telefondan ko'p foydalanmang, sport bilan shug'ullaning! ⚽",
    "Kitob o'qish - eng yaxshi do'st 📚",
    "Oilangiz bilan vaqt o'tkazing 👨‍👩‍👧",
    "Tabiat sirlari ajoyib - tashqarida o'ynang 🌳",
    "Yangi narsalarni o'rganish - kuchingiz manbai 💪",
    "Do'stlaringizga yordam bering 🤝",
    "Kunni ertalab nonushta bilan boshlang 🍳",
    "Yaxshi uyqu - kuch manbai 😴",
    "Suv ichish unutmang 💧",
    "Har kuni biror narsa o'rganib oling 🎓",
  ];

  static String getRandom() {
    final index = DateTime.now().day % 10;
    return 'dashboard.motivational.m${index + 1}'.tr();
  }
}
