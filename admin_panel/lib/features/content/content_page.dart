import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ux/app_error_handler.dart';
import '../../core/ux/app_feedback.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/error_state_view.dart';
import '../../core/widgets/skeletons.dart';
import 'video_upload/video_upload_modal.dart';

class ContentPage extends StatefulWidget {
  const ContentPage({super.key});

  @override
  State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  final _api = AdminApi();
  final _search = TextEditingController();
  Timer? _debounce;
  Timer? _poll;

  List<Map<String, dynamic>> _categories = [];
  String _status = '';
  String _categoryId = '';
  String _plan = '';
  String _level = '';
  int _page = 1;
  final int _limit = 10;

  bool _loading = true;
  String? _error;
  List<_VideoRowVm> _items = [];
  int _totalPages = 1;
  int _total = 0;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      _loadVideos(silent: true);
    });
  }

  Future<void> _bootstrap() async {
    await _loadCategories();
    await _loadVideos();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final c = await _api.fetchVideoCategories();
      if (!mounted) return;
      setState(() => _categories = c);
    } catch (_) {
      /* list still works without categories */
    }
  }

  Future<void> _loadVideos({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await _api.fetchVideos(
        q: _search.text.trim().isEmpty ? null : _search.text.trim(),
        status: _status.isEmpty ? null : _status,
        categoryId: _categoryId.isEmpty ? null : _categoryId,
        planRequired: _plan.isEmpty ? null : _plan,
        level: _level.isEmpty ? null : _level,
        page: _page,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _items = r.items.map(_VideoRowVm.fromJson).toList();
        _page = r.page;
        _totalPages = r.totalPages;
        _total = r.total;
        _selected.removeWhere((id) => !_items.any((e) => e.id == id));
        _error = null;
        if (!silent) _loading = false;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _bulk(String action) async {
    if (_selected.isEmpty) return;
    try {
      await _api.bulkVideos(_selected.toList(), action);
      if (!mounted) return;
      setState(() => _selected.clear());
      AppFeedback.success(context, 'Tanlangan videolar yangilandi');
      await _loadVideos();
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showError(context, e);
    }
  }

  Future<void> _setFeatured(_VideoRowVm v, bool featured) async {
    try {
      await _api.patchVideo(v.id, featured: featured);
      if (!mounted) return;
      await _loadVideos(silent: true);
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showError(context, e);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _page = 1;
      _loadVideos();
    });
  }

  Future<void> _approve(String id) async {
    try {
      await _api.approveVideo(id);
      if (!mounted) return;
      AppFeedback.success(context, 'Video aktivlashtirildi');
      await _loadVideos();
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showError(context, e, onRetry: () => _approve(id));
    }
  }

  Future<void> _reject(String id) async {
    try {
      await _api.rejectVideo(id);
      if (!mounted) return;
      AppFeedback.success(context, 'Video yashirildi');
      await _loadVideos();
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showError(context, e, onRetry: () => _reject(id));
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _api.deleteVideo(id);
      if (!mounted) return;
      AppFeedback.success(context, 'Video o‘chirildi');
      await _loadVideos();
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showError(context, e, onRetry: () => _delete(id));
    }
  }

  Future<void> _openUpload() async {
    final created = await VideoUploadModal.open(
      context,
      categories: _categories,
      api: _api,
    );
    if (!mounted || created == null || created.isEmpty) return;
    await _loadVideos();
    if (!mounted) return;
    AppFeedback.success(context, 'Video qo‘shildi');
  }

  void _goPage(int p) {
    if (p < 1 || p > _totalPages || p == _page) return;
    setState(() => _page = p);
    _loadVideos();
  }

  bool? get _allSelectedValue {
    if (_items.isEmpty || _selected.isEmpty) return false;
    if (_selected.length == _items.length) return true;
    return null;
  }

  void _toggleAll(bool? v) {
    setState(() {
      if (v == true) {
        _selected
          ..clear()
          ..addAll(_items.map((e) => e.id));
      } else {
        _selected.clear();
      }
    });
  }

  void _toggleRow(String id, bool? v) {
    setState(() {
      if (v == true) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nums = NumberFormat.decimalPattern('en_US');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Videolar',
          subtitle: '$_total ta video',
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: _openUpload,
            child: const Text('Video joylash'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilterBar(
          children: [
            SearchField(
              controller: _search,
              width: 360,
              onChanged: _onSearchChanged,
            ),
            AppFilterDropdown(
              hint: 'Barcha kategoriyalar',
              selectedValue: _categoryId.isEmpty ? _allSentinel : _categoryId,
              items: [
                const DropdownMenuItem(
                  value: _allSentinel,
                  child: Text('Barcha kategoriyalar'),
                ),
                ..._categories.map(
                  (c) => DropdownMenuItem(
                    value: c['id']?.toString() ?? '',
                    child: Text(c['name']?.toString() ?? ''),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _categoryId = v == _allSentinel || v == null ? '' : v;
                  _page = 1;
                });
                _loadVideos();
              },
            ),
            AppFilterDropdown(
              hint: 'Barcha statuslar',
              selectedValue: _status.isEmpty ? _allSentinel : _status,
              items: const [
                DropdownMenuItem(
                  value: _allSentinel,
                  child: Text('Barcha statuslar'),
                ),
                DropdownMenuItem(value: 'approved', child: Text('Aktiv')),
                DropdownMenuItem(value: 'hidden', child: Text('Yashirin')),
              ],
              onChanged: (v) {
                setState(() {
                  _status = v == _allSentinel || v == null ? '' : v;
                  _page = 1;
                });
                _loadVideos();
              },
            ),
            AppFilterDropdown(
              hint: 'Barcha obunalar',
              selectedValue: _plan.isEmpty ? _allSentinel : _plan,
              prefix: const Icon(Icons.filter_alt_outlined, size: 18),
              items: const [
                DropdownMenuItem(
                  value: _allSentinel,
                  child: Text('Barcha obunalar'),
                ),
                DropdownMenuItem(value: 'free', child: Text('Free')),
                DropdownMenuItem(value: 'standard', child: Text('Standard')),
                DropdownMenuItem(value: 'premium', child: Text('Premium')),
              ],
              onChanged: (v) {
                setState(() {
                  _plan = v == _allSentinel || v == null ? '' : v;
                  _page = 1;
                });
                _loadVideos();
              },
            ),
            AppFilterDropdown(
              hint: 'Barcha darajalar',
              selectedValue: _level.isEmpty ? _allSentinel : _level,
              items: const [
                DropdownMenuItem(
                  value: _allSentinel,
                  child: Text('Barcha darajalar'),
                ),
                DropdownMenuItem(value: 'school', child: Text('Maktab')),
                DropdownMenuItem(value: 'university', child: Text('Oliygoh')),
                DropdownMenuItem(value: 'both', child: Text('Ikkalasi')),
              ],
              onChanged: (v) {
                setState(() {
                  _level = v == _allSentinel || v == null ? '' : v;
                  _page = 1;
                });
                _loadVideos();
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${_selected.length} ta tanlangan',
                  style: AppTextStyles.pageSubtitle,
                ),
                AppSecondaryButton(
                  label: 'Aktivlashtirish',
                  onPressed: () => _bulk('approve'),
                ),
                AppSecondaryButton(
                  label: 'Yashirish',
                  onPressed: () => _bulk('hide'),
                ),
                AppDangerButton(
                  label: 'O‘chirish',
                  onPressed: () => _bulk('delete'),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadVideos(),
            child: _loading && _items.isEmpty
                ? const SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: SizedBox(height: 420, child: ContentListSkeleton()),
                  )
                : _error != null && _items.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 400,
                      child: AppErrorStateView(
                        error: _error!,
                        onRetry: _loadVideos,
                        title: 'Videolar yuklanmadi',
                      ),
                    ),
                  )
                : _items.isEmpty
                ? const SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 360,
                      child: EmptyStateView(
                        title: 'Video topilmadi',
                        subtitle: 'Filtr yoki qidiruvni o‘zgartirib ko‘ring',
                      ),
                    ),
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      AppTable(
                        dataRowMinHeight: 72,
                        dataRowMaxHeight: 88,
                        columns: [
                          DataColumn(
                            label: Checkbox(
                              value: _allSelectedValue,
                              tristate: true,
                              onChanged: _toggleAll,
                            ),
                          ),
                          const DataColumn(label: Text('Video')),
                          const DataColumn(label: Text('Nomi')),
                          const DataColumn(label: Text('Yosh chegarasi')),
                          const DataColumn(label: Text('Qo‘shilgan sana')),
                          const DataColumn(label: Text('Status')),
                          const DataColumn(label: Text('Statistika')),
                          const DataColumn(label: Text('')),
                        ],
                        rows: _items.map((v) {
                          final st = v.statusKey == 'approved';
                          return DataRow(
                            cells: [
                              DataCell(
                                Checkbox(
                                  value: _selected.contains(v.id),
                                  onChanged: (x) => _toggleRow(v.id, x),
                                ),
                              ),
                              DataCell(_ThumbCell(vm: v)),
                              DataCell(
                                SizedBox(
                                  width: 220,
                                  child: Row(
                                    children: [
                                      if (v.featured)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(
                                            Icons.star,
                                            color: Color(0xFFD97706),
                                            size: 18,
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          v.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.sectionTitle
                                              .copyWith(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(Text(v.ageRange)),
                              DataCell(Text(v.createdDate)),
                              DataCell(
                                StatusBadge(label: v.statusUz, good: st),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.visibility_outlined,
                                      size: 16,
                                      color: Colors.grey.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      nums.format(v.views),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.thumb_up_alt_outlined,
                                      size: 16,
                                      color: Colors.grey.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      nums.format(v.likes),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'approve':
                                        _approve(v.id);
                                      case 'reject':
                                        _reject(v.id);
                                      case 'feat_on':
                                        _setFeatured(v, true);
                                      case 'feat_off':
                                        _setFeatured(v, false);
                                      case 'delete':
                                        _delete(v.id);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    if (v.statusKey != 'approved')
                                      const PopupMenuItem(
                                        value: 'approve',
                                        child: Text('Aktivlashtirish'),
                                      ),
                                    if (v.statusKey == 'approved')
                                      const PopupMenuItem(
                                        value: 'reject',
                                        child: Text('Yashirish'),
                                      ),
                                    if (!v.featured)
                                      const PopupMenuItem(
                                        value: 'feat_on',
                                        child: Text('Featured yoqish'),
                                      ),
                                    if (v.featured)
                                      const PopupMenuItem(
                                        value: 'feat_off',
                                        child: Text('Featured o‘chirish'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('O‘chirish'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                      if (_totalPages > 1) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _PaginationBar(
                          page: _page,
                          totalPages: _totalPages,
                          onPage: _goPage,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

const _allSentinel = '__all__';

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.onPage,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    final pages = <int>{1, totalPages, page, page - 1, page + 1}
      ..removeWhere((p) => p < 1 || p > totalPages);
    final sorted = pages.toList()..sort();
    int? prev;
    for (final p in sorted) {
      if (prev != null && p - prev > 1) {
        chips.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('...', style: TextStyle(color: Colors.grey.shade600)),
          ),
        );
      }
      final selected = p == page;
      chips.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: InkWell(
            onTap: () => onPage(p),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.backgroundAlt : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '$p',
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
      prev = p;
    }

    return Row(
      children: [
        TextButton.icon(
          onPressed: page > 1 ? () => onPage(page - 1) : null,
          icon: const Icon(Icons.chevron_left, size: 20),
          label: const Text('Oldingi'),
        ),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: chips,
          ),
        ),
        TextButton.icon(
          onPressed: page < totalPages ? () => onPage(page + 1) : null,
          icon: const Icon(Icons.chevron_right, size: 20),
          label: const Text('Keyingisi'),
        ),
      ],
    );
  }
}

class _ThumbCell extends StatelessWidget {
  const _ThumbCell({required this.vm});
  final _VideoRowVm vm;

  @override
  Widget build(BuildContext context) {
    final dur = vm.durationLabel;
    return SizedBox(
      width: 112,
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (vm.thumbnail != null && vm.thumbnail!.isNotEmpty)
              Image.network(
                vm.thumbnail!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: Colors.grey.shade300),
              )
            else
              Container(color: Colors.grey.shade300),
            Container(
              color: Colors.black26,
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            if (dur.isNotEmpty)
              Positioned(
                right: 6,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    dur,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoRowVm {
  final String id;
  final String title;
  final String ageRange;
  final String statusKey;
  final String statusUz;
  final String createdDate;
  final int views;
  final int likes;
  final bool featured;
  final String? thumbnail;
  final int? durationSec;

  const _VideoRowVm({
    required this.id,
    required this.title,
    required this.ageRange,
    required this.statusKey,
    required this.statusUz,
    required this.createdDate,
    required this.views,
    required this.likes,
    this.featured = false,
    this.thumbnail,
    this.durationSec,
  });

  String get durationLabel {
    final s = durationSec;
    if (s == null || s <= 0) return '';
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  factory _VideoRowVm.fromJson(Map<String, dynamic> json) {
    final af = (json['ageFrom'] as num?)?.toInt();
    final at = (json['ageTo'] as num?)?.toInt();
    final raw = (json['status'] ?? '').toString().toLowerCase();
    final active = raw == 'approved';
    final created = json['createdAt']?.toString();
    DateTime? dt;
    if (created != null) {
      dt = DateTime.tryParse(created);
    }
    final dateStr = dt != null
        ? DateFormat('yyyy-MM-dd').format(dt.toLocal())
        : '-';

    return _VideoRowVm(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '-').toString(),
      ageRange: (af != null && at != null) ? '$af-$at' : '-',
      statusKey: raw,
      statusUz: active ? 'Aktiv' : 'Yashirin',
      createdDate: dateStr,
      views: (json['views'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      featured: json['featured'] == true,
      thumbnail: json['thumbnail']?.toString(),
      durationSec: (json['durationSec'] as num?)?.toInt(),
    );
  }
}
