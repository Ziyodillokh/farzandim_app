import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

import '../audio_upload_constants.dart';
import '../picked_audio.dart';
import '../../video_upload/video_upload_constants.dart' show formatFileSize;

class AudioUploadBox extends StatefulWidget {
  const AudioUploadBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final PickedAudio? value;
  final ValueChanged<PickedAudio?> onChanged;
  final String? errorText;

  @override
  State<AudioUploadBox> createState() => _AudioUploadBoxState();
}

class _AudioUploadBoxState extends State<AudioUploadBox> {
  DropzoneViewController? _dz;
  bool _hovering = false;

  Future<void> _emitError(String msg) async {
    widget.onChanged(null);
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _acceptWeb(DropzoneFileInterface file, DropzoneViewController c) async {
    final name = await c.getFilename(file);
    if (!isAllowedAudioFileName(name)) {
      await _emitError('Audio fayl formati qabul qilinmadi (mp3, m4a, ... )');
      return;
    }
    final size = await c.getFileSize(file);
    if (size > kMaxAudioUploadBytes) {
      await _emitError('Fayl hajmi 500 MB dan oshmasligi kerak');
      return;
    }
    widget.onChanged(PickedAudio(
      fileName: name,
      sizeBytes: size,
      webFile: file,
      webController: c,
    ));
  }

  Future<void> _pickWeb() async {
    final c = _dz;
    if (c == null) return;
    try {
      final list = await c.pickFiles(
        multiple: false,
        mime: const ['audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/webm', 'audio/ogg'],
      );
      if (list.isEmpty) return;
      await _acceptWeb(list.first, c);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Tanlash bekor qilindi yoki xato: $e')),
        );
      }
    }
  }

  Future<void> _pickIo() async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus', 'webm'],
    );
    final f = (r != null && r.files.length == 1) ? r.files.single : null;
    final path = f?.path;
    if (path == null || path.isEmpty) return;
    final name = f!.name;
    if (!isAllowedAudioFileName(name)) {
      await _emitError('Faqat audio fayl formatlari');
      return;
    }
    final size = f.size;
    if (size > kMaxAudioUploadBytes) {
      await _emitError('Fayl hajmi 500 MB dan oshmasligi kerak');
      return;
    }
    widget.onChanged(PickedAudio(
      fileName: name,
      sizeBytes: size,
      platformPath: path,
    ));
  }

  Widget _dashedShell({required List<Widget> children}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.errorText != null
              ? const Color(0xFFEF4444)
              : _hovering
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFCBD5E1),
          width: widget.errorText != null ? 1.8 : 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = widget.value != null;

    if (kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            SizedBox(
              height: 200,
              child: DropzoneView(
                operation: DragOperation.copy,
                cursor: CursorType.copy,
                mime: const [
                  'audio/mpeg',
                  'audio/mp4',
                  'audio/wav',
                  'audio/webm',
                  'audio/ogg',
                ],
                onCreated: (c) => _dz = c,
                onHover: () => setState(() => _hovering = true),
                onLeave: () => setState(() => _hovering = false),
                onDropInvalid: (_) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(content: Text('Audio formati mos kelmaydi')),
                  );
                },
                onDropFile: (file) async {
                  final c = _dz;
                  if (c == null) return;
                  await _acceptWeb(file, c);
                  setState(() => _hovering = false);
                },
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: _dashedShell(
                  children: [
                    Icon(
                      Icons.headphones_outlined,
                      size: 40,
                      color: hasFile ? const Color(0xFF22C55E) : const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasFile ? widget.value!.fileName : 'Audio faylni tanlang yoki tashlang',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'MP3, M4A, AAC, WAV, OGG — maks. 500 MB',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    if (hasFile) ...[
                      const SizedBox(height: 6),
                      Text(
                        formatFileSize(widget.value!.sizeBytes),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF22C55E)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: FilledButton.tonalIcon(
                    onPressed: _pickWeb,
                    icon: const Icon(Icons.folder_open_outlined, size: 20),
                    label: const Text('Audio fayl tanlash'),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _dashedShell(
      children: [
        Icon(
          Icons.headphones_outlined,
          size: 40,
          color: hasFile ? const Color(0xFF22C55E) : const Color(0xFF64748B),
        ),
        const SizedBox(height: 10),
        Text(
          hasFile ? widget.value!.fileName : 'Audio faylni tanlang',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'MP3, M4A, AAC, WAV, OGG — maks. 500 MB',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        if (hasFile) ...[
          const SizedBox(height: 6),
          Text(
            formatFileSize(widget.value!.sizeBytes),
            style: const TextStyle(fontSize: 12, color: Color(0xFF22C55E)),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          onPressed: _pickIo,
          icon: const Icon(Icons.folder_open_outlined, size: 20),
          label: const Text('Audio fayl tanlash'),
        ),
      ],
    );
  }
}
