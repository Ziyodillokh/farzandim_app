// ─────────────────────────────────────────────────────────────────────
// VideoThumbCache — dumaloq video xabarlar uchun disk thumbnail keshi
// ─────────────────────────────────────────────────────────────────────
//
// MEM-3: avval HAR video-bubble thumbnail ko'rsatish uchun JONLI
// VideoPlayerController (native ExoPlayer/AVPlayer) ochib USHLAB TURARDI —
// 30 xabarli chatda 30 ta parallel native pleyer (xotira + dekoder
// resurslari, zaif telefonlarda chat sekinlashadi/o'ladi).
//
// Endi: video BIR MARTA yuklab olinadi → birinchi kadrdan BITTA JPG
// yaratiladi (mavjud video_compress paketi — YANGI dependency yo'q) →
// doimiy kesh papkaga saqlanadi. Keyingi ochilishlarda 0 tarmoq, 0 pleyer
// — oddiy Image.file. Pleyer FAQAT foydalanuvchi o'ynatganda ochiladi.

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

/// Video xabar thumbnail'larini diskda keshlovchi statik servis.
class VideoThumbCache {
  VideoThumbCache._();

  /// Parallel so'rovlar dedup'i — bir xil xabar uchun bitta ish.
  static final Map<String, Future<File?>> _inFlight = {};

  /// video_compress bir vaqtda bitta operatsiyani xohlaydi — global
  /// ketma-ketlik zanjiri (navbat).
  static Future<void> _queue = Future<void>.value();

  /// Xabar uchun thumbnail faylini qaytaradi (keshdan yoki yaratib).
  /// Xato bo'lsa `null` — chaqiruvchi fallback ko'rsatadi.
  static Future<File?> getThumb({
    required String messageId,
    required String videoUrl,
    required Dio dio,
  }) {
    return _inFlight.putIfAbsent(messageId, () async {
      try {
        return await _getOrCreate(messageId, videoUrl, dio);
      } catch (e) {
        debugPrint('VideoThumbCache($messageId): $e');
        return null;
      } finally {
        // Muvaffaqiyatda keyingi chaqiruv keshdagi fayldan oladi;
        // xatoda keyingi urinishga ruxsat.
        unawaited(
          Future<void>.delayed(
            Duration.zero,
            () => _inFlight.remove(messageId),
          ),
        );
      }
    });
  }

  static Future<File?> _getOrCreate(
    String messageId,
    String videoUrl,
    Dio dio,
  ) async {
    final dir = await getApplicationCacheDirectory();
    final thumbDir = Directory('${dir.path}/video_thumbs');
    final safeId = messageId.replaceAll(RegExp(r'[^\w\-]'), '_');
    final thumbFile = File('${thumbDir.path}/$safeId.jpg');

    // 1. Kesh bor — darhol.
    if (thumbFile.existsSync() && thumbFile.lengthSync() > 0) {
      return thumbFile;
    }

    await thumbDir.create(recursive: true);

    // 2. Videoni vaqtinchaga yuklab olish (round videolar client-side
    //    compress qilingan, ~1MB) — bu BIR MARTALIK xarajat; avval har
    //    chat ochilishda har video uchun ExoPlayer stream bufferlanardi.
    final tmpVideo = File('${thumbDir.path}/$safeId.tmp.mp4');
    try {
      await dio.download(videoUrl, tmpVideo.path);

      // 3. Birinchi kadrdan JPG (video_compress navbati orqali —
      //    plagin parallel chaqiruvlarni yoqtirmaydi).
      final completer = Completer<File?>();
      _queue = _queue.then((_) async {
        try {
          final thumb = await VideoCompress.getFileThumbnail(
            tmpVideo.path,
            quality: 60,
          );
          completer.complete(thumb);
        } catch (e) {
          completer.complete(null);
        } finally {
          // Kafolat: completer HAR DOIM yakunlanadi — aks holda kutilmagan
          // xato turida await abadiy osilib, navbat zanjiri buzilardi.
          if (!completer.isCompleted) completer.complete(null);
        }
      });
      final rawThumb = await completer.future;
      if (rawThumb == null || !rawThumb.existsSync()) return null;

      // 4. Doimiy nomga ko'chirish (video_compress o'z temp'iga yozadi).
      await rawThumb.copy(thumbFile.path);
      unawaited(rawThumb.delete().catchError((_) => rawThumb));
      return thumbFile;
    } finally {
      // Vaqtinchalik videoni har holatda o'chiramiz (disk band bo'lmasin).
      if (tmpVideo.existsSync()) {
        unawaited(tmpVideo.delete().catchError((_) => tmpVideo));
      }
    }
  }
}
