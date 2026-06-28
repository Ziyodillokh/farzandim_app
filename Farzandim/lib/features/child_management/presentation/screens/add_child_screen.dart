import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/constants/uzbekistan_regions.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/services/image_picker_service.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/custom_dropdown.dart';
import 'package:farzandim/shared/widgets/custom_text_field.dart';
import 'package:farzandim/shared/widgets/gender_selector.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/photo_source_bottom_sheet.dart';
import 'package:farzandim/shared/widgets/photo_upload_placeholder.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:farzandim/shared/widgets/secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Bola qo'shish yoki tahrirlash formasi.
///
/// **Add mode** (`childId == null`): yangi bola yaratiladi, oila kodi
/// generatsiya qilinadi, oila kodi ekraniga o'tiladi.
///
/// **Edit mode** (`childId != null`, Bosqich 7.2): provider'dan bola
/// o'qib state'ga to'ldiriladi (photoBytes, ism, yosh, hudud, jinsi).
/// Saqlanganda `updateChild` chaqiriladi va list ekraniga qaytadi.
/// Oila kodi va createdAt o'zgartirilmaydi.
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
  int? _selectedAge;
  String? _selectedRegion;
  Gender? _selectedGender;
  Uint8List? _photoBytes;
  bool _isSaving = false;

  bool get _isEditMode => widget.childId != null;

  /// Forma to'liq to'ldirilganmi? Tugma `enabled` holatini boshqaradi.
  ///
  /// - Ism: trim qilingach kamida 2 belgi (bo'sh joylar hisobga olinmaydi)
  /// - Yoshi, hududi, jinsi: dropdown'lar tanlangan bo'lishi shart
  bool get _isFormValid =>
      _nameController.text.trim().length >= 2 &&
      _selectedAge != null &&
      _selectedRegion != null &&
      _selectedGender != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      // Edit mode — provider'dan bola o'qib state'ni to'ldiramiz.
      final child = ref.read(childByIdProvider(widget.childId!));
      if (child != null) {
        _nameController.text = child.name;
        _phoneController.text = child.phoneNumber ?? '';
        _selectedAge = child.age;
        _selectedRegion = child.region;
        _selectedGender = child.gender;
        _photoBytes = child.photoBytes;
      }
    }
  }

  @override
  void dispose() {
    // Memory leak'ning oldini olish uchun controller'ni yopamiz.
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Foto tanlash oqimi:
  /// 1) Bottom sheet ochib, manba (galereya/kamera) tanlanadi
  /// 2) `image_picker` orqali rasm tanlanadi (yoki bekor qilinadi)
  /// 3) Bytes state'iga yoziladi → `setState` UI'ni yangilaydi
  ///
  /// Har `await` dan keyin `mounted` tekshirilamiz — widget dispose
  /// bo'lgan bo'lsa setState xato bermaslik uchun.
  Future<void> _onPickPhoto() async {
    final source = await PhotoSourceBottomSheet.show(context);
    if (source == null) return; // foydalanuvchi bekor qildi
    if (!mounted) return;

    final service = ImagePickerService();
    final bytes = source == ImageSource.gallery
        ? await service.pickFromGallery()
        : await service.pickFromCamera();

    if (!mounted) return;
    if (bytes == null) return; // tanlash bekor qilindi yoki ruxsat berilmadi

    setState(() => _photoBytes = bytes);
  }

  /// Add yoki Edit mode'da forma ma'lumotlarini Firestore'ga saqlaydi.
  ///
  /// **Add mode**: `childActionsProvider.addChild` chaqiriladi —
  /// pairing code yaratiladi, Firestore'ga yoziladi, oila kodi
  /// ekraniga o'tiladi.
  /// **Edit mode**: identifikator, oila kodi, createdAt o'zgarmaydi.
  /// `updateChild` Firestore'ga `update` qiladi.
  ///
  /// **Eslatma — `photoBytes`:** Bosqich 2.5.A'da Firebase Storage
  /// upload yo'q. `photoUrl` Bosqich 2.5.B'da qo'shiladi.
  Future<void> _onSave() async {
    if (!_isFormValid) return;

    setState(() => _isSaving = true);

    final actions = ref.read(childActionsProvider.notifier);

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
        age: _selectedAge!,
        gender: _selectedGender!,
        region: _selectedRegion!,
        phoneNumber: _phoneController.text.trim(),
      );
      // Foydalanuvchi yangi foto tanlagan bo'lsa Storage'ga upload
      // qilinadi (eski URL almashtiriladi).
      final result = await actions.updateChild(
        widget.childId!,
        updated,
        newPhotoBytes: _photoBytes,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (result.isSuccess) {
        context.pop();
      } else {
        _showError(result.error);
      }
      return;
    }

    // ─── Add mode ───
    // `photoBytes` berilgan bo'lsa repository Storage'ga upload qiladi.
    final result = await actions.addChild(
      name: _nameController.text.trim(),
      age: _selectedAge!,
      gender: _selectedGender!,
      region: _selectedRegion!,
      photoBytes: _photoBytes,
      phoneNumber: _phoneController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.isSuccess) {
      // Child obyektini extra orqali ham yuboramiz — race condition
      // oldini olish uchun (childrenProvider GET'ni kutmasdan
      // FamilyCodeScreen darhol bola ma'lumotlarini ko'rsata oladi).
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
    return Scaffold(
      appBar: AppBar(
        // go_router avtomatik back tugmasini chiqaradi (push'dan kelgan).
        title: Text(
          _isEditMode
              ? 'childManagement.addEdit.editTitle'.tr()
              : 'childManagement.addEdit.addTitle'.tr(),
          style: AppTextStyles.bodyM.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: GradientBackground(
        child: SafeArea(
          // ── Tashqi Column: forma (scroll) + pastdagi tugmalar (fiks) ──
          child: Column(
            children: [
              // Forma — qolgan joyni egallaydi va scroll qiladi.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppDimensions.lg),

                      // ── Fotosurat ──
                      _label('childManagement.addEdit.photoLabel'.tr()),
                      const SizedBox(height: 12),
                      Center(
                        child: PhotoUploadPlaceholder(
                          photoBytes: _photoBytes,
                          onTap: _onPickPhoto,
                          onRemove: () => setState(() => _photoBytes = null),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.xl),

                      // ── Ism ──
                      _label('childManagement.addEdit.nameLabel'.tr()),
                      const SizedBox(height: AppDimensions.sm),
                      CustomTextField(
                        controller: _nameController,
                        hint: 'childManagement.addEdit.nameHint'.tr(),
                        maxLength: 30,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppDimensions.lg),

                      // ── Telefon raqami (ixtiyoriy — SOS "Qo'ng'iroq") ──
                      _label('childManagement.addEdit.phoneLabel'.tr()),
                      const SizedBox(height: AppDimensions.sm),
                      CustomTextField(
                        controller: _phoneController,
                        hint: 'childManagement.addEdit.phoneHint'.tr(),
                        keyboardType: TextInputType.phone,
                        maxLength: 20,
                      ),
                      const SizedBox(height: AppDimensions.lg),

                      // ── Yoshi ──
                      _label('childManagement.addEdit.ageLabel'.tr()),
                      const SizedBox(height: AppDimensions.sm),
                      CustomDropdown<int>(
                        hint: 'childManagement.addEdit.ageHint'.tr(),
                        value: _selectedAge,
                        items: [
                          for (var age = 5; age <= 18; age++)
                            DropdownMenuItem(
                              value: age,
                              child: Text(
                                'childManagement.addEdit.ageItem'.tr(
                                  namedArgs: {'age': '$age'},
                                ),
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _selectedAge = v),
                      ),
                      const SizedBox(height: AppDimensions.lg),

                      // ── Hudud ──
                      _label('childManagement.addEdit.regionLabel'.tr()),
                      const SizedBox(height: AppDimensions.sm),
                      CustomDropdown<String>(
                        hint: 'childManagement.addEdit.regionHint'.tr(),
                        value: _selectedRegion,
                        items: [
                          for (final region in UzbekistanRegions.regions)
                            DropdownMenuItem(
                              value: region,
                              child: Text(region),
                            ),
                        ],
                        onChanged: (v) => setState(() => _selectedRegion = v),
                      ),
                      const SizedBox(height: AppDimensions.lg),

                      // ── Jinsi ──
                      _label('childManagement.addEdit.genderLabel'.tr()),
                      const SizedBox(height: AppDimensions.sm),
                      GenderSelector(
                        selected: _selectedGender,
                        onChanged: (g) => setState(() => _selectedGender = g),
                      ),
                      const SizedBox(height: AppDimensions.xl),
                    ],
                  ),
                ),
              ),

              // ── Pastki tugmalar — scroll qilmaydi, doim ko'rinadi ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.lg,
                  AppDimensions.md,
                  AppDimensions.lg,
                  AppDimensions.lg,
                ),
                child: Row(
                  children: [
                    // flex: 1 — kichikroq tugma chap tomonda
                    Expanded(
                      child: SecondaryButton(
                        label: 'childManagement.addEdit.backButton'.tr(),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // flex: 2 — asosiy harakat 2 marta kengroq
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: _isEditMode
                            ? 'childManagement.addEdit.updateButton'.tr()
                            : 'childManagement.addEdit.saveButton'.tr(),
                        isLoading: _isSaving,
                        onPressed: _isFormValid && !_isSaving ? _onSave : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Forma seksiyasi sarlavhasi — 16sp Semibold oq matn.
  Widget _label(String text) => Text(
    text,
    style: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w600),
  );
}
