// ─────────────────────────────────────────────────────────────────────
// photo_request_provider — Child App Backend (Sprint 4.4.9.4)
// ─────────────────────────────────────────────────────────────────────
//
// Eski Firestore stream + Storage upload → Backend REST.
// WS `photo_request:received` (Child App'da Socket yo'q hozir, polling
// 10 sek bilan kompensatsiya yoki keyinroq adapt).

import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/photo/data/models/photo_request.dart';
import 'package:farzandim_child/features/photo/data/repositories/backend_photo_request_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Pending photo requests — Backend fetch (polling 10s, Socket adapt
/// keyinroq).
final pendingPhotoRequestsProvider = StreamProvider<List<PhotoRequest>>((
  ref,
) async* {
  final pairing = ref.watch(pairingStateProvider);
  if (!pairing.isPaired || pairing.childId == null) {
    yield const [];
    return;
  }

  final repo = ref.watch(backendPhotoRequestRepositoryProvider);
  final controller = StreamController<List<PhotoRequest>>();

  Future<void> fetch() async {
    if (controller.isClosed) return;
    final raw = await repo.getPendingRequests(childId: pairing.childId!);
    final list = raw.map(PhotoRequest.fromBackendJson).toList(growable: false);
    if (!controller.isClosed) controller.add(list);
  }

  await fetch(); // initial
  // Polling 10s — Child App'da Socket.io yo'q hozir.
  final timer = Timer.periodic(const Duration(seconds: 10), (_) => fetch());

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  yield* controller.stream;
});

enum CaptureStatus { idle, capturing, uploading, done, error }

class CaptureState {
  const CaptureState({this.status = CaptureStatus.idle, this.errorMessage});

  final CaptureStatus status;
  final String? errorMessage;
}

final photoCaptureProvider =
    StateNotifierProvider<PhotoCaptureNotifier, CaptureState>(
      PhotoCaptureNotifier.new,
    );

class PhotoCaptureNotifier extends StateNotifier<CaptureState> {
  PhotoCaptureNotifier(this._ref) : super(const CaptureState());

  final Ref _ref;

  final ImagePicker _picker = ImagePicker();

  /// Kamera ochilib rasm olinadi, Backend'ga yuklanadi.
  ///
  /// `request` — Backend'dan kelgan pending photo request.
  /// State: idle → capturing → uploading → done (yoki idle agar cancel).
  Future<void> capture(PhotoRequest request) async {
    state = const CaptureState(status: CaptureStatus.capturing);
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (photo == null) {
        // Foydalanuvchi kamera dialogini yopdi.
        state = const CaptureState();
        return;
      }

      state = const CaptureState(status: CaptureStatus.uploading);
      final ok = await _ref
          .read(backendPhotoRequestRepositoryProvider)
          .uploadPhoto(requestId: request.id, photoFile: File(photo.path));
      if (!ok) {
        state = CaptureState(
          status: CaptureStatus.error,
          errorMessage: 'photo.uploadFailed'.tr(),
        );
        return;
      }

      // List refresh — pending'dan chiqib ketadi.
      _ref.invalidate(pendingPhotoRequestsProvider);
      state = const CaptureState(status: CaptureStatus.done);
    } catch (e) {
      state = CaptureState(
        status: CaptureStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Bola rad etadi — Backend `/decline`.
  Future<void> decline(String requestId) async {
    try {
      await _ref
          .read(backendPhotoRequestRepositoryProvider)
          .declineRequest(requestId);
      _ref.invalidate(pendingPhotoRequestsProvider);
    } catch (e) {
      state = CaptureState(
        status: CaptureStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = const CaptureState();
  }
}
