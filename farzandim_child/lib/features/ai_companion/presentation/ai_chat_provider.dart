// ─────────────────────────────────────────────────────────────────────
// ai_chat_provider — Faro suhbat holati (StateNotifier) (#65)
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/ai_companion/data/ai_companion_repository.dart';
import 'package:farzandim_child/features/ai_companion/data/ai_message.dart';

@immutable
class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.sending = false,
    this.loaded = false,
    this.error,
  });

  final List<AiMessage> messages;
  final bool sending;
  final bool loaded;
  final String? error;

  AiChatState copyWith({
    List<AiMessage>? messages,
    bool? sending,
    bool? loaded,
    String? error,
    bool clearError = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      loaded: loaded ?? this.loaded,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AiChatNotifier extends StateNotifier<AiChatState> {
  AiChatNotifier(this._repo) : super(const AiChatState()) {
    _load();
  }

  final AiCompanionRepository _repo;

  Future<void> _load() async {
    final history = await _repo.history();
    if (!mounted) return;
    state = state.copyWith(messages: history, loaded: true);
  }

  Future<void> reload() => _load();

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    // Optimistik: bola xabarini darhol ko'rsatamiz + "yozmoqda" holati.
    state = state.copyWith(
      messages: [...state.messages, AiMessage.localUser(trimmed)],
      sending: true,
      clearError: true,
    );

    try {
      final reply = await _repo.send(trimmed);
      if (!mounted) return;
      state = state.copyWith(
        messages: [...state.messages, reply],
        sending: false,
      );
    } on AiChatException catch (e) {
      if (!mounted) return;
      state = state.copyWith(sending: false, error: e.message);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        sending: false,
        error: 'Xatolik. Qayta urinib ko\'r.',
      );
    }
  }
}

final aiChatProvider =
    StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier(ref.watch(aiCompanionRepositoryProvider));
});
