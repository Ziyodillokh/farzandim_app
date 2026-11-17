// PIN paneli: sarlavha, 4 ta nuqta (xatoda qizarib silkinadi) va shisha
// raqam tugmalari. Qulf ekrani va «Men › Ilova qulfi» oqimlarida bir xil.

import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/men/lock/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kiritilgan kodni tekshiradi: `null` — qabul, matn — xato (panel tozalanadi).
typedef PinCheckFn = Future<String?> Function(String pin);

class PinPanel extends StatefulWidget {
  const PinPanel({
    super.key,
    required this.title,
    required this.onComplete,
    this.subtitle,
    this.blockedText,
    this.leftKey,
  });

  final String title;
  final String? subtitle;
  final PinCheckFn onComplete;

  /// Berilsa — tugmalar o'chiq, shu matn ko'rinadi (ko'p xato).
  final String? blockedText;

  /// Pastki chap tugma (masalan barmoq izi).
  final Widget? leftKey;

  @override
  State<PinPanel> createState() => _PinPanelState();
}

class _PinPanelState extends State<PinPanel>
    with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  String _pin = '';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool get _enabled => !_busy && widget.blockedText == null;

  Future<void> _digit(String d) async {
    if (!_enabled || _pin.length >= kPinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length < kPinLength) return;
    setState(() => _busy = true);
    final error = await widget.onComplete(_pin);
    if (!mounted) return;
    if (error == null) {
      setState(() => _busy = false);
      return;
    }
    // Xato: nuqtalar qizarib silkinadi, kiritish darhol qayta boshlanadi.
    HapticFeedback.heavyImpact();
    setState(() {
      _error = error;
      _busy = false;
      _pin = '';
    });
    unawaited(_shake.forward(from: 0));
  }

  void _backspace() {
    if (!_enabled || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.blockedText ?? _error ?? widget.subtitle;
    final isAlert = widget.blockedText != null || _error != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: GText.display(22),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: Semantics(
            liveRegion: isAlert,
            child: Text(
              message ?? '',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GText.onest(
                14,
                color: isAlert ? GColors.errorText : GColors.textMuted,
                height: 1.35,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value),
              0,
            ),
            child: child,
          ),
          child: _Dots(filled: _pin.length, error: _error != null),
        ),
        const SizedBox(height: 36),
        _Keypad(
          enabled: _enabled,
          onDigit: _digit,
          onBackspace: _backspace,
          leftKey: widget.leftKey,
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.error});

  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'g5.lock.entered'.tr(
        namedArgs: {'n': '$filled', 'total': '$kPinLength'},
      ),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < kPinLength; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: error
                        ? GColors.danger
                        : i < filled
                        ? GColors.text
                        : Colors.transparent,
                    border: Border.all(
                      color: error
                          ? GColors.danger
                          : i < filled
                          ? GColors.text
                          : GColors.text.withValues(alpha: .35),
                      width: 1.6,
                    ),
                    boxShadow: i < filled && !error
                        ? [
                            BoxShadow(
                              color: GHue.blue.base.withValues(alpha: .55),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    this.leftKey,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? leftKey;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in _rows) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final d in row) _DigitKey(d, onTap: () => onDigit(d)),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: PinKey.size + 24,
                child: Center(child: leftKey),
              ),
              _DigitKey('0', onTap: () => onDigit('0')),
              SizedBox.square(
                dimension: PinKey.size + 24,
                child: Center(
                  child: PinKey(
                    semanticLabel: 'g5.lock.delete'.tr(),
                    onTap: onBackspace,
                    plain: true,
                    child: const GIcon(
                      GIcons.backspace,
                      size: 28,
                      color: GColors.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey(this.digit, {required this.onTap});

  final String digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: PinKey(
        semanticLabel: digit,
        onTap: onTap,
        child: Text(digit, style: GText.display(28)),
      ),
    );
  }
}

/// Dumaloq shisha tugma (raqam, barmoq izi, o'chirish).
class PinKey extends StatelessWidget {
  const PinKey({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.plain = false,
  });

  static const size = 74.0;

  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;

  /// Fon va chegarasiz (yordamchi tugmalar).
  final bool plain;

  @override
  Widget build(BuildContext context) {
    return GPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      pressedScale: .9,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: plain
            ? null
            : BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: .10),
                    Colors.white.withValues(alpha: .03),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
        child: ExcludeSemantics(child: child),
      ),
    );
  }
}

/// «Ko'p urinish» matni: qolgan soniya yoki daqiqa.
String pinBlockedText(DateTime until, DateTime now) {
  final left = until.difference(now);
  final seconds = left.inSeconds + 1;
  return seconds < 60
      ? 'g5.lock.blockedSeconds'.tr(namedArgs: {'n': '$seconds'})
      : 'g5.lock.blockedMinutes'.tr(
          namedArgs: {'n': '${(seconds / 60).ceil()}'},
        );
}
