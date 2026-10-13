// ─────────────────────────────────────────────────────────────────────
// Banner "keyinroq" (snooze) — yopilgan eslatma qachon qayta chiqadi
// ─────────────────────────────────────────────────────────────────────
//
// Joylashuv "Har doim" eslatmasi majburlovchi bo'lmasligi kerak (Apple
// 5.1.1): bola yopsa, bir necha kun ko'rinmaydi, keyin bir marta eslatadi.

/// Joylashuv eslatmasi yopilgandan keyin shuncha vaqt ko'rinmaydi.
const kLocationBannerSnooze = Duration(days: 7);

/// [dismissedAtMs] — yopilgan vaqt (ms, epoch); `null` — hech yopilmagan.
/// Yopilgan vaqt kelajakda bo'lsa (soat orqaga surilgan) — eslatma qayta
/// ko'rsatiladi, aks holda u uzoq muddatga yo'qolib qolardi.
bool isBannerSnoozed({
  required int? dismissedAtMs,
  required DateTime now,
  Duration snooze = kLocationBannerSnooze,
}) {
  if (dismissedAtMs == null) return false;
  final elapsed = now.difference(
    DateTime.fromMillisecondsSinceEpoch(dismissedAtMs),
  );
  return !elapsed.isNegative && elapsed < snooze;
}
