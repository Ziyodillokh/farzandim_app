// Ovozli xabarni backend'ga multipart orqali yuborish holati.

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
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

  /// Audio faylni backend'ga multipart qilib yuboradi.
  ///
  /// `childId` — UI'da tanlangan bola; backend'ga `receiverId` sifatida
  /// `child.linkedDeviceUid` ketadi. Bola hali pair qilinmagan bo'lsa
  /// xato qaytariladi.
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
        errorMessage: 'voiceChat.childNotFound'.tr(),
      );
      return null;
    }
    final receiverId = child.linkedDeviceUid;
    if (receiverId == null || receiverId.isEmpty) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'voiceChat.notPaired'.tr(),
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
