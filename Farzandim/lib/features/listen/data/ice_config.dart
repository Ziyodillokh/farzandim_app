// ─────────────────────────────────────────────────────────────────────
// ICE konfiguratsiyasi — WebRTC P2P ulanishi uchun
// ─────────────────────────────────────────────────────────────────────
//
// STUN har doim bor (bepul, Google). TURN — coturn serveri (3-qism infra)
// o'rnatilgach `--dart-define` orqali beriladi. TURN bo'lmasa mobil
// operator NAT'lari ortida ovoz ba'zi tarmoqlarda kelmasligi mumkin.

const String _turnUrl = String.fromEnvironment('TURN_URL');
const String _turnUsername = String.fromEnvironment('TURN_USERNAME');
const String _turnCredential = String.fromEnvironment('TURN_CREDENTIAL');

/// RTCPeerConnection uchun konfiguratsiya.
Map<String, dynamic> buildIceConfig() {
  final servers = <Map<String, dynamic>>[
    {
      'urls': [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
      ],
    },
  ];
  if (_turnUrl.isNotEmpty) {
    servers.add({
      'urls': _turnUrl,
      'username': _turnUsername,
      'credential': _turnCredential,
    });
  }
  return {
    'iceServers': servers,
    'sdpSemantics': 'unified-plan',
  };
}
