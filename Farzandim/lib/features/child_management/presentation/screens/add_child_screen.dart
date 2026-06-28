// ─────────────────────────────────────────────────────────────────────
// AddChildScreen — "Farzandingizni qo'shing" (Parvoz dizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Gradient fon + tepada 3 qadamli Solar step-indikator (1: bola ma'lumoti,
// 2: ulash, 3: kutubxona). Maydonlar: ism, tug'ilgan kun (kalendar),
// telefon, jins (tanlash). Pastda primary "Keyingisi" tugmasi.
//
// MA'LUMOT: tug'ilgan kundan YOSH hisoblanadi va backendga shu yuboriladi
// (backend tug'ilgan kunni saqlamaydi — faqat `age`). Tahrirda mavjud
// yoshdan taxminiy sana tiklanadi (yosh aniq round-trip bo'ladi). Hudud
// bu dizaynda yo'q — bo'sh yuboriladi (repo bo'sh hududni o'tkazib yuboradi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _surface = Color(0xFF11161D); // kalendar / sheet yuzasi
const _stepInactive = Color(0xFF1B2128); // nofaol qadam doirasi
const _fieldFill = Color(0x0DFFFFFF); // oq 5%
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _line = Color(0x1AFFFFFF); // qadam chizig'i (oq 10%)
const _dim = Color(0x8CFFFFFF); // oq 55%

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.5,
}) =>
    GoogleFonts.unbounded(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: ls,
      height: 1.25,
    );

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Bola qo'shish yoki tahrirlash formasi (Parvoz dizayn).
///
/// **Add mode** (`childId == null`): yangi bola yaratiladi, oila kodi
/// ekraniga o'tiladi. **Edit mode**: provider'dan o'qib to'ldiriladi.
class AddChildScreen extends ConsumerStatefulWidget {
  /// `AddChildScreen` konstruktor.
  const AddChildScreen({super.key, this.childId});

  /// Tahrirlanadigan bola id'si. `null` bo'lsa add mode.
  final String? childId;

  @override
  ConsumerState<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends ConsumerState<AddChildScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _birthDate;
  Gender? _selectedGender;
  bool _isSaving = false;
  int? _initialAge; // edit: backenddagi asliy yosh
  bool _birthDateChanged = false; // foydalanuvchi sanani o'zgartirdimi

  bool get _isEditMode => widget.childId != null;

  bool get _isFormValid =>
      _nameController.text.trim().length >= 2 &&
      _birthDate != null &&
      _selectedGender != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final child = ref.read(childByIdProvider(widget.childId!));
      if (child != null) {
        _nameController.text = child.name;
        _phoneController.text = child.phoneNumber ?? '';
        _selectedGender = child.gender;
        _initialAge = child.age;
        // Backend faqat `age` saqlaydi — ko'rsatish uchun taxminiy sana
        // tiklaymiz. Saqlashda sana o'zgarmasa ASLIY yosh ishlatiladi
        // (29-fevralda round-trip xatosi bo'lmasligi uchun).
        if (child.age > 0) {
          final now = DateTime.now();
          // 29-fevral boshqa (kabisa bo'lmagan) yilga rolldan o'tmasin.
          final day = (now.month == 2 && now.day == 29) ? 28 : now.day;
          _birthDate = DateTime(now.year - child.age, now.month, day);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Tug'ilgan kundan to'liq yoshni hisoblaydi.
  int _ageFromBirth(DateTime b) {
    final now = DateTime.now();
    var age = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 25);
    final raw = _birthDate ?? DateTime(now.year - 10, now.month, now.day);
    // initialDate firstDate..lastDate oralig'ida bo'lishi shart (assert).
    final initial = raw.isBefore(first)
        ? first
        : (raw.isAfter(now) ? now : raw);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'childManagement.addEdit.birthDateHint'.tr(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _blue,
            onPrimary: Colors.white,
            surface: _surface,
          ),
          datePickerTheme: const DatePickerThemeData(
            backgroundColor: _surface,
            headerBackgroundColor: _blue,
            headerForegroundColor: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateChanged = true;
      });
    }
  }

  Future<void> _pickGender() async {
    final picked = await showModalBottomSheet<Gender>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final g in Gender.values)
              ListTile(
                leading: Icon(
                  g == Gender.male ? SolarIconsBold.men : SolarIconsBold.women,
                  color: _selectedGender == g ? _blue : _dim,
                ),
                title: Text(g.label, style: _pop(16)),
                trailing: _selectedGender == g
                    ? const Icon(SolarIconsBold.checkCircle, color: _blue)
                    : null,
                onTap: () => Navigator.of(ctx).pop(g),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _selectedGender = picked);
  }

  Future<void> _onSave() async {
    if (!_isFormValid || _isSaving) return;
    setState(() => _isSaving = true);
    final actions = ref.read(childActionsProvider.notifier);
    // Tahrirda sana qo'lda o'zgartirilmagan bo'lsa asliy yoshni saqlaymiz —
    // reconstruct qilingan sanadan qayta hisoblash xatosi bo'lmasin.
    final age = (_isEditMode && !_birthDateChanged && _initialAge != null)
        ? _initialAge!
        : _ageFromBirth(_birthDate!);
    final phone = _phoneController.text.trim();

    if (_isEditMode) {
      final existing = ref.read(childByIdProvider(widget.childId!));
      if (existing == null) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        context.pop();
        return;
      }
      final updated = Child(
        id: existing.id,
        familyCode: existing.familyCode,
        createdAt: existing.createdAt,
        isConnected: existing.isConnected,
        deviceModel: existing.deviceModel,
        photoUrl: existing.photoUrl,
        name: _nameController.text.trim(),
        age: age,
        gender: _selectedGender!,
        region: existing.region,
        phoneNumber: phone,
      );
      final result = await actions.updateChild(widget.childId!, updated);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (result.isSuccess) {
        context.pop();
      } else {
        _showError(result.error);
      }
      return;
    }

    final result = await actions.addChild(
      name: _nameController.text.trim(),
      age: age,
      gender: _selectedGender!,
      region: '',
      phoneNumber: phone,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result.isSuccess) {
      context.go(AppRoutes.familyCodePath(result.data!.id), extra: result.data);
    } else {
      _showError(result.error);
    }
  }

  void _showError(String? error) {
    AppToast.error(
      context,
      'childManagement.addEdit.errorPrefix'.tr(
        namedArgs: {'error': error ?? ''},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final genderLabel = _selectedGender?.label;
    final birthText = _birthDate != null ? _fmtDate(_birthDate!) : null;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Tepa-markazda yumshoq ko'k yog'du.
          const Positioned(
            top: -70,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: _Glow())),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const _StepIndicator(),
                        const SizedBox(height: 32),
                        Text(
                          'childManagement.addEdit.formTitleAdd'.tr(),
                          style: _unb(27),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'childManagement.addEdit.subtitle'.tr(),
                          style: _pop(14, c: _dim),
                        ),
                        const SizedBox(height: 28),
                        _TextField(
                          label: 'childManagement.addEdit.nameFieldLabel'.tr(),
                          controller: _nameController,
                          hint: 'childManagement.addEdit.nameHint'.tr(),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 20),
                        _TapField(
                          label: 'childManagement.addEdit.birthDateLabel'.tr(),
                          value: birthText,
                          hint: 'childManagement.addEdit.birthDateHint'.tr(),
                          icon: SolarIconsOutline.calendar,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 20),
                        _TextField(
                          label:
                              'childManagement.addEdit.phoneFieldLabel'.tr(),
                          controller: _phoneController,
                          hint: 'childManagement.addEdit.phoneHint'.tr(),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),
                        _TapField(
                          label:
                              'childManagement.addEdit.genderFieldLabel'.tr(),
                          value: genderLabel,
                          hint: 'childManagement.addEdit.genderHint'.tr(),
                          icon: SolarIconsOutline.altArrowDown,
                          onTap: _pickGender,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: _PrimaryButton(
                    label: _isEditMode
                        ? 'childManagement.addEdit.updateButton'.tr()
                        : 'childManagement.addEdit.nextButton'.tr(),
                    loading: _isSaving,
                    enabled: _isFormValid,
                    onTap: _onSave,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════ Fon yog'dusi ════════════

class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 280,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            _blue.withValues(alpha: 0.22),
            const Color(0x00216BFF),
          ],
          stops: const [0, 0.7],
        ),
      ),
    );
  }
}

// ════════════ Qadam indikatori ════════════

class _StepIndicator extends StatelessWidget {
  const _StepIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _StepCircle(icon: SolarIconsBold.userRounded, active: true),
        _StepLine(),
        _StepCircle(icon: SolarIconsBold.clipboardCheck),
        _StepLine(),
        _StepCircle(icon: SolarIconsBold.book2),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({required this.icon, this.active = false});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? _blue : _stepInactive,
        border: active ? null : Border.all(color: _fieldBorder),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: 24,
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.75),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) {
    return const Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(height: 2, child: ColoredBox(color: _line)),
      ),
    );
  }
}

// ════════════ Maydonlar ════════════

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: _pop(14)),
    );
  }
}

/// Matn kiritish maydoni — yorliq + dumaloq quti (fokusda ko'k rim).
class _TextField extends StatefulWidget {
  const _TextField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(widget.label),
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focused ? _blue : _fieldBorder,
              width: focused ? 1.5 : 1,
            ),
          ),
          child: TextSelectionTheme(
            data: const TextSelectionThemeData(
              cursorColor: _blue,
              selectionHandleColor: _blue,
              selectionColor: Color(0x5C216BFF),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: widget.keyboardType,
              onChanged: widget.onChanged,
              cursorColor: _blue,
              style: _pop(15),
              decoration: InputDecoration(
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: widget.hint,
                hintStyle: _pop(15, c: Colors.white.withValues(alpha: 0.32)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bosiladigan maydon (sana / jins) — qiymat + o'ng ikon.
class _TapField extends StatelessWidget {
  const _TapField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.value,
  });

  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _fieldBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? value! : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(
                      15,
                      c: hasValue
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.32),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 22, color: _dim),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════ Primary tugma ════════════

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    required this.loading,
    required this.enabled,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: canTap ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: ParvozGlass(
          blue: true,
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: _pop(16, w: FontWeight.w500)),
                    const SizedBox(width: 10),
                    const Icon(
                      SolarIconsOutline.arrowRight,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
