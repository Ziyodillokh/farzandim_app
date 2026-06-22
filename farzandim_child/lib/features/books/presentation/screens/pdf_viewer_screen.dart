import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_theme.dart';
import 'package:farzandim_child/features/books/data/models/book_model.dart';
import 'package:farzandim_child/features/books/data/repositories/books_backend_repository.dart';

// Sprint 5.x — PDF kitobni native viewer'da ochish.
//
// Pipeline:
//   1. Signed pdfUrl'ni Dio bilan tmp faylga yuklab olish
//   2. flutter_pdfview Android native (com.shockwave/PdfRenderer) ishlatadi
//   3. POST /content/books/:id/read  (fire-and-forget — counter++)
//
// iOS uchun ham flutter_pdfview qo'llab-quvvatlanadi (WKWebView orqali).

class PdfViewerScreen extends ConsumerStatefulWidget {
  const PdfViewerScreen({super.key, required this.book});

  final BookModel book;

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  String? _localPath;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _ready = false;
  PDFViewController? _controller;
  bool _showBottomBar = true;

  @override
  void initState() {
    super.initState();
    _downloadAndOpen();
    // Read counter — fire-and-forget
    ref.read(booksBackendRepositoryProvider).markRead(widget.book.id);
  }

  Future<void> _downloadAndOpen() async {
    try {
      if (widget.book.pdfUrl.isEmpty) {
        setState(() => _error = 'PDF havolasi yo\'q');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/book-${widget.book.id}.pdf';
      final file = File(path);
      if (!await file.exists()) {
        final dio = Dio();
        await dio.download(widget.book.pdfUrl, path);
      }
      if (!mounted) return;
      setState(() => _localPath = path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _jumpToPage() async {
    if (_totalPages == 0 || _controller == null) return;
    final ctl = TextEditingController(text: '${_currentPage + 1}');
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => Theme(
        data: AppTheme.darkTheme,
        child: AlertDialog(
          backgroundColor: AppColors.parvozSurface,
          title: const Text(
            'Sahifaga o\'tish',
            style: TextStyle(color: AppColors.parvozText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctl,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.parvozText),
                decoration: InputDecoration(
                  labelText: 'Sahifa raqami (1–$_totalPages)',
                  labelStyle: const TextStyle(color: AppColors.parvozTextDim),
                  filled: true,
                  fillColor: AppColors.parvozSurfaceHigh,
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.parvozBorderStrong),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.parvozGreen),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Jami: $_totalPages sahifa',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.parvozTextDim,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Bekor',
                style: TextStyle(color: AppColors.parvozTextDim),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.parvozGreen,
                foregroundColor: AppColors.parvozOnGreen,
              ),
              onPressed: () {
                final n = int.tryParse(ctl.text.trim());
                if (n != null && n >= 1 && n <= _totalPages) {
                  Navigator.pop(ctx, n - 1);
                }
              },
              child: const Text('O\'tish'),
            ),
          ],
        ),
      ),
    );
    if (picked != null && _controller != null) {
      await _controller!.setPage(picked);
    }
  }

  void _showSearchPlaceholder() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Theme(
        data: AppTheme.darkTheme,
        child: AlertDialog(
          backgroundColor: AppColors.parvozSurface,
          title: const Text(
            'Qidirish',
            style: TextStyle(color: AppColors.parvozText),
          ),
          content: const Text(
            'Matn qidirish hozircha qo\'llab-quvvatlanmaydi. Keyingi versiyada qo\'shiladi.',
            style: TextStyle(color: AppColors.parvozTextDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'OK',
                style: TextStyle(color: AppColors.parvozGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              height: 56,
              padding: const EdgeInsets.only(left: 4, right: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.parvozBorderStrong),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.parvozText,
                        size: 24,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.parvozText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Qidirish',
                    icon: const Icon(Icons.search, color: AppColors.parvozText),
                    onPressed: _ready ? _showSearchPlaceholder : null,
                  ),
                  IconButton(
                    tooltip: 'Sahifaga o\'tish',
                    icon: const Icon(
                      Icons.format_list_numbered,
                      color: AppColors.parvozText,
                    ),
                    onPressed: _ready ? _jumpToPage : null,
                  ),
                  if (_totalPages > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, right: 4),
                      child: Text(
                        '${_currentPage + 1}/$_totalPages',
                        style: const TextStyle(
                          color: AppColors.parvozTextDim,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _showBottomBar = !_showBottomBar),
              child: Stack(
                children: [
                  _buildBody(),
                  if (_ready && _totalPages > 1 && _showBottomBar)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: _PageScrubber(
                          currentPage: _currentPage,
                          totalPages: _totalPages,
                          onChanged: (p) {
                            _controller?.setPage(p);
                          },
                          onFirst: () => _controller?.setPage(0),
                          onLast: () => _controller?.setPage(_totalPages - 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.error,
                  color: AppColors.parvozTextDim, size: 48),
              const SizedBox(height: 16),
              const Text(
                'PDF ochilmadi',
                style: TextStyle(color: AppColors.parvozText, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.parvozTextDim, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    if (_localPath == null) {
      return Stack(
        children: [
          if (widget.book.hasCover)
            Positioned.fill(
              child: Image.network(
                widget.book.coverUrl,
                fit: BoxFit.cover,
                color: Colors.black54,
                colorBlendMode: BlendMode.darken,
              ),
            ),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.parvozGreen),
                SizedBox(height: 16),
                Text(
                  'Kitob yuklanmoqda...',
                  style: TextStyle(color: AppColors.parvozText),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Stack(
      children: [
        PDFView(
          filePath: _localPath!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          pageSnap: true,
          fitPolicy: FitPolicy.WIDTH,
          backgroundColor: Colors.black,
          onRender: (pages) {
            setState(() {
              _ready = true;
              _totalPages = pages ?? 0;
            });
          },
          onError: (err) {
            setState(() => _error = '$err');
          },
          onPageError: (page, err) {
            setState(() => _error = 'Sahifa $page xato: $err');
          },
          onViewCreated: (controller) {
            _controller = controller;
          },
          onPageChanged: (page, total) {
            if (page != null) setState(() => _currentPage = page);
          },
        ),
        if (!_ready)
          const Center(
              child: CircularProgressIndicator(color: AppColors.parvozGreen)),
      ],
    );
  }
}

// ─── Page scrubber (pastdagi sahifa boshqaruvi) ────────────────────────

class _PageScrubber extends StatelessWidget {
  const _PageScrubber({
    required this.currentPage,
    required this.totalPages,
    required this.onChanged,
    required this.onFirst,
    required this.onLast,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onChanged;
  final VoidCallback onFirst;
  final VoidCallback onLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.parvozSurface,
        border: Border(
          top: BorderSide(color: AppColors.parvozBorderStrong),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Birinchi sahifa',
            icon: const Icon(Icons.first_page, color: AppColors.parvozText),
            onPressed: onFirst,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.parvozGreen,
                inactiveTrackColor: AppColors.parvozBorderStrong,
                thumbColor: AppColors.parvozGreen,
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: currentPage.toDouble().clamp(0, (totalPages - 1).toDouble()),
                min: 0,
                max: (totalPages - 1).toDouble(),
                divisions: totalPages > 1 ? totalPages - 1 : null,
                label: '${currentPage + 1}',
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Oxirgi sahifa',
            icon: const Icon(Icons.last_page, color: AppColors.parvozText),
            onPressed: onLast,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${currentPage + 1}/$totalPages',
              style: const TextStyle(
                color: AppColors.parvozText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
