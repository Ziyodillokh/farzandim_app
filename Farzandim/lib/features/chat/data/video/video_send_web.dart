// Video yuborish — web (Flutter web fayl yuklashni bu oqimda qo'llamaydi).

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web'da video yuborib bo'lmaydi — `false` qaytadi (telefon kerak).
Future<bool> sendRecordedVideo(
  WidgetRef ref, {
  required String childId,
  required String path,
  required int seconds,
}) async =>
    false;
