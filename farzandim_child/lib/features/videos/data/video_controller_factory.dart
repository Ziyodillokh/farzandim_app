// ─────────────────────────────────────────────────────────────────────
// videoControllerFor — videoUrl turiga qarab to'g'ri controller yaratadi
// ─────────────────────────────────────────────────────────────────────
//
// `http(s)://...`  → tarmoqdan (real videolar — backend/admin panel).
// boshqa (masalan `assets/videos/sample.mp4`) → APK ichidagi asset (mock
// placeholder, OFFLINE ham ishlaydi). Ikkala video player ekrani ham shu
// fabrikadan foydalanadi — bir joyda mantiq.

import 'package:video_player/video_player.dart';

VideoPlayerController videoControllerFor(String videoUrl) {
  final url = videoUrl.trim();
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }
  return VideoPlayerController.asset(url);
}
