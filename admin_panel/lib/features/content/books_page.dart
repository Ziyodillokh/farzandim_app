import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ux/app_error_handler.dart';
import '../../core/ux/app_feedback.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/error_state_view.dart';
import '../../core/widgets/skeletons.dart' show ContentListSkeleton;
import 'book_upload/book_upload_modal.dart';

// ─── ViewModel ───────────────────────────────────────────────────────────────

class _BookVm {
  final String id;
  final String title;
  final String author;
  final String category;
  final String ageRange;
  final int pages;
  final String planRequired;
  final String statusKey;
  final String statusUz;
  final String createdDate;
  final String? coverUrl;
  final String? pdfUrl;

  const _BookVm({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.ageRange,
    required this.pages,
    required this.planRequired,
    required this.statusKey,
    required this.statusUz,
    required this.createdDate,
    this.coverUrl,
    this.pdfUrl,
  });

  factory _BookVm.fromJson(Map<String, dynamic> j) {
    final status = j['status']?.toString() ?? 'hidden';
    final statusUz = switch (status) {
      'approved' => 'Faol',
      'hidden' => 'Yashirin',
      'deleted' => "O'chirilgan",
      _ => status,
    };
    final createdAt = DateTime.tryParse(j['createdAt']?.toString() ?? '');
    return _BookVm(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      author: j['author']?.toString() ?? '',
      category: j['category']?.toString() ?? 'school',
      ageRange:
          '${j['ageFrom'] ?? 0}–${j['ageTo'] ?? 18}',
      pages: (j['pages'] as num?)?.toInt() ?? 0,
      planRequired: j['planRequired']?.toString() ?? 'free',
      statusKey: status,
      statusUz: statusUz,
      createdDate: createdAt != null
          ? DateFormat('dd.MM.yyyy').format(createdAt)
          : '',
      coverUrl: j['coverUrl']?.toString(),
      pdfUrl: j['pdfUrl']?.toString(),
    );
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  final _api = AdminApi();
  final _search = TextEditingController();
  Timer? _debounce;
  Timer? _poll;

  String _status = '';
  int _page = 1;
  final int _limit = 20;

  bool _loading = true;
  String? _error;
  List<_BookVm> _items = [];
  int _totalPages = 1;
  int _total = 0;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadRows();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadRows(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadRows({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final r = await _api.fetchBooks(
        q: _search.text.trim().isEmpty ? null : _search.text.trim(),
        status: _status.isEmpty ? null : _status,
        page: _page,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _items = r.items.map(_BookVm.fromJson).toList();
        _page = r.page;
        _totalPages = r.totalPages;
        _total = r.total;
        _selected.removeWhere((id) => !_items.any((e) => e.id == id));
        if (!silent) _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _page = 1;
      _loadRows();
    });
  }

  void _goPage(int p) {
    if (p < 1 || p > _totalPages || p == _page) return;
    setState(() => _page = p);
    _loadRows();
  }

  Future<void> _openCreate() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _BookFormDialog(api: _api),
    );
    if (!mounted || created != true) return;
    await _loadRows();
    if (!mounted) return;
    AppFeedback.success(context, 'Kitob qo\'shildi');
  }

  // Sprint 5.6d — multipart PDF upload modal
  Future<void> _openUpload() async {
    final created = await BookUploadModal.open(context, api: _api);
    if (!mounted || created == null) return;
    await _loadRows();
    if (!mounted) return;
    AppFeedback.success(context, 'PDF yuklandi');
  }

  Future<void> _openEdit(_BookVm book) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _BookFormDialog(api: _api, book: book),
    );
    if (!mounted || updated != true) return;
    await _loadRows();
  }

  Future<void> _approve(String id) async {
    try {
      await _api.approveBook(id);
      if (!mounted) return;
      AppFeedback.success(context, 'Aktivlashtirildi');
      await _loadRows();
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showError(context, e, onRetry: () => _approve(id));
    }
  }

  Future<void> _reject(String id) async {
    try {
      await _api.rejectBook(id);
      if (!mounted) return;
      AppFeedback.success(context, 'Rad etildi');
      await _loadRows();
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showError(context, e);
    }
  }

  Future<void> _delete(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kitobni o\'chirish'),
        content: Text('"$title" ni o\'chirmoqchimisiz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Bekor')),
          FilledButton(
          style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteBook(id);
      if (!mounted) return;
      AppFeedback.success(context, "O'chirildi");
      await _loadRows();
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Kitoblar / PDF'),
                    if (_total > 0)
                      Text('$_total ta kitob',
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openCreate,
                icon: const Icon(Icons.link, size: 18),
                label: const Text("URL bilan qo'shish"),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppPrimaryButton(
                label: '+ PDF yuklash',
                onPressed: _openUpload,
              ),
            ],
          ),
        ),

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Sarlavha yoki muallif...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _status.isEmpty ? null : _status,
                hint: const Text('Holat'),
                items: const [
                  DropdownMenuItem(value: 'approved', child: Text('Faol')),
                  DropdownMenuItem(value: 'hidden', child: Text('Yashirin')),
                ],
                onChanged: (v) {
                  setState(() { _status = v ?? ''; _page = 1; });
                  _loadRows();
                },
              ),
              if (_status.isNotEmpty)
                ActionChip(
                  label: const Text('Filtrni tozalash'),
                  onPressed: () {
                    setState(() { _status = ''; _page = 1; });
                    _loadRows();
                  },
                ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Table
        Expanded(child: _buildTable()),

        // Pagination
        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }

  Widget _buildTable() {
    if (_loading) return const ContentListSkeleton();
    if (_error != null) {
      return AppErrorStateView(
        error: _error!,
        onRetry: _loadRows,
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Kitoblar topilmadi.'),
        ),
      );
    }

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: AppSpacing.md,
          columns: const [
            DataColumn(label: Text('Muqova')),
            DataColumn(label: Text('Sarlavha')),
            DataColumn(label: Text('Muallif')),
            DataColumn(label: Text('Kategoriya')),
            DataColumn(label: Text('Yosh')),
            DataColumn(label: Text('Sahifalar')),
            DataColumn(label: Text('Tarif')),
            DataColumn(label: Text('Holat')),
            DataColumn(label: Text('Qo\'shildi')),
            DataColumn(label: Text('Amallar')),
          ],
          rows: _items.map((book) {
            final isActive = book.statusKey == 'approved';
            return DataRow(
              cells: [
                DataCell(_CoverCell(url: book.coverUrl)),
                DataCell(
                  SizedBox(
                    width: 180,
                    child: Text(book.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(Text(book.author,
                    overflow: TextOverflow.ellipsis)),
                DataCell(Text(book.category)),
                DataCell(Text(book.ageRange)),
                DataCell(Text('${book.pages}')),
                DataCell(_PlanBadge(plan: book.planRequired)),
                DataCell(_StatusBadge(
                    status: book.statusKey, label: book.statusUz)),
                DataCell(Text(book.createdDate)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Tahrirlash',
                      onPressed: () => _openEdit(book),
                    ),
                    if (!isActive)
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline_rounded,
                            color: Colors.green),
                        tooltip: 'Faollashtirish',
                        onPressed: () => _approve(book.id),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.pause_circle_outline_rounded,
                            color: Colors.orange),
                        tooltip: 'Yashirish',
                        onPressed: () => _reject(book.id),
                      ),
                    if (book.pdfUrl != null)
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        tooltip: 'PDF ko\'rish',
                        onPressed: () {
                          // open in new tab / browser if running on web
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      tooltip: "O'chirish",
                      onPressed: () => _delete(book.id, book.title),
                    ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _page > 1 ? () => _goPage(_page - 1) : null,
          ),
          Text('$_page / $_totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed:
                _page < _totalPages ? () => _goPage(_page + 1) : null,
          ),
        ],
      ),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _CoverCell extends StatelessWidget {
  const _CoverCell({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: 40,
        height: 48,
        color: Colors.grey.shade200,
        child: const Icon(Icons.menu_book_outlined,
            size: 20, color: Colors.grey),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Image.network(url!,
          width: 40,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(
                width: 40,
                height: 48,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image_outlined,
                    size: 18, color: Colors.grey),
              )),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => Colors.green,
      'hidden' => Colors.orange,
      _ => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.plan});
  final String plan;

  @override
  Widget build(BuildContext context) {
    final isPremium = plan != 'free';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPremium
            ? Colors.amber.withValues(alpha: 0.15)
            : Colors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        isPremium ? plan[0].toUpperCase() + plan.substring(1) : 'Bepul',
        style: TextStyle(
            color: isPremium ? Colors.amber.shade700 : Colors.blue,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Create/Edit modal ────────────────────────────────────────────────────────

class _BookFormDialog extends StatefulWidget {
  const _BookFormDialog({required this.api, this.book});
  final AdminApi api;
  final _BookVm? book;

  @override
  State<_BookFormDialog> createState() => _BookFormDialogState();
}

class _BookFormDialogState extends State<_BookFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _description;
  late final TextEditingController _pdfUrl;
  late final TextEditingController _coverUrl;
  late final TextEditingController _category;
  late final TextEditingController _pages;
  late final TextEditingController _ageFrom;
  late final TextEditingController _ageTo;
  String _planRequired = 'free';
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.book != null;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    _title = TextEditingController(text: b?.title ?? '');
    _author = TextEditingController(text: b?.author ?? '');
    _description = TextEditingController();
    _pdfUrl = TextEditingController(text: b?.pdfUrl ?? '');
    _coverUrl = TextEditingController(text: b?.coverUrl ?? '');
    _category = TextEditingController(text: b?.category ?? 'school');
    _pages = TextEditingController(text: b != null ? '${b.pages}' : '');
    _ageFrom = TextEditingController(
        text: b != null ? b.ageRange.split('–').first : '7');
    _ageTo = TextEditingController(
        text: b != null ? b.ageRange.split('–').last : '18');
    _planRequired = b?.planRequired ?? 'free';
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _description.dispose();
    _pdfUrl.dispose();
    _coverUrl.dispose();
    _category.dispose();
    _pages.dispose();
    _ageFrom.dispose();
    _ageTo.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final body = {
      'title': _title.text.trim(),
      'author': _author.text.trim(),
      if (_description.text.trim().isNotEmpty)
        'description': _description.text.trim(),
      'pdfUrl': _pdfUrl.text.trim(),
      if (_coverUrl.text.trim().isNotEmpty) 'coverUrl': _coverUrl.text.trim(),
      'category': _category.text.trim().isEmpty
          ? 'school'
          : _category.text.trim(),
      'pages': int.tryParse(_pages.text.trim()) ?? 1,
      'ageFrom': int.tryParse(_ageFrom.text.trim()) ?? 7,
      'ageTo': int.tryParse(_ageTo.text.trim()) ?? 18,
      'planRequired': _planRequired,
    };

    try {
      if (_isEdit) {
        await widget.api.updateBook(widget.book!.id, body);
      } else {
        await widget.api.createBook(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppErrorHandler.userMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(_isEdit ? 'Kitobni tahrirlash' : 'Yangi kitob qo\'shish'),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _field('Sarlavha *', _title,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Sarlavha majburiy'
                                : null),
                        _field('Muallif *', _author,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Muallif majburiy'
                                : null),
                        _field('Tavsif', _description, maxLines: 3),
                        _field('PDF URL *', _pdfUrl,
                            hint: 'https://...',
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'PDF URL majburiy';
                              }
                              if (!v.trim().startsWith('http')) {
                                return 'To\'g\'ri URL kiriting';
                              }
                              return null;
                            }),
                        _field('Muqova URL', _coverUrl,
                            hint: 'https://... (ixtiyoriy)'),
                        _field('Kategoriya', _category,
                            hint: 'school / literature / science'),
                        Row(
                          children: [
                            Expanded(
                                child: _field('Sahifalar *', _pages,
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      final n = int.tryParse(v ?? '');
                                      if (n == null || n < 1) {
                                        return 'Musbat son';
                                      }
                                      return null;
                                    })),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                                child: _field('Yosh dan', _ageFrom,
                                    keyboardType: TextInputType.number)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                                child: _field('Yosh gacha', _ageTo,
                                    keyboardType: TextInputType.number)),
                          ],
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _planRequired,
                          decoration:
                              const InputDecoration(labelText: 'Tarif'),
                          items: const [
                            DropdownMenuItem(
                                value: 'free', child: Text('Bepul')),
                            DropdownMenuItem(
                                value: 'standard',
                                child: Text('Standart')),
                            DropdownMenuItem(
                                value: 'premium',
                                child: Text('Premium')),
                          ],
                          onChanged: (v) =>
                              setState(() => _planRequired = v ?? 'free'),
                        ), // DropdownButtonFormField
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Bekor'),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AppPrimaryButton(
                    label: _saving
                        ? 'Saqlanmoqda...'
                        : (_isEdit ? 'Saqlash' : 'Qo\'shish'),
                    onPressed: _saving ? null : _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: validator,
      ),
    );
  }
}
