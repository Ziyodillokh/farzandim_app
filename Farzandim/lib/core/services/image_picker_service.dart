import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Galereya yoki kameradan rasm tanlash xizmati.
///
/// `image_picker` paketini o'rab oladi va `Uint8List` (bayt massivi)
/// qaytaradi — web/iOS/Android'da bir xil ishlaydi.
///
/// **Nega `String? path` emas, `Uint8List? bytes`?**
/// Web'da `XFile.path` `blob:http://...` shaklida bo'ladi va
/// `dart:io.File` web'da mavjud emas — `Image.file` web build'ni
/// sindiradi. Bytes universal: `Image.memory(bytes)` hamma joyda
/// ishlaydi va Bosqich 1.6'da Firebase Storage'ga yuklash uchun
/// ham bytes kerak.
///
/// Foydalanish:
/// ```dart
/// final service = ImagePickerService();
/// final bytes = await service.pickFromGallery();
/// if (bytes != null) {
///   setState(() => _photoBytes = bytes);
/// }
/// ```
class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  /// Galereyadan bitta rasm tanlash. Foydalanuvchi bekor qilsa `null`.
  Future<Uint8List?> pickFromGallery() => _pick(ImageSource.gallery);

  /// Kameradan rasm olish. Foydalanuvchi bekor qilsa yoki kamera yo'q
  /// bo'lsa `null` (web'da har doim `null`).
  Future<Uint8List?> pickFromCamera() => _pick(ImageSource.camera);

  /// Umumiy ichki metod — ikki manba uchun bir xil mantiq.
  ///
  /// `imageQuality: 80` — JPG siqilish darajasi (0-100).
  /// `maxWidth: 800` — maksimal eni; balandlik proporsional.
  /// Avatar uchun yetarli, hajmni 100x kichraytiradi
  /// (5MB → ~50KB).
  Future<Uint8List?> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }
}
