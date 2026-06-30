// "Bolani ilovasini ulash" — bola ma'lumotlari to'ldirilib "Keyingisi"
// bosilganda chiqadigan Parvoz modal varaq (orqa foni = farzand ma'lumotlari
// sahifasi). 5 xonali oila kodini shisha (secondary) qutida katta ko'rsatadi
// (bosib nusxalansa bo'ladi), yo'riqnoma beradi.
//
// Varaq pastga tortib yopilsa bo'ladi (qotmaydi), lekin yopish keyingi
// sahifaga o'tkazmaydi — "Keyingisi"ni qayta bossa varaq yana chiqadi.
// "Keyingi" tugmasi bola qurilmasi ULANGUNCHA o'chiq turadi: ulanmasdan
// keyingi (nazorat) sahifaga o'tib bo'lmaydi.
//
// Ulanish `child.isConnected` orqali aniqlanadi; varaq ochiq turganda har
// 3s backend qayta tekshiriladi (childrenRefreshTickProvider). Ulangach
// "Keyingi" yonadi → pop(true), add_child nazorat sahifasiga o'tadi.

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Parvoz tokenlar (lokal) ════════════
const _bg = Color(0xFF0B1016);
const _green = Color(0xFF34C759);
const _dim = Color(0x8CFFFFFF); // oq 55%

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.4,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.2,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// "Bolani ilovasini ulash" varag'ini ochadi. Bola ulanib "Keyingi"
/// bosilsa `true`, pastga tortib yopilsa `null` qaytaradi.
Future<bool?> showConnectChildSheet(
  BuildContext context, {
  required String childId,
  Child? initialChild,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) =>
        _ConnectChildSheet(childId: childId, initialChild: initialChild),
  );
}

class _ConnectChildSheet extends ConsumerStatefulWidget {
  const _ConnectChildSheet({required this.childId, this.initialChild});

  final String childId;
  final Child? initialChild;

  @override
  ConsumerState<_ConnectChildSheet> createState() => _ConnectChildSheetState();
}

class _ConnectChildSheetState extends ConsumerState<_ConnectChildSheet> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Varaq ochiq turganda backend'ni tezroq (3s) tekshiramiz — o'rnatilgan
    // 60s poll bola "ulandi" lahzasini kuttirib qo'ymasin. Tick ro'yxatni
    // bo'shatmasdan qayta yuklaydi (invalidate emas).
    _poll = Timer.periodic(const Duration(seconds: 3), (timer) {
      // Ulangach to'xtaymiz — isConnected barqaror flag, ortga qaytmaydi.
      final c = ref.read(childByIdProvider(widget.childId));
      if (c?.isConnected ?? false) {
        timer.cancel();
        return;
      }
      ref.read(childrenRefreshTickProvider.notifier).state++;
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    AppToast.success(context, 'connectChild.copied'.tr());
  }

  void _proceed() {
    _poll?.cancel();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final child =
        ref.watch(childByIdProvider(widget.childId)) ?? widget.initialChild;
    final connected = child?.isConnected ?? false;
    final code = child?.familyCode ?? widget.initialChild?.familyCode ?? '';

    final height = MediaQuery.of(context).size.height * 0.8;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: ColoredBox(
        color: _bg,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'connectChild.title'.tr(),
                  textAlign: TextAlign.center,
                  style: _unb(17, w: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _CodeBox(code: code, onCopy: () => _copyCode(code)),
                ),
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'connectChild.instructionsTitle'.tr(),
                      style: _unb(20, w: FontWeight.w700, ls: -0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const _Steps(),
                const Spacer(),
                _StatusLine(connected: connected),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _NextButton(
                    enabled: connected,
                    onTap: connected ? _proceed : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Katta kod qutisi — shisha (secondary) fon; bosilsa nusxalanadi.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCopy,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 88,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.025),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 34), // o'ng nusxa ikonini muvozanatlash
                Expanded(
                  child: Text(
                    code,
                    textAlign: TextAlign.center,
                    style: _unb(34, w: FontWeight.w700, ls: 4),
                  ),
                ),
                Icon(
                  Icons.copy_rounded,
                  size: 22,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Raqamlangan yo'riqnoma (1–4).
class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 1; i <= 4; i++) ...[
            _StepRow(number: i, text: 'connectChild.step$i'.tr()),
            if (i != 4) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number.',
          style: _pop(14, w: FontWeight.w600, c: _dim),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: _pop(14))),
      ],
    );
  }
}

/// Ulanish holati — kutilmoqda (spinner) yoki ulandi (yashil belgi).
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (connected)
          const Icon(Icons.check_circle_rounded, size: 18, color: _green)
        else
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _dim),
          ),
        const SizedBox(width: 8),
        Text(
          connected
              ? 'connectChild.connected'.tr()
              : 'connectChild.waiting'.tr(),
          style: _pop(13, c: connected ? _green : _dim),
        ),
      ],
    );
  }
}

/// Pastdagi "Keyingi" — ulanguncha o'chiq (xira); ulansa pop(true).
class _NextButton extends StatelessWidget {
  const _NextButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ParvozGlass(
          blue: true,
          child: Text(
            'connectChild.next'.tr(),
            style: _pop(16, w: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
