// Voice xabarlar provider'lari (backend REST + WS real-time); har bola
// ro'yxati child.linkedDeviceUid bo'yicha filtrlanadi.

import 'dart:async';

import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/video_message/data/models/video_message.dart';
import 'package:farzandim/features/video_message/data/repositories/backend_video_message_repository.dart';
import 'package:farzandim/features/video_message/presentation/providers/video_message_provider.dart';
import 'package:farzandim/features/voice_message/data/models/voice_message.dart';
import 'package:farzandim/features/voice_message/data/repositories/backend_voice_message_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Joriy auth user ID (Parent). Backend xabarlarini parse qilishda
/// va `sender` directionini aniqlashda ishlatiladi.
String? _currentUserId(Ref ref) {
  final auth = ref.watch(backendAuthProvider);
  return auth is AuthAuthenticated ? auth.user.id : null;
}

/// Joriy parent'ning barcha ovozli xabarlari — xom backend JSON.
///
/// Fetch ataylab bitta joyda: backend baribir parent'ning to'liq
/// ro'yxatini qaytaradi, avval esa har bola-instance endpointni o'zi
/// chaqirib N ta bir xil so'rov ketardi. Per-bola providerlar faqat
/// filtr qiladi, WS eventda ham bitta refetch bo'ladi.
///
/// Yuborish/retry'dan keyin yangilash: `ref.invalidate(rawVoiceMessagesProvider)`.
final rawVoiceMessagesProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) async* {
  final currentUserId = _currentUserId(ref);
  if (currentUserId == null) {
    yield const <Map<String, dynamic>>[];
    return;
  }

  final repo = ref.watch(backendVoiceMessageRepositoryProvider);

  yield await repo.getMessagesRaw();

  // WS `voice:received` — yangi xabar keldi, bitta refetch (barcha
  // bola-filtrlar shu natijadan oziqlanadi).
  final controller = StreamController<List<Map<String, dynamic>>>();
  final subscription = repo.voiceReceivedStream().listen((data) async {
    if (data is! Map) return;
    try {
      final refreshed = await repo.getMessagesRaw();
      if (!controller.isClosed) controller.add(refreshed);
    } catch (_) {
      // tarmoq blip — oxirgi ro'yxat saqlanadi, keyingi event qayta uradi
    }
  });
  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });
  yield* controller.stream;
});

/// Bola uchun barcha ovozli xabarlar — umumiy xom ro'yxatdan filtr.
///
/// Bola hali Child App'da pair qilmagan (`linkedDeviceUid == null`) →
/// bo'sh ro'yxat.
final voiceMessagesProvider =
    Provider.family<AsyncValue<List<VoiceMessage>>, String>((ref, childId) {
      final currentUserId = _currentUserId(ref);
      if (currentUserId == null) {
        return const AsyncValue.data(<VoiceMessage>[]);
      }

      // Butun ro'yxat emas, faqat shu bolaning linkedDeviceUid'ini watch
      // qilamiz (`select`) — children-polling har 60s yangi List identity
      // bersa ham pair/unpair bo'lmaguncha bu provider qayta hisoblanmaydi.
      final childUserId = ref.watch(
        childrenListProvider.select((children) {
          for (final c in children) {
            if (c.id == childId) return c.linkedDeviceUid;
          }
          return null;
        }),
      );
      if (childUserId == null) {
        return const AsyncValue.data(<VoiceMessage>[]);
      }

      List<VoiceMessage> parse(List<Map<String, dynamic>> raw) {
        final mine = raw.where(
          (m) => m['senderId'] == childUserId || m['receiverId'] == childUserId,
        );
        // Bitta buzuq xabar butun tarixni yiqitmasin.
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

      final rawAsync = ref.watch(rawVoiceMessagesProvider);
      // Refetch paytida AsyncLoading oldingi qiymatni ichida olib yuradi,
      // lekin `whenData` uni tashlab yuboradi — har xabar yuborilganda chat
      // bir lahza bo'shardi. hasValue bo'lsa mavjud ro'yxat ko'rinadi.
      if (rawAsync.hasValue) {
        return AsyncValue.data(parse(rawAsync.requireValue));
      }
      return rawAsync.whenData(parse);
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
final unreadVoiceMessagesProvider = Provider.family<AsyncValue<int>, String>((
  ref,
  childId,
) {
  return ref
      .watch(voiceMessagesProvider(childId))
      .whenData(
        (all) => all
            .where(
              (m) => m.sender == 'child' && m.status == VoiceMessageStatus.sent,
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

// ─────────────────────────────────────────────────────────────────────
// Chat tarixi paginatsiyasi — eski sahifalarni yuqoriga scroll'da yuklash.
// ─────────────────────────────────────────────────────────────────────

/// Yuklangan eski sahifalar holati. Jonli oyna (oxirgi ~100 xabar)
/// raw provider'larda turadi; bu yerda faqat undan eski xabarlar.
@immutable
class ChatHistoryState {
  const ChatHistoryState({
    this.older = const <ChatItem>[],
    this.loading = false,
    this.hasMoreVoice = true,
    this.hasMoreVideo = true,
  });

  /// Eski xabarlar (ASC saralangan).
  final List<ChatItem> older;

  /// Hozir sahifa yuklanyaptimi (UI spinner uchun).
  final bool loading;

  /// Voice tarixida yana eski sahifa bor (taxmin: to'liq sahifa qaytgan).
  final bool hasMoreVoice;

  /// Video tarixida yana eski sahifa bor.
  final bool hasMoreVideo;

  /// Umumiy "yana yuklasa bo'ladi" belgisi.
  bool get hasMore => hasMoreVoice || hasMoreVideo;

  ChatHistoryState copyWith({
    List<ChatItem>? older,
    bool? loading,
    bool? hasMoreVoice,
    bool? hasMoreVideo,
  }) => ChatHistoryState(
    older: older ?? this.older,
    loading: loading ?? this.loading,
    hasMoreVoice: hasMoreVoice ?? this.hasMoreVoice,
    hasMoreVideo: hasMoreVideo ?? this.hasMoreVideo,
  );
}

/// Chat tarixini sahifalab yuklaydi. Har manba (voice/video) o'z
/// cursor'i bilan: eng eski ma'lum xabar vaqtidan `before` so'raladi.
class ChatHistoryNotifier extends StateNotifier<ChatHistoryState> {
  ChatHistoryNotifier(this._ref, this.childId)
    : super(const ChatHistoryState());

  final Ref _ref;

  /// Qaysi bola chati.
  final String childId;

  static const int _pageSize = 30;

  /// Eng eski ma'lum voice xabar vaqti (older + jonli oynadan).
  DateTime? _oldestVoice() {
    for (final item in state.older) {
      if (item is VoiceItem) return item.createdAt;
    }
    final live =
        _ref.read(voiceMessagesProvider(childId)).valueOrNull ?? const [];
    return live.isEmpty ? null : live.first.createdAt;
  }

  DateTime? _oldestVideo() {
    for (final item in state.older) {
      if (item is VideoItem) return item.createdAt;
    }
    final live =
        _ref.read(videoMessagesProvider(childId)).valueOrNull ?? const [];
    return live.isEmpty ? null : live.first.createdAt;
  }

  /// Keyingi eski sahifani yuklaydi. Yuklash davom etayotgan yoki
  /// tarix tugagan bo'lsa hech narsa qilmaydi (scroll-listener tinch
  /// chaqiraveradi).
  Future<void> loadOlder() async {
    if (state.loading || !state.hasMore) return;
    final auth = _ref.read(backendAuthProvider);
    if (auth is! AuthAuthenticated) return;
    final currentUserId = auth.user.id;
    final childUserId = _ref
        .read(childrenListProvider)
        .firstWhereOrNull((c) => c.id == childId)
        ?.linkedDeviceUid;
    if (childUserId == null) return;

    state = state.copyWith(loading: true);
    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        if (state.hasMoreVoice)
          _ref
              .read(backendVoiceMessageRepositoryProvider)
              .getMessagesRaw(
                peerId: childUserId,
                before: _oldestVoice(),
                limit: _pageSize,
              )
        else
          Future.value(const []),
        if (state.hasMoreVideo)
          _ref
              .read(backendVideoMessageRepositoryProvider)
              .getMessages(
                peerId: childUserId,
                before: _oldestVideo(),
                limit: _pageSize,
              )
        else
          Future.value(const []),
      ]);
      if (!mounted) return;

      final voicePage = parseListSafely(
        // peerId server tomonda filtrlaydi; eski backend versiyasiga
        // qarshi himoya uchun klientda ham tekshiramiz.
        results[0].where(
          (m) => m['senderId'] == childUserId || m['receiverId'] == childUserId,
        ),
        (m) => VoiceMessage.fromBackendJson(
          m,
          currentUserId: currentUserId,
          childId: childId,
        ),
        tag: 'chatHistoryVoice',
      );
      final videoPage = parseListSafely(
        results[1].where(
          (m) => m['senderId'] == childUserId || m['receiverId'] == childUserId,
        ),
        (m) => VideoMessage.fromBackendJson(
          m,
          currentUserId: currentUserId,
          childId: childId,
        ),
        tag: 'chatHistoryVideo',
      );

      // Dublikatlarni tashlab (jonli oyna bilan kesishish bo'lishi
      // mumkin), yangi sahifani mavjud older bilan qo'shib ASC saralaymiz.
      final known = <String>{
        for (final item in state.older) item.id,
        for (final v
            in _ref.read(voiceMessagesProvider(childId)).valueOrNull ??
                const <VoiceMessage>[])
          'v_${v.id}',
        for (final v
            in _ref.read(videoMessagesProvider(childId)).valueOrNull ??
                const <VideoMessage>[])
          'r_${v.id}',
      };
      final fresh = <ChatItem>[
        ...voicePage.map(VoiceItem.new),
        ...videoPage.map(VideoItem.new),
      ].where((item) => !known.contains(item.id));

      final merged = <ChatItem>[...fresh, ...state.older]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      state = state.copyWith(
        older: merged,
        loading: false,
        hasMoreVoice: state.hasMoreVoice && results[0].length >= _pageSize,
        hasMoreVideo: state.hasMoreVideo && results[1].length >= _pageSize,
      );
    } catch (_) {
      // Tarmoq xatosi — cursor o'zgarmadi, keyingi urinish qaytadan oladi.
      if (mounted) state = state.copyWith(loading: false);
    }
  }
}

/// Chat tarixi provider — har bola uchun alohida. Ekrandan chiqilgach
/// 2 daqiqa kesh saqlanadi (tez qaytishda qayta yuklamaslik uchun).
final chatHistoryProvider = StateNotifierProvider.autoDispose
    .family<ChatHistoryNotifier, ChatHistoryState, String>((ref, childId) {
      keepAliveFor(ref, const Duration(minutes: 2));
      return ChatHistoryNotifier(ref, childId);
    });

/// Voice + Video xabarlarni bitta sortlangan ro'yxatga birlashtiradi.
///
/// Ikkala manba ham `StreamProvider` — har biri yangilanganda combined
/// ro'yxat avtomatik qayta hisoblanadi (`whenData`). ASC sortlangan
/// (chronological — eski tepada, yangi pastda — voice ekrani kabi).
/// Yuklangan eski sahifalar (`chatHistoryProvider`) lenta boshiga qo'shiladi.
final chatMessagesProvider =
    Provider.family<AsyncValue<List<ChatItem>>, String>((ref, childId) {
      final voiceAsync = ref.watch(voiceMessagesProvider(childId));
      final videoAsync = ref.watch(videoMessagesProvider(childId));
      final older = ref.watch(
        chatHistoryProvider(childId).select((s) => s.older),
      );

      // Ikkalasi ham loading/error bo'lsa shu state'ni propagate qilamiz.
      if (voiceAsync.isLoading && videoAsync.isLoading) {
        return const AsyncValue.loading();
      }
      // Xato faqat boshqa manba ham ma'lumotsiz bo'lsa propagate qilinadi;
      // bittasi xato, bittasi data bo'lsa — datani ko'rsataveramiz.
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

      // Eski sahifalar + jonli oyna; id bo'yicha dedup — jonli nusxa ustun
      // (read-status yangiroq bo'ladi).
      final byId = <String, ChatItem>{
        for (final item in older) item.id: item,
        for (final item in voices.map(VoiceItem.new)) item.id: item,
        for (final item in videos.map(VideoItem.new)) item.id: item,
      };
      final items = byId.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return AsyncValue.data(items);
    });

/// List ekrani uchun eng oxirgi chat elementi — VOICE YOKI VIDEO (preview +
/// saralash). Avval faqat voice hisobga olinardi → video xabar list'da "yangi
/// xabar" sifatida ko'rinmasdi, tepaga chiqmasdi.
final latestChatItemProvider = Provider.family<AsyncValue<ChatItem?>, String>((
  ref,
  childId,
) {
  return ref.watch(chatMessagesProvider(childId)).whenData((all) {
    if (all.isEmpty) return null;
    return all.last; // ASC — eng yangisi oxirida
  });
});

/// O'qilmagan (bola yuborgan, hali seen bo'lmagan) VOICE + VIDEO xabarlar
/// soni — qizil badge. Avval faqat voice sanalardi → video "yangi xabar"
/// belgisi umuman ko'rinmasdi.
final unreadChatCountProvider = Provider.family<AsyncValue<int>, String>((
  ref,
  childId,
) {
  return ref.watch(chatMessagesProvider(childId)).whenData((all) {
    var n = 0;
    for (final item in all) {
      switch (item) {
        case VoiceItem(:final message):
          if (message.sender == 'child' &&
              message.status == VoiceMessageStatus.sent) {
            n++;
          }
        case VideoItem(:final message):
          if (message.sender == 'child' &&
              message.status == VideoMessageStatus.sent) {
            n++;
          }
      }
    }
    return n;
  });
});

/// List ekrani uchun bolalarni saralangan ro'yxat sifatida qaytaradi:
/// yuqorida — eng yangi xabar (voice YOKI video) bo'lgan bolalar (yangidan
/// eskiga), pastda — hech qachon xabar yo'q bolalar.
final sortedChildrenForVoiceProvider = Provider<List<Child>>((ref) {
  final children = ref.watch(childrenListProvider);
  if (children.isEmpty) return const [];

  final pairs =
      children.map((child) {
        final latest = ref.watch(latestChatItemProvider(child.id)).valueOrNull;
        return (child: child, latest: latest);
      }).toList()..sort((a, b) {
        if (a.latest == null && b.latest == null) return 0;
        if (a.latest == null) return 1;
        if (b.latest == null) return -1;
        return b.latest!.createdAt.compareTo(a.latest!.createdAt);
      });

  return pairs.map((p) => p.child).toList();
});
