// ─────────────────────────────────────────────────────────────────────
// video_message_provider — upload state + video messages stream
// ─────────────────────────────────────────────────────────────────────
//
// Sprint 4.4.18 (child port): Backend REST + WS `video:received` real-time
// (Parent voice/video pattern bilan parallel).

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/video_message/data/models/video_message.dart';
import 'package:farzandim_child/features/video_message/data/repositories/backend_video_message_repository.dart';
import 'package:farzandim_child/features/video_message/data/services/video_message_service.dart';

enum UploadStatus { idle, uploading, sent, error }

class UploadState {
  const UploadState({
    this.status = UploadStatus.idle,
    this.progress = 0.0,
    this.errorMessage,
    this.lastMessageId,
  });

  final UploadStatus status;
  final double progress;
  final String? errorMessage;
  final String? lastMessageId;

  UploadState copyWith({
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    String? lastMessageId,
  }) {
    return UploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      lastMessageId: lastMessageId ?? this.lastMessageId,
    );
  }
}

final videoMessageServiceProvider =
    Provider<VideoMessageService>((ref) => VideoMessageService());

/// Bola yuborgan oxirgi video xabar (status indikator uchun). Pairing
/// state'dan parentUid + childId o'qiydi. **LEGACY** — Firestore stream.
final latestVideoMessageProvider = StreamProvider<VideoMessage?>((ref) {
  final pairing = ref.watch(pairingStateProvider);
  if (!pairing.isPaired ||
      pairing.parentUid == null ||
      pairing.childId == null) {
    return Stream.value(null);
  }
  return ref.watch(videoMessageServiceProvider).latestForChild(
        parentUid: pairing.parentUid!,
        childId: pairing.childId!,
      );
});

/// Video xabarlar ro'yxati — Backend fetch + WS `video:received` listen.
///
/// Voice pattern bilan parallel: pairing.currentUserId orqali Backend
/// `/api/video-messages` (joriy user'ga aloqador hammasi) → DESC sortlangan
/// keladi. Bu yerda ASC ga aylantirib qaytaramiz (chat ekran chronological).
final videoMessagesProvider =
    StreamProvider<List<VideoMessage>>((ref) async* {
  final pairing = ref.watch(pairingStateProvider);
  if (!pairing.isPaired) {
    yield const <VideoMessage>[];
    return;
  }
  final currentUserId = pairing.currentUserId ?? '';
  if (currentUserId.isEmpty) {
    yield const <VideoMessage>[];
    return;
  }
  final repo = ref.watch(backendVideoMessageRepositoryProvider);

  Future<List<VideoMessage>> fetch() async {
    final raw = await repo.getMessages();
    return raw
        .map(
          (m) => VideoMessage.fromBackendJson(
            m,
            currentUserId: currentUserId,
          ),
        )
        .toList();
  }

  yield await fetch();

  final controller = StreamController<List<VideoMessage>>();
  final sub = repo.receivedStream().listen((_) async {
    if (!controller.isClosed) controller.add(await fetch());
  });
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  yield* controller.stream;
});

final videoMessageUploadProvider =
    StateNotifierProvider<VideoMessageUploadNotifier, UploadState>(
  (ref) => VideoMessageUploadNotifier(ref),
);

class VideoMessageUploadNotifier extends StateNotifier<UploadState> {
  VideoMessageUploadNotifier(this._ref) : super(const UploadState());

  final Ref _ref;

  /// Video yuborish. `requestId` berilsa — Parent so'roviga javob deb
  /// hisoblanadi va `video_requests/{id}.status = 'completed'` yoziladi.
  Future<bool> send({
    required File videoFile,
    required int durationSeconds,
    String? requestId,
  }) async {
    final pairing = _ref.read(pairingStateProvider);
    if (!pairing.isPaired ||
        pairing.parentUid == null ||
        pairing.childId == null) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'Pair qilingan emas',
      );
      return false;
    }

    state = const UploadState(
      status: UploadStatus.uploading,
      progress: 0.0,
    );

    try {
      // Sprint 4.4.9 Day 4: Backend POST /video-messages.
      // receiverId = parentUid (Backend Parent User.id pairing'da).
      // `requestId` Backend tomondan ignored — Backend Video API
      // request lifecycle yo'q (faqat free-form video messages).
      final id = await _ref
          .read(backendVideoMessageRepositoryProvider)
          .sendMessage(
            receiverId: pairing.parentUid!,
            videoFile: videoFile,
            durationSeconds: durationSeconds,
            onProgress: (p) {
              state = state.copyWith(progress: p);
            },
          );

      // Sprint 4.4.18 port: ro'yxat refresh — yangi xabar darhol chiqsin.
      _ref.invalidate(videoMessagesProvider);

      state = state.copyWith(
        status: UploadStatus.sent,
        progress: 1.0,
        lastMessageId: id,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = const UploadState();
  }
}
