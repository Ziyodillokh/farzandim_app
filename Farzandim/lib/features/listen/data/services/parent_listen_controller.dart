// ─────────────────────────────────────────────────────────────────────
// ParentListenController — jonli eshitishni QABUL qiluvchi (WebRTC answerer)
// ─────────────────────────────────────────────────────────────────────
//
// Ota-ona bola atrofidagi ovozni JONLI eshitadi. Bu kontroller:
//   1. sessiyani boshlaydi (REST) → backend bolani uyg'otadi;
//   2. WebRTC PeerConnection (FAQAT qabul — recvonly) o'rnatadi;
//   3. bola OFFER yuborganda ANSWER qaytaradi, ICE almashadi;
//   4. bola audiosini karnaydan ijro etadi.
//
// ⚠️ Ovoz hech qayerda SAQLANMAYDI — faqat jonli oqim. Sessiya tugaganda
// (ota-ona yoki bola to'xtatsa, yoki timeout) hammasi yopiladi.

import 'dart:async';

import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/features/listen/data/ice_config.dart';
import 'package:farzandim/features/listen/data/repositories/listen_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Eshitish bosqichi — UI shu holatga qarab ekran ko'rsatadi.
enum ListenPhase { connecting, listening, ended, error }

class ParentListenController {
  ParentListenController({
    required SocketClient socket,
    required ListenRepository repo,
  })  : _socket = socket,
        _repo = repo;

  final SocketClient _socket;
  final ListenRepository _repo;

  /// UI kuzatadigan holat.
  final ValueNotifier<ListenPhase> phase =
      ValueNotifier<ListenPhase>(ListenPhase.connecting);

  RTCPeerConnection? _pc;
  final List<StreamSubscription<dynamic>> _subs = [];
  final List<RTCIceCandidate> _pendingCandidates = [];
  String? _sessionId;
  bool _remoteSet = false;
  bool _closed = false;

  /// Eshitishni boshlaydi. `true` — sessiya yaratildi va ulanish boshlandi.
  Future<bool> start(String childId) async {
    final session = await _repo.start(childId);
    if (session == null) {
      phase.value = ListenPhase.error;
      return false;
    }
    _sessionId = session.id;
    try {
      await _setupPeer();
      _wireSignaling();
      return true;
    } catch (e) {
      debugPrint('ParentListen.start xato: $e');
      await _cleanup();
      phase.value = ListenPhase.error;
      return false;
    }
  }

  Future<void> _setupPeer() async {
    final pc = await createPeerConnection(buildIceConfig());
    _pc = pc;

    // FAQAT qabul: bola audio yuboradi, biz olamiz (mikrofon ochmaymiz).
    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    pc
      ..onIceCandidate = (RTCIceCandidate c) {
        if (c.candidate == null || _sessionId == null) return;
        _socket.emitListenSignal(_sessionId!, {
          'type': 'candidate',
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        });
      }
      ..onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'audio') {
          // Ovoz karnaydan chiqsin (quloqqa emas).
          try {
            unawaited(Helper.setSpeakerphoneOn(true));
          } catch (_) {}
          if (!_closed) phase.value = ListenPhase.listening;
        }
      }
      ..onConnectionState = (RTCPeerConnectionState s) {
        if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          unawaited(_finish(ListenPhase.error));
        }
      };
  }

  void _wireSignaling() {
    _subs
      ..add(_socket.eventStream('listen:signal').listen(_onSignal))
      // Bola yoki backend (timeout) sessiyani tugatsa — darhol yopamiz.
      ..add(
        _socket.eventStream('listen:ended').listen((dynamic data) {
          if (data is Map && data['id'] == _sessionId) {
            unawaited(_finish(ListenPhase.ended));
          }
        }),
      );
  }

  Future<void> _onSignal(dynamic data) async {
    if (data is! Map || data['sessionId'] != _sessionId) return;
    final signal = data['signal'];
    if (signal is! Map) return;
    final pc = _pc;
    if (pc == null) return;

    try {
      if (signal['type'] == 'offer') {
        await pc.setRemoteDescription(
          RTCSessionDescription(signal['sdp'] as String?, 'offer'),
        );
        _remoteSet = true;
        for (final c in _pendingCandidates) {
          await pc.addCandidate(c);
        }
        _pendingCandidates.clear();

        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        _socket.emitListenSignal(_sessionId!, {
          'type': 'answer',
          'sdp': answer.sdp,
        });
      } else if (signal['type'] == 'candidate') {
        final cand = RTCIceCandidate(
          signal['candidate'] as String?,
          signal['sdpMid'] as String?,
          signal['sdpMLineIndex'] as int?,
        );
        if (_remoteSet) {
          await pc.addCandidate(cand);
        } else {
          _pendingCandidates.add(cand);
        }
      }
    } catch (e) {
      debugPrint('ParentListen._onSignal xato: $e');
    }
  }

  /// Ota-ona "To'xtatish" bosdi.
  Future<void> stop() async {
    final id = _sessionId;
    await _cleanup();
    if (!_closed) phase.value = ListenPhase.ended;
    if (id != null) await _repo.end(id);
  }

  Future<void> _finish(ListenPhase p) async {
    await _cleanup();
    if (phase.value != ListenPhase.ended && phase.value != ListenPhase.error) {
      phase.value = p;
    }
  }

  Future<void> _cleanup() async {
    _closed = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _pendingCandidates.clear();
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}
  }

  void dispose() {
    unawaited(_cleanup());
    phase.dispose();
  }
}
