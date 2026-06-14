// ─────────────────────────────────────────────────────────────────────
// UnlockRequestBridge — native bloklash overlay'idan "Ruxsat so'rash"
// ─────────────────────────────────────────────────────────────────────
//
// Bola bloklangan ilovada overlay'dagi "Ruxsat so'rash" tugmasini bossa,
// native (RestrictionService) Parvoz'ni `unlock_request_package` extra bilan
// ochadi. Bu yerda Flutter shu paketni o'qib (consumePendingUnlock) yoki
// ilova allaqachon ochiq bo'lsa native push (onUnlockRequested) orqali
// backend'ga so'rov yuboradi.

// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UnlockRequestBridge {
  UnlockRequestBridge(this._onRequest) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onUnlockRequested') {
        final pkg = call.arguments as String?;
        if (pkg != null && pkg.isNotEmpty) {
          await _onRequest(pkg);
        }
      }
      return null;
    });
  }

  static const MethodChannel _channel = MethodChannel('farzandim_child/unlock');

  /// `packageName` uchun so'rov yuboradigan callback (repo + UI feedback).
  final Future<void> Function(String packageName) _onRequest;

  /// App ochilganda (cold start) — native saqlab qo'ygan kutilayotgan
  /// so'rov paketini olib, bo'sh bo'lmasa so'rov yuboradi.
  Future<void> checkPending() async {
    if (!Platform.isAndroid) return;
    try {
      final pkg = await _channel.invokeMethod<String>('consumePendingUnlock');
      if (pkg != null && pkg.isNotEmpty) {
        await _onRequest(pkg);
      }
    } on PlatformException catch (e) {
      debugPrint('UnlockRequestBridge.checkPending xato: ${e.message}');
    } on MissingPluginException {
      // iOS yoki kanal yo'q — jim chiqamiz.
    }
  }
}
