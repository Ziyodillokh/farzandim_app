import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class GradientBackground extends ConsumerWidget {
  /// `GradientBackground` konstruktor.
  const GradientBackground({required this.child, super.key});

  /// Gradient ustida ko'rsatiladigan mazmun.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // themeMode'ni WATCH qilamiz — light/dark toggle'da bu widget MUSTAQIL
    // qayta quriladi (ota-ekran qurilmasa ham). Shuning uchun fon gradienti
    // DARHOL almashadi (avval faqat refresh/navigatsiyada o'zgarardi).
    ref.watch(themeModeProvider);
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
