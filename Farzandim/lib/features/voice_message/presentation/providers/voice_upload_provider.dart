// ─────────────────────────────────────────────────────────────────────
// voice_upload_provider — Backend voice upload (Sprint 4.4.5)
// ─────────────────────────────────────────────────────────────────────
//
// Eski Firebase Storage upload → Backend multipart POST.

import 'dart:io';

import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/voice_message/data/repositories/backend_voice_message_repository.dart';
import 'package:farzandim/features/voice_message/presentation/providers/voice_message_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Audio yuborish jarayoni holati.
enum UploadStatus {
  idle,
  uploading,
  sent,
  error,
}

@immutable
class VoiceUploadState {
  const VoiceUploadState({
    this.status = UploadStatus.idle,
    this.progress = 0,
    this.errorMessage,
  });

  final UploadStatus status;
  final double progress;
  final String? errorMessage;

  VoiceUploadState copyWith({
    UploadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return VoiceUploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
    );
  }
}

class VoiceUploadNotifier extends StateNotifier<VoiceUploadState> {
  VoiceUploadNotifier(this._ref) : super(const VoiceUploadState());

  final Ref _ref;

  /// Audio fayl yuboradi (Backend multipart).
  ///
  /// `childId` — Parent App'da tanlangan bola UI uchun (model'da saqlanadi).
  /// Backend chaqirishida `receiverId` = `child.linkedDeviceUid` (paired
  /// Child User ID). Bola hali pair qilmagan bo'lsa xato qaytariladi.
  ///
  /// Backend Claude security: senderId === receiverId → 400 (bola o'ziga
  /// yubora olmaydi). Parent App tomondan parent JWT bilan child userga
  /// yuboradi — security check OK.
  Future<String?> send({
    required String childId,
    required String childName,
    required String localFilePath,
    required int durationSeconds,
    required List<double> waveform,
  }) async {
    // Bola Backend Child User ID'sini topish.
    final child = _ref.read(childByIdProvider(childId));
    if (child == null) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'Bola topilmadi',
      );
      return null;
    }
    final receiverId = child.linkedDeviceUid;
    if (receiverId == null || receiverId.isEmpty) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage:
            "Bola hali Child App'da pair qilmagan — voice yubora olmaysiz",
      );
      return null;
    }

    state = state.copyWith(
      status: UploadStatus.uploading,
      progress: 0,
    );

    try {
      final messageId = await _ref
          .read(backendVoiceMessageRepositoryProvider)
          .sendMessage(
            receiverId: receiverId,
            audioFile: File(localFilePath),
            durationSeconds: durationSeconds,
            onProgress: (progress) {
              state = state.copyWith(progress: progress);
            },
          );

      // Backend POST tugadi — voice ro'yxatini refresh qilamiz.
      _ref.invalidate(rawVoiceMessagesProvider);

      state = state.copyWith(status: UploadStatus.sent);
      return messageId;
    } catch (e) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  void reset() {
    state = const VoiceUploadState();
  }
}

final voiceUploadProvider =
    StateNotifierProvider<VoiceUploadNotifier, VoiceUploadState>(
  VoiceUploadNotifier.new,
);
