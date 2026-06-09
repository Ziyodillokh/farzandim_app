import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/error_state_view.dart';

// Sprint 5.x — Audit log viewer (admin actions tracker).

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final _api = AdminApi();
  bool _loading = true;
  String? _error;
  List<_AuditEvent> _items = [];
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  final int _limit = 50;

  // Filters
  String? _action;
  String? _status;
  List<String> _actionOptions = [];

  @override
  void initState() {
    super.initState();
    _loadActions();
    _loadPage();
  }

  Future<void> _loadActions() async {
    try {
      final actions = await _api.fetchAuditActions();
      if (!mounted) return;
      setState(() => _actionOptions = actions);
    } catch (_) {/* ignore */}
  }

  Future<void> _loadPage({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final d = await _api.fetchAuditLog(
        page: _page,
        limit: _limit,
        action: _action,
        status: _status,
      );
      if (!mounted) return;
      final items = (d['items'] as List?)?.cast<dynamic>() ?? const [];
      final pag = (d['pagination'] as Map?)?.cast<String, dynamic>() ?? const {};
      setState(() {
        _items = items
            .whereType<Map<String, dynamic>>()
            .map(_AuditEvent.fromJson)
            .toList();
        _totalPages = (pag['totalPages'] as num?)?.toInt() ?? 1;
        _total = (pag['total'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _goPage(int p) {
    if (p < 1 || p > _totalPages || p == _page) return;
    setState(() => _page = p);
    _loadPage();
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
                    const SectionTitle('Audit log'),
                    if (_total > 0)
                      Text('$_total ta yozuv',
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Yangilash',
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : () { _page = 1; _loadPage(); },
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
                width: 260,
                child: DropdownButtonFormField<String?>(
                  initialValue: _action,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Action',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Hammasi'),
                    ),
                    ..._actionOptions.map(
                      (a) => DropdownMenuItem<String?>(
                        value: a,
                        child: Text(a, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() { _action = v; _page = 1; });
                    _loadPage();
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('Hammasi')),
                    DropdownMenuItem<String?>(value: 'success', child: Text('Success')),
                    DropdownMenuItem<String?>(value: 'failure', child: Text('Failure')),
                  ],
                  onChanged: (v) {
                    setState(() { _status = v; _page = 1; });
                    _loadPage();
                  },
                ),
              ),
              if (_action != null || _status != null)
                ActionChip(
                  label: const Text('Filtrlarni tozalash'),
                  onPressed: () {
                    setState(() { _action = null; _status = null; _page = 1; });
                    _loadPage();
                  },
                ),
            ],
          ),
        ),

        const Divider(height: 1),
        Expanded(child: _buildTable()),
        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }

  Widget _buildTable() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AppErrorStateView(error: _error!, onRetry: _loadPage);
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Audit log bo\'sh.'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _AuditRow(event: _items[i]),
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
            onPressed: _page < _totalPages ? () => _goPage(_page + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.event});
  final _AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final isFailure = event.status == 'failure';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator
          Container(
            margin: const EdgeInsets.only(top: 4, right: 12),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isFailure ? AppColors.danger : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SelectableText(
                      event.action,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (event.resourceType != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.resourceType!,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.blue),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  children: [
                    if (event.email != null)
                      Text(event.email!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    if (event.resourceId != null)
                      Text('→ ${event.resourceId!.substring(0, 8)}...',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace')),
                    if (event.ipAddress != null)
                      Text(event.ipAddress!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                  ],
                ),
                if (event.details != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.details!,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            event.fmtTime,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AuditEvent {
  final String id;
  final String? moderatorId;
  final String? email;
  final String action;
  final String? resourceType;
  final String? resourceId;
  final String status;
  final String? ipAddress;
  final String? details;
  final DateTime createdAt;

  _AuditEvent({
    required this.id,
    required this.action,
    required this.status,
    required this.createdAt,
    this.moderatorId,
    this.email,
    this.resourceType,
    this.resourceId,
    this.ipAddress,
    this.details,
  });

  factory _AuditEvent.fromJson(Map<String, dynamic> j) {
    return _AuditEvent(
      id: j['id']?.toString() ?? '',
      moderatorId: j['moderatorId']?.toString(),
      email: j['email']?.toString(),
      action: j['action']?.toString() ?? '?',
      resourceType: j['resourceType']?.toString(),
      resourceId: j['resourceId']?.toString(),
      status: j['status']?.toString() ?? 'success',
      ipAddress: j['ipAddress']?.toString(),
      details: j['details']?.toString(),
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  String get fmtTime {
    final local = createdAt.toLocal();
    return DateFormat('dd.MM HH:mm').format(local);
  }
}
