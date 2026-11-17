// Yuborilmagan shaxsiy murojaatlar navbati (H05 → H07 «Xabaring hali
// yuborilmadi»). Internet bo'lmasa murojaat qurilmada qoladi va «Qayta
// urinish» bilan o'sha `clientRequestId` bilan yuboriladi — server takrorni
// yangi murojaat qilmaydi.
//
// Matn maxfiy: SharedPreferences emas, Keychain / KeyStore (secure storage);
// kalit bola hisobiga bog'langan, yuborilgach darhol o'chadi.

import 'dart:convert';

import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_models.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Navbatdagi murojaatlar chegarasi (eski yozuvlar tashlanadi).
const kVoiceOutboxMax = 5;

/// [childId] akkauntining navbat kaliti (secure storage).
String voiceOutboxKey(String childId) => 'g5_voice_outbox_v1_$childId';

@immutable
class PendingVoiceRequest {
  const PendingVoiceRequest({
    required this.id,
    required this.message,
    required this.urgent,
    required this.createdAt,
  });

  static PendingVoiceRequest? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final message = json['message'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    if (id is! String || message is! String || createdAt == null) return null;
    return PendingVoiceRequest(
      id: id,
      message: message,
      urgent: json['urgent'] == true,
      createdAt: createdAt,
    );
  }

  /// `clientRequestId` — serverda takrorni aniqlash uchun.
  final String id;
  final String message;
  final bool urgent;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'id': id,
    'message': message,
    'urgent': urgent,
    'createdAt': createdAt.toIso8601String(),
  };
}

abstract interface class VoiceOutboxStore {
  Future<String?> read(String key);

  /// `null` — kalit o'chiriladi.
  Future<void> write(String key, String? value);
}

class SecureVoiceOutboxStore implements VoiceOutboxStore {
  const SecureVoiceOutboxStore();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);
}

final voiceOutboxStoreProvider = Provider<VoiceOutboxStore>(
  (_) => const SecureVoiceOutboxStore(),
);

final voiceOutboxProvider =
    AsyncNotifierProvider<VoiceOutbox, List<PendingVoiceRequest>>(
      VoiceOutbox.new,
    );

class VoiceOutbox extends AsyncNotifier<List<PendingVoiceRequest>> {
  String? _key;

  @override
  Future<List<PendingVoiceRequest>> build() async {
    final account = ref.watch(schoolAccountProvider);
    _key = account == null ? null : voiceOutboxKey(account);
    final key = _key;
    if (key == null) return const [];
    try {
      final raw = await ref.read(voiceOutboxStoreProvider).read(key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return List.unmodifiable(
        decoded.map(PendingVoiceRequest.tryFromJson).nonNulls,
      );
    } on Object catch (e) {
      debugPrint('[voice] navbat o\'qilmadi: ${e.runtimeType}');
      return const [];
    }
  }

  PendingVoiceRequest? find(String id) =>
      state.valueOrNull?.where((p) => p.id == id).firstOrNull;

  /// Murojaatni navbatga qo'yadi (yuborishdan oldin) — ilova yopilsa ham
  /// yo'qolmaydi.
  Future<PendingVoiceRequest> enqueue({
    required String id,
    required String message,
    required bool urgent,
  }) async {
    final pending = PendingVoiceRequest(
      id: id,
      message: message,
      urgent: urgent,
      createdAt: ref.read(learningClockProvider)(),
    );
    final current = await future;
    await _save(
      [
        ...current.where((p) => p.id != id),
        pending,
      ].reversed.take(kVoiceOutboxMax).toList().reversed.toList(),
    );
    return pending;
  }

  /// Navbatdagi murojaatni yuboradi. Muvaffaqiyatda navbatdan o'chadi.
  /// Tarmoq / server xatosida navbatda qoladi va xato qaytadi; server
  /// murojaatni qabul qilmasa (400) — navbatdan o'chadi.
  Future<VoiceRequest> send(String id) async {
    final pending = (await future).where((p) => p.id == id).firstOrNull;
    if (pending == null) {
      throw const SchoolException(SchoolErrorCode.unknown, 'outbox');
    }
    try {
      final request = await ref
          .read(voiceRepositoryProvider)
          .createRequest(
            message: pending.message,
            urgent: pending.urgent,
            clientRequestId: pending.id,
          );
      await discard(id);
      ref.invalidate(voiceRequestsProvider);
      return request;
    } on SchoolException catch (e) {
      if (e.code == SchoolErrorCode.validation) await discard(id);
      rethrow;
    }
  }

  Future<void> discard(String id) async {
    final current = await future;
    await _save(current.where((p) => p.id != id).toList());
  }

  Future<void> _save(List<PendingVoiceRequest> items) async {
    final next = List<PendingVoiceRequest>.unmodifiable(items);
    state = AsyncData(next);
    final key = _key;
    if (key == null) return;
    try {
      await ref
          .read(voiceOutboxStoreProvider)
          .write(
            key,
            next.isEmpty
                ? null
                : jsonEncode([for (final p in next) p.toJson()]),
          );
    } on Object catch (e) {
      debugPrint('[voice] navbat saqlanmadi: ${e.runtimeType}');
    }
  }
}
