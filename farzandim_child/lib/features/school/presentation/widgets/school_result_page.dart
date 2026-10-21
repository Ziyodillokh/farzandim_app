// Maktab sahifalarining yakuniy holati qolipi: animatsiyali belgi, sarlavha,
// mazmun va pastda tugmalar (QR natijasi, test / so'rovnoma / murojaat
// yuborildi). Kichik ekran yoki katta shriftda mazmun aylanadi.

import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SchoolResultPage extends StatelessWidget {
  const SchoolResultPage({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.children,
    required this.actions,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: DesignScale(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _IconBadge(icon: icon, color: color),
                          const SizedBox(height: 22),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: homeDisplay(
                              24,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                          ),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Natija ostidagi izoh matni (markazda, xira).
class SchoolResultNote extends StatelessWidget {
  const SchoolResultNote(this.text, {super.key, this.top = 12});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: homeText(15, color: HomeColors.textDim, height: 1.45),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          ),
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 46, color: Colors.white),
          ),
        )
        .animate()
        .scale(
          duration: 450.ms,
          curve: Curves.easeOutBack,
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
        )
        .fadeIn(duration: 200.ms);
  }
}
