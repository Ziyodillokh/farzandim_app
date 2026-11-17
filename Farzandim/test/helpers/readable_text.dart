// O'qiladigan matn tekshiruvi: tor ekran yoki katta shriftda matn so'z
// o'rtasidan uzilmasin (ism harflari ustunga tushib qolmasin) va
// chegaralangan matnlar belgilangan qatordan oshmasin.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// [paragraph] ning qatorlari: o'sha matn va sozlamalar bilan, o'sha
/// kenglikda qayta joylangan [TextPainter] (RenderParagraph qator
/// ma'lumotini ochmaydi). Ichida vidjet (WidgetSpan) bo'lsa — null.
TextPainter? _linesOf(RenderParagraph paragraph) {
  var hasWidgets = false;
  paragraph.text.visitChildren((span) {
    hasWidgets = span is PlaceholderSpan;
    return !hasWidgets;
  });
  if (hasWidgets) return null;
  final wraps =
      paragraph.softWrap || paragraph.overflow == TextOverflow.ellipsis;
  return TextPainter(
    text: paragraph.text,
    textAlign: paragraph.textAlign,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
    ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '…' : null,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: wraps ? paragraph.size.width : double.infinity);
}

/// [paragraph] da qator so'z ichida boshlangan joylar (qatordagi birinchi
/// belgi va undan oldingisi — ikkalasi ham harf yoki raqam).
List<int> midWordBreaks(RenderParagraph paragraph) {
  final painter = _linesOf(paragraph);
  if (painter == null) return const [];
  final text = paragraph.text.toPlainText();
  final breaks = <int>[];
  for (var offset = 1; offset < text.length; offset++) {
    final line = painter.getLineBoundary(TextPosition(offset: offset));
    if (line.start != offset) continue;
    if (_wordChar.hasMatch(text[offset - 1]) &&
        _wordChar.hasMatch(text[offset])) {
      breaks.add(offset);
    }
  }
  painter.dispose();
  return breaks;
}

/// Ekrandagi hech bir matn so'z o'rtasidan uzilmagan.
void expectNoMidWordBreaks(WidgetTester tester) {
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    final breaks = midWordBreaks(paragraph);
    expect(
      breaks,
      isEmpty,
      reason:
          "«${paragraph.text.toPlainText()}» so'z o'rtasidan uzildi "
          '(${paragraph.size.width.toStringAsFixed(0)} px kenglikda)',
    );
  }
}

/// [text] matni ekranda nechta qatorda turibdi.
int lineCountOf(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.text(text, findRichText: true).first,
  );
  final painter = _linesOf(paragraph)!;
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines;
}

/// Maktab ekranlari shriftlari (Poppins, Unbounded) `assets/google_fonts`
/// dan yuklanadi. Busiz test "FlutterTest" shriftida chizadi — har harf
/// 1em keng, qator uzilishi telefondagidan butunlay farq qiladi.
Future<void> loadSchoolFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final w in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
  ]) {
    GoogleFonts.poppins(fontWeight: w);
    GoogleFonts.unbounded(fontWeight: w);
  }
  await GoogleFonts.pendingFonts();
}
