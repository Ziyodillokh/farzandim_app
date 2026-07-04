// ─────────────────────────────────────────────────────────────────────
// VideoCapture — web implementatsiyasi (brauzer getUserMedia + MediaRecorder)
// ─────────────────────────────────────────────────────────────────────
//
// Flutter'ning `camera` paketi web'da video yozmaydi, shuning uchun brauzer
// native API'lari ishlatiladi: kamera oqimi <video> elementida ko'rsatiladi
// (HtmlElementView), MediaRecorder yozadi, natija blob URL sifatida qaytadi.

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// ignore_for_file: cascade_invocations, avoid_escaping_inner_quotes

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:farzandim/features/chat/data/video/video_capture.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Web uchun `VideoCapture` yaratadi.
VideoCapture createVideoCapture() => _WebVideoCapture();

/// Blob/URL manbadan video pleer boshqaruvchisi (web).
VideoPlayerController createVideoController(String source) =>
    VideoPlayerController.networkUrl(Uri.parse(source));

class _WebVideoCapture implements VideoCapture {
  html.MediaStream? _stream;
  html.MediaRecorder? _recorder;
  html.VideoElement? _video;
  final List<html.Blob> _chunks = [];
  String? _viewType;
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  Future<void> init() async {
    final media = html.window.navigator.mediaDevices;
    if (media == null) {
      throw Exception('Bu brauzer kamerani qo\'llamaydi');
    }
    _stream = await media.getUserMedia({
      'video': {'facingMode': 'user'},
      'audio': true,
    });
    final video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..srcObject = _stream
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';
    video.setAttribute('playsinline', 'true');
    _video = video;
    _viewType = 'chat-cam-${_stream.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType!,
      (int _) => video,
    );
    _ready = true;
  }

  @override
  Widget preview() {
    final vt = _viewType;
    if (vt == null) return const SizedBox.shrink();
    return HtmlElementView(viewType: vt);
  }

  @override
  Future<void> start() async {
    final stream = _stream;
    if (stream == null) return;
    _chunks.clear();
    final recorder = html.MediaRecorder(stream);
    recorder.addEventListener('dataavailable', (html.Event e) {
      final blob = (e as html.BlobEvent).data;
      if (blob != null && blob.size > 0) _chunks.add(blob);
    });
    recorder.start();
    _recorder = recorder;
  }

  @override
  Future<String?> stop() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    final done = Completer<void>();
    recorder.addEventListener('stop', (_) {
      if (!done.isCompleted) done.complete();
    });
    recorder.stop();
    await done.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
    _recorder = null;
    if (_chunks.isEmpty) return null;
    final blob = html.Blob(_chunks);
    return html.Url.createObjectUrlFromBlob(blob);
  }

  @override
  Future<void> cancel() async {
    try {
      _recorder?.stop();
    } catch (_) {
      // e'tiborsiz
    }
    _recorder = null;
    _chunks.clear();
  }

  @override
  Future<void> dispose() async {
    try {
      _recorder?.stop();
    } catch (_) {}
    _stream?.getTracks().forEach((t) => t.stop());
    _video?.srcObject = null;
    _stream = null;
    _video = null;
  }
}
