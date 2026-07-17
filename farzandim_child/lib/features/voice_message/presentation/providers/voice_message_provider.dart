// ─────────────────────────────────────────────────────────────────────
// voice_message_provider — Backend voice messages (Sprint 4.4.5)
// ─────────────────────────────────────────────────────────────────────
//
// Eski: Firestore stream + Firebase Storage upload
// Yangi: Backend REST. WS real-time push keyingi qadamda (Child App'ga
// socket_client.dart adapt qilingach).

import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/video_message/data/models/video_message.dart';
import 'package:farzandim_child/features/video_message/presentation/providers/video_message_provider.dart';
import 'package:farzandim_child/features/voice_message/data/models/voice_message.dart';
import 'package:farzandim_child/features/voice_message/data/repositories/backend_voice_message_repository.dart';
import 'package:farzandim_child/features/voice_message/data/services/voice_message_service.dart';

enum VoiceUploadStatus { idle, uploading, sent, error }

class VoiceUploadState {
  const VoiceUploadState({
    this.status = VoiceUploadStatus.idle,
    this.progress = 0.0,
    this.errorMessage,
    this.lastMessageId,
  });

  final VoiceUploadStatus status;
  final double progress;
  final String? errorMessage;
  final String? lastMessageId;

  VoiceUploadState copyWith({
    VoiceUploadStatus? status,
    double? progress,
    String? errorMessage,
    String? lastMessageId,
  }) {
    return VoiceUploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      lastMessageId: lastMessageId ?? this.lastMessageId,
    );
  }
}

/// Legacy service — eski code (audio recorder, playback) hali ishlatadi.
/// Sprint 4.4.5 davomida Backend repository'ga to'liq ko'chiramiz.
final voiceMessageServiceProvider = Provider<VoiceMessageService>(
  (ref) => VoiceMessageService(),
);

/// Voice xabarlar ro'yxati — Backend fetch + WS `voice:received` listen.
final voiceMessagesProvider = StreamProvider<List<VoiceMessage>>((ref) async* {
  final pairing = ref.watch(pairingStateProvider);
  if (!pairing.isPaired) {
    yield const <VoiceMessage>[];
    return;
  }
  final currentUserId = pairing.currentUserId ?? '';
  final parentUid = pairing.parentUid;
  final repo = ref.watch(backendVoiceMessageRepositoryProvider);

  // faqat ota-ona bilan oxirgi 100 ta xabar — to'liq tarix tortilmaydi
  Future<List<VoiceMessage>> fetch() => repo.getMessages(
    currentUserId: currentUserId,
    peerId: parentUid,
    limit: 100,
  );

  yield await fetch();

  // WS `voice:received` — ota-ona yuborganida ham, o'zining
  // yuborgan xabari Backend tomonidan emit qilinganida ham refresh.
  final controller = StreamController<List<VoiceMessage>>();
  final sub = repo.voiceReceivedStream().listen((_) async {
    if (!controller.isClosed) controller.add(await fetch());
  });
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  yield* controller.stream;
});

/// Eng oxirgi xabar (Dashboard quick-card preview uchun).
/// `AsyncValue` qaytaradi — UI'da `.when(data/loading/error)` ishlatadi.
final latestVoiceMessageProvider =
    Provider.family<AsyncValue<VoiceMessage?>, String>((ref, childId) {
      return ref.watch(voiceMessagesProvider).whenData((all) {
        if (all.isEmpty) return null;
        // Backend default sort — eng yangisi birinchi (createdAt DESC).
        return all.first;
      });
    });

/// Ota-ona yuborgan ko'rilmagan xabarlar soni (Dashboard badge uchun).
final unreadVoiceMessagesCountProvider =
    Provider.family<AsyncValue<int>, String>((ref, childId) {
      return ref
          .watch(voiceMessagesProvider)
          .whenData(
            (all) => all
                .where(
                  (m) =>
                      m.sender == 'parent' &&
                      m.status == VoiceMessageStatus.sent,
                )
                .length,
          );
    });

final voiceMessageUploadProvider =
    StateNotifierProvider<VoiceMessageUploadNotifier, VoiceUploadState>(
      (ref) => VoiceMessageUploadNotifier(ref),
    );

class VoiceMessageUploadNotifier extends StateNotifier<VoiceUploadState> {
  VoiceMessageUploadNotifier(this._ref) : super(const VoiceUploadState());

  final Ref _ref;

  Future<bool> send({
    required File audioFile,
    required int durationSeconds,
    required List<double> waveform,
  }) async {
    final pairing = _ref.read(pairingStateProvider);
    if (!pairing.isPaired || pairing.parentUid == null) {
      state = state.copyWith(
        status: VoiceUploadStatus.error,
        errorMessage: 'common.notPaired'.tr(),
      );
      return false;
    }

    state = const VoiceUploadState(
      status: VoiceUploadStatus.uploading,
      progress: 0.0,
    );

    try {
      // Child → parent (receiverId = pairing.parentUid Backend Parent User.id).
      final id = await _ref
          .read(backendVoiceMessageRepositoryProvider)
          .sendMessage(
            receiverId: _ref.read(pairingStateProvider).parentUid!,
            audioFile: audioFile,
            durationSeconds: durationSeconds,
            onProgress: (p) {
              state = state.copyWith(progress: p);
            },
          );

      // Voice ro'yxatini refresh — Backend'dan yangi xabar bilan.
      _ref.invalidate(voiceMessagesProvider);

      state = state.copyWith(
        status: VoiceUploadStatus.sent,
        progress: 1.0,
        lastMessageId: id,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: VoiceUploadStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = const VoiceUploadState();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Combined chat items (voice + video) — Telegram-style timeline.
// ─────────────────────────────────────────────────────────────────────

/// Bitta chat lentadagi element — voice yoki video xabar.
///
/// Sealed pattern: switch'lar exhaustive bo'ladi (yangi tip qo'shilsa
/// compiler xato beradi).
sealed class ChatItem {
  const ChatItem();

  /// Saralash uchun universal vaqt.
  DateTime get createdAt;

  /// Universal ID (rebuild key).
  String get id;
}

/// Voice xabar (ovozli) ko'rinishidagi chat element.
class VoiceItem extends ChatItem {
  const VoiceItem(this.message);

  final VoiceMessage message;

  @override
  DateTime get createdAt =>
      message.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  @override
  String get id => 'v_${message.id ?? message.hashCode}';
}

/// Video xabar (yumaloq) ko'rinishidagi chat element.
class VideoItem extends ChatItem {
  const VideoItem(this.message);

  final VideoMessage message;

  @override
  DateTime get createdAt =>
      message.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  @override
  String get id => 'r_${message.id ?? message.hashCode}';
}

/// Voice + Video xabarlarni bitta sortlangan ro'yxatga birlashtiradi.
///
/// Ikkala manba ham `StreamProvider` — har biri yangilanganda combined
/// ro'yxat avtomatik qayta hisoblanadi (`whenData`). ASC sortlangan
/// (chronological — eski tepada, yangi pastda — voice ekrani kabi).
final chatMessagesProvider = Provider<AsyncValue<List<ChatItem>>>((ref) {
  final voiceAsync = ref.watch(voiceMessagesProvider);
  final videoAsync = ref.watch(videoMessagesProvider);

  // Ikkalasi ham loading bo'lsa shu state'ni propagate qilamiz.
  if (voiceAsync.isLoading && videoAsync.isLoading) {
    return const AsyncValue.loading();
  }
  // Xato — faqat boshqa manba ham ma'lumotsiz bo'lsa propagate qilamiz.
  // Bittasi xato, bittasi data → datani ko'rsatamiz (grace degradation).
  if (voiceAsync.hasError && videoAsync.valueOrNull == null) {
    return AsyncValue.error(
      voiceAsync.error!,
      voiceAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (videoAsync.hasError && voiceAsync.valueOrNull == null) {
    return AsyncValue.error(
      videoAsync.error!,
      videoAsync.stackTrace ?? StackTrace.current,
    );
  }

  final voices = voiceAsync.valueOrNull ?? const <VoiceMessage>[];
  final videos = videoAsync.valueOrNull ?? const <VideoMessage>[];

  final items = <ChatItem>[
    ...voices.map(VoiceItem.new),
    ...videos.map(VideoItem.new),
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  return AsyncValue.data(items);
});
