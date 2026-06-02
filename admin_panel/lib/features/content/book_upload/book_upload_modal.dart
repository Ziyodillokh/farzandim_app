import 'package:flutter/material.dart';

import '../../../core/network/admin_api.dart';
import '../../../core/ux/app_error_handler.dart';
import '../audiobook_upload/audio_upload_multipart.dart' show thumbnailToMultipart;
import '../video_upload/picked_video.dart' show PickedThumbnail;
import '../video_upload/widgets/thumbnail_upload_box.dart';
import 'pdf_upload_multipart.dart';
import 'picked_pdf.dart';
import 'widgets/pdf_upload_box.dart';

/// Sprint 5.6d — Books PDF multipart upload modal.
///
/// POST /admin/books/upload (pdfFile + coverFile? + metadata JSON).
/// Audiobook upload modaliga juda o'xshash, lekin author + pages + category
/// dropdown maydonlari.
class BookUploadModal extends StatefulWidget {
  const BookUploadModal({super.key, required this.api});

  final AdminApi api;

  static Future<Map<String, dynamic>?> open(
    BuildContext context, {
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
            child: BookUploadModal(api: api),
          ),
        );
      },
    );
  }

  @override
  State<BookUploadModal> createState() => _BookUploadModalState();
}

class _BookUploadModalState extends State<BookUploadModal> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _desc = TextEditingController();
  final _pages = TextEditingController(text: '1');

  PickedPdf? _pdf;
  PickedThumbnail? _cover;

  int _ageFrom = 7;
  int _ageTo = 14;
  String _category = 'school';
  String _plan = 'free';

  bool _saving = false;
  double _uploadProgress = 0;
  bool _done = false;
  String? _pdfBoxError;

  static const _titleMax = 200;
  static const _descMax = 4000;

  // Backend `Book.category` — string slug (default "school"). Hozircha
  // dropdown'da seed'dagi 3 ta kategoriya bor; kelajakda kategoriya API
  // orqali keladi.
  static const _categoryOptions = <_CategoryChoice>[
    _CategoryChoice('school', 'Maktab darsliklari'),
    _CategoryChoice('adabiyot', 'Adabiyot'),
    _CategoryChoice('tarjima', 'Tarjima'),
  ];

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _desc.dispose();
    _pages.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_title.text.trim().isEmpty) return false;
    if (_author.text.trim().isEmpty) return false;
    if (_pdf == null) return false;
    if (_saving) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pdf == null) {
      setState(() => _pdfBoxError = 'PDF faylini yuklang');
      return;
    }
    setState(() {
      _saving = true;
      _uploadProgress = 0;
      _done = false;
    });
    try {
      final pages = int.tryParse(_pages.text.trim()) ?? 1;
      final meta = <String, dynamic>{
        'title': _title.text.trim(),
        'author': _author.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        'pages': pages.clamp(1, 99999),
        'ageFrom': _ageFrom,
        'ageTo': _ageTo,
        'category': _category,
        'planRequired': _plan,
        'status': 'hidden',
      };
      final pdfFile = await pdfToMultipart(_pdf!);
      final coverFile = await thumbnailToMultipart(_cover);
      final created = await widget.api.uploadBook(
        pdfFile: pdfFile,
        coverFile: coverFile,
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
              _header(),
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Color(0xFFB45309),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kitob qo‘shish (PDF)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'PDF fayl va muqova rasmini yuklang',
                  style:
                      TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
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
            if (v.trim().length > _titleMax) return 'Juda uzoq';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _author,
          maxLength: 150,
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
        PdfUploadBox(
          value: _pdf,
          errorText: _pdfBoxError,
          onChanged: (v) {
            setState(() {
              _pdf = v;
              _pdfBoxError = v == null ? 'PDF fayl majburiy' : null;
            });
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Muqova (ixtiyoriy)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ThumbnailUploadBox(
          value: _cover,
          onChanged: (c) => setState(() => _cover = c),
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
          controller: _pages,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Sahifalar soni',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(
            labelText: 'Kategoriya',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          items: _categoryOptions
              .map(
                (c) => DropdownMenuItem(value: c.slug, child: Text(c.label)),
              )
              .toList(),
          onChanged:
              _saving ? null : (v) => setState(() => _category = v ?? 'school'),
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
          onChanged:
              _saving ? null : (v) => setState(() => _plan = v ?? 'free'),
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
          if (_pdf != null) ...[
            const SizedBox(height: 8),
            Text(
              _pdf!.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
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

class _CategoryChoice {
  const _CategoryChoice(this.slug, this.label);
  final String slug;
  final String label;
}
