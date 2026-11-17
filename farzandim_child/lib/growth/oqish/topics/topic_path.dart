// U02 mavzular yo'li: tugunlar ikki yo'lakda navbatma-navbat (chap/o'ng),
// orasida egri chiziq. Qatorlar balandligi o'lchanadi — katta shriftda ham
// chiziqlar tugunlarni aniq tutashtiradi.

import 'dart:ui' show PathMetric;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/oqish/topics/topic_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const _laneX = [44.0, 96.0];
const _nodeSize = 52.0;
const _currentSize = 72.0;
const _ringSize = 92.0;
const _minRow = 96.0;

class TopicPath extends StatefulWidget {
  const TopicPath({
    super.key,
    required this.map,
    required this.onOpen,
    required this.labelOf,
  });

  final SubjectTopicMap map;
  final ValueChanged<LearningTopic> onOpen;
  final Widget Function(LearningTopic topic) labelOf;

  @override
  State<TopicPath> createState() => _TopicPathState();
}

class _TopicPathState extends State<TopicPath> {
  final _heights = <int, double>{};

  void _onRowSize(int index, Size size) {
    if (!mounted || _heights[index] == size.height) return;
    setState(() => _heights[index] = size.height);
  }

  @override
  Widget build(BuildContext context) {
    final topics = widget.map.topics;
    final language = context.locale.languageCode;
    final rows = [
      for (var i = 0; i < topics.length; i++)
        _Reporter(
          onSize: (size) => _onRowSize(i, size),
          child: _row(i, topics[i], language),
        ),
    ];
    return CustomPaint(
      painter: _ConnectorPainter(
        heights: [
          for (var i = 0; i < topics.length; i++) _heights[i] ?? _minRow,
        ],
        styles: [for (final t in topics) _segmentStyle(t)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  _Segment _segmentStyle(LearningTopic topic) {
    if (topic.id == widget.map.currentTopicId) return _Segment.future;
    return switch (topic.mastery) {
      TopicMastery.mastered => _Segment.mastered,
      TopicMastery.practice => _Segment.practice,
      TopicMastery.notAssessed => _Segment.future,
    };
  }

  Widget _row(int index, LearningTopic topic, String language) {
    final isCurrent = topic.id == widget.map.currentTopicId;
    final lane = _laneX[index % 2];
    // Matn tugunga ergashadi (kanvasdagidek): tugun o'ng chetidan keyin.
    final labelLeft =
        lane + (isCurrent ? _ringSize / 2 + 14 : _nodeSize / 2 + 16);
    final node = isCurrent
        ? _CurrentNode(subject: widget.map.subject)
        : _Node(topic: topic);
    final size = isCurrent ? _ringSize : _nodeSize;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minRow),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(left: lane - size / 2, child: node),
          Padding(
            padding: EdgeInsets.only(left: labelLeft, top: 10, bottom: 10),
            child: widget.labelOf(topic),
          ),
        ],
      ),
    );
    if (!topic.available) return MergeSemantics(child: content);
    return MergeSemantics(
      child: GPressable(
        onTap: () => widget.onOpen(topic),
        pressedScale: .98,
        child: Semantics(
          hint: 'g5.topics.openA11y'.tr(
            namedArgs: {'topic': topic.title.of(language)},
          ),
          child: content,
        ),
      ),
    );
  }
}

enum _Segment { mastered, practice, future }

class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({required this.heights, required this.styles});

  final List<double> heights;
  final List<_Segment> styles;

  @override
  void paint(Canvas canvas, Size size) {
    var top = 0.0;
    for (var i = 0; i < heights.length - 1; i++) {
      final from = Offset(_laneX[i % 2], top + heights[i] / 2);
      final nextTop = top + heights[i];
      final to = Offset(_laneX[(i + 1) % 2], nextTop + heights[i + 1] / 2);
      final dy = (to.dy - from.dy) / 2;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx, from.dy + dy, to.dx, to.dy - dy, to.dx, to.dy);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      switch (styles[i]) {
        case _Segment.mastered:
          canvas.drawPath(path, paint..color = const Color(0xD934D399));
        case _Segment.practice:
          canvas.drawPath(path, paint..color = const Color(0xD9F5B13D));
        case _Segment.future:
          _dashed(canvas, path, paint..color = const Color(0x3DFFFFFF));
      }
      top = nextTop;
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, d + 1), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      !_listEquals(old.heights, heights) || !_listEquals(old.styles, styles);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.topic});

  final LearningTopic topic;

  @override
  Widget build(BuildContext context) {
    if (!topic.available || topic.mastery == TopicMastery.notAssessed) {
      return CustomPaint(
        painter: const _DashedCircle(),
        child: const SizedBox.square(dimension: _nodeSize),
      );
    }
    final mastered = topic.mastery == TopicMastery.mastered;
    final base = mastered ? GHue.green.base : GHue.gold.base;
    final iconColor = mastered
        ? const Color(0xFF8BE8C0)
        : const Color(0xFFFFD27A);
    return GOuterShadow(
      borderRadius: BorderRadius.circular(_nodeSize / 2),
      shadows: [BoxShadow(color: base.withValues(alpha: .08), spreadRadius: 5)],
      child: Container(
        width: _nodeSize,
        height: _nodeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradientOver(
            RadialGradient(
              center: const Alignment(-.3, -.5),
              colors: [
                base.withValues(alpha: mastered ? .42 : .36),
                base.withValues(alpha: mastered ? .16 : .12),
              ],
              stops: const [0, .7],
            ),
            // Asos to'liq qoplaydi — yo'l chizig'i tugun ostidan ko'rinmaydi.
            mastered ? const Color(0xFF081418) : const Color(0xFF1A140A),
          ),
          border: Border.all(
            color: iconColor.withValues(alpha: .55),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: GIcon(
          mastered ? GIcons.check : GIcons.arrowsClockwise,
          size: 22,
          color: iconColor,
          secondaryOpacity: 0,
        ),
      ),
    );
  }
}

class _CurrentNode extends StatelessWidget {
  const _CurrentNode({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _ringSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x5296B9FF), width: 1.5),
        ),
        child: Center(
          child: GOuterShadow(
            borderRadius: BorderRadius.circular(_currentSize / 2),
            shadows: const [
              BoxShadow(color: Color(0x244F86FF), spreadRadius: 6),
              BoxShadow(color: Color(0x8C4F86FF), blurRadius: 36),
            ],
            child: Container(
              width: _currentSize,
              height: _currentSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment(-.5, -.87),
                  end: Alignment(.5, .87),
                  colors: [Color(0xFF5B8DFF), GColors.primaryDeep],
                ),
              ),
              alignment: Alignment.center,
              child: GIcon(subject.gIcon, size: 30, color: GColors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  const _DashedCircle();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(.75);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.4),
          colors: [Color(0xFF1A2444), Color(0xFF0C1328)],
        ).createShader(rect),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0x73B2BED6);
    final path = Path()..addOval(rect);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => false;
}

/// Qator o'lchamini xabar qiladi (yo'l chizig'i uchun).
class _Reporter extends SingleChildRenderObjectWidget {
  const _Reporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReporter(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderReporter renderObject) =>
      renderObject.onSize = onSize;
}

class _RenderReporter extends RenderProxyBox {
  _RenderReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _last) {
      _last = size;
      final reported = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onSize(reported));
    }
  }
}
