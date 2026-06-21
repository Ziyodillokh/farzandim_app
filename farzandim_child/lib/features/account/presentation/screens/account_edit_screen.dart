// ─────────────────────────────────────────────────────────────────────
// AccountEditScreen — bola profili tahrirlash (Parvoz NIGHT/GLASS redizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Maydonlar: foto (galereya), ism, yosh (5-18), hudud, til. Saqlash backend
// orqali (uploadMyAvatar + updateMyProfile). LOGIKA SAQLANGAN — faqat ko'rinish
// night/glass (parvoz tokenlar + parvozGlass). Light keyin alohida.

import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/account/presentation/providers/child_repository_provider.dart';
import 'package:farzandim_child/features/account/presentation/widgets/age_list_dialog.dart';
import 'package:farzandim_child/features/account/presentation/widgets/region_picker_bottom_sheet.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class AccountEditScreen extends ConsumerStatefulWidget {
  const AccountEditScreen({super.key});

  @override
  ConsumerState<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends ConsumerState<AccountEditScreen> {
  final TextEditingController _nameController = TextEditingController();

  int? _selectedAge;
  String? _selectedRegion;
  Uint8List? _selectedPhotoBytes;
  String? _existingPhotoUrl;

  bool _isLoading = false;
  bool _hasLoaded = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _loadCurrentData(Map<String, dynamic> childData) {
    if (_hasLoaded) return;
    _hasLoaded = true;

    _nameController.text = (childData['name'] as String?) ?? '';
    _selectedAge = childData['age'] as int?;
    _selectedRegion = childData['region'] as String?;
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

      if (_selectedPhotoBytes != null) {
        await repo.uploadMyAvatar(bytes: _selectedPhotoBytes!);
      }

      await repo.updateMyProfile(
        name: name,
        age: _selectedAge,
        region: _selectedRegion,
      );

      ref.invalidate(childDataStreamProvider((
        parentUid: pairing.parentUid!,
        childId: pairing.childId!,
      )));
      ref.invalidate(childAvatarUrlProvider(pairing.childId!));

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
      if (mounted) setState(() => _isLoading = false);
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
        backgroundColor: AppColors.parvozBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.parvozGreen),
        ),
      );
    }

    final childDataAsync = ref.watch(childDataStreamProvider((
      parentUid: pairing.parentUid!,
      childId: pairing.childId!,
    )));

    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      body: Column(
        children: [
          ParvozHeader(
            title: 'account.title'.tr(),
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: childDataAsync.when(
              data: (data) {
                if (data != null) _loadCurrentData(data);
                return _buildForm(context);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.parvozGreen),
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
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: parvozGlass(radius: 24),
                        clipBehavior: Clip.antiAlias,
                        child: _buildPhoto(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.photo_camera_rounded,
                          color: AppColors.parvozGreen, size: 18),
                      label: Text(
                        'account.photoLabel'.tr(),
                        style: const TextStyle(
                          color: AppColors.parvozGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('account.nameLabel'.tr()),
                  const SizedBox(height: 8),
                  Container(
                    decoration: parvozGlassFlat(radius: 14),
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: AppColors.parvozText),
                      decoration: InputDecoration(
                        hintText: 'account.nameHint'.tr(),
                        hintStyle:
                            const TextStyle(color: AppColors.parvozTextDim),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('account.ageLabel'.tr()),
                  const SizedBox(height: 8),
                  _buildPicker(
                    icon: Icons.cake_rounded,
                    text: _selectedAge != null
                        ? 'account.ageValue'
                            .tr(namedArgs: {'age': '$_selectedAge'})
                        : 'account.agePlaceholder'.tr(),
                    onTap: _selectAge,
                    isPlaceholder: _selectedAge == null,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('account.regionLabel'.tr()),
                  const SizedBox(height: 8),
                  _buildPicker(
                    icon: Icons.location_on_rounded,
                    text: _selectedRegion ?? 'account.regionPlaceholder'.tr(),
                    onTap: _selectRegion,
                    isPlaceholder: _selectedRegion == null,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('account.languageLabel'.tr()),
                  const SizedBox(height: 8),
                  _buildPicker(
                    icon: Icons.translate_rounded,
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
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: AppColors.parvozGlassRim),
                  ),
                  child: Text(
                    'account.backButton'.tr(),
                    style: const TextStyle(color: AppColors.parvozText),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.parvozGreen,
                    foregroundColor: AppColors.parvozOnGreen,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.parvozOnGreen,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'account.saveButton'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.parvozText,
      ),
    );
  }

  Widget _buildPicker({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isPlaceholder = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: parvozGlassFlat(radius: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.parvozGreen, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isPlaceholder
                      ? AppColors.parvozTextDim
                      : AppColors.parvozText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.parvozTextDim),
          ],
        ),
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
        errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
      );
    }
    return _buildPhotoPlaceholder();
  }

  Widget _buildPhotoPlaceholder() {
    return const Center(
      child: Icon(
        Icons.photo_camera_rounded,
        color: AppColors.parvozTextDim,
        size: 32,
      ),
    );
  }

  String _currentLanguageLabel(BuildContext context) {
    final code = context.locale.languageCode;
    return 'languages.$code'.tr();
  }

  Future<void> _selectLanguage() async {
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      backgroundColor: AppColors.parvozSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LanguagePickerSheet(current: context.locale),
    );

    if (selected != null && mounted && selected != context.locale) {
      await context.setLocale(selected);
    }
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({required this.current});

  final Locale current;

  static const _options = [Locale('uz'), Locale('ru'), Locale('en')];

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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.parvozText,
              ),
            ),
            const SizedBox(height: 12),
            for (final locale in _options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'languages.${locale.languageCode}'.tr(),
                  style: const TextStyle(color: AppColors.parvozText),
                ),
                trailing: locale == current
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.parvozGreen)
                    : const Icon(Icons.radio_button_unchecked,
                        color: AppColors.parvozTextDim),
                onTap: () => Navigator.pop(context, locale),
              ),
          ],
        ),
      ),
    );
  }
}
