import 'package:flutter/material.dart';

import '../../../core/network/admin_api.dart';
import '../../../core/ux/app_error_handler.dart';
import 'picked_video.dart';
import 'video_probe.dart';
import 'video_probe_result.dart';
import 'video_upload_multipart.dart';
import 'widgets/thumbnail_upload_box.dart';
import 'widgets/video_preview_panel.dart';
import 'widgets/video_upload_box.dart';

/// Premium SaaS-style “Video joylash” experience (two columns, multipart upload).
class VideoUploadModal extends StatefulWidget {
  const VideoUploadModal({
    super.key,
    required this.categories,
    required this.api,
  });

  final List<Map<String, dynamic>> categories;
  final AdminApi api;

  static Future<Map<String, dynamic>?> open(
    BuildContext context, {
    required List<Map<String, dynamic>> categories,
    required AdminApi api,
  }) {
    return showGeneralDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'close',
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, _) {
        return SafeArea(
          child: Center(
            child: VideoUploadModal(categories: categories, api: api),
          ),
        );
      },
    );
  }

  @override
  State<VideoUploadModal> createState() => _VideoUploadModalState();
}

class _VideoUploadModalState extends State<VideoUploadModal> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _duration = TextEditingController();

  PickedVideo? _video;
  PickedThumbnail? _thumb;
  VideoProbeResult? _probe;
  bool _probing = false;

  int _ageFrom = 3;
  int _ageTo = 8;
  String? _categoryId;
  String _plan = 'free';

  bool _saving = false;
  double _uploadProgress = 0;
  bool _done = false;
  String? _videoBoxError;

  static const _titleMax = 100;
  static const _descMax = 300;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _duration.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final t = _title.text.trim();
    if (t.isEmpty || t.length > _titleMax) return false;
    if (_desc.text.length > _descMax) return false;
    if (_video == null) return false;
    if (_ageFrom > _ageTo) return false;
    return !_saving;
  }

  Future<void> _applyVideo(PickedVideo? v) async {
    setState(() {
      _video = v;
      _probe = null;
      _videoBoxError = v == null ? 'Video majburiy' : null;
      if (v == null) _duration.clear();
    });
    if (v == null) return;
    setState(() => _probing = true);
    final r = await probeVideo(v);
    if (!mounted) return;
    setState(() {
      _probe = r;
      _probing = false;
      if (_duration.text.trim().isEmpty &&
          r.durationSec != null &&
          r.durationSec! > 0) {
        _duration.text = '${r.durationSec}';
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_video == null) {
      setState(() => _videoBoxError = 'Video faylini yuklang');
      return;
    }
    if (_ageFrom > _ageTo) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Yosh oralig‘i noto‘g‘ri')));
      return;
    }
    setState(() {
      _saving = true;
      _uploadProgress = 0;
      _done = false;
    });
    try {
      final ds = int.tryParse(_duration.text.trim());
      final meta = <String, dynamic>{
        'title': _title.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        'ageFrom': _ageFrom,
        'ageTo': _ageTo,
        if (ds != null && ds >= 0) 'durationSec': ds,
        if (_categoryId != null && _categoryId!.isNotEmpty)
          'categoryId': _categoryId,
        'planRequired': _plan,
        'status': 'hidden',
        'featured': false,
      };
      final vf = await videoToMultipart(_video!);
      final tf = await thumbnailToMultipart(_thumb);
      final created = await widget.api.uploadVideo(
        videoFile: vf,
        thumbnailFile: tf,
        metadata: meta,
        onSendProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => _uploadProgress = sent / total);
        },
      );
      if (!mounted) return;
      setState(() {
        _done = true;
        _uploadProgress = 1;
      });
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          if (!_done) _uploadProgress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 720),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Video joylash',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Fayl yuklang, ma’lumotlarni to‘ldiring va nashr qiling',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (_saving && _uploadProgress > 0 && _uploadProgress < 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final narrow = c.maxWidth < 880;
                      final form = Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          child: narrow
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _leftColumn(context),
                                    const SizedBox(height: 20),
                                    _rightColumn(context),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 11,
                                      child: _leftColumn(context),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      flex: 9,
                                      child: _rightColumn(context),
                                    ),
                                  ],
                                ),
                        ),
                      );
                      return form;
                    },
                  ),
                ),
              ),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(Map<String, dynamic> c) {
    final name = c['name']?.toString() ?? '';
    final level = c['level']?.toString() ?? 'both';
    final tag = level == 'school'
        ? 'Maktab'
        : level == 'university'
            ? 'Oliygoh'
            : 'Ikkalasi';
    return '$name ($tag)';
  }

  Widget _leftColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Asosiy ma’lumotlar',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _title,
          maxLength: _titleMax,
          decoration: const InputDecoration(
            labelText: 'Sarlavha',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Majburiy';
            if (v.trim().length > _titleMax) {
              return '$_titleMax belgidan oshmasin';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _desc,
          maxLength: _descMax,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Tavsif',
            alignLabelWithHint: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          validator: (v) {
            if ((v ?? '').length > _descMax) {
              return '$_descMax belgidan oshmasin';
            }
            return null;
          },
        ),
        const SizedBox(height: 18),
        const Text(
          'Video fayl',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        if (_probing) const LinearProgressIndicator(minHeight: 2),
        if (_probing) const SizedBox(height: 8),
        VideoUploadBox(
          value: _video,
          errorText: _videoBoxError,
          onChanged: _applyVideo,
        ),
        if (_video != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _saving ? null : () => _applyVideo(null),
              child: const Text('Videoni almashtirish'),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Thumbnail',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        ThumbnailUploadBox(
          value: _thumb,
          onChanged: (t) => setState(() => _thumb = t),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _ageFrom,
                decoration: const InputDecoration(
                  labelText: 'Yosh dan',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                items: List.generate(
                  19,
                  (i) => DropdownMenuItem(value: i, child: Text('$i')),
                ),
                onChanged: _saving
                    ? null
                    : (v) => setState(() {
                        _ageFrom = v ?? 0;
                        if (_ageFrom > _ageTo) _ageTo = _ageFrom;
                      }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _ageTo,
                decoration: const InputDecoration(
                  labelText: 'Yosh gacha',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                items: List.generate(
                  19,
                  (i) => DropdownMenuItem(value: i, child: Text('$i')),
                ),
                onChanged: _saving
                    ? null
                    : (v) => setState(() {
                        _ageTo = v ?? 18;
                        if (_ageFrom > _ageTo) _ageFrom = _ageTo;
                      }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _duration,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Davomiylik (sekund, ixtiyoriy)',
            hintText: 'Avto aniqlanadi — qo‘lda o‘zgartirish mumkin',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _categoryId,
          decoration: const InputDecoration(
            labelText: 'Kategoriya',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Tanlanmagan'),
            ),
            ...widget.categories.map(
              (c) => DropdownMenuItem<String?>(
                value: c['id']?.toString(),
                child: Text(_categoryLabel(c)),
              ),
            ),
          ],
          onChanged: _saving ? null : (v) => setState(() => _categoryId = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _plan,
          decoration: const InputDecoration(
            labelText: 'Obuna',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'free', child: Text('Free')),
            DropdownMenuItem(value: 'standard', child: Text('Standard')),
            DropdownMenuItem(value: 'premium', child: Text('Premium')),
          ],
          onChanged: _saving
              ? null
              : (v) => setState(() => _plan = v ?? 'free'),
        ),
      ],
    );
  }

  Widget _rightColumn(BuildContext context) {
    return VideoPreviewPanel(
      video: _video,
      probe: _probe,
      manualDurationText: _duration.text,
    );
  }

  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Row(
        children: [
          if (_done)
            const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 22),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Bekor qilish'),
          ),
          const Spacer(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _canSubmit ? _submit : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Saqlash va nashr qilish',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
