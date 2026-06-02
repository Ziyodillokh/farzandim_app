import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/admin_api.dart';
import '../../core/network/admin_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ux/app_error_handler.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/error_state_view.dart';
import '../../core/widgets/skeletons.dart';
import 'staff_permissions.dart';

class ModeratorsPage extends StatefulWidget {
  const ModeratorsPage({super.key});

  @override
  State<ModeratorsPage> createState() => _ModeratorsPageState();
}

class _ModeratorsPageState extends State<ModeratorsPage> {
  final _search = TextEditingController();
  final _api = AdminApi();
  Timer? _debounce;
  String _roleFilter = '';
  String _statusFilter = '';
  int _page = 1;
  static const _pageSize = 20;

  late Future<AdminModeratorsPageResult> _future;

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
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _page = 1;
        _future = _load();
      });
    });
  }

  Future<AdminModeratorsPageResult> _load() {
    return _api.fetchModerators(
      q: _search.text.trim(),
      role: _roleFilter,
      status: _statusFilter,
      page: _page,
      limit: _pageSize,
    );
  }

  void _applyFilters() {
    setState(() {
      _page = 1;
      _future = _load();
    });
  }

  String _ago(String? iso) {
    if (iso == null || iso.isEmpty) {
      return '—';
    }
    final t = DateTime.tryParse(iso);
    if (t == null) {
      return '—';
    }
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) {
      return 'hozirgina';
    }
    if (d.inMinutes < 60) {
      return '${d.inMinutes} daqiqa oldin';
    }
    if (d.inHours < 24) {
      return '${d.inHours} soat oldin';
    }
    if (d.inDays < 7) {
      return '${d.inDays} kun oldin';
    }
    if (d.inDays < 30) {
      final w = d.inDays ~/ 7;
      return w < 1 ? '1 hafta oldin' : '$w hafta oldin';
    }
    final mo = d.inDays ~/ 30;
    return mo < 1 ? '1 oy oldin' : '$mo oy oldin';
  }

  String _roleLabel(String? key) {
    if (key == null || key.isEmpty) {
      return '—';
    }
    for (final e in kModeratorRoleChoices) {
      if (e.key == key) {
        return e.value;
      }
    }
    return key;
  }

  Color _roleColor(String? key) {
    switch (key) {
      case 'super_admin':
        return const Color(0xFF7DD3FC);
      case 'finance':
        return const Color(0xFFC4B5FD);
      case 'content_maker':
        return const Color(0xFF93C5FD);
      case 'support':
        return const Color(0xFFE9D5FF);
      default:
        return const Color(0xFFDDD6FE);
    }
  }

  Color _roleText(String? key) {
    switch (key) {
      case 'super_admin':
        return const Color(0xFF0369A1);
      case 'finance':
        return const Color(0xFF5B21B6);
      case 'content_maker':
        return const Color(0xFF1D4ED8);
      case 'support':
        return const Color(0xFF6B21A8);
      default:
        return const Color(0xFF4C1D95);
    }
  }

  String _initials(String name) {
    final p = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (p.isEmpty) {
      return '?';
    }
    if (p.length == 1) {
      return p[0].substring(0, 1).toUpperCase();
    }
    return '${p[0][0]}${p[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AdminSession.isStaffAdmin;
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Moderatorlar',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isAdmin)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => context.go('/moderators/new'),
                  child: const Text("Moderator qo‘shish"),
                ),
            ],
          ),
          if (!isAdmin) ...[
            const SizedBox(height: 8),
            Text(
              'Faqat admin moderatorlarni boshqarishi mumkin',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final search = _SearchField(ctrl: _search);
              final r1 = AppFilterDropdown(
                hint: 'Barcha rollar',
                selectedValue: _roleFilter,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Barcha rollar'),
                  ),
                  ...kModeratorRoleChoices.map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _roleFilter = v ?? '';
                    _applyFilters();
                  });
                },
              );
              final st = AppFilterDropdown(
                hint: 'Barcha statuslar',
                selectedValue: _statusFilter,
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
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: search),
                    const SizedBox(width: 12),
                    SizedBox(width: 200, child: r1),
                    const SizedBox(width: 12),
                    SizedBox(width: 200, child: st),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 200,
                      child: AppFilterDropdown(
                        hint: 'Barcha statuslar',
                        selectedValue: '',
                        items: const [
                          DropdownMenuItem(
                            value: '',
                            child: Text('Barcha statuslar'),
                          ),
                        ],
                        onChanged: (_) {},
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: 8),
                  r1,
                  const SizedBox(height: 8),
                  st,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isAdmin
                ? _table()
                : const Center(child: Text('Huquq yetarli emas')),
          ),
        ],
      ),
    );
  }

  Widget _table() {
    return FutureBuilder<AdminModeratorsPageResult>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorStateView(
            error: snap.error!,
            onRetry: () => setState(() => _future = _load()),
          );
        }
        if (!snap.hasData) {
          return const UsersTableSkeleton();
        }
        final data = snap.data!;
        if (data.items.isEmpty) {
          return const EmptyStateView(
            title: 'Moderator topilmadi',
            subtitle: 'Qidiruv yoki filtrni o‘zgartiring',
          );
        }
        return Column(
          children: [
            Expanded(
              child: AppCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF9FAFB),
                      ),
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 64,
                      headingRowHeight: 56,
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(
                          label: Text(
                            "Ism familiya",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Telefon raqami',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Rol',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Ohirgi faolligi',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataColumn(label: Text('')),
                      ],
                      rows: data.items.map((m) {
                        final name = '${m['name'] ?? "—"}';
                        final email = '${m['email'] ?? ""}';
                        final phone = (m['phone'] as String?)?.trim() ?? '—';
                        final rKey = m['moderatorRoleKey'] as String?;
                        final st = m['status'] as String? ?? 'active';
                        final last = m['lastActivityAt'] as String?;
                        final id = '${m['id']}';
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFFE5E7EB),
                                    child: Text(
                                      _initials(name),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (email.isNotEmpty)
                                          Text(
                                            email,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              phone == '—'
                                  ? const Text('—')
                                  : _PhoneCell(phone: phone),
                            ),
                            DataCell(
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 120,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _roleColor(rKey),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _roleLabel(rKey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _roleText(rKey),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                st == 'blocked' ? 'Bloklangan' : 'Aktiv',
                                style: TextStyle(
                                  color: st == 'blocked'
                                      ? const Color(0xFFFF5722)
                                      : const Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _ago(last),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Tahrirlash',
                                    onPressed: () =>
                                        context.go('/moderators/new?id=$id'),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: st == 'blocked'
                                        ? 'Blokdan chiqarish'
                                        : 'Bloklash',
                                    onPressed: () =>
                                        _blockToggle(id, st != 'blocked'),
                                    icon: Icon(
                                      Icons.remove_circle_outline_rounded,
                                      size: 20,
                                      color: st == 'blocked'
                                          ? AppColors.textSecondary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: "O'chirish",
                                    onPressed: () => _confirmDelete(id, name),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Sahifa ${data.page} / ${data.totalPages} · ${data.total} ta',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: data.page > 1
                      ? () => setState(() {
                          _page = data.page - 1;
                          _future = _load();
                        })
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  onPressed: data.page < data.totalPages
                      ? () => setState(() {
                          _page = data.page + 1;
                          _future = _load();
                        })
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _blockToggle(String id, bool block) async {
    try {
      if (block) {
        await _api.blockModerator(id);
      } else {
        await _api.unblockModerator(id);
      }
      if (!mounted) {
        return;
      }
      setState(() => _future = _load());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorHandler.userMessage(e))));
      }
    }
  }

  Future<void> _confirmDelete(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Moderatorni o'chirish"),
        content: Text('"$name" o‘chirilsinmi? (soft delete)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Bekor'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await _api.deleteModerator(id);
      if (!mounted) {
        return;
      }
      setState(() => _future = _load());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorHandler.userMessage(e))));
      }
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.ctrl});
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 22,
          color: AppColors.textSecondary,
        ),
        hintText: 'Qidiruv',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class _PhoneCell extends StatelessWidget {
  const _PhoneCell({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(phone, style: const TextStyle(fontSize: 14))),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(maxWidth: 32, minWidth: 32),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: phone));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Nusxa olindi'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          icon: const Icon(
            Icons.copy_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
