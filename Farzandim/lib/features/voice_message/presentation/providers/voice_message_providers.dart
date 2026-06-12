// ─────────────────────────────────────────────────────────────────────
// voice_message_providers — Backend voice (Sprint 4.4.5)
// ─────────────────────────────────────────────────────────────────────
//
// Eski: Firestore stream + Firebase Auth (currentUser)
// Yangi: Backend REST + WS `voice:received` real-time.
//
// Parent App tomondan filter: child.linkedDeviceUid (paired Child User ID)
// bilan match qiladigan xabarlar (sender yoki receiver) — har bola uchun
// alohida ro'yxat.

import 'dart:async';

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/video_message/data/models/video_message.dart';
import 'package:farzandim/features/video_message/presentation/providers/video_message_provider.dart';
import 'package:farzandim/features/voice_message/data/models/voice_message.dart';
import 'package:farzandim/features/voice_message/data/repositories/backend_voice_message_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Joriy auth user ID (Parent). Backend xabarlarini parse qilishda
/// va `sender` directionini aniqlashda ishlatiladi.
String? _currentUserId(Ref ref) {
  final auth = ref.watch(backendAuthProvider);
  return auth is AuthAuthenticated ? auth.user.id : null;
}

/// Bola uchun barcha ovozli xabarlar — Backend + child filter.
///
/// Backend `/api/voice-messages` joriy user (parent)'ga aloqador barcha
/// xabarlarni qaytaradi. Bu yerda `child.linkedDeviceUid` bilan filter
/// qilamiz — faqat shu bola bilan suhbat.
///
/// Bola hali Child App'da pair qilmagan (`linkedDeviceUid == null`) →
/// bo'sh ro'yxat.
///
/// Real-time refresh: WS `voice:received` event'ida invalidate.
final voiceMessagesProvider =
    StreamProvider.family<List<VoiceMessage>, String>((ref, childId) async* {
  final currentUserId = _currentUserId(ref);
  if (currentUserId == null) {
    yield const <VoiceMessage>[];
    return;
  }

  // MUHIM (P0-4): butun ro'yxatni emas, FAQAT shu bolaning linkedDeviceUid'ini
  // watch qilamiz (`select`). Avval childrenListProvider'ning har yangilanishi
  // (60s polling) yangi List identity berib bu provider'ni QAYTA ISHGA
  // tushirardi → butun xabar tarixi har 60s qayta yuklanardi. select bilan
  // provider faqat linkedDeviceUid HAQIQATAN o'zgarganda (pair/unpair)
  // recompute bo'ladi; yangi xabarlar esa quyidagi WS orqali keladi.
  final childUserId = ref.watch(childrenListProvider.select((children) {
    for (final c in children) {
      if (c.id == childId) return c.linkedDeviceUid;
    }
    return null;
  }));
  if (childUserId == null) {
    // Bola hali Child App'da pair qilmagan — suhbat yo'q.
    yield const <VoiceMessage>[];
    return;
  }

  final repo = ref.watch(backendVoiceMessageRepositoryProvider);

  Future<List<VoiceMessage>> fetch() async {
    final raw = await repo.getMessagesRaw();
    final mine = raw.where(
      (m) =>
          m['senderId'] == childUserId || m['receiverId'] == childUserId,
    );
    // ARCH-12: bitta buzuq xabar butun tarixni yiqitmasin.
    final parsed = parseListSafely(
      mine,
      (m) => VoiceMessage.fromBackendJson(
        m,
        currentUserId: currentUserId,
        childId: childId,
      ),
      tag: 'voiceMessages',
    );
    // Backend DESC keladi — chat ekrani uchun ASC (chronological).
    return parsed.reversed.toList();
  }

  yield await fetch();

  // WS `voice:received` — yangi xabar keldi, refetch.
  final controller = StreamController<List<VoiceMessage>>();
  final subscription = repo.voiceReceivedStream().listen((data) async {
    if (data is! Map) return;
    final senderId = data['senderId'] as String?;
    final receiverId = data['receiverId'] as String?;
    // Faqat shu bola bilan bog'liq xabar bo'lsa refetch.
    if (senderId == childUserId || receiverId == childUserId) {
      final refreshed = await fetch();
      if (!controller.isClosed) controller.add(refreshed);
    }
  });
  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });
  yield* controller.stream;
});

/// Eng oxirgi ovozli xabar — list ekrani preview.
final latestVoiceMessageProvider =
    Provider.family<AsyncValue<VoiceMessage?>, String>((ref, childId) {
  return ref.watch(voiceMessagesProvider(childId)).whenData((all) {
    if (all.isEmpty) return null;
    // ASC saralangan — eng yangisi oxirida.
    return all.last;
  });
});

/// O'qilmagan (bola yuborgan, hali sent) xabarlar soni — qizil badge.
final unreadVoiceMessagesProvider =
    Provider.family<AsyncValue<int>, String>((ref, childId) {
  return ref.watch(voiceMessagesProvider(childId)).whenData(
    (all) => all
        .where(
          (m) =>
              m.sender == 'child' && m.status == VoiceMessageStatus.sent,
        )
        .length,
  );
});

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
  DateTime get createdAt => message.createdAt;

  @override
  String get id => 'v_${message.id}';
}

/// Video xabar (yumaloq) ko'rinishidagi chat element.
class VideoItem extends ChatItem {
  const VideoItem(this.message);

  final VideoMessage message;

  @override
  DateTime get createdAt => message.createdAt;

  @override
  String get id => 'r_${message.id}';
}

/// Voice + Video xabarlarni bitta sortlangan ro'yxatga birlashtiradi.
///
/// Ikkala manba ham `StreamProvider` — har biri yangilanganda combined
/// ro'yxat avtomatik qayta hisoblanadi (`whenData`). ASC sortlangan
/// (chronological — eski tepada, yangi pastda — voice ekrani kabi).
final chatMessagesProvider =
    Provider.family<AsyncValue<List<ChatItem>>, String>((ref, childId) {
  final voiceAsync = ref.watch(voiceMessagesProvider(childId));
  final videoAsync = ref.watch(videoMessagesProvider(childId));

  // Ikkalasi ham loading/error bo'lsa shu state'ni propagate qilamiz.
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

/// List ekrani uchun bolalarni saralangan ro'yxat sifatida qaytaradi:
/// yuqorida — eng yangi xabar bo'lgan bolalar (yangidan eskiga),
/// pastda — hech qachon ovozli xabar yo'q bolalar.
final sortedChildrenForVoiceProvider = Provider<List<Child>>((ref) {
  final children = ref.watch(childrenListProvider);
  if (children.isEmpty) return const [];

  final pairs = children.map((child) {
    final latest =
        ref.watch(latestVoiceMessageProvider(child.id)).valueOrNull;
    return (child: child, latest: latest);
  }).toList()
    ..sort((a, b) {
      if (a.latest == null && b.latest == null) return 0;
      if (a.latest == null) return 1;
      if (b.latest == null) return -1;
      return b.latest!.createdAt.compareTo(a.latest!.createdAt);
    });

  return pairs.map((p) => p.child).toList();
});
