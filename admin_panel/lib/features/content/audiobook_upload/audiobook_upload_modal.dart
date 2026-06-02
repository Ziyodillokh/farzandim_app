import 'package:flutter/material.dart';

import '../../../core/network/admin_api.dart';
import '../../../core/ux/app_error_handler.dart';
import '../video_upload/picked_video.dart' show PickedThumbnail;
import '../video_upload/widgets/thumbnail_upload_box.dart';
import 'audio_probe.dart';
import 'audio_probe_result.dart';
import 'audio_upload_multipart.dart';
import 'picked_audio.dart';
import 'widgets/audio_upload_box.dart';

class AudiobookUploadModal extends StatefulWidget {
  const AudiobookUploadModal({
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
            child: AudiobookUploadModal(categories: categories, api: api),
          ),
        );
      },
    );
  }

  @override
  State<AudiobookUploadModal> createState() => _AudiobookUploadModalState();
}

class _AudiobookUploadModalState extends State<AudiobookUploadModal> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _desc = TextEditingController();
  final _duration = TextEditingController();
  final _points = TextEditingController(text: '10');
  final _parts = TextEditingController(text: '1');

  PickedAudio? _audio;
  PickedThumbnail? _thumb;
  AudioProbeResult? _probe;
  bool _probing = false;

  int _ageFrom = 3;
  int _ageTo = 8;
  String? _categoryId;
  String _plan = 'free';

  bool _saving = false;
  double _uploadProgress = 0;
  bool _done = false;
  String? _audioBoxError;

  static const _titleMax = 200;
  static const _descMax = 2000;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _desc.dispose();
    _duration.dispose();
    _points.dispose();
    _parts.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final t = _title.text.trim();
    final a = _author.text.trim();
    if (t.isEmpty || t.length > _titleMax) return false;
    if (a.isEmpty) return false;
    if (_desc.text.length > _descMax) return false;
    if (_audio == null) return false;
    if (_ageFrom > _ageTo) return false;
    if (_saving) return false;
    return true;
  }

  Future<void> _applyAudio(PickedAudio? v) async {
    setState(() {
      _audio = v;
      _probe = null;
      _audioBoxError = v == null ? 'Audio fayl majburiy' : null;
      if (v == null) _duration.clear();
    });
    if (v == null) return;
    setState(() => _probing = true);
    final r = await probeAudio(v);
    if (!mounted) return;
    setState(() {
      _probing = false;
      _probe = r;
      if (_duration.text.trim().isEmpty &&
          r.durationSec != null &&
          r.durationSec! > 0) {
        _duration.text = '${r.durationSec}';
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_audio == null) {
      setState(() => _audioBoxError = 'Audio faylini yuklang');
      return;
    }
    final ds = int.tryParse(_duration.text.trim());
    if (ds == null || ds < 1) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Davomiylik (sekund) to‘g‘ri kiriting (minimum 1)'),
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _uploadProgress = 0;
      _done = false;
    });
    try {
      final pr = int.tryParse(_points.text.trim()) ?? 10;
      final pc = int.tryParse(_parts.text.trim()) ?? 1;
      final meta = <String, dynamic>{
        'title': _title.text.trim(),
        'author': _author.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        'ageFrom': _ageFrom,
        'ageTo': _ageTo,
        'durationSec': ds,
        if (_categoryId != null && _categoryId!.isNotEmpty)
          'categoryId': _categoryId,
        'planRequired': _plan,
        'status': 'hidden',
        'pointsReward': pr.clamp(0, 500),
        'partsCount': pc.clamp(1, 999),
      };
      final af = await audioToMultipart(_audio!);
      final tf = await thumbnailToMultipart(_thumb);
      final created = await widget.api.uploadAudiobook(
        audioFile: af,
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
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.headphones_outlined,
                        color: Color(0xFF3730A3),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audiokitob qo‘shish',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Audio fayl va rasm yuklang',
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
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: _formLeft()),
                          const SizedBox(width: 24),
                          Expanded(flex: 9, child: _formRight()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formLeft() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _title,
          maxLength: _titleMax,
          decoration: const InputDecoration(
            labelText: 'Nomi (sarlavha)',
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
              return 'Juda uzoq';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _author,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Muallif',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Majburiy';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _desc,
          maxLength: _descMax,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Tavsif',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_probing) const LinearProgressIndicator(minHeight: 2),
        if (_probing) const SizedBox(height: 6),
        AudioUploadBox(
          value: _audio,
          errorText: _audioBoxError,
          onChanged: _applyAudio,
        ),
        const SizedBox(height: 8),
        const Text(
          'Thumbnail (ixtiyoriy)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ThumbnailUploadBox(
          value: _thumb,
          onChanged: (t) => setState(() => _thumb = t),
        ),
        const SizedBox(height: 12),
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
            labelText: 'Davomiylik (sekund) *',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        if (_probe?.durationSec != null)
          Text(
            'Tavsiya: ${_probe!.durationSec} s',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _points,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Ball mukofoti',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _parts,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Bo‘limlar soni',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
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
                child: Text(c['name']?.toString() ?? ''),
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

  Widget _formRight() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ko‘rinish',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _title.text.trim().isEmpty ? 'Sarlavha' : _title.text.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            _author.text.trim().isEmpty ? 'Muallif' : _author.text.trim(),
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
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
          FilledButton(
            onPressed: _canSubmit && !_saving ? _submit : null,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Yuklash va saqlash'),
          ),
        ],
      ),
    );
  }
}
