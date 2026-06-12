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
    final isDark = AppColors.isDark;
    // Glass uchun chuqurlik SHART: brand gradient + aurora blob'lar.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          stops: const [0, 0.55],
        ),
      ),
      child: Stack(
        children: [
          // Aurora ambient glow — shisha kartalar orqasida chuqurlik.
          Positioned.fill(
            child: ClipRect(
              child: Stack(
                // Dark (Aurora Brand-Glow): BITTA tepadagi forest yorug'lik
                //   (xona bitta manbadan yoritilgan) + yuqori-o'ngda mint
                //   kicker + pastda juda nozik forest "pol". "Yashil maydon"
                //   emas — yorug'lik kartalar atrofidagi bo'sh joyda yashaydi
                //   (opaque karta uni o'zidan ortda to'sadi, shu sabab "soup"
                //   bo'lmaydi).
                // Light: AVVALGI sxema — o'zgarmaydi.
                children: isDark
                    ? [
                        // Turkuaz tepa yog'du — xona bitta yorug' manbadan
                        // yoritilgan (shaffof shisha shu yorug'likni tutadi).
                        _blob(
                          AppColors.secondary,
                          0.12,
                          top: -150,
                          left: 0,
                          size: 560,
                        ),
                        // Mint kicker — yuqori-o'ngda salqin aks-sado.
                        _blob(
                          AppColors.accent,
                          0.07,
                          top: 100,
                          right: -120,
                          size: 380,
                        ),
                        // Pastda juda nozik teal "pol" — bo'shliq o'lik
                        // bo'lmasin.
                        _blob(
                          AppColors.secondary,
                          0.05,
                          bottom: -200,
                          left: 10,
                          size: 420,
                        ),
                      ]
                    : [
                        _blob(
                          AppColors.auroraPrimary,
                          0.06,
                          top: -120,
                          left: -90,
                          size: 420,
                        ),
                        _blob(
                          AppColors.auroraLight,
                          0.05,
                          top: 230,
                          right: -150,
                          size: 470,
                        ),
                        _blob(
                          AppColors.auroraAccent,
                          0.045,
                          bottom: -170,
                          left: 20,
                          size: 400,
                        ),
                      ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  /// Yumshoq rangli aurora dog'i (radial gradient, transparentga so'nadi).
  Widget _blob(
    Color color,
    double alpha, {
    required double size,
    double? top,
    double? left,
    double? right,
    double? bottom,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: alpha),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
