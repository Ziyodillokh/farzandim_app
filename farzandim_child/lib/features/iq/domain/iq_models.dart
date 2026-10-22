// IQ test modellari (docs/IQ-REJA.md §4, §8) — server javobi xavfsiz o'qiladi.
// Majburiy maydon noto'g'ri bo'lsa `FormatException` (repozitoriy uni
// `IqErrorCode.unknown`ga aylantiradi). To'g'ri javob kaliti serverdan
// hech qachon kelmaydi. Savol rasmli (SVG) yoki matnli (uch tilda).

import 'package:farzandim_child/features/school/domain/school_json.dart';

enum IqAgeStatus { ok, ageRequired, ageOutOfRange, unknown }

enum IqResultStatus { provisional, normed }

enum IqBand {
  veryHigh,
  high,
  aboveAverage,
  average,
  belowAverage,
  low,
  veryLow,
}

enum IqSessionStatus { started, inProgress, completed, abandoned, unknown }

/// Savol turi: rasmli naqsh, sonlar qatori, so'z munosabati, mantiq.
enum IqItemKind { figural, numeric, verbal, logic }

IqItemKind? _kindOf(Object? value) => switch (value) {
  'FIGURAL' => IqItemKind.figural,
  'NUMERIC' => IqItemKind.numeric,
  'VERBAL' => IqItemKind.verbal,
  'LOGIC' => IqItemKind.logic,
  _ => null,
};

Map<String, dynamic> _map(Object? value, String what) =>
    value is Map<String, dynamic> ? value : throw FormatException(what);

String _id(Object? value, String what) =>
    jsonNonEmpty(value) ?? (throw FormatException(what));

int _int(Object? value, String what) =>
    jsonInt(value) ?? (throw FormatException(what));

class IqAge {
  const IqAge({required this.status, this.age, this.level});

  factory IqAge.fromJson(Object? json) {
    final m = _map(json, 'age');
    return IqAge(
      status: switch (m['status']) {
        'OK' => IqAgeStatus.ok,
        'AGE_REQUIRED' => IqAgeStatus.ageRequired,
        'AGE_OUT_OF_RANGE' => IqAgeStatus.ageOutOfRange,
        _ => IqAgeStatus.unknown,
      },
      age: jsonInt(m['age']),
      level: jsonInt(m['level']),
    );
  }

  final IqAgeStatus status;
  final int? age;
  final int? level;
}

/// Uch tilli matn (savol sharti / variant). `uz` majburiy, qolgani — zaxira.
class IqText {
  const IqText({required this.uz, required this.ru, required this.en});

  factory IqText.fromJson(Object? json, String what) {
    final m = _map(json, what);
    final uz = _id(m['uz'], '$what.uz');
    return IqText(
      uz: uz,
      ru: jsonNonEmpty(m['ru']) ?? uz,
      en: jsonNonEmpty(m['en']) ?? uz,
    );
  }

  final String uz;
  final String ru;
  final String en;

  String of(String languageCode) => switch (languageCode) {
    'ru' => ru,
    'en' => en,
    _ => uz,
  };
}

/// Aralash formada tur bo'yicha xom natija.
class IqDomainScore {
  const IqDomainScore({
    required this.kind,
    required this.right,
    required this.total,
  });

  final IqItemKind kind;
  final int right;
  final int total;

  /// Buzuq yoki noma'lum tur — tashlab yuboriladi (natija baribir ko'rinadi).
  static List<IqDomainScore> listFrom(Object? json) {
    if (json is! List) return const [];
    return [
      for (final d in json)
        if (d is Map<String, dynamic>)
          if ((_kindOf(d['kind']), jsonInt(d['right']), jsonInt(d['total']))
              case (final kind?, final right?, final total?)
              when total > 0 && right >= 0 && right <= total)
            IqDomainScore(kind: kind, right: right, total: total),
    ];
  }
}

class IqResult {
  const IqResult({
    required this.correct,
    required this.total,
    required this.status,
    required this.percentile,
    required this.band,
    required this.completedAt,
    this.standardScore,
    this.ciLow,
    this.ciHigh,
    this.domains = const [],
  });

  factory IqResult.fromJson(Object? json) {
    final m = _map(json, 'result');
    final ci = m['ci95'];
    final normed = m['status'] == 'NORMED';
    return IqResult(
      correct: _int(m['correct'], 'correct'),
      total: _int(m['total'], 'total'),
      status: normed ? IqResultStatus.normed : IqResultStatus.provisional,
      percentile: _int(m['percentile'], 'percentile').clamp(1, 99),
      band: _bandOf(m['band']),
      completedAt: jsonInstant(m['completedAt']) ?? DateTime.now().toUtc(),
      // IQ raqami faqat NORMED holatda (serverda ham shunday).
      standardScore: normed ? jsonInt(m['standardScore']) : null,
      ciLow: normed && ci is List && ci.length == 2 ? jsonInt(ci[0]) : null,
      ciHigh: normed && ci is List && ci.length == 2 ? jsonInt(ci[1]) : null,
      domains: IqDomainScore.listFrom(m['domains']),
    );
  }

  final int correct;
  final int total;
  final IqResultStatus status;
  final int percentile;
  final IqBand band;
  final DateTime completedAt;
  final int? standardScore;
  final int? ciLow;
  final int? ciHigh;

  /// Faqat aralash formada (rasmli A/B formada bo'sh).
  final List<IqDomainScore> domains;

  bool get isNormed => status == IqResultStatus.normed && standardScore != null;

  static IqBand _bandOf(Object? value) => switch (value) {
    'VERY_HIGH' => IqBand.veryHigh,
    'HIGH' => IqBand.high,
    'ABOVE_AVERAGE' => IqBand.aboveAverage,
    'BELOW_AVERAGE' => IqBand.belowAverage,
    'LOW' => IqBand.low,
    'VERY_LOW' => IqBand.veryLow,
    _ => IqBand.average,
  };
}

class IqHistoryEntry {
  const IqHistoryEntry({
    required this.sessionId,
    required this.level,
    required this.result,
  });

  factory IqHistoryEntry.fromJson(Object? json) {
    final m = _map(json, 'history');
    return IqHistoryEntry(
      sessionId: _id(m['sessionId'], 'sessionId'),
      level: _int(m['level'], 'level'),
      result: IqResult.fromJson(m['result']),
    );
  }

  final String sessionId;
  final int level;
  final IqResult result;
}

class IqActive {
  const IqActive({
    required this.sessionId,
    required this.answered,
    required this.total,
  });

  final String sessionId;
  final int answered;
  final int total;
}

class IqOverview {
  const IqOverview({
    required this.age,
    required this.canStart,
    required this.history,
    this.nextAvailableAt,
    this.active,
    this.last,
  });

  factory IqOverview.fromJson(Object? json) {
    final m = _map(json, 'overview');
    final rawActive = m['active'];
    final active = rawActive is Map<String, dynamic> ? rawActive : null;
    final history = m['history'];
    return IqOverview(
      age: IqAge.fromJson(m['age']),
      canStart: m['canStart'] == true,
      nextAvailableAt: jsonInstant(m['nextAvailableAt']),
      active: active == null
          ? null
          : IqActive(
              sessionId: _id(active['sessionId'], 'active.sessionId'),
              answered: jsonInt(active['answered']) ?? 0,
              total: jsonInt(active['total']) ?? 0,
            ),
      last: m['last'] == null ? null : IqResult.fromJson(m['last']),
      history: history is List
          ? [for (final h in history) IqHistoryEntry.fromJson(h)]
          : const [],
    );
  }

  final IqAge age;
  final bool canStart;
  final DateTime? nextAvailableAt;
  final IqActive? active;
  final IqResult? last;
  final List<IqHistoryEntry> history;
}

/// Variant: rasmli savolda `svg`, matnli savolda `text`.
class IqOption {
  const IqOption({required this.key, this.svg, this.text});

  final String key;
  final String? svg;
  final IqText? text;
}

class IqItem {
  const IqItem({
    required this.id,
    required this.position,
    required this.options,
    this.kind = IqItemKind.figural,
    this.gridSvg,
    this.stem,
    this.choice,
  });

  factory IqItem.fromJson(Object? json) {
    final m = _map(json, 'item');
    final options = m['options'];
    if (options is! List || options.isEmpty) {
      throw const FormatException('options');
    }
    // `kind` yo'q (eski server) — rasmli.
    final kind = m['kind'] == null
        ? IqItemKind.figural
        : _kindOf(m['kind']) ?? (throw const FormatException('kind'));
    final isFigural = kind == IqItemKind.figural;
    return IqItem(
      id: _id(m['id'], 'item.id'),
      position: _int(m['position'], 'position'),
      kind: kind,
      gridSvg: isFigural ? _id(m['gridSvg'], 'gridSvg') : null,
      stem: isFigural ? null : IqText.fromJson(m['stem'], 'stem'),
      options: [
        for (final o in options)
          isFigural
              ? IqOption(
                  key: _id(_map(o, 'option')['key'], 'option.key'),
                  svg: _id(_map(o, 'option')['svg'], 'option.svg'),
                )
              : IqOption(
                  key: _id(_map(o, 'option')['key'], 'option.key'),
                  text: IqText.fromJson(
                    _map(o, 'option')['text'],
                    'option.text',
                  ),
                ),
      ],
      choice: jsonNonEmpty(m['choice']),
    );
  }

  final String id;
  final int position;
  final IqItemKind kind;

  /// Faqat rasmli savolda.
  final String? gridSvg;

  /// Faqat matnli savolda: 1-qator — ko'rsatma, qolgani — savolning o'zi.
  final IqText? stem;
  final List<IqOption> options;
  final String? choice;

  bool get isFigural => kind == IqItemKind.figural;

  IqItem withChoice(String? value) => IqItem(
    id: id,
    position: position,
    kind: kind,
    gridSvg: gridSvg,
    stem: stem,
    options: options,
    choice: value,
  );
}

class IqSession {
  const IqSession({
    required this.id,
    required this.status,
    required this.level,
    required this.items,
    this.result,
  });

  factory IqSession.fromJson(Object? json) {
    final m = _map(json, 'session');
    final items = m['items'];
    if (items is! List) throw const FormatException('items');
    return IqSession(
      id: _id(m['id'], 'session.id'),
      status: switch (m['status']) {
        'STARTED' => IqSessionStatus.started,
        'IN_PROGRESS' => IqSessionStatus.inProgress,
        'COMPLETED' => IqSessionStatus.completed,
        'ABANDONED' => IqSessionStatus.abandoned,
        _ => IqSessionStatus.unknown,
      },
      level: jsonInt(m['level']) ?? 0,
      items: [for (final i in items) IqItem.fromJson(i)]
        ..sort((a, b) => a.position.compareTo(b.position)),
      result: m['result'] == null ? null : IqResult.fromJson(m['result']),
    );
  }

  final String id;
  final IqSessionStatus status;
  final int level;
  final List<IqItem> items;
  final IqResult? result;

  bool get isOpen =>
      status == IqSessionStatus.started || status == IqSessionStatus.inProgress;

  int get answeredCount => items.where((i) => i.choice != null).length;

  bool get isAllAnswered => items.isNotEmpty && answeredCount == items.length;

  /// Aralash forma (bir nechta savol turi) — savol turi belgisi ko'rsatiladi.
  bool get isMixed => items.map((i) => i.kind).toSet().length > 1;

  /// Birinchi javobsiz savol (davom ettirish uchun), hammasi javobli — 0.
  int get resumeIndex {
    final index = items.indexWhere((i) => i.choice == null);
    return index < 0 ? 0 : index;
  }

  IqSession withItem(int index, IqItem item) => IqSession(
    id: id,
    status: status,
    level: level,
    items: [...items]..[index] = item,
    result: result,
  );
}
