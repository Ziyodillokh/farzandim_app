import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hozir tanlangan bola indeksi (`childrenProvider` ro'yxatida).
///
/// `ChildPageView` swipe qilganda yangilanadi va Dashboard'ning boshqa
/// kartalari (rating, screen time) shu indeks bo'yicha ma'lumot ko'rsatadi.
///
/// **Default:** 0 — birinchi bola tanlangan.
///
/// **Eslatma:** ro'yxatdan tashqaridagi indeksni o'qiganda
/// `clamp(0, children.length - 1)` ishlating — bola o'chirilsa indeks
/// avtomatik to'g'irlanmaydi.
final selectedChildIndexProvider = StateProvider<int>((ref) => 0);
