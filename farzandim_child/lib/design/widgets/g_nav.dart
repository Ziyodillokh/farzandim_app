// Pastki menyu (4 tab: Bugun · Oʻqish · Maktab · Men) va pastki varaq (sheet).

import 'package:farzandim_child/design/icons/g_icon.dart';
import 'package:farzandim_child/design/tokens.dart';
import 'package:farzandim_child/design/typography.dart';
import 'package:farzandim_child/design/widgets/g_glass.dart';
import 'package:farzandim_child/design/widgets/g_pressable.dart';
import 'package:flutter/material.dart';

/// Tab ildiz ekranlari ostida menyu egallaydigan joy (GScreen shuni zaxiralaydi).
class GTabInset extends InheritedWidget {
  const GTabInset({super.key, required this.height, required super.child});

  final double height;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GTabInset>()?.height ?? 0;

  @override
  bool updateShouldNotify(GTabInset old) => old.height != height;
}

/// Menyu balandligi: 72 + pastdan 20 + yuqoridan 12 nafas.
const kGTabBarHeight = 104.0;

class GTabItem {
  const GTabItem({required this.label, required this.icon});

  final String label;
  final GIconData icon;
}

/// Suzuvchi shisha menyu: 72px, yon tomonlardan 14px, pastdan 20px + xavfsiz zona.
class GTabBar extends StatelessWidget {
  const GTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<GTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _radius = 28.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, 20 + bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: const [
            BoxShadow(
              color: Color(0xD9000000),
              offset: Offset(0, 24),
              blurRadius: 44,
              spreadRadius: -16,
            ),
          ],
        ),
        // Blur ishlatilmaydi: fon 88–94% qoplangan, blur ko'rinmaydi, lekin har
        // kadrda qimmat qatlam qo'shadi.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: CustomPaint(
            foregroundPainter: const GRingPainter(
              radius: _radius,
              gradient: LinearGradient(
                begin: Alignment(-.34, -.94),
                end: Alignment(.34, .94),
                colors: [
                  Color(0x33FFFFFF),
                  Color(0x0DFFFFFF),
                  Color(0x08FFFFFF),
                  Color(0x2496B9FF),
                ],
                stops: [0, .4, .6, 1],
              ),
            ),
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xE0121A32), Color(0xF0080C1B)],
                ),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(child: _tab(i)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int index) {
    final item = items[index];
    final on = index == currentIndex;
    final color = on ? GColors.white : GColors.textFaint;
    return GPressable(
      onTap: () => onSelect(index),
      selected: on,
      exclusive: true,
      semanticLabel: item.label,
      pressedScale: .94,
      haptic: !on,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: on
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [GColors.primary, GColors.primaryMid],
                    )
                  : null,
              boxShadow: on
                  ? const [
                      BoxShadow(
                        color: Color(0xCC2F63F5),
                        offset: Offset(0, 8),
                        blurRadius: 18,
                        spreadRadius: -6,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: GIcon(
              item.icon,
              size: 22,
              color: color,
              secondaryOpacity: .3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            maxLines: 1,
            style: GText.tab.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Pastdan chiqadigan varaq (tasdiqlash, filtr, tanlov).
Future<T?> showGSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // Tab ildizidan ochilganda ham suzuvchi menyu ustida chiqsin.
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x9E03060F),
    builder: (context) => _GSheet(child: builder(context)),
  );
}

class _GSheet extends StatelessWidget {
  const _GSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.paddingOf(context).bottom +
        MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 28 + bottom),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GRadius.sheet),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF7141C36), Color(0xFC090D1D)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xCC000000),
            offset: Offset(0, -24),
            blurRadius: 60,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: GText.body,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x2EFFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
