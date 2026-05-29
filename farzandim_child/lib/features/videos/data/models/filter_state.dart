// ─────────────────────────────────────────────────────────────────────
// VideoFilterState — Filter bottom sheet'ning immutable state'i
// ─────────────────────────────────────────────────────────────────────
//
// 3 ta multi-select (sohalar, yonalishlar, fanlar) + 1 ta single-select
// (yoshGuruhi). `count` getter — chiqari ko'rsatkich uchun (filter
// ikon ustidagi badge).

class VideoFilterState {
  const VideoFilterState({
    this.sohalar = const [],
    this.yonalishlar = const [],
    this.fanlar = const [],
    this.yoshGuruhi,
  });

  final List<String> sohalar;
  final List<String> yonalishlar;
  final List<String> fanlar;
  final String? yoshGuruhi;

  bool get isEmpty =>
      sohalar.isEmpty &&
      yonalishlar.isEmpty &&
      fanlar.isEmpty &&
      yoshGuruhi == null;

  int get count =>
      sohalar.length +
      yonalishlar.length +
      fanlar.length +
      (yoshGuruhi != null ? 1 : 0);

  VideoFilterState copyWith({
    List<String>? sohalar,
    List<String>? yonalishlar,
    List<String>? fanlar,
    String? yoshGuruhi,
    bool clearYosh = false,
  }) {
    return VideoFilterState(
      sohalar: sohalar ?? this.sohalar,
      yonalishlar: yonalishlar ?? this.yonalishlar,
      fanlar: fanlar ?? this.fanlar,
      yoshGuruhi: clearYosh ? null : (yoshGuruhi ?? this.yoshGuruhi),
    );
  }
}
