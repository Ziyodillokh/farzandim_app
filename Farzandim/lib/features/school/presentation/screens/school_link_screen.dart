// ─────────────────────────────────────────────────────────────────────
// SchoolLinkScreen — maktab taklif kodini kiritish (yoki QR skanerlash)
// ─────────────────────────────────────────────────────────────────────
//
// Ikki xil kod: 6 xonali RAQAMLI o'quvchi kodi ("042913", bosh nol bilan)
// va 8 belgili vasiy kodi ("XXXX-XXXX"; kichik harf, bo'shliq va "-" ham
// qabul qilinadi). Maydon raqam kiritilganda raqamli klaviaturani ochadi
// (harf paydo bo'lsa yoki "ABC" bosilsa — harfli); uzun matn yopishtirilsa
// undan kod ajratiladi. Muvaffaqiyatda moslanmagan o'quvchilar uchun
// moslash varag'i ochiladi, so'ng sahifa `true` bilan yopiladi
// (chaqiruvchi yangilangan ro'yxatni ko'radi). Xato maydon ostida:
// noto'g'ri/eskirgan kod, juda ko'p urinish, tarmoq. QR — panel chiqargan
// `https://farzandimedu.uz/link?code=...` yoki xom kod (`SchoolInviteScanScreen`):
// FAQAT havola darrov yuboriladi; xom kod (istalgan begona QR bo'lishi
// mumkin) maydonga yoziladi va "Ulanish"ni ota-ona bosadi — tasodifiy kod
// noto'g'ri urinishlar limitini sarflamasin. Telefon kamerasi bilan
// skanerlangan havola (deep link) kodni [SchoolLinkScreen.initialCode]
// orqali maydonga yozadi — yuborishni baribir ota-ona tasdiqlaydi (begona
// havola ota-onani o'zi bilmagan maktabga ulab qo'ymasin).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/data/invite_code.dart';
import 'package:farzandim/features/school/presentation/invite_code_formatter.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/screens/school_invite_scan_screen.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/features/school/presentation/widgets/student_child_match_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF); // oq 60%
const _danger = Color(0xFFFF5A5D);

TextStyle _unb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: -0.5,
  height: 1.3,
);

TextStyle _pop(double size, {Color c = Colors.white}) =>
    GoogleFonts.poppins(fontSize: size, color: c, height: 1.5);

/// Taklif kodi bilan maktabga ulanish.
class SchoolLinkScreen extends ConsumerStatefulWidget {
  const SchoolLinkScreen({this.scannerBuilder, this.initialCode, super.key});

  /// QR skaner ekrani; berilmasa kamera skaneri (testlarda kamerasiz
  /// almashtiriladi).
  final WidgetBuilder? scannerBuilder;

  /// Havoladan (`farzandimedu.uz/link?code=…`) kelgan kod — maydon oldindan
  /// to'ldiriladi, yuborish ota-onaning o'zida.
  final String? initialCode;

  @override
  ConsumerState<SchoolLinkScreen> createState() => _SchoolLinkScreenState();
}

class _SchoolLinkScreenState extends ConsumerState<SchoolLinkScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  /// Raqamli klaviatura (6 xonali kod uchun qulay). Matnga harf kirsa
  /// o'zi `false` bo'ladi; "ABC" / "123" tugmasi uni qo'lda almashtiradi.
  bool _numericPad = true;

  /// Kod havoladan olingan (ekranda izoh ko'rsatiladi).
  bool _fromLink = false;

  @override
  void initState() {
    super.initState();
    final code = InviteCode.fromLinkParam(widget.initialCode);
    if (code == null) return;
    final text = InviteCode.format(code);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _numericPad = InviteCode.isNumericInput(text);
    _fromLink = true;
  }

  bool get _isValid => InviteCode.isValid(_controller.text);

  /// Matnda harf bo'lsa yoki foydalanuvchi tanlasa — harfli klaviatura.
  bool get _showNumericPad =>
      _numericPad && InviteCode.isNumericInput(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Yangi kiritishda eski xato yo'qoladi va tugma holati yangilanadi;
  /// harf kiritilsa (yoki yopishtirilsa) klaviatura harfliga o'tadi.
  void _onChanged(String text) => setState(() {
    _error = null;
    _fromLink = false;
    if (!InviteCode.isNumericInput(text)) _numericPad = false;
  });

  Future<void> _scan() async {
    FocusScope.of(context).unfocus();
    final scan = await Navigator.of(context).push<ScannedInvite>(
      MaterialPageRoute(
        builder: widget.scannerBuilder ?? (_) => const SchoolInviteScanScreen(),
      ),
    );
    if (scan == null || !mounted) return;
    final text = InviteCode.format(scan.code);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {
      _error = null;
      _numericPad = InviteCode.isNumericInput(text);
    });
    // Faqat Parvoz havolasi (panel QR'i) ishonchli — darrov yuboriladi.
    if (scan.fromLink) await _submit();
  }

  Future<void> _submit() async {
    if (_submitting || !_isValid) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref
        .read(schoolActionsProvider.notifier)
        .redeem(_controller.text);
    if (!mounted) return;
    final links = result.data;
    if (links == null) {
      setState(() {
        _submitting = false;
        _error = result.error ?? 'errors.generic'.tr();
      });
      return;
    }
    AppToast.success(context, 'school.link.success'.tr());
    final pending = links.unmatchedStudents;
    if (pending.isNotEmpty) {
      final addChild = await showStudentChildMatchSheet(
        context,
        links: links,
        studentIds: [for (final student in pending) student.id],
      );
      if (!mounted) return;
      if (addChild) {
        // Farzand hali yo'q: shu sahifa bola qo'shish bilan almashadi;
        // o'quvchi keyin dashboard kartasidan bog'lanadi.
        context.pushReplacement(AppRoutes.addChild);
        return;
      }
    }
    _finish();
  }

  /// Chaqiruvchiga qaytish; to'g'ridan-to'g'ri ochilgan bo'lsa — maktab.
  void _finish() {
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go(AppRoutes.school);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return SchoolScaffold(
      title: 'school.link.title'.tr(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const _HeroIcon(),
          const SizedBox(height: 20),
          Text(
            'school.link.heading'.tr(),
            textAlign: TextAlign.center,
            style: _unb(20),
          ),
          const SizedBox(height: 8),
          Text(
            'school.link.body'.tr(),
            textAlign: TextAlign.center,
            style: _pop(14, c: _dim),
          ),
          const SizedBox(height: 28),
          ParvozTextField(
            label: 'school.link.codeLabel'.tr(),
            hint: 'school.link.codeHint'.tr(),
            controller: _controller,
            keyboardType: _showNumericPad
                ? TextInputType.number
                : TextInputType.visiblePassword,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: const [InviteCodeInputFormatter()],
            onChanged: _onChanged,
            suffix: InviteCode.isNumericInput(_controller.text)
                ? _KeyboardToggle(
                    numeric: _showNumericPad,
                    onTap: () => setState(() => _numericPad = !_numericPad),
                  )
                : null,
          ),
          if (_fromLink && error == null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(SolarIconsBold.linkCircle, size: 18, color: _blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'school.link.fromLinkHint'.tr(),
                    style: _pop(13, c: _dim),
                  ),
                ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  SolarIconsBold.dangerCircle,
                  size: 18,
                  color: _danger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(error, style: _pop(13, c: _danger)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          ParvozSecondaryButton(
            label: 'school.link.scan'.tr(),
            leading: const Icon(
              SolarIconsOutline.qrCode,
              size: 20,
              color: Colors.white,
            ),
            enabled: !_submitting,
            onPressed: _scan,
          ),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: ParvozPrimaryButton(
          label: 'school.link.submit'.tr(),
          onPressed: _submit,
          enabled: _isValid,
          loading: _submitting,
          showArrow: false,
        ),
      ),
    );
  }
}

/// Maydon ichidagi klaviatura almashtirgich: raqamli klaviaturada "ABC"
/// (harfli kod uchun), harflida "123". Ko'rinishi ixcham, bosiladigan joyi
/// kamida 48x48 dp.
class _KeyboardToggle extends StatelessWidget {
  const _KeyboardToggle({required this.numeric, required this.onTap});

  final bool numeric;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      onTap: onTap,
      label: numeric
          ? 'school.link.keyboardLetters'.tr()
          : 'school.link.keyboardDigits'.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('keyboard-toggle'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          alignment: Alignment.center,
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 34),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Text(
              numeric ? 'ABC' : '123',
              style: _pop(
                13,
              ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Akademik qalpoq — ko'k doira, yumshoq yog'du.
class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _blue,
          boxShadow: [
            BoxShadow(
              color: ParvozColors.glow.withValues(alpha: 0.45),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          SolarIconsBold.squareAcademicCap,
          size: 36,
          color: Colors.white,
        ),
      ),
    );
  }
}
