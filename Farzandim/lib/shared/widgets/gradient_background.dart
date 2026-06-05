import 'package:farzandim/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// PDF dizaynidagi gradient fon — yuqoridan pastga, moviy tusdan
/// chuqur qora rangga.
///
/// Loyihada **deyarli har bir Scaffold** shu widget bilan o'raladi
/// (Welcome'dan tashqari — uning o'z rasm fon'i bor):
///
/// ```dart
/// Scaffold(
///   backgroundColor: Colors.transparent,
///   body: GradientBackground(
///     child: SafeArea(child: ...),
///   ),
/// )
/// ```
///
/// Gradient stops `[0.0, 0.5]` — yuqori yarmida tranzitsiya, pastki yarmi
/// solid `backgroundBottom`. Bu PDF dizaynidagi "fade to black" effektini
/// beradi.
///
/// Bosqich 7 (Theme polish)'da bu widget'ni `app.dart` darajasida global
/// qilib qo'yamiz, har Scaffold'da takrorlash shart bo'lmaydi.
class GradientBackground extends StatelessWidget {
  /// `GradientBackground` konstruktor.
  const GradientBackground({required this.child, super.key});

  /// Gradient ustida ko'rsatiladigan mazmun.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundTop,
            AppColors.backgroundBottom,
          ],
          stops: const [0, 0.5],
        ),
      ),
      child: child,
    );
  }
}
