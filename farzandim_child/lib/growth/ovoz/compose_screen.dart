// H05 · Yangi shaxsiy murojaat: qabul qiluvchi, qisqa erkin matn, ixtiyoriy
// «Shoshilinch» kaliti va yuborish. Avval qurilmadagi navbatga yoziladi —
// internet bo'lmasa H07 «Xabaring hali yuborilmadi» holatida qoladi.
// Anonim so'rov javoblari bu shaklga hech qachon tushmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_models.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_outbox.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_repository.dart';
import 'package:farzandim_child/growth/ovoz/voice_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VoiceComposeScreen extends ConsumerStatefulWidget {
  const VoiceComposeScreen({super.key});

  @override
  ConsumerState<VoiceComposeScreen> createState() => _VoiceComposeScreenState();
}

class _VoiceComposeScreenState extends ConsumerState<VoiceComposeScreen> {
  final _text = TextEditingController();
  var _urgent = false;
  var _sending = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _text.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'g5.voice.compose.empty'.tr());
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final outbox = ref.read(voiceOutboxProvider.notifier);
    final id = newRequestId();
    await outbox.enqueue(id: id, message: message, urgent: _urgent);
    try {
      final request = await outbox.send(id);
      if (!mounted) return;
      GrowthLinks.voiceRequest(context, request.id, replace: true);
    } on SchoolException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case SchoolErrorCode.network ||
            SchoolErrorCode.unknown ||
            SchoolErrorCode.unavailable:
          // Navbatda qoldi — H07 «hali yuborilmadi» holati.
          GrowthLinks.voiceRequest(context, id, replace: true);
        case SchoolErrorCode.tooManyRequests:
          await outbox.discard(id);
          setState(() {
            _sending = false;
            _error = 'g5.voice.compose.tooMany'.tr();
          });
        default:
          await outbox.discard(id);
          setState(() {
            _sending = false;
            _error = 'g5.voice.compose.failed'.tr();
          });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = ref.watch(voiceContactProvider).valueOrNull;
    final name = voicePsychologistName(contact ?? VoiceContact.unknown);
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.close(
            label: 'g5.voice.compose.cancel'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.voice.compose.title'.tr(),
        ),
        dock: GButton(
          label: 'g5.voice.compose.send'.tr(),
          icon: GIcons.paperPlaneRight,
          loading: _sending,
          onPressed: _sending ? null : _send,
        ),
        children: [
          GList(
            children: [
              GListItem(
                leading: GAvatar(
                  initials: name.characters.first.toUpperCase(),
                  hue: GHue.sky,
                  size: 40,
                ),
                title: 'g5.voice.compose.to'.tr(namedArgs: {'name': name}),
              ),
            ],
          ),
          GTextField(
            label: 'g5.voice.compose.prompt'.tr(),
            controller: _text,
            hint: 'g5.voice.compose.hint'.tr(),
            multiline: true,
            maxLength: kVoiceMessageMaxLength,
            textCapitalization: TextCapitalization.sentences,
            enabled: !_sending,
            error: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          GList(
            children: [
              GListItem(
                leading: const GTile(
                  icon: GIcons.warningCircle,
                  hue: GHue.rose,
                  size: 40,
                ),
                title: 'g5.voice.compose.urgent'.tr(),
                subtitle: 'g5.voice.compose.urgentHint'.tr(),
                trailing: GSwitch(
                  value: _urgent,
                  semanticLabel: 'g5.voice.compose.urgent'.tr(),
                  onChanged: _sending
                      ? null
                      : (v) => setState(() => _urgent = v),
                ),
              ),
            ],
          ),
          GNote(
            text: 'g5.voice.compose.whoReads'.tr(),
            kind: GNoteKind.info,
            icon: GIcons.lockKey,
          ),
        ],
      ),
    );
  }
}
