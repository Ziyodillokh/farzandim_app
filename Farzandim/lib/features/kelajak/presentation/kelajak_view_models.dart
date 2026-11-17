// ─────────────────────────────────────────────────────────────────────
// kelajak_view_models — Kelajak ekranlarining sof mantiqi (widget'siz)
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard kartasi holati, top qiziqish nomlari, o'zgarish belgisi
// (+25 / −10, foizsiz), qiziqishi ortayotgan yo'nalishlar va Career Lab
// guruhlari. Qat'iy hukm yo'q: faqat backend bergan, ishonchli
// (`reliable`) yo'nalishlar ko'rsatiladi.

import 'package:farzandim/features/kelajak/data/models/kelajak_insights.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_progress.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_text.dart';
import 'package:flutter/foundation.dart';

/// "Ortayotgan" deb hisoblanadigan eng kichik o'zgarish (backend
/// `improved` / `interestsRising` bilan bir xil: delta ≥ 10).
const int kKelajakRisingDelta = 10;

/// Kartada ko'rsatiladigan top yo'nalishlar soni.
const int kKelajakCardTopCount = 3;

/// Dashboard kartasi va Growth havolasi holati.
sealed class KelajakCardMode {
  const KelajakCardMode();

  factory KelajakCardMode.of(KelajakSummary? summary) {
    if (summary == null) return const KelajakCardHidden();
    final status = summary.age.status;
    if (status == KelajakAgeStatus.ageRequired) {
      return const KelajakCardAgeRequired();
    }
    if (status == KelajakAgeStatus.ageOutOfRange && !summary.hasAnswers) {
      return const KelajakCardHidden();
    }
    final names = kelajakTopInterestNames(summary);
    if (names.isNotEmpty) return KelajakCardInterests(names);
    if (!summary.hasAnswers) return const KelajakCardEmpty();
    return KelajakCardForming(summary.sessionsCompleted);
  }
}

/// Yuklanmoqda / xato / bo'lim yo'q / yosh mos emas — ko'rinmaydi.
class KelajakCardHidden extends KelajakCardMode {
  const KelajakCardHidden();
}

/// Bolaning yoshi kiritilmagan.
class KelajakCardAgeRequired extends KelajakCardMode {
  const KelajakCardAgeRequired();
}

/// Hali birorta test yakunlanmagan.
class KelajakCardEmpty extends KelajakCardMode {
  const KelajakCardEmpty();
}

/// Testlar bor, lekin yo'nalish aytishga javoblar hali yetarli emas.
class KelajakCardForming extends KelajakCardMode {
  const KelajakCardForming(this.sessions);

  final int sessions;
}

/// Qiziqish yuqori bo'lgan yo'nalishlar ("Ijodiy", "Tadqiqotchi").
class KelajakCardInterests extends KelajakCardMode {
  const KelajakCardInterests(this.names);

  final List<LocalizedText> names;
}

/// Top yo'nalishlar qisqa nomi (RIASEC nomi, bo'lmasa sarlavha);
/// ishonchli profil bo'lmasa bo'sh.
List<LocalizedText> kelajakTopInterestNames(KelajakSummary summary) =>
    List.unmodifiable([
      for (final insight in summary.insights.interests.take(
        kKelajakCardTopCount,
      ))
        summary.interests?.nameOf(insight.code) ?? insight.title,
    ]);

/// "+25", "−10" (haqiqiy minus belgisi), "0" — foiz belgisisiz.
String kelajakDeltaLabel(int delta) => switch (delta) {
  > 0 => '+$delta',
  < 0 => '−${delta.abs()}',
  _ => '0',
};

/// "10-12" → "10–12".
String kelajakAgeGroupLabel(String ageGroup) => ageGroup.replaceAll('-', '–');

/// Qiziqishi sezilarli ortgan yo'nalishlar (eng ko'p o'sgani oldin).
List<KelajakProgressInterest> kelajakRisingInterests(KelajakProgress p) {
  final rising = [
    for (final interest in p.interests)
      if ((interest.delta ?? 0) >= kKelajakRisingDelta) interest,
  ]..sort((a, b) => (b.delta ?? 0).compareTo(a.delta ?? 0));
  return List.unmodifiable(rising);
}

/// O'zgarishlar bo'limida ko'rsatadigan narsa bormi.
bool kelajakHasProgress(KelajakProgress p) =>
    p.categories.isNotEmpty || kelajakRisingInterests(p).isNotEmpty;

/// Career Lab bo'limi: yoqqan, betaraf va yoqmagan faoliyatlar hamda
/// keyingi sinov tavsiyasi.
@immutable
class KelajakCareerLabView {
  const KelajakCareerLabView({
    required this.liked,
    required this.neutral,
    required this.disliked,
    required this.next,
  });

  factory KelajakCareerLabView.of(KelajakInsights insights) {
    List<KelajakDirection> tried(KelajakVerdict verdict) => List.unmodifiable([
      for (final item in insights.triedDirections)
        if (item.verdict == verdict) item.direction,
    ]);
    return KelajakCareerLabView(
      liked: insights.likedDirections,
      neutral: tried(KelajakVerdict.neutral),
      disliked: tried(KelajakVerdict.disliked),
      next: List.unmodifiable(
        insights.next.where((n) => n.kind == KelajakNextKind.careerLab),
      ),
    );
  }

  final List<KelajakDirection> liked;
  final List<KelajakDirection> neutral;
  final List<KelajakDirection> disliked;
  final List<KelajakNextStep> next;

  bool get isEmpty =>
      liked.isEmpty && neutral.isEmpty && disliked.isEmpty && next.isEmpty;
}

/// Career Lab'dan tashqari keyingi tavsiyalar (test yechish, ertaga).
List<KelajakNextStep> kelajakGeneralNextSteps(KelajakInsights insights) =>
    List.unmodifiable(
      insights.next.where((n) => n.kind != KelajakNextKind.careerLab),
    );

/// Hali javob yo'q va aytadigan signal ham yo'q — bo'sh holat.
bool kelajakShowsEmptyState(KelajakSummary summary) =>
    !summary.hasAnswers && summary.support == null;
