// ─────────────────────────────────────────────────────────────────────
// video_message_provider — Backend video messages (Sprint 4.4.18)
// ─────────────────────────────────────────────────────────────────────
//
// Voice pattern bilan parallel: fetch + WS video:received + multipart
// upload. child.linkedDeviceUid bilan filter.

import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/utils/safe_parse.dart';
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

/// Joriy parent'ning BARCHA video xabarlari — xom backend JSON.
///
/// MASSHTAB (PERF, voice'dagi P0-4 bilan parallel): backend
/// `/api/video-messages` baribir parent'ning to'liq ro'yxatini qaytaradi —
/// avval har bola-instance shu endpointni O'ZI chaqirardi va ustiga
/// `childByIdProvider`ni `select`siz watch qilgani uchun bola onlayn
/// bo'lsa HAR heartbeat'da (~60s) to'liq tarix qayta tortilardi. Endi
/// fetch BITTA joyda; per-bola providerlar faqat filtr.
///
/// Yuborish/refresh'dan keyin yangilash: `ref.invalidate(rawVideoMessagesProvider)`.
final rawVideoMessagesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final currentUserId = _currentUserId(ref);
  if (currentUserId == null) {
    yield const <Map<String, dynamic>>[];
    return;
  }

  final repo = ref.watch(backendVideoMessageRepositoryProvider);

  yield await repo.getMessages();

  // WS `video:received` — yangi xabar keldi, bitta refetch (barcha
  // bola-filtrlar shu natijadan oziqlanadi).
  final controller = StreamController<List<Map<String, dynamic>>>();
  final sub = repo.receivedStream().listen((data) async {
    if (data is! Map) return;
    try {
      final fresh = await repo.getMessages();
      if (!controller.isClosed) controller.add(fresh);
    } catch (_) {
      // tarmoq blip — oxirgi ro'yxat saqlanadi, keyingi event qayta uradi
    }
  });
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  yield* controller.stream;
});

/// Bola bilan video xabarlar — umumiy xom ro'yxatdan filtr.
///
/// Bola hali pair qilmagan (`linkedDeviceUid == null`) → bo'sh ro'yxat.
final videoMessagesProvider =
    Provider.family<AsyncValue<List<VideoMessage>>, String>((ref, childId) {
  final currentUserId = _currentUserId(ref);
  if (currentUserId == null) {
    return const AsyncValue.data(<VideoMessage>[]);
  }

  // MUHIM (P0-4 bilan parallel): butun Child obyektini emas, FAQAT
  // linkedDeviceUid'ni watch qilamiz (`select`) — 60s heartbeat yangi
  // Child (lastSeenAt) berganda bu provider recompute BO'LMAYDI.
  final childUserId = ref.watch(childrenListProvider.select((children) {
    for (final c in children) {
      if (c.id == childId) return c.linkedDeviceUid;
    }
    return null;
  }));
  if (childUserId == null) {
    return const AsyncValue.data(<VideoMessage>[]);
  }

  List<VideoMessage> parse(List<Map<String, dynamic>> raw) {
    final mine = raw.where(
      (m) => m['senderId'] == childUserId || m['receiverId'] == childUserId,
    );
    // ARCH-12: bitta buzuq xabar butun tarixni yiqitmasin.
    final parsed = parseListSafely(
      mine,
      (m) => VideoMessage.fromBackendJson(
        m,
        currentUserId: currentUserId,
        childId: childId,
      ),
      tag: 'videoMessages',
    );
    // Backend DESC keladi — chat ekrani uchun ASC (chronological).
    return parsed.reversed.toList();
  }

  final rawAsync = ref.watch(rawVideoMessagesProvider);
  // Flash-guard (voice bilan bir xil): refetch paytida oldingi ro'yxat
  // ko'rsatilib turadi — chat bir lahza bo'shab qolmaydi.
  if (rawAsync.hasValue) {
    return AsyncValue.data(parse(rawAsync.requireValue));
  }
  return rawAsync.whenData(parse);
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
        errorMessage: 'videoMessages.notPaired'.tr(),
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
      _ref.invalidate(rawVideoMessagesProvider);
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
