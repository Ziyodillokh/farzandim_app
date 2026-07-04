// ─────────────────────────────────────────────────────────────────────
// VideoCapture factory — platformaga qarab io/web implementatsiyasini tanlaydi
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim/features/chat/data/video/video_capture.dart';
import 'package:farzandim/features/chat/data/video/video_capture_io.dart'
    if (dart.library.html) 'package:farzandim/features/chat/data/video/video_capture_web.dart'
    as impl;
import 'package:video_player/video_player.dart';

/// Joriy platforma uchun `VideoCapture` yaratadi.
VideoCapture createVideoCapture() => impl.createVideoCapture();

/// Manba (blob URL yoki fayl yo'li) uchun video pleer boshqaruvchisi.
VideoPlayerController createVideoController(String source) =>
    impl.createVideoController(source);
