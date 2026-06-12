// ─────────────────────────────────────────────────────────────────────
// video_message_provider — Backend video messages (Sprint 4.4.18)
// ─────────────────────────────────────────────────────────────────────
//
// Voice pattern bilan parallel: fetch + WS video:received + multipart
// upload. child.linkedDeviceUid bilan filter.

import 'dart:async';
import 'dart:io';

import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/video_message/data/models/video_message.dart';
import 'package:farzandim/features/video_message/data/repositories/backend_video_message_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Joriy Parent user ID.
String? _currentUserId(Ref ref) {
  final auth = ref.watch(backendAuthProvider);
  return auth is AuthAuthenticated ? auth.user.id : null;
}

/// Bola bilan video xabarlar — Backend fetch + WS `video:received`.
final videoMessagesProvider =
    StreamProvider.family<List<VideoMessage>, String>((ref, childId) async* {
  final currentUserId = _currentUserId(ref);
  if (currentUserId == null) {
    yield const <VideoMessage>[];
    return;
  }

  final child = ref.watch(childByIdProvider(childId));
  final childUserId = child?.linkedDeviceUid;
  if (childUserId == null) {
    yield const <VideoMessage>[];
    return;
  }

  final repo = ref.watch(backendVideoMessageRepositoryProvider);

  Future<List<VideoMessage>> fetch() async {
    final raw = await repo.getMessages();
    return raw
        .where((m) =>
            m['senderId'] == childUserId ||
            m['receiverId'] == childUserId)
        .map(
          (m) => VideoMessage.fromBackendJson(
            m,
            currentUserId: currentUserId,
            childId: childId,
          ),
        )
        .toList()
        .reversed
        .toList();
  }

  yield await fetch();

  final controller = StreamController<List<VideoMessage>>();
  final sub = repo.receivedStream().listen((data) async {
    if (data is! Map) return;
    final s = data['senderId'] as String?;
    final r = data['receiverId'] as String?;
    if (s == childUserId || r == childUserId) {
      final fresh = await fetch();
      if (!controller.isClosed) controller.add(fresh);
    }
  });
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  yield* controller.stream;
});

/// Video upload notifier.
enum VideoUploadStatus { idle, uploading, sent, error }

@immutable
class VideoUploadState {
  const VideoUploadState({
    this.status = VideoUploadStatus.idle,
    this.progress = 0,
    this.errorMessage,
  });

  final VideoUploadStatus status;
  final double progress;
  final String? errorMessage;

  VideoUploadState copyWith({
    VideoUploadStatus? status,
    double? progress,
    String? errorMessage,
  }) =>
      VideoUploadState(
        status: status ?? this.status,
        progress: progress ?? this.progress,
        errorMessage: errorMessage,
      );
}

class VideoUploadNotifier extends StateNotifier<VideoUploadState> {
  VideoUploadNotifier(this._ref) : super(const VideoUploadState());

  final Ref _ref;

  /// Multipart upload (Parent → child user).
  Future<bool> send({
    required String childId,
    required File videoFile,
    int? durationSeconds,
  }) async {
    final child = _ref.read(childByIdProvider(childId));
    final receiverId = child?.linkedDeviceUid;
    if (receiverId == null || receiverId.isEmpty) {
      state = state.copyWith(
        status: VideoUploadStatus.error,
        errorMessage: 'Bola hali pair qilmagan',
      );
      return false;
    }

    state = state.copyWith(
      status: VideoUploadStatus.uploading,
      progress: 0,
    );

    try {
      await _ref.read(backendVideoMessageRepositoryProvider).sendMessage(
            receiverId: receiverId,
            videoFile: videoFile,
            durationSeconds: durationSeconds,
            onProgress: (p) {
              state = state.copyWith(progress: p);
            },
          );
      _ref.invalidate(videoMessagesProvider(childId));
      state = state.copyWith(
        status: VideoUploadStatus.sent,
        progress: 1,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: VideoUploadStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void reset() => state = const VideoUploadState();
}

final videoUploadProvider =
    StateNotifierProvider<VideoUploadNotifier, VideoUploadState>(
  VideoUploadNotifier.new,
);
