import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../picked_video.dart';
import '../video_upload_constants.dart';

class ThumbnailUploadBox extends StatelessWidget {
  const ThumbnailUploadBox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PickedThumbnail? value;
  final ValueChanged<PickedThumbnail?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final r = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final f = (r != null && r.files.length == 1) ? r.files.single : null;
    if (f == null) return;
    final name = f.name;
    if (!isAllowedThumbnailFileName(name)) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('JPG, PNG yoki WebP tanlang')),
      );
      return;
    }
    final b = f.bytes;
    if (b == null || b.isEmpty) return;
    if (b.length > kMaxThumbnailBytes) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Rasm hajmi 8 MB dan oshmasligi kerak')),
      );
      return;
    }
    onChanged(PickedThumbnail(fileName: name, bytes: b));
  }

  @override
  Widget build(BuildContext context) {
    final thumb = value;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumb == null
                  ? Container(
                      alignment: Alignment.center,
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(Icons.image_outlined, size: 36, color: Color(0xFF94A3B8)),
                    )
                  : Image.memory(
                      Uint8List.fromList(thumb.bytes),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _pick(context),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
            label: const Text('Rasm tanlash'),
          ),
          if (thumb != null)
            TextButton(
              onPressed: () => onChanged(null),
              child: const Text('Olib tashlash'),
            ),
        ],
      ),
    );
  }
}
