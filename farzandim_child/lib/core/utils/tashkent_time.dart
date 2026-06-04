// ─────────────────────────────────────────────────────────────────────
// tashkent_time — Toshkent (Asia/Tashkent) vaqt yordamchilari
// ─────────────────────────────────────────────────────────────────────
//
// Asia/Tashkent — qat'iy UTC+5 (yozgi vaqt / DST yo'q). Background
// isolate yoki UTC manbalardan kelgan vaqtlar telefon foydalanuvchisi
// kutgan mahalliy vaqtga aniq keltiriladi. Qurilma zonasi noto'g'ri
// sozlangan bo'lsa ham natija doim Toshkent vaqti bo'ladi.

/// Toshkent UTC offseti (DST yo'q, doim +5).
const Duration tashkentOffset = Duration(hours: 5);

/// Hozirgi Toshkent vaqti (qurilma zonasidan qat'i nazar).
DateTime tashkentNow() => DateTime.now().toUtc().add(tashkentOffset);

/// Berilgan vaqtni Toshkent zonasiga keltiradi (manba UTC yoki local).
DateTime toTashkent(DateTime dt) => dt.toUtc().add(tashkentOffset);
