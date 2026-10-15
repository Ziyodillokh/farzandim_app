// ─────────────────────────────────────────────────────────────────────
// DesignScale — Growth sahifalari hamma telefonda bir xil ko'rinsin
// ─────────────────────────────────────────────────────────────────────
//
// Maketlar 393pt kenglik (iPhone 15 Pro) uchun chizilgan. Kengligi boshqa
// telefonda (360dp, 412dp, 430dp …) oddiy layout cho'ziladi yoki siqiladi
// — shriftlar bir xil qolib, kartalar boshqacha joylashadi. Bu o'ram
// sahifani maket kengligida chizib, ekran kengligiga MUTANOSIB
// masshtablaydi: proporsiyalar, shriftlar va joylashuv hamma joyda bir xil.
//
// Masshtab [minScale]–[maxScale] oralig'ida (planshetda haddan tashqari
// kattalashmasin — u holda layout kengayadi).

import 'package:flutter/material.dart';

/// Maket kengligi (pt).
const double kDesignWidth = 393;

const double _minScale = 0.88;
const double _maxScale = 1.15;

/// Ekran kengligi bo'yicha masshtab koeffitsiyenti.
double designScaleFor(double screenWidth) =>
    (screenWidth / kDesignWidth).clamp(_minScale, _maxScale);

/// Bolasini maket kengligida chizib, ekran kengligiga mutanosib
/// masshtablaydi. Bolaga moslashtirilgan `MediaQuery` beriladi (o'lcham,
/// xavfsiz zonalar, klaviatura — masshtablangan koordinatalarda).
class DesignScale extends StatelessWidget {
  const DesignScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = designScaleFor(mq.size.width);
    if ((scale - 1).abs() < 0.005) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return child;
        }
        return FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: constraints.maxWidth / scale,
            height: constraints.maxHeight / scale,
            child: MediaQuery(
              data: mq.copyWith(
                size: mq.size / scale,
                padding: mq.padding / scale,
                viewPadding: mq.viewPadding / scale,
                viewInsets: mq.viewInsets / scale,
                devicePixelRatio: mq.devicePixelRatio * scale,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Belgilangan balandlikdagi qatorni (masalan, pastki nav) masshtablaydi.
class DesignScaleRow extends StatelessWidget {
  const DesignScaleRow({super.key, required this.height, required this.child});

  /// Maket koordinatalaridagi balandlik.
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = designScaleFor(MediaQuery.sizeOf(context).width);
    if ((scale - 1).abs() < 0.005) {
      return SizedBox(height: height, child: child);
    }
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        height: height * scale,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: constraints.maxWidth / scale,
            height: height,
            child: child,
          ),
        ),
      ),
    );
  }
}
