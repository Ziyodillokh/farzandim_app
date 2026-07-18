// ─────────────────────────────────────────────────────────────────────
// EditChildScreen — "Shaxsi ma'lumotlar" (bola profilini tahrirlash)
// ─────────────────────────────────────────────────────────────────────
//
// "Bola sozlamalari" profil kartasidagi ruchka (edit) bosilganda ochiladi.
// Maydonlar: profil rasmi, ism, jins, tug'ilgan kun, telefon. Pastda
// "Bolani o'chirish" (maroon) + "Saqlash" (ko'k) tugmalari.
//
// MA'LUMOT: backend faqat `age` saqlaydi — tug'ilgan kundan yosh hisoblanadi.
// Sana qo'lda o'zgartirilmasa asliy yosh saqlanadi (round-trip xatosi yo'q).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/services/image_picker_service.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/child_management/presentation/screens/connect_child_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _field = Color(0xFF12171E); // maydon foni
const _chipBg = Color(0xFF1B2128); // orqaga tugmasi / yuklash pill
const _surface = Color(0xFF11161D); // sheet / kalendar yuzasi
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _dim = Color(0x8CFFFFFF); // oq 55%
const _placeholder = Color(0x59FFFFFF); // oq 35%
const _red = Color(0xFFFF5A5F); // o'chirish
const _redBg = Color(0x1AFF5A5F); // o'chirish foni
const _redBorder = Color(0x33FF5A5F); // o'chirish rimi

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.5,
}) => GoogleFonts.unbounded(
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
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.4);

/// Bola profilini tahrirlash ekrani ("Shaxsi ma'lumotlar").
class EditChildScreen extends ConsumerStatefulWidget {
  /// `EditChildScreen` konstruktor.
  const EditChildScreen({super.key, this.childId, this.initialChild});

  /// Tahrirlanadigan bola id'si. `null` bo'lsa — YANGI bola qo'shish rejimi
  /// (o'chirish tugmasi yo'q; saqlangach ulanish varag'i ochiladi).
  final String? childId;

  /// `state.extra` orqali kelgan Child — provider race'ni chetlash uchun.
  final Child? initialChild;

  @override
  ConsumerState<EditChildScreen> createState() => _EditChildScreenState();
}

class _EditChildScreenState extends ConsumerState<EditChildScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _birthDate;
  Gender? _selectedGender;
  Uint8List? _photoBytes; // yangi tanlangan rasm
  bool _isSaving = false;
  int? _initialAge; // backenddagi asliy yosh
  bool _birthDateChanged = false; // sana qo'lda o'zgartirildimi

  bool get _isEdit => widget.childId != null;

  bool get _isFormValid =>
      _nameController.text.trim().length >= 2 &&
      _selectedGender != null &&
      (_birthDate != null || _initialAge != null);

  /// Controller lokal raqamни saqlaydi ("+998" prefiks alohida) — saqlashda
  /// birlashtiramiz. Bo'sh bo'lsa telefon yo'q (ixtiyoriy).
  String get _composedPhone {
    final local = _phoneController.text.trim();
    return local.isEmpty ? '' : '+998$local';
  }

  @override
  void initState() {
    super.initState();
    if (!_isEdit) return; // add rejimi — forma bo'sh boshlanadi
    final child =
        ref.read(childByIdProvider(widget.childId!)) ?? widget.initialChild;
    if (child != null) {
      _nameController.text = child.name;
      // "+998901234567" — prefiks alohida ko'rsatiladi, faqat lokal olamiz.
      final storedDigits =
          (child.phoneNumber ?? '').replaceAll(RegExp('[^0-9]'), '');
      _phoneController.text = storedDigits.startsWith('998')
          ? storedDigits.substring(3)
          : storedDigits;
      _selectedGender = child.gender;
      _initialAge = child.age;
      // Backend faqat `age` saqlaydi — ko'rsatish uchun taxminiy sana
      // tiklaymiz (sana o'zgarmasa saqlashda ASLIY yosh ishlatiladi).
      if (child.age > 0) {
        final now = DateTime.now();
        final day = (now.month == 2 && now.day == 29) ? 28 : now.day;
        _birthDate = DateTime(now.year - child.age, now.month, day);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: _DragHandle()),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 14),
                child: Text(
                  'childManagement.addEdit.genderHint'.tr(),
                  style: _unb(17),
                ),
              ),
              for (final g in Gender.values) ...[
                _GenderOption(
                  gender: g,
                  selected: _selectedGender == g,
                  onTap: () => Navigator.of(ctx).pop(g),
                ),
                if (g != Gender.values.last) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _selectedGender = picked);
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
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
            ListTile(
              leading: const Icon(SolarIconsBold.gallery, color: _blue),
              title: Text(
                'childManagement.addEdit.photoGallery'.tr(),
                style: _pop(16),
              ),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(SolarIconsBold.camera, color: _blue),
              title: Text(
                'childManagement.addEdit.photoCamera'.tr(),
                style: _pop(16),
              ),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final service = ref.read(imagePickerServiceProvider);
    final bytes = source == ImageSource.gallery
        ? await service.pickFromGallery()
        : await service.pickFromCamera();
    if (!mounted || bytes == null) return;
    setState(() => _photoBytes = bytes);
  }

  Future<void> _onSave() async {
    if (!_isFormValid || _isSaving) return;
    if (!_isEdit) {
      await _createChild();
      return;
    }
    final existing = ref.read(childByIdProvider(widget.childId!));
    if (existing == null) {
      context.pop();
      return;
    }
    setState(() => _isSaving = true);
    // Sana o'zgarmagan bo'lsa asliy yoshni saqlaymiz.
    final age = (!_birthDateChanged && _initialAge != null)
        ? _initialAge!
        : _ageFromBirth(_birthDate!);
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
      phoneNumber: _composedPhone,
    );
    final result = await ref
        .read(childActionsProvider.notifier)
        .updateChild(widget.childId!, updated, newPhotoBytes: _photoBytes);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result.isSuccess) {
      context.pop();
    } else {
      AppToast.error(
        context,
        'childManagement.addEdit.errorPrefix'.tr(
          namedArgs: {'error': result.error ?? ''},
        ),
      );
    }
  }

  /// YANGI bola yaratish (add rejimi) — muvaffaqiyatda ulanish varag'i
  /// ochiladi (oila kodi), bola ulanib "Keyingi" bosilsa nazorat sahifasi.
  Future<void> _createChild() async {
    setState(() => _isSaving = true);
    final result = await ref
        .read(childActionsProvider.notifier)
        .addChild(
          name: _nameController.text.trim(),
          age: _ageFromBirth(_birthDate!),
          gender: _selectedGender!,
          region: '',
          phoneNumber: _composedPhone,
          photoBytes: _photoBytes,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!result.isSuccess) {
      AppToast.error(
        context,
        'childManagement.addEdit.errorPrefix'.tr(
          namedArgs: {'error': result.error ?? ''},
        ),
      );
      return;
    }
    final child = result.data;
    if (child == null) {
      context.pop();
      return;
    }
    final proceed = await showConnectChildSheet(
      context,
      childId: child.id,
      initialChild: child,
    );
    if (!mounted) return;
    if (proceed ?? false) {
      context.go(AppRoutes.controlsSetupPath(child.id), extra: child);
    } else {
      context.pop();
    }
  }

  Future<void> _confirmDelete() async {
    final child = ref.read(childByIdProvider(widget.childId!));
    final name = child?.name ?? _nameController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: Text(
          'childManagement.list.deleteDialog.title'.tr(),
          style: _unb(18),
        ),
        content: Text(
          'childManagement.list.deleteDialog.content'.tr(
            namedArgs: {'name': name},
          ),
          style: _pop(14, c: _dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'childManagement.list.deleteDialog.cancel'.tr(),
              style: _pop(14, c: _dim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'childManagement.list.deleteDialog.delete'.tr(),
              style: _pop(14, w: FontWeight.w600, c: _red),
            ),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;
    setState(() => _isSaving = true);
    final result = await ref
        .read(childActionsProvider.notifier)
        .deleteChild(widget.childId!);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result.isSuccess) {
      AppToast.success(
        context,
        'childManagement.list.deletedSnack'.tr(namedArgs: {'name': name}),
      );
      context.go(AppRoutes.dashboard);
    } else {
      AppToast.error(
        context,
        'childManagement.list.errorPrefix'.tr(
          namedArgs: {'error': result.error ?? ''},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _isEdit
        ? ref.watch(childByIdProvider(widget.childId!))
        : null;
    final genderLabel = _selectedGender?.label;
    final birthText = _birthDate != null ? _fmtDate(_birthDate!) : null;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
              child: Row(
                children: [
                  _BackButton(onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.dashboard);
                    }
                  }),
                  const SizedBox(width: 14),
                  Text(
                    _isEdit
                        ? 'childManagement.addEdit.personalInfoTitle'.tr()
                        : 'childManagement.addEdit.addTitle'.tr(),
                    style: _unb(22),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _PhotoRow(
                    bytes: _photoBytes,
                    existingChild: existing,
                    onUpload: _pickPhoto,
                  ),
                  const SizedBox(height: 22),
                  _LabeledInput(
                    label: 'childManagement.addEdit.nameFieldLabel'.tr(),
                    controller: _nameController,
                    hint: 'childManagement.addEdit.nameHint'.tr(),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 18),
                  _LabeledTap(
                    label: 'childManagement.addEdit.genderFieldLabel'.tr(),
                    value: genderLabel,
                    hint: 'childManagement.addEdit.genderHint'.tr(),
                    icon: SolarIconsBold.altArrowDown,
                    onTap: _pickGender,
                  ),
                  const SizedBox(height: 18),
                  _LabeledTap(
                    label: 'childManagement.addEdit.birthDateLabel'.tr(),
                    value: birthText,
                    hint: 'childManagement.addEdit.birthDatePlaceholder'.tr(),
                    icon: SolarIconsBold.calendar,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 18),
                  _LabeledInput(
                    label: 'childManagement.addEdit.phoneFieldLabel'.tr(),
                    controller: _phoneController,
                    hint: 'childManagement.addEdit.phoneHint'.tr(),
                    keyboardType: TextInputType.phone,
                    // "+998" doimiy prefiks — controller faqat lokal 9 raqam.
                    prefix: const Text(
                      '+998',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                  ),
                  if (_isEdit) ...[
                    const SizedBox(height: 24),
                    _DeleteButton(onTap: _isSaving ? null : _confirmDelete),
                  ],
                ],
              ),
            ),
            // ── Saqlash ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _SaveButton(
                enabled: _isFormValid,
                loading: _isSaving,
                onTap: _onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Orqaga tugmasi ════════════

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _fieldBorder),
        ),
        child: const Icon(
          SolarIconsOutline.arrowLeft,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ════════════ Profil rasmi qatori ════════════

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.bytes,
    required this.existingChild,
    required this.onUpload,
  });

  final Uint8List? bytes;
  final Child? existingChild;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AvatarBox(bytes: bytes, existingChild: existingChild),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'childManagement.addEdit.photoLabel'.tr(),
            style: _pop(15),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onUpload,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _chipBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _fieldBorder),
            ),
            child: Text(
              'childManagement.addEdit.photoUpload'.tr(),
              style: _pop(13, w: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar-preview: tanlangan bytes → mavjud rasm → oq doira + odam ikoni.
class _AvatarBox extends StatelessWidget {
  const _AvatarBox({required this.bytes, required this.existingChild});

  final Uint8List? bytes;
  final Child? existingChild;

  static const double _d = 40;

  @override
  Widget build(BuildContext context) {
    final picked = bytes;
    if (picked != null) {
      return ClipOval(
        child: Image.memory(
          picked,
          width: _d,
          height: _d,
          fit: BoxFit.cover,
          cacheWidth: 120,
        ),
      );
    }
    final child = existingChild;
    if (child != null && child.hasCustomPhoto) {
      return ChildAvatar(child: child, size: _d, showBorder: false);
    }
    return Container(
      width: _d,
      height: _d,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        SolarIconsBold.user,
        size: 22,
        color: Color(0xFF0B0F14),
      ),
    );
  }
}

// ════════════ Maydonlar ════════════

BoxDecoration _fieldDecoration() => BoxDecoration(
  color: _field,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: _fieldBorder),
);

/// Yozma maydon (ism / telefon) — sarlavha + yumaloq input.
class _LabeledInput extends StatelessWidget {
  const _LabeledInput({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.onChanged,
    this.prefix,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? prefix;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _pop(14)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: _fieldDecoration(),
          // Matn belgilash ranglari ko'k (global teal emas).
          child: TextSelectionTheme(
            data: const TextSelectionThemeData(
              cursorColor: _blue,
              selectionHandleColor: _blue,
              selectionColor: Color(0x5C216BFF),
            ),
            child: Row(
              children: [
                if (prefix != null) ...[
                  prefix!,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    onChanged: onChanged,
                    inputFormatters: inputFormatters,
                    cursorColor: _blue,
                    style: _pop(15),
                    decoration: InputDecoration(
                      // Global teal fill va border'larni o'chiramiz — faqat
                      // tashqi Container ko'rinsin (ichki teal quti bo'lmasin).
                      filled: false,
                      isCollapsed: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 18),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: hint,
                      hintStyle: _pop(15, c: _placeholder),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bosiladigan maydon (jins / sana) — sarlavha + qiymat + o'ng ikon.
class _LabeledTap extends StatelessWidget {
  const _LabeledTap({
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
        Text(label, style: _pop(14)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: _fieldDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? value! : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(15, c: hasValue ? Colors.white : _placeholder),
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

// ════════════ Tugmalar ════════════

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _redBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _redBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              SolarIconsBold.trashBinMinimalistic,
              size: 20,
              color: _red,
            ),
            const SizedBox(width: 10),
            Text(
              'childManagement.addEdit.deleteChildButton'.tr(),
              style: _pop(15, w: FontWeight.w600, c: _red),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: canTap ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'childManagement.addEdit.saveButton'.tr(),
                  style: _pop(16, w: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

// ════════════ Jins tanlash varag'i ════════════

/// Pastki varaq tepasidagi ushlagich chizig'i.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Bitta jins varianti — rangli ikon chip + nom + tanlangan belgisi.
class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.gender,
    required this.selected,
    required this.onTap,
  });

  final Gender gender;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMale = gender == Gender.male;
    // O'g'il — ko'k, Qiz — pushti; ikonlar aniq ajralib tursin.
    final accent = isMale ? _blue : const Color(0xFFFF6B9D);
    final iconAsset = isMale
        ? 'assets/icons/ic_gender_male.svg'
        : 'assets/icons/ic_gender_female.svg';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.10) : _chipBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.7) : _fieldBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                iconAsset,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(gender.label, style: _pop(16, w: FontWeight.w500)),
            ),
            _CheckDot(selected: selected, accent: accent),
          ],
        ),
      ),
    );
  }
}

/// O'ng tarafdagi tanlangan/tanlanmagan doira belgisi.
class _CheckDot extends StatelessWidget {
  const _CheckDot({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _fieldBorder, width: 1.4),
      ),
    );
  }
}
