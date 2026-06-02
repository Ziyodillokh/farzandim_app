import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/error_state_view.dart';
import '../../core/widgets/skeletons.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _search = TextEditingController();
  final _api = AdminApi();
  Timer? _debounce;

  String _roleFilter = '';
  String _statusFilter = '';
  String _planFilter = '';
  int _page = 1;
  static const _pageSize = 20;

  late Future<AdminUsersPageResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _search.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() {
        _page = 1;
        _future = _load();
      });
    });
  }

  Future<AdminUsersPageResult> _load() {
    return _api.fetchUsers(
      q: _search.text.trim(),
      role: _roleFilter,
      status: _statusFilter,
      plan: _planFilter,
      page: _page,
      limit: _pageSize,
    );
  }

  void _retry() {
    setState(() => _future = _load());
  }

  Future<void> _onRefresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _applyFilters() {
    setState(() {
      _page = 1;
      _future = _load();
    });
  }

  String _fmtAgo(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final t = DateTime.tryParse(iso);
    if (t == null) return '—';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'hozirgina';
    if (d.inMinutes < 60) return '${d.inMinutes} daqiqa oldin';
    if (d.inHours < 24) return '${d.inHours} soat oldin';
    if (d.inDays < 30) return '${d.inDays} kun oldin';
    final mo = d.inDays ~/ 30;
    return mo < 1 ? '1 oy oldin' : '$mo oy oldin';
  }

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p[0].substring(0, 1).toUpperCase();
    return '${p[0][0]}${p[1][0]}'.toUpperCase();
  }

  Future<void> _openDetails(_UserVm u) async {
    try {
      final raw = u.kind == 'child'
          ? await _api.getChildProfile(u.id)
          : await _api.getUserById(u.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(u.name),
          content: SingleChildScrollView(
            child: SelectableText(
              JsonEncoder.withIndent('  ').convert(raw),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Yopish')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maʼlumot yuklanmadi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final minH = MediaQuery.sizeOf(context).height - 220;
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Foydalanuvchilar',
              style: AppTextStyles.pageTitle.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ),
          LayoutBuilder(
            builder: (context, c) {
              // Breakpoint'lar: wide ≥1200 — search + 3 dropdown bir qatorda
              //                  med  ≥760  — search + dropdowns wrap qiladi
              //                  narrow      — hammasi vertikal
              final wide = c.maxWidth >= 1200;
              final medium = c.maxWidth >= 760;
              final filters = <Widget>[
                AppFilterDropdown(
                  hint: 'Barcha rollar',
                  selectedValue: _roleFilter,
                  width: 180,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Barcha rollar')),
                    DropdownMenuItem(value: 'parent', child: Text('Ota-ona')),
                    DropdownMenuItem(value: 'child', child: Text('Bola')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _roleFilter = v ?? '';
                      _applyFilters();
                    });
                  },
                ),
                AppFilterDropdown(
                  hint: 'Barcha statuslar',
                  selectedValue: _statusFilter,
                  width: 180,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Barcha statuslar')),
                    DropdownMenuItem(value: 'active', child: Text('Aktiv')),
                    DropdownMenuItem(value: 'blocked', child: Text('Bloklangan')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _statusFilter = v ?? '';
                      _applyFilters();
                    });
                  },
                ),
                AppFilterDropdown(
                  hint: 'Barcha obunalar',
                  selectedValue: _planFilter,
                  width: 180,
                  prefix: const Icon(Icons.filter_list_rounded, size: 20),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Barcha obunalar')),
                    DropdownMenuItem(value: 'premium', child: Text('Premium')),
                    DropdownMenuItem(value: 'free', child: Text('Free')),
                    DropdownMenuItem(value: 'basic', child: Text('Basic')),
                    DropdownMenuItem(value: 'standard', child: Text('Standart')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _planFilter = v ?? '';
                      _applyFilters();
                    });
                  },
                ),
              ];

              final search = SearchField(
                controller: _search,
                width: wide ? null : double.infinity,
                onChanged: (_) {},
              );

              if (wide) {
                // Search Expanded + 3 dropdown bir qatorda (≥1200px)
                final children = <Widget>[Expanded(child: search)];
                for (final f in filters) {
                  children.add(const SizedBox(width: AppSpacing.sm));
                  children.add(f);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: children,
                );
              }
              if (medium) {
                // ≥760px lekin <1200px — search yuqorida full-width,
                // filterlar pastda Wrap qatorida.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: filters,
                    ),
                  ],
                );
              }
              // Mobil — hammasi vertikal stretch
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: AppSpacing.sm),
                  ...filters.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      // Mobil ekranda dropdown to'liq kenglikda
                      child: SizedBox(width: double.infinity, child: f),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: minH.clamp(360, 2400),
                  child: FutureBuilder<AdminUsersPageResult>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const UsersTableSkeleton();
                      }
                      if (snapshot.hasError) {
                        return AppErrorStateView(
                          error: snapshot.error!,
                          onRetry: _retry,
                        );
                      }
                      final data = snapshot.data!;
                      if (data.items.isEmpty) {
                        return const EmptyStateView(
                          title: 'Foydalanuvchi topilmadi',
                          subtitle: 'Filtr yoki qidiruvni o\'zgartirib ko\'ring',
                        );
                      }

                      final rows = data.items.map((j) => _UserVm.fromJson(j)).toList();

                      return Column(
                        children: [
                          Expanded(
                            child: AppTable(
                              dataRowMinHeight: 72,
                              dataRowMaxHeight: 88,
                              columns: const [
                                DataColumn(label: Text('Ism familiya')),
                                DataColumn(label: Text('Telefon raqami')),
                                DataColumn(label: Text('Rol')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Obuna')),
                                DataColumn(label: Text('Ohirgi faolligi')),
                                DataColumn(label: Text('')),
                              ],
                              rows: rows.map((u) {
                                final active = u.statusLabel == 'Aktiv';
                                final phone = u.phone ?? '—';
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                            child: Text(
                                              _initials(u.name),
                                              style: const TextStyle(
                                                color: Color(0xFF4338CA),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  u.name,
                                                  style: AppTextStyles.body.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (u.email != null && u.email!.isNotEmpty)
                                                  Text(
                                                    u.email!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              phone,
                                              style: AppTextStyles.body,
                                            ),
                                          ),
                                          if (phone != '—')
                                            IconButton(
                                              tooltip: 'Nusxalash',
                                              icon: const Icon(Icons.copy_rounded, size: 18),
                                              onPressed: () async {
                                                await Clipboard.setData(ClipboardData(text: phone));
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Nusxalandi')),
                                                  );
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                    DataCell(RoleBadge(label: u.roleLabel)),
                                    DataCell(StatusBadge(label: u.statusLabel, good: active)),
                                    DataCell(Text(u.planLabel, style: AppTextStyles.body)),
                                    DataCell(Text(_fmtAgo(u.lastActivityAt), style: AppTextStyles.body)),
                                    DataCell(
                                      AppSecondaryButton(
                                        onPressed: () => _openDetails(u),
                                        label: 'Batafsil',
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          // Pagination: faqat totalPages > 1 bo'lganda ko'rsatamiz
                          if (data.totalPages > 1) ...[
                            const SizedBox(height: AppSpacing.sm),
                            AppPagination(
                              page: data.page,
                              totalPages: data.totalPages,
                              onPrev: data.page > 1
                                  ? () => setState(() {
                                        _page = data.page - 1;
                                        _future = _load();
                                      })
                                  : null,
                              onNext: data.page < data.totalPages
                                  ? () => setState(() {
                                        _page = data.page + 1;
                                        _future = _load();
                                      })
                                  : null,
                            ),
                          ],
                        ],
                      );
                    },
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

class _UserVm {
  final String id;
  final String kind;
  final String name;
  final String? email;
  final String? phone;
  final String roleLabel;
  final String statusLabel;
  final String planLabel;
  final String? lastActivityAt;

  const _UserVm({
    required this.id,
    required this.kind,
    required this.name,
    required this.email,
    required this.phone,
    required this.roleLabel,
    required this.statusLabel,
    required this.planLabel,
    required this.lastActivityAt,
  });

  factory _UserVm.fromJson(Map<String, dynamic> json) {
    final kind = (json['kind'] ?? 'parent').toString().toLowerCase();
    final role = (json['role'] ?? '').toString().toUpperCase();
    final roleLabel = role == 'CHILD' || kind == 'child' ? 'Bola' : 'Ota-ona';
    final st = (json['status'] ?? 'active').toString().toLowerCase();
    final statusLabel = st == 'active' ? 'Aktiv' : 'Bloklangan';
    final planLabel = (json['planLabel'] ?? 'Free').toString();
    return _UserVm(
      id: (json['id'] ?? '').toString(),
      kind: kind,
      name: (json['name'] ?? '—').toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      roleLabel: roleLabel,
      statusLabel: statusLabel,
      planLabel: planLabel,
      lastActivityAt: json['lastActivityAt']?.toString(),
    );
  }
}

