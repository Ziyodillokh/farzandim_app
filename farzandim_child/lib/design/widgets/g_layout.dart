// Ekran karkasi: fon orblari (`.bg`), ekran (`.scr`), yuqori panel (`.top`),
// bo'lim sarlavhasi (`.sec-h`), ro'yxat (`.list`/`.li`) va pastki dock (`.dock`).

import 'package:farzandim_child/design/icons/g_icon.dart';
import 'package:farzandim_child/design/tokens.dart';
import 'package:farzandim_child/design/typography.dart';
import 'package:farzandim_child/design/widgets/g_buttons.dart';
import 'package:farzandim_child/design/widgets/g_glass.dart';
import 'package:farzandim_child/design/widgets/g_nav.dart';
import 'package:farzandim_child/design/widgets/g_pressable.dart';
import 'package:farzandim_child/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

typedef _Orb = ({
  double size,
  double? left,
  double? right,
  double? top,
  double? bottom,
  Color color,
  double alpha,
});

const _orbs = <GBgTheme, List<_Orb>>{
  GBgTheme.blue: [
    (
      size: 440,
      left: -170,
      right: null,
      top: -200,
      bottom: null,
      color: Color(0xFF305CEB),
      alpha: .46,
    ),
    (
      size: 320,
      left: null,
      right: -160,
      top: 200,
      bottom: null,
      color: Color(0xFF00A0FF),
      alpha: .16,
    ),
    (
      size: 480,
      left: -60,
      right: null,
      top: null,
      bottom: -300,
      color: Color(0xFF1E3AB4),
      alpha: .34,
    ),
  ],
  GBgTheme.green: [
    (
      size: 420,
      left: -170,
      right: null,
      top: -180,
      bottom: null,
      color: Color(0xFF10B981),
      alpha: .24,
    ),
    (
      size: 380,
      left: null,
      right: -190,
      top: 120,
      bottom: null,
      color: Color(0xFF305CEB),
      alpha: .36,
    ),
    (
      size: 460,
      left: -100,
      right: null,
      top: null,
      bottom: -290,
      color: Color(0xFF1E3AB4),
      alpha: .34,
    ),
  ],
  GBgTheme.gold: [
    (
      size: 420,
      left: -15,
      right: null,
      top: -150,
      bottom: null,
      color: Color(0xFFF59E0B),
      alpha: .20,
    ),
    (
      size: 360,
      left: -200,
      right: null,
      top: 220,
      bottom: null,
      color: Color(0xFF305CEB),
      alpha: .36,
    ),
    (
      size: 480,
      left: null,
      right: -160,
      top: null,
      bottom: -280,
      color: Color(0xFF1E3AB4),
      alpha: .36,
    ),
  ],
  GBgTheme.rose: [
    (
      size: 420,
      left: null,
      right: -150,
      top: -150,
      bottom: null,
      color: Color(0xFFF43F5E),
      alpha: .24,
    ),
    (
      size: 380,
      left: -200,
      right: null,
      top: 300,
      bottom: null,
      color: Color(0xFF305CEB),
      alpha: .34,
    ),
    (
      size: 460,
      left: null,
      right: -100,
      top: null,
      bottom: -290,
      color: Color(0xFF1E3AB4),
      alpha: .34,
    ),
  ],
  GBgTheme.teal: [
    (
      size: 420,
      left: null,
      right: -170,
      top: -170,
      bottom: null,
      color: Color(0xFF14B8A6),
      alpha: .22,
    ),
    (
      size: 380,
      left: -200,
      right: null,
      top: 180,
      bottom: null,
      color: Color(0xFF305CEB),
      alpha: .34,
    ),
    (
      size: 460,
      left: null,
      right: -100,
      top: null,
      bottom: -290,
      color: Color(0xFF1E3AB4),
      alpha: .34,
    ),
  ],
};

/// To'q fon va uchta yumshoq rangli orb (bo'lim mavzusiga qarab).
class GBackground extends StatelessWidget {
  const GBackground({super.key, this.theme = GBgTheme.blue});

  final GBgTheme theme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: GColors.bg,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final orb in _orbs[theme]!)
            Positioned(
              left: orb.left,
              right: orb.right,
              top: orb.top,
              bottom: orb.bottom,
              width: orb.size,
              height: orb.size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      orb.color.withValues(alpha: orb.alpha),
                      orb.color.withValues(alpha: 0),
                    ],
                    stops: const [0, .7],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ekran: fon + xavfsiz zona + kontent + ixtiyoriy dock (pastki tugmalar).
///
/// Uch xil kontent:
/// * `GScreen(children: …)` — aylantiriladigan ro'yxat, orasiga 14px bo'shliq;
/// * `GScreen.slivers(slivers: …)` — uzun yoki dangasa ro'yxatlar (yozishma, tarix);
/// * `GScreen.fill(body: …)` — aylanmaydigan, butun balandlikni egallaydigan ekran
///   (savol, pleyer): ichida `Expanded`/`Spacer` ishlaydi.
///
/// Klaviatura ochilsa dock uning ustiga ko'tariladi; dock balandligi o'lchanadi,
/// shuning uchun ikki-uch qatorli dock ham kontentni yopmaydi.
class GScreen extends StatefulWidget {
  const GScreen({
    super.key,
    required List<Widget> this.children,
    this.top,
    this.dock,
    this.panel,
    this.theme = GBgTheme.blue,
    this.gap = GSpace.gap,
    this.controller,
    this.onRefresh,
  }) : slivers = null,
       body = null;

  const GScreen.slivers({
    super.key,
    required List<Widget> this.slivers,
    this.top,
    this.dock,
    this.theme = GBgTheme.blue,
    this.controller,
    this.onRefresh,
  }) : children = null,
       body = null,
       panel = null,
       gap = GSpace.gap;

  const GScreen.fill({
    super.key,
    required Widget this.body,
    this.top,
    this.dock,
    this.theme = GBgTheme.blue,
  }) : children = null,
       slivers = null,
       panel = null,
       gap = GSpace.gap,
       controller = null,
       onRefresh = null;

  final Widget? top;
  final List<Widget>? children;
  final List<Widget>? slivers;
  final Widget? body;
  final Widget? dock;

  /// Dock o'rniga o'z foni bo'lgan pastki panel (masalan javob tushuntirishi):
  /// balandligi o'lchanadi, kontent uning ostida qolmaydi.
  final Widget? panel;
  final GBgTheme theme;
  final double gap;
  final ScrollController? controller;
  final Future<void> Function()? onRefresh;

  @override
  State<GScreen> createState() => _GScreenState();
}

class _GScreenState extends State<GScreen> {
  /// O'lchangunga qadar: bitta 56px tugmali dock.
  double _dockHeight = GSpace.dockReserve;

  void _onDockSize(Size size) {
    if (!mounted) return;
    if ((size.height - _dockHeight).abs() > .5) {
      setState(() => _dockHeight = size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    // Tab ildizida menyu joyi; klaviatura ochiq bo'lsa menyu yashiriladi.
    final tabInset = keyboard > 0 ? 0.0 : GTabInset.of(context);
    final safeBottom = keyboard > 0 ? 0.0 : media.padding.bottom;
    final dockBottom = keyboard > 0
        ? keyboard
        : (tabInset > 0 ? tabInset + safeBottom : 0.0);
    final hasBottom = widget.dock != null || widget.panel != null;
    final contentBottom =
        (hasBottom ? _dockHeight : 28) +
        (keyboard > 0 ? keyboard : tabInset + safeBottom);
    final padding = EdgeInsets.fromLTRB(
      GSpace.screenH,
      media.padding.top + GSpace.screenTop,
      GSpace.screenH,
      contentBottom,
    );

    return Theme(
      data: GTheme.dark,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
            style: GText.body,
            child: IconTheme(
              data: const IconThemeData(color: GColors.text),
              child: Stack(
                children: [
                  Positioned.fill(child: GBackground(theme: widget.theme)),
                  Positioned.fill(child: _content(padding)),
                  if (widget.panel != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: keyboard > 0 ? keyboard : 0,
                      child: _SizeReporter(
                        onSize: _onDockSize,
                        child: widget.panel!,
                      ),
                    )
                  else if (widget.dock != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: dockBottom,
                      child: _SizeReporter(
                        onSize: _onDockSize,
                        child: GDock(
                          bottomInset: tabInset > 0 || keyboard > 0
                              ? 0
                              : safeBottom,
                          child: widget.dock!,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(EdgeInsets padding) {
    if (widget.body != null) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.top != null) ...[
              widget.top!,
              SizedBox(height: widget.gap),
            ],
            Expanded(child: widget.body!),
          ],
        ),
      );
    }
    final physics = const AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    );
    final Widget scroll;
    if (widget.slivers != null) {
      scroll = CustomScrollView(
        controller: widget.controller,
        physics: physics,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              padding.top,
              padding.right,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: widget.top != null
                  ? Padding(
                      padding: EdgeInsets.only(bottom: widget.gap),
                      child: widget.top,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          for (final sliver in widget.slivers!)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: padding.left),
              sliver: sliver,
            ),
          SliverToBoxAdapter(child: SizedBox(height: padding.bottom)),
        ],
      );
    } else {
      final children = widget.children!;
      scroll = ListView(
        controller: widget.controller,
        padding: padding,
        physics: physics,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (widget.top != null) widget.top!,
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0 || widget.top != null) SizedBox(height: widget.gap),
            children[i],
          ],
        ],
      );
    }
    if (widget.onRefresh == null) return scroll;
    return RefreshIndicator(
      onRefresh: widget.onRefresh!,
      color: GColors.primary,
      backgroundColor: const Color(0xFF121A32),
      edgeOffset: MediaQuery.paddingOf(context).top,
      child: scroll,
    );
  }
}

/// Bolasining o'lchamini har layout'dan keyin xabar qiladi (dock balandligi uchun).
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

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

/// Pastki tugmalar zonasi: fonga singib ketuvchi gradient.
class GDock extends StatelessWidget {
  const GDock({super.key, required this.child, this.bottomInset = 0});

  final Widget child;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: GEffects.dockFade),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          GSpace.screenH,
          40,
          GSpace.screenH,
          28 + bottomInset,
        ),
        child: child,
      ),
    );
  }
}

/// Dock ichidagi yonma-yon tugmalar (`.dock-row`): har biri teng kenglikda.
class GDockRow extends StatelessWidget {
  const GDockRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// Yuqori panel: orqaga/yopish tugmasi, sarlavha, izoh va o'ngdagi amallar.
class GTopBar extends StatelessWidget {
  const GTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// Standart «Orqaga» tugmasi.
  static Widget back({
    required String label,
    required VoidCallback onPressed,
  }) => GIconButton(icon: GIcons.caretLeft, label: label, onPressed: onPressed);

  /// Standart «Yopish» tugmasi.
  static Widget close({
    required String label,
    required VoidCallback onPressed,
  }) => GIconButton(icon: GIcons.x, label: label, onPressed: onPressed);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: GSpace.minTap),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GText.topTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!, style: GText.topSub),
                  ],
                ],
              ),
            ),
          ),
          for (final action in actions) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }
}

/// Bo'lim: kichik katta-harfli sarlavha + ixtiyoriy «Hammasi» havolasi + kontent.
class GSection extends StatelessWidget {
  const GSection({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Sarlavha o'ng tomonidagi bosilmaydigan izoh (masalan «1/3 bajarildi»).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title.toUpperCase(), style: GText.label),
              ),
            ),
            if (trailing != null) trailing!,
            if (actionLabel != null)
              GPressable(
                onTap: onAction,
                semanticLabel: actionLabel,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 32,
                    minWidth: 48,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: Text(
                      actionLabel!,
                      style: GText.onest(
                        13,
                        weight: FontWeight.w600,
                        color: GColors.link,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: GSpace.sectionGap),
        child,
      ],
    );
  }
}

/// Shisha ro'yxat (`.list`): qatorlar orasida ingichka chiziq.
class GList extends StatelessWidget {
  const GList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GGlass(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: GColors.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Ro'yxat qatori (`.li`): chap tomonda tile/avatar, sarlavha + izoh, o'ngda chip yoki strelka.
class GListItem extends StatelessWidget {
  const GListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Standart: bosiladigan qatorda strelka ko'rinadi.
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final chevron = showChevron ?? onTap != null;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: GSpace.minTap),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: GText.itemTitle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: GText.caption),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (chevron) ...[
              const SizedBox(width: 8),
              GIcon(
                GIcons.caretRight,
                size: 18,
                color: GColors.chevron,
                secondaryOpacity: 0,
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return MergeSemantics(child: row);
    // MergeSemantics tashqarida: tugma tuguni sarlavha va izohni o'z nomi sifatida oladi.
    return MergeSemantics(
      child: GPressable(onTap: onTap, pressedScale: .985, child: row),
    );
  }
}
