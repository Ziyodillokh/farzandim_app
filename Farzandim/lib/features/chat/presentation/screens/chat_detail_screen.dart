// ─────────────────────────────────────────────────────────────────────
// ChatDetailScreen — chat detali (Parvoz dizayn, REAL backend)
// ─────────────────────────────────────────────────────────────────────
//
// Chat = ota-ona ↔ bola. Real: chatMessagesProvider (matn/ovoz/video),
// sendText (matn), voiceUploadProvider (ovoz), videoUploadProvider (video),
// AudioPlayerManager (ovoz eshitish), videoStreamUrl (video eshitish).
//
// ⚠️ Web: matn + ko'rish + eshitish ishlaydi. Ovoz/video YUBORISH `File`
// talab qiladi → faqat telefonda (web'da "faqat telefonda" toast).

import 'dart:async';

import 'package:dio/dio.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/chat/data/video/video_send.dart';
import 'package:farzandim/features/chat/presentation/screens/round_video_player.dart';
import 'package:farzandim/features/chat/presentation/screens/round_video_record_sheet.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/video_message/data/models/video_message.dart';
import 'package:farzandim/features/video_message/data/repositories/backend_video_message_repository.dart';
import 'package:farzandim/features/video_message/presentation/providers/video_message_provider.dart';
import 'package:farzandim/features/voice_message/data/models/voice_message.dart';
import 'package:farzandim/features/voice_message/data/repositories/backend_voice_message_repository.dart';
import 'package:farzandim/features/voice_message/data/services/audio_player_manager.dart';
import 'package:farzandim/features/voice_message/presentation/providers/voice_message_providers.dart';
import 'package:farzandim/features/voice_message/presentation/providers/voice_upload_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:video_player/video_player.dart';

// ════════════ Parvoz tokenlar ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _chipBg = Color(0xFF1B2128);
const _recvBubble = Color(0xFF1C232B);
const _fieldBorder = Color(0x1FFFFFFF);
const _dim = Color(0x8CFFFFFF);
const _rec = Color(0xFFFF4D4F);

const _waveHeights = <double>[
  0.3,
  0.6,
  0.9,
  0.5,
  0.75,
  1,
  0.45,
  0.65,
  0.35,
  0.85,
  0.5,
  0.7,
  0.4,
  0.95,
  0.55,
  0.8,
  0.35,
  0.6,
  0.9,
  0.45,
  0.7,
  0.5,
  0.8,
  0.4,
];

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
}) => GoogleFonts.unbounded(fontSize: s, fontWeight: w, color: c, height: 1.2);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.35);

String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

/// Chat detali ekrani (real).
class ChatDetailScreen extends ConsumerStatefulWidget {
  /// `ChatDetailScreen` konstruktor.
  const ChatDetailScreen({required this.contactId, super.key});

  /// Bola id'si (route parametri).
  final String contactId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _scroll = ScrollController();
  String? _playingId;
  StreamSubscription<String?>? _playSub;

  @override
  void initState() {
    super.initState();
    _playSub = AudioPlayerManager.instance.currentIdStream.listen((id) {
      if (mounted) setState(() => _playingId = id);
    });
    // Chat ochilganda boladan kelgan o'qilmagan xabarlarni "o'qildi" deb
    // belgilaymiz — bola tomonida ✓✓ (ko'rildi) chiqadi.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final receiver = _child?.linkedDeviceUid;
      if (receiver == null || receiver.isEmpty) return;
      final ok = await ref
          .read(backendVoiceMessageRepositoryProvider)
          .markAllRead(fromUserId: receiver);
      if (ok) ref.invalidate(rawVoiceMessagesProvider);
    });
  }

  @override
  void dispose() {
    _playSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        // reverse:true ro'yxatda "past" = offset 0 (Telegram kabi).
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Child? get _child => ref.read(childByIdProvider(widget.contactId));

  Future<void> _sendText(String text) async {
    final receiver = _child?.linkedDeviceUid;
    if (receiver == null || receiver.isEmpty) {
      AppToast.error(context, 'chat.notPaired'.tr());
      return;
    }
    try {
      await ref
          .read(backendVoiceMessageRepositoryProvider)
          .sendText(receiverId: receiver, text: text);
      ref.invalidate(rawVoiceMessagesProvider);
      _scrollToBottom();
    } catch (_) {
      if (mounted) AppToast.error(context, 'chat.sendError'.tr());
    }
  }

  Future<void> _sendVoice(String path, int secs) async {
    final child = _child;
    String? id;
    if (kIsWeb) {
      // Web: recorder blob URL qaytaradi — baytlarni olib yuboramiz.
      try {
        final res = await Dio().get<List<int>>(
          path,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = Uint8List.fromList(res.data ?? const []);
        if (bytes.isEmpty) {
          throw Exception('blob boʻsh');
        }
        id = await ref
            .read(voiceUploadProvider.notifier)
            .sendBytes(
              childId: widget.contactId,
              bytes: bytes,
              filename: 'voice.webm',
              durationSeconds: secs,
            );
      } catch (_) {
        id = null;
      }
    } else {
      id = await ref
          .read(voiceUploadProvider.notifier)
          .send(
            childId: widget.contactId,
            childName: child?.name ?? '',
            localFilePath: path,
            durationSeconds: secs,
            waveform: const [],
          );
    }
    if (!mounted) return;
    if (id != null) {
      ref.invalidate(rawVoiceMessagesProvider);
      _scrollToBottom();
    } else {
      AppToast.error(context, 'chat.sendError'.tr());
    }
  }

  Future<void> _sendVideo() async {
    final res = await showRoundVideoRecord(context);
    if (res == null || !mounted) return;
    if (kIsWeb) {
      AppToast.info(context, 'chat.videoDeviceOnly'.tr());
      return;
    }
    final ok = await sendRecordedVideo(
      ref,
      childId: widget.contactId,
      path: res.url,
      seconds: res.seconds,
    );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(rawVideoMessagesProvider);
      _scrollToBottom();
    } else {
      AppToast.error(context, 'chat.sendError'.tr());
    }
  }

  Future<void> _togglePlayVoice(VoiceMessage m) async {
    final url = ref
        .read(backendVoiceMessageRepositoryProvider)
        .audioStreamUrl(m.id);
    await AudioPlayerManager.instance.playOrToggle(
      messageId: m.id,
      audioUrl: url,
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(childByIdProvider(widget.contactId));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.contactId));

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(child: child),
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _blue),
                ),
                error: (_, __) => Center(
                  child: Text(
                    'errors.loadFailed'.tr(),
                    style: _pop(14, c: _dim),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'chat.startConversation'.tr(),
                        style: _pop(14, c: _dim),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scroll,
                    // Telegram kabi: pastdan boshlanadi, yangisi pastda.
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[items.length - 1 - i];
                      return switch (item) {
                        VoiceItem(:final message) => _voiceItem(message),
                        VideoItem(:final message) => _RoundVideoMessage(
                          msg: message,
                          // Proxy stream URL (@Public, auth header'siz) —
                          // imzolangan `getFileUrl` signed URL telefondan yetib
                          // bo'lmaydi (repo izohiga qarang), shuning uchun
                          // RoundVideoBubble kabi proxy'dan o'ynatamiz.
                          getUrl: () async => ref
                              .read(backendVideoMessageRepositoryProvider)
                              .videoStreamUrl(message.id),
                          onTap: (url) => showRoundVideoPlayer(context, url),
                        ),
                      };
                    },
                  );
                },
              ),
            ),
            _InputBar(
              onSendText: _sendText,
              onSendVoice: _sendVoice,
              onCamera: _sendVideo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceItem(VoiceMessage m) {
    if (m.isText) return _TextBubble(msg: m);
    if (m.isImage || m.isFile) {
      return _TextBubble(
        msg: m,
        overrideText: m.isImage
            ? 'chat.previewImage'.tr()
            : 'chat.previewFile'.tr(),
      );
    }
    return _VoiceBubble(
      msg: m,
      playing: _playingId == m.id,
      onTap: () => _togglePlayVoice(m),
    );
  }
}

// ════════════ Header ════════════

class _Header extends StatelessWidget {
  const _Header({required this.child});

  final Child? child;

  @override
  Widget build(BuildContext context) {
    final online = child?.isLiveOnline ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          _RoundIconButton(
            icon: SolarIconsOutline.arrowLeft,
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.chatList);
              }
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Text(child?.name ?? 'Chat', style: _unb(18)),
                const SizedBox(height: 2),
                Text(
                  online ? 'chat.online'.tr() : 'chat.lastSeen'.tr(),
                  style: _pop(
                    13,
                    w: FontWeight.w500,
                    c: online ? const Color(0xFF34C759) : _dim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (child != null)
            ChildAvatar(child: child!, size: 44, showBorder: false),
        ],
      ),
    );
  }
}

// ════════════ Matn pufakchasi ════════════

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.msg, this.overrideText});

  final VoiceMessage msg;
  final String? overrideText;

  @override
  Widget build(BuildContext context) {
    final mine = msg.sender == 'parent';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
        decoration: BoxDecoration(
          color: mine ? _blue : _recvBubble,
          borderRadius: _radius(mine),
        ),
        // Telegram kabi: vaqt + ✓ matn bilan bir qatorda (sig'masa pastda).
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          children: [
            Text(overrideText ?? msg.text ?? '', style: _pop(15)),
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: _MetaRow(msg: msg, onLight: mine),
            ),
          ],
        ),
      ),
    );
  }
}

BorderRadius _radius(bool mine) => BorderRadius.only(
  topLeft: const Radius.circular(18),
  topRight: const Radius.circular(18),
  bottomLeft: Radius.circular(mine ? 18 : 4),
  bottomRight: Radius.circular(mine ? 4 : 18),
);

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.msg, this.onLight = false});

  final VoiceMessage msg;
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final mine = msg.sender == 'parent';
    final sub = onLight ? Colors.white70 : _dim;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(_time(msg.createdAt), style: _pop(11, c: sub)),
        if (mine) ...[
          const SizedBox(width: 4),
          Icon(
            msg.isSeen ? Icons.done_all_rounded : Icons.done_rounded,
            size: 15,
            color: onLight ? Colors.white : _blue,
          ),
        ],
      ],
    );
  }
}

// ════════════ Ovozli xabar ════════════

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({
    required this.msg,
    required this.playing,
    required this.onTap,
  });

  final VoiceMessage msg;
  final bool playing;
  final VoidCallback onTap;

  String get _dur {
    final m = msg.durationSeconds ~/ 60;
    final s = (msg.durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final mine = msg.sender == 'parent';
    final barColor = mine ? Colors.white : _blue;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: mine ? _blue : _recvBubble,
          borderRadius: _radius(mine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: mine
                          ? Colors.white.withValues(alpha: 0.22)
                          : _blue.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 22,
                      color: mine ? Colors.white : _blue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _Waveform(color: barColor),
                const SizedBox(width: 10),
                Text(_dur, style: _pop(12, c: mine ? Colors.white70 : _dim)),
              ],
            ),
            const SizedBox(height: 4),
            _MetaRow(msg: msg, onLight: mine),
          ],
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final h in _waveHeights)
            Container(
              width: 2.5,
              height: 6 + h * 18,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════ Dumaloq video ════════════

class _RoundVideoMessage extends StatefulWidget {
  const _RoundVideoMessage({
    required this.msg,
    required this.getUrl,
    required this.onTap,
  });

  final VideoMessage msg;

  /// Imzolangan (signed) video URL'ini oladi — 1 soat amal qiladi.
  final Future<String?> Function() getUrl;
  final void Function(String url) onTap;

  @override
  State<_RoundVideoMessage> createState() => _RoundVideoMessageState();
}

/// Bola ilovasidagi kabi: yumaloq video ichida REAL birinchi kadr
/// (VideoPlayerController paused holatida) + play tugma + davomiylik.
class _RoundVideoMessageState extends State<_RoundVideoMessage> {
  static const double _d = 190;

  VideoPlayerController? _thumb;
  String? _signedUrl;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadThumb());
  }

  Future<void> _loadThumb() async {
    VideoPlayerController? c;
    try {
      final url = await widget.getUrl();
      if (url == null || url.isEmpty) {
        throw Exception("stream url yo'q");
      }
      _signedUrl = url;
      c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      await c.seekTo(Duration.zero);
      await c.setVolume(0);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _thumb = c;
        _loading = false;
      });
    } catch (_) {
      // c yaratilib initialize/seekTo/setVolume tashlagan bo'lsa — native
      // pleer leak bo'lmasin uchun dispose qilamiz (avval faqat _failed=true
      // edi, controller esa hech qachon ozod qilinmasdi).
      await c?.dispose();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _thumb?.dispose();
    super.dispose();
  }

  String get _dur {
    final secs = widget.msg.durationSeconds;
    final m = secs ~/ 60;
    final sec = (secs % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final mine = msg.sender == 'parent';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () async {
                var url = _signedUrl;
                url ??= await widget.getUrl();
                if (url != null && url.isNotEmpty) widget.onTap(url);
              },
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: _d,
                height: _d,
                child: ClipOval(
                  child: ColoredBox(
                    color: _recvBubble,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // REAL birinchi kadr yoki holat belgisi.
                        if (_thumb != null && _thumb!.value.isInitialized)
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _thumb!.value.size.width,
                              height: _thumb!.value.size.height,
                              child: VideoPlayer(_thumb!),
                            ),
                          )
                        else if (_loading)
                          const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: _blue,
                              ),
                            ),
                          )
                        else
                          const Center(
                            child: Icon(
                              Icons.videocam_off_rounded,
                              color: _dim,
                              size: 36,
                            ),
                          ),
                        // Pastki kontrast gradienti.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.35),
                              ],
                            ),
                          ),
                        ),
                        // Markazdagi play tugma.
                        if (!_loading && !_failed)
                          Center(
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                size: 34,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        // Davomiylik belgisi (pastda markazda).
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _dur,
                                style: _pop(11, w: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_time(msg.createdAt), style: _pop(11, c: _dim)),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.status == VideoMessageStatus.seen
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 15,
                      color: _blue,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Kirish paneli ════════════

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.onSendText,
    required this.onSendVoice,
    required this.onCamera,
  });

  final ValueChanged<String> onSendText;
  final void Function(String path, int secs) onSendVoice;
  final VoidCallback onCamera;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _recorder = AudioRecorder();
  final _textCtrl = TextEditingController();
  bool _recording = false;
  bool _starting = false;
  int _elapsed = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _sendText() {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    widget.onSendText(t);
    _textCtrl.clear();
    setState(() {});
  }

  Future<void> _startVoice() async {
    if (_starting || _recording) return;
    setState(() => _starting = true);
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) AppToast.error(context, 'chat.micDenied'.tr());
        return;
      }
      var path = '';
      if (!kIsWeb) {
        // record paketi native'da ABSOLYUT, yozib bo'ladigan yo'l talab qiladi.
        // Avval nisbiy 'voice_x.m4a' berilib, u qurilmada yozib bo'lmaydigan
        // cwd'ga (Android'da '/') nisbatan hal qilinib, yozuv bo'sh bo'lardi.
        // AudioRecorderService kabi vaqtinchalik papkadan absolyut yo'l.
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      await _recorder.start(const RecordConfig(), path: path);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _elapsed = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed++);
      });
    } catch (_) {
      if (mounted) AppToast.error(context, 'chat.micError'.tr());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _cancelVoice() async {
    _timer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _stopSendVoice() async {
    _timer?.cancel();
    final secs = _elapsed;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _recording = false);
    if (path != null) widget.onSendVoice(path, secs < 1 ? 1 : secs);
  }

  String get _elapsedLabel {
    final m = _elapsed ~/ 60;
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 10 + bottom),
      child: _recording ? _recordingRow() : _idleRow(),
    );
  }

  Widget _idleRow() {
    final hasText = _textCtrl.text.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _chipBg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _fieldBorder),
            ),
            child: TextSelectionTheme(
              data: const TextSelectionThemeData(
                cursorColor: _blue,
                selectionHandleColor: _blue,
                selectionColor: Color(0x5C216BFF),
              ),
              child: TextField(
                controller: _textCtrl,
                style: _pop(15),
                cursorColor: _blue,
                minLines: 1,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _sendText(),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  filled: false,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'chat.inputHint'.tr(),
                  hintStyle: _pop(15, c: _dim),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (hasText)
          _CircleAction(icon: Icons.send_rounded, blue: true, onTap: _sendText)
        else ...[
          _CircleAction(icon: SolarIconsBold.microphone, onTap: _startVoice),
          const SizedBox(width: 10),
          _CircleAction(icon: SolarIconsBold.camera, onTap: widget.onCamera),
        ],
      ],
    );
  }

  Widget _recordingRow() {
    return Row(
      children: [
        _CircleAction(icon: Icons.close_rounded, onTap: _cancelVoice),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: _chipBg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _fieldBorder),
            ),
            child: Row(
              children: [
                const _PulsingDot(),
                const SizedBox(width: 10),
                Text(_elapsedLabel, style: _pop(15, w: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'chat.recording'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(13, c: _dim),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _CircleAction(
          icon: Icons.send_rounded,
          blue: true,
          onTap: _stopSendVoice,
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Container(
        width: 11,
        height: 11,
        decoration: const BoxDecoration(color: _rec, shape: BoxShape.circle),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
    this.blue = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool blue;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: blue ? _blue : _chipBg,
          shape: BoxShape.circle,
          border: blue ? null : Border.all(color: _fieldBorder),
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _fieldBorder),
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}
