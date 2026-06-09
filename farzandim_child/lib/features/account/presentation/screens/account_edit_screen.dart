// ─────────────────────────────────────────────────────────────────────
// AccountEditScreen — bola profili tahrirlash (PDF p21)
// ─────────────────────────────────────────────────────────────────────
//
// Maydonlar: foto (galereya), ism, yosh (5-18), hudud (14 viloyat).
// Saqlash: Firestore (`users/{p}/children/{c}`) + Storage agar foto
// almashtirilgan bo'lsa.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/account/presentation/providers/child_repository_provider.dart';
import 'package:farzandim_child/features/account/presentation/widgets/age_list_dialog.dart';
import 'package:farzandim_child/features/account/presentation/widgets/region_picker_bottom_sheet.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class AccountEditScreen extends ConsumerStatefulWidget {
  const AccountEditScreen({super.key});

  @override
  ConsumerState<AccountEditScreen> createState() =>
      _AccountEditScreenState();
}

class _AccountEditScreenState extends ConsumerState<AccountEditScreen> {
  final TextEditingController _nameController = TextEditingController();

  int? _selectedAge;
  String? _selectedRegion;
  File? _selectedPhoto;
  String? _existingPhotoUrl;

  bool _isLoading = false;
  bool _hasLoaded = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Birinchi marta (childData kelgach) controller va state'ga
  /// hozirgi qiymatlarni yozib qo'yamiz. Keyingi stream emissionlarini
  /// e'tiborga olmaymiz — foydalanuvchi inputi bekor bo'lib ketmasligi uchun.
  void _loadCurrentData(Map<String, dynamic> childData) {
    if (_hasLoaded) return;
    _hasLoaded = true;

    _nameController.text = (childData['name'] as String?) ?? '';
    _selectedAge = childData['age'] as int?;
    _selectedRegion = childData['region'] as String?;
    _existingPhotoUrl = childData['photoUrl'] as String?;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedPhoto = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectRegion() async {
    final result = await RegionPickerBottomSheet.show(
      context,
      selectedRegion: _selectedRegion,
    );
    if (result != null && mounted) {
      setState(() => _selectedRegion = result);
    }
  }

  Future<void> _selectAge() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AgeListDialog(selectedAge: _selectedAge),
    );
    if (result != null && mounted) {
      setState(() => _selectedAge = result);
    }
  }

  Future<void> _onSave() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showSnack('account.errorNameEmpty'.tr(), AppColors.error);
      return;
    }
    if (_selectedAge == null) {
      _showSnack('account.errorAgeEmpty'.tr(), AppColors.error);
      return;
    }
    if (_selectedRegion == null) {
      _showSnack('account.errorRegionEmpty'.tr(), AppColors.error);
      return;
    }

    final pairing = ref.read(pairingStateProvider);
    if (pairing.parentUid == null || pairing.childId == null) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(childRepositoryProvider);
      String? photoUrl = _existingPhotoUrl;

      if (_selectedPhoto != null) {
        photoUrl = await repo.uploadChildPhoto(
          parentUid: pairing.parentUid!,
          childId: pairing.childId!,
          photoFile: _selectedPhoto!,
        );
      }

      await repo.updateChildProfile(
        parentUid: pairing.parentUid!,
        childId: pairing.childId!,
        name: name,
        age: _selectedAge,
        region: _selectedRegion,
        photoUrl: photoUrl,
      );

      if (!mounted) return;
      _showSnack('account.savedSnack'.tr(), AppColors.success);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'account.errorPrefix'.tr(namedArgs: {'error': '$e'}),
        AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String text, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: bg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pairing = ref.watch(pairingStateProvider);

    if (!pairing.isPaired ||
        pairing.parentUid == null ||
        pairing.childId == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    final childDataAsync = ref.watch(childDataStreamProvider((
      parentUid: pairing.parentUid!,
      childId: pairing.childId!,
    )));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: childDataAsync.when(
            data: (data) {
              if (data != null) _loadCurrentData(data);
              return _buildForm(context);
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'account.errorPrefix'.tr(namedArgs: {'error': '$e'}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(AppIcons.back,
                    color: context.adaptive.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'account.title'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.adaptive.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('account.photoLabel'.tr()),
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: context.adaptive.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: context.adaptive.border,
                            width: 1,
                          ),
                        ),
                        child: _buildPhoto(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildLabel('account.nameLabel'.tr()),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: context.adaptive.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.adaptive.border,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _nameController,
                      style: TextStyle(
                          color: context.adaptive.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'account.nameHint'.tr(),
                        hintStyle: TextStyle(
                            color: context.adaptive.textTertiary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('account.ageLabel'.tr()),
                  const SizedBox(height: 8),
                  _buildPicker(
                    text: _selectedAge != null
                        ? 'account.ageValue'.tr(
                            namedArgs: {'age': '$_selectedAge'},
                          )
                        : 'account.agePlaceholder'.tr(),
                    onTap: _selectAge,
                    isPlaceholder: _selectedAge == null,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('account.regionLabel'.tr()),
                  const SizedBox(height: 8),
                  _buildPicker(
                    text: _selectedRegion ??
                        'account.regionPlaceholder'.tr(),
                    onTap: _selectRegion,
                    isPlaceholder: _selectedRegion == null,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('account.languageLabel'.tr()),
                  const SizedBox(height: 8),
                  _buildPicker(
                    text: _currentLanguageLabel(context),
                    onTap: _selectLanguage,
                    isPlaceholder: false,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    side: BorderSide(color: context.adaptive.border),
                  ),
                  child: Text(
                    'account.backButton'.tr(),
                    style:
                        TextStyle(color: context.adaptive.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'account.saveButton'.tr(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.adaptive.textPrimary,
      ),
    );
  }

  Widget _buildPicker({
    required String text,
    required VoidCallback onTap,
    bool isPlaceholder = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.adaptive.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.adaptive.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isPlaceholder
                      ? context.adaptive.textTertiary
                      : context.adaptive.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down,
                color: context.adaptive.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    if (_selectedPhoto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(_selectedPhoto!, fit: BoxFit.cover),
      );
    }
    if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          _existingPhotoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
        ),
      );
    }
    return _buildPhotoPlaceholder();
  }

  Widget _buildPhotoPlaceholder() {
    return Center(
      child: Icon(
        AppIcons.camera,
        color: context.adaptive.textTertiary,
        size: 32,
      ),
    );
  }

  // ── Til tanlash ─────────────────────────────────────────────────────
  String _currentLanguageLabel(BuildContext context) {
    final code = context.locale.languageCode;
    return 'languages.$code'.tr();
  }

  Future<void> _selectLanguage() async {
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      backgroundColor: context.adaptive.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LanguagePickerSheet(current: context.locale),
    );

    if (selected != null && mounted && selected != context.locale) {
      // easy_localization SharedPreferences'ga saqlaydi — qayta ochilganda ham saqlanadi.
      await context.setLocale(selected);
    }
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({required this.current});

  final Locale current;

  static const _options = [
    Locale('uz'),
    Locale('ru'),
    Locale('en'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'account.languagePickerTitle'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.adaptive.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            for (final locale in _options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'languages.${locale.languageCode}'.tr(),
                  style:
                      TextStyle(color: context.adaptive.textPrimary),
                ),
                trailing: locale == current
                    ? const Icon(AppIcons.success,
                        color: AppColors.primary)
                    : Icon(Icons.radio_button_unchecked,
                        color: context.adaptive.textTertiary),
                onTap: () => Navigator.pop(context, locale),
              ),
          ],
        ),
      ),
    );
  }
}
