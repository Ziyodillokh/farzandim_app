import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime ruxsat so'rovining yakuniy natijasi.
enum PermissionOutcome {
  /// Foydalanuvchi ruxsat berdi (yoki cheklangan kirish berdi).
  granted,

  /// Bu safar rad etildi, ammo qayta so'ralsa OS dialogi yana chiqadi.
  denied,

  /// Doimiy rad etilgan ("Boshqa so'ramang") — faqat Sozlamalardan yoqiladi.
  permanentlyDenied,

  /// Qurilma darajasida BLOKLANGAN (Ekran vaqti cheklovi yoki MDM profili).
  /// Foydalanuvchi ilova sozlamalaridan yoqa OLMAYDI — tizim cheklovini
  /// olib tashlash kerak. Shu sababli `permanentlyDenied` dan ajratilgan:
  /// "Sozlamalarni ochish" bu holatda foydasiz maslahat bo'lardi.
  restricted,
}

/// Runtime ruxsatlarni "just-in-time" so'rab, doimiy rad holatini
/// markazlashtirilgan tarzda boshqaradigan servis.
///
/// Ruxsat AYNAN o'sha funksiya ishlatilganda so'raladi (mikrofon — ovozli
/// xabar yozishda, kamera — video yozishda), ilova ochilishida emas. Doimiy
/// rad etilganda foydalanuvchi tuzoqqa tushib qolmasligi uchun chaqiruvchi
/// ekran [showOpenAppSettingsDialog] orqali "Sozlamalarni ochish"ni taklif
/// qiladi.
class PermissionService {
  /// Const konstruktor — holatga ega emas, har joyda `const` yaratiladi.
  const PermissionService();

  /// Bitta ruxsatni so'raydi va sodda, qaror qabul qilish oson natija
  /// qaytaradi. Allaqachon berilgan bo'lsa OS dialogi ko'rsatilmaydi.
  Future<PermissionOutcome> request(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) {
      return PermissionOutcome.granted;
    }
    if (status.isRestricted) {
      return PermissionOutcome.restricted;
    }
    if (status.isPermanentlyDenied) {
      return PermissionOutcome.permanentlyDenied;
    }

    final result = await permission.request();
    if (result.isGranted || result.isLimited) {
      return PermissionOutcome.granted;
    }
    if (result.isRestricted) {
      return PermissionOutcome.restricted;
    }
    if (result.isPermanentlyDenied) {
      return PermissionOutcome.permanentlyDenied;
    }
    return PermissionOutcome.denied;
  }
}

/// Doimiy rad etilgan ruxsat uchun "Sozlamalarni ochish" dialogi.
///
/// Foydalanuvchi tasdiqlasa, ilova sozlamalari sahifasini ochadi — u yerdan
/// ruxsatni qo'lda yoqishi mumkin.
Future<void> showOpenAppSettingsDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('permissions.openSettings'.tr()),
        ),
      ],
    ),
  );
  if (open ?? false) {
    await openAppSettings();
  }
}
