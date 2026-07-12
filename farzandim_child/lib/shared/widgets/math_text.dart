// Matn ichidagi LaTeX matematik ifodalarni to'g'ri belgilar bilan render
// qiladigan widget. Admin test savol/variantlariga LaTeX yozganда (masalan
// `\((-\infty; 2) \cup (3; +\infty)\)`) xom matn emas, chiroyli matematik
// ko'rinish chiqadi: ∞ = cheksizlik, ∪ birlashma, kasr/daraja/ildiz va h.k.
//
// Qo'llab-quvvatlanadigan delimiterlar: `\(...\)`, `\[...\]`, `$$...$$`,
// `$...$`. Delimiter topilmasa oddiy `Text` kabi ishlaydi (tez yo'l).

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Aralash matn + LaTeX matematik ifodani inline render qiladi.
class MathText extends StatelessWidget {
  /// `MathText` konstruktor. [style] matn va matematika uchun umumiy uslub.
  const MathText(
    this.data, {
    required this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  /// Ko'rsatiladigan matn (ichida LaTeX bo'lishi mumkin).
  final String data;

  /// Matn va matematika uslubi (rang, o'lcham, qalinlik).
  final TextStyle style;

  /// Matnni tekislash.
  final TextAlign textAlign;

  /// Maksimal satr soni (null = cheksiz).
  final int? maxLines;

  /// Sig'masa nima qilish.
  final TextOverflow overflow;

  // `\(...\)` | `\[...\]` | `$$...$$` | `$...$` — birinchi mos kelgan guruh
  // LaTeX ifodasi. `dotAll` — ko'p qatorli ifodalar uchun.
  static final RegExp _mathPattern = RegExp(
    r'\\\((.+?)\\\)|\\\[(.+?)\\\]|\$\$(.+?)\$\$|\$([^$]+?)\$',
    dotAll: true,
  );

  @override
  Widget build(BuildContext context) {
    final matches = _mathPattern.allMatches(data).toList();
    if (matches.isEmpty) {
      // Matematik ifoda yo'q — oddiy matn (ellipsis to'g'ri ishlaydi).
      return Text(
        data,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: data.substring(cursor, m.start)));
      }
      final expr =
          (m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4) ?? '').trim();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          baseline: TextBaseline.alphabetic,
          child: Math.tex(
            expr,
            mathStyle: MathStyle.text,
            textStyle: style,
            // LaTeX buzuq bo'lsa — xom ifodani jimgina matn ko'rsatamiz.
            onErrorFallback: (_) => Text(expr, style: style),
          ),
        ),
      );
      cursor = m.end;
    }
    if (cursor < data.length) {
      spans.add(TextSpan(text: data.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
