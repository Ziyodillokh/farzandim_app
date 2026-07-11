// ─────────────────────────────────────────────────────────────────────
// AccountEditScreen — "Akkount sozlamalari" (Figma 1:1, Parvoz night)
// ─────────────────────────────────────────────────────────────────────
//
// Sozlamalar'dagi "Akkount" va profildagi avatar bosilganda ochiladi.
// Tuzilishi (Figma):
//   • Header: ← kvadrat tugma + "Akkount sozlamalari" (chapga)
//   • Profil rasm qatori: kichik avatar + "Profil rasm" + "Rasm yuklash" pill
//   • "Ism familiya" input
//   • "Farzandingizning tug'ilgan kuni" input (KK.OO.YYYY)
//   • Pastda ko'k "Saqlash"
//
// LOGIKA SAQLANGAN: uploadMyAvatar + updateMyProfile (backend). Tug'ilgan
// kundan yosh hisoblanadi; region avvalgi qiymatida saqlanadi.

import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/features/account/presentation/providers/child_repository_provider.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

// ════════════ Figma tokenlar ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _field = Color(0xFF060B12);
const _fieldBorder = Color(0x1FFFFFFF);
const _glass = Color(0x14FFFFFF);
const _glassBorder = Color(0x24FFFFFF);
const _red = Color(0xFFE74C4C);
const _green = Color(0xFF22C55E);

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w700,
  Color c = Colors.white,
  double ls = -0.3,
}) => GoogleFonts.unbounded(
  fontSize: s,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.25,
);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.4);

class AccountEditScreen extends ConsumerStatefulWidget {
  const AccountEditScreen({super.key});

  @override
  ConsumerState<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends ConsumerState<AccountEditScreen> {
  final _nameController = TextEditingController();
  final _birthController = TextEditingController();

  int? _loadedAge;
  String? _selectedRegion;
  Uint8List? _selectedPhotoBytes;
  String? _existingPhotoUrl;

  bool _isLoading = false;
  bool _hasLoaded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _birthController.dispose();
    super.dispose();
  }

  void _loadCurrentData(Map<String, dynamic> childData) {
    if (_hasLoaded) return;
    _hasLoaded = true;

    _nameController.text = (childData['name'] as String?) ?? '';
    _loadedAge = childData['age'] as int?;
    _selectedRegion = childData['region'] as String?;
    // Yosh ma'lum bo'lsa taxminiy tug'ilgan yil ko'rsatiladi (01.01.YYYY).
    if (_loadedAge != null) {
      _birthController.text = '01.01.${DateTime.now().year - _loadedAge!}';
    }
    final childId = childData['id'] as String?;
    final photoPath = childData['photoPath'] as String?;
    final bust = DateTime.now().millisecondsSinceEpoch;
    _existingPhotoUrl = (childId != null && photoPath != null)
        ? '${EnvConfig.apiUrl}/children/$childId/avatar/image?t=$bust'
        : null;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() => _selectedPhotoBytes = bytes);
    }
  }

  /// "KK.OO.YYYY" dan yoshni hisoblaydi; xato format bo'lsa null.
  int? _ageFromBirthText(String text) {
    final m = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(text.trim());
    if (m == null) return null;
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final year = int.parse(m.group(3)!);
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;
    final now = DateTime.now();
    if (year < now.year - 25 || year > now.year) return null;
    var age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) age--;
    return age;
  }

  Future<void> _onSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack("Ism familiyani kiriting", _red);
      return;
    }

    // Tug'ilgan kun kiritilgan bo'lsa — yosh shu yerdan; bo'sh bo'lsa eski.
    int? age = _loadedAge;
    final birthText = _birthController.text.trim();
    if (birthText.isNotEmpty) {
      final parsed = _ageFromBirthText(birthText);
      if (parsed == null) {
        _showSnack("Sana KK.OO.YYYY formatida bo'lsin", _red);
        return;
      }
      age = parsed;
    }

    final pairing = ref.read(pairingStateProvider);
    if (pairing.parentUid == null || pairing.childId == null) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(childRepositoryProvider);

      if (_selectedPhotoBytes != null) {
        await repo.uploadMyAvatar(bytes: _selectedPhotoBytes!);
      }

      await repo.updateMyProfile(name: name, age: age, region: _selectedRegion);

      ref.invalidate(
        childDataStreamProvider((
          parentUid: pairing.parentUid!,
          childId: pairing.childId!,
        )),
      );
      ref.invalidate(childAvatarUrlProvider(pairing.childId!));

      if (!mounted) return;
      _showSnack('Saqlandi!', _green);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Xatolik: $e', _red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String text, Color bg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: bg));
  }

  @override
  Widget build(BuildContext context) {
    final pairing = ref.watch(pairingStateProvider);

    if (!pairing.isPaired ||
        pairing.parentUid == null ||
        pairing.childId == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: Colors.white38)),
      );
    }

    final childDataAsync = ref.watch(
      childDataStreamProvider((
        parentUid: pairing.parentUid!,
        childId: pairing.childId!,
      )),
    );

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header (Figma: ← + sarlavha chapda) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 54, 16, 24),
              child: Row(
                children: [
                  _SquareBtn(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text('Akkount sozlamalari', style: _unb(19))),
                ],
              ),
            ),
            Expanded(
              child: childDataAsync.when(
                data: (data) {
                  if (data != null) _loadCurrentData(data);
                  return _buildForm(context);
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white38),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Xatolik: $e',
                      textAlign: TextAlign.center,
                      style: _pop(13.5, c: _red),
                    ),
                  ),
                ),
              ),
            ),
            // ── Saqlash (Figma: to'liq enli ko'k pill) ──
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 14 + bottomInset),
              child: GestureDetector(
                onTap: _isLoading ? null : _onSave,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: _isLoading ? 0.6 : 1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : Text('Saqlash', style: _pop(15, w: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Profil rasm qatori ──
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: _buildPhoto(),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Profil rasm', style: _pop(14))),
              GestureDetector(
                onTap: _pickPhoto,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _glass,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _glassBorder),
                  ),
                  child: Text(
                    'Rasm yuklash',
                    style: _pop(12.5, w: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text('Ism familiya', style: _pop(13.5)),
          const SizedBox(height: 10),
          _Field(controller: _nameController, hint: 'Ism familiya'),
          const SizedBox(height: 18),
          Text("Farzandingizning tug'ilgan kuni", style: _pop(13.5)),
          const SizedBox(height: 10),
          _Field(
            controller: _birthController,
            hint: 'KK.OO.YYYY',
            keyboardType: TextInputType.datetime,
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    if (_selectedPhotoBytes != null) {
      return Image.memory(_selectedPhotoBytes!, fit: BoxFit.cover);
    }
    if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      return Image.network(
        _existingPhotoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _photoPlaceholder(),
      );
    }
    return _photoPlaceholder();
  }

  Widget _photoPlaceholder() {
    final name = _nameController.text.trim();
    return Container(
      color: const Color(0xFF66B3FF),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: _unb(18, w: FontWeight.w800),
      ),
    );
  }
}

// ════════════ Widget'lar ════════════

class _SquareBtn extends StatelessWidget {
  const _SquareBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _glass,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _glassBorder),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

/// Figma input: to'q navy fon + nozik chegara + oq matn.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: _pop(14.5),
        cursorColor: _blue,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: _pop(14.5, c: const Color(0x4DFFFFFF)),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
