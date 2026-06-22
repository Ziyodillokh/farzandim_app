import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:farzandim_child/core/theme/app_colors.dart';
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
      builder: (ctx) {
        final pv = ctx.adaptive;
        return AlertDialog(
          backgroundColor: pv.pvSurface,
          title: Text(
            'Sahifaga o\'tish',
            style: TextStyle(color: pv.pvText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctl,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: TextStyle(color: pv.pvText),
                decoration: InputDecoration(
                  labelText: 'Sahifa raqami (1–$_totalPages)',
                  labelStyle: TextStyle(color: pv.pvTextDim),
                  filled: true,
                  fillColor: pv.pvSurfaceHigh,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: pv.pvBorderStrong),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: pv.pvGreen),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Jami: $_totalPages sahifa',
                style: TextStyle(
                  fontSize: 12,
                  color: pv.pvTextDim,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Bekor',
                style: TextStyle(color: pv.pvTextDim),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: pv.pvGreen,
                foregroundColor: pv.pvOnGreen,
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
        );
      },
    );
    if (picked != null && _controller != null) {
      await _controller!.setPage(picked);
    }
  }

  void _showSearchPlaceholder() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final pv = ctx.adaptive;
        return AlertDialog(
          backgroundColor: pv.pvSurface,
          title: Text(
            'Qidirish',
            style: TextStyle(color: pv.pvText),
          ),
          content: Text(
            'Matn qidirish hozircha qo\'llab-quvvatlanmaydi. Keyingi versiyada qo\'shiladi.',
            style: TextStyle(color: pv.pvTextDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'OK',
                style: TextStyle(color: pv.pvGreen),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pv = context.adaptive;
    return Scaffold(
      backgroundColor: pv.pvBg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              height: 56,
              padding: const EdgeInsets.only(left: 4, right: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: pv.pvBorderStrong),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: pv.pvText,
                        size: 24,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pv.pvText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Qidirish',
                    icon: Icon(Icons.search, color: pv.pvText),
                    onPressed: _ready ? _showSearchPlaceholder : null,
                  ),
                  IconButton(
                    tooltip: 'Sahifaga o\'tish',
                    icon: Icon(
                      Icons.format_list_numbered,
                      color: pv.pvText,
                    ),
                    onPressed: _ready ? _jumpToPage : null,
                  ),
                  if (_totalPages > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, right: 4),
                      child: Text(
                        '${_currentPage + 1}/$_totalPages',
                        style: TextStyle(
                          color: pv.pvTextDim,
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
    final pv = context.adaptive;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.error, color: pv.pvTextDim, size: 48),
              const SizedBox(height: 16),
              Text(
                'PDF ochilmadi',
                style: TextStyle(color: pv.pvText, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: pv.pvTextDim, fontSize: 12),
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
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: pv.pvGreen),
                const SizedBox(height: 16),
                Text(
                  'Kitob yuklanmoqda...',
                  style: TextStyle(color: pv.pvText),
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
          Center(child: CircularProgressIndicator(color: pv.pvGreen)),
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
    final pv = context.adaptive;
    return Container(
      decoration: BoxDecoration(
        color: pv.pvSurface,
        border: Border(
          top: BorderSide(color: pv.pvBorderStrong),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Birinchi sahifa',
            icon: Icon(Icons.first_page, color: pv.pvText),
            onPressed: onFirst,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: pv.pvGreen,
                inactiveTrackColor: pv.pvBorderStrong,
                thumbColor: pv.pvGreen,
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
            icon: Icon(Icons.last_page, color: pv.pvText),
            onPressed: onLast,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${currentPage + 1}/$totalPages',
              style: TextStyle(
                color: pv.pvText,
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
