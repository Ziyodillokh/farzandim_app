import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/common.dart';

class MonetizationPaymentsPage extends StatefulWidget {
  const MonetizationPaymentsPage({super.key});

  @override
  State<MonetizationPaymentsPage> createState() =>
      _MonetizationPaymentsPageState();
}

class _MonetizationPaymentsPageState extends State<MonetizationPaymentsPage> {
  final _api = AdminApi();
  final _q = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _plans = [];
  String? _filterPlan;
  String? _method;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
    });
    try {
      final plans = await _api.listMonetizationPlans();
      if (!mounted) {
        return;
      }
      setState(() => _plans = plans);
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final rows = await _api.listMonetizationPayments(
        q: _q.text.trim().isEmpty ? null : _q.text.trim(),
        planId: _filterPlan,
        method: _method,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        const AdminPageHeader(
          title: "Payment tarixi",
          subtitle: "Monetizatsiya",
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _q,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Qidiruv',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _dd(
              value: _filterPlan,
              hint: 'Barcha tariflar',
              items: {
                for (final p in _plans)
                  p['id']?.toString() ?? '': p['name']?.toString() ?? '',
              },
              onChange: (v) {
                setState(() => _filterPlan = v);
                _load();
              },
            ),
            const SizedBox(width: 12),
            _dd(
              value: _method,
              hint: "Barcha to'lov usullar",
              items: const {
                'click': 'Click',
                'payme': 'Payme',
                'card': 'Karta (Click/Payme)',
              },
              onChange: (v) {
                setState(() => _method = v);
                _load();
              },
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else
          _Table(rows: _rows),
      ],
    );
  }

  Widget _dd({
    required String? value,
    required String hint,
    required Map<String, String> items,
    required void Function(String?)? onChange,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('(hammasi)')),
            ...items.entries.map(
              (e) => DropdownMenuItem<String?>(
                value: e.key,
                child: Text(
                  e.value,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
          onChanged: onChange,
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          "To'lovlar yo'q",
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(Colors.grey.shade100),
          columns: const [
            DataColumn(
              label: Text(
                "Foydalanuvchi",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                "Ota-ona hisobi",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                "Tarif",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                "Summa",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                "To'lov usuli",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                "Sana",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          rows: [
            for (final p in rows)
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      p['user']?['name']?.toString() ?? "—",
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  DataCell(
                    Text(
                      _parentAccount(p),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    Text(
                      p['catalogPlan']?['name']?.toString() ??
                          p['plan']?.toString() ??
                          "—",
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  DataCell(
                    Text(
                      _sum(p),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      _methodLabel(p['method']?.toString() ?? ''),
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      _dt(p['createdAt']),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _parentAccount(Map<String, dynamic> p) {
    final u = p['user'] as Map?;
    if (u == null) {
      return "—";
    }
    final e = u['email']?.toString();
    if (e != null && e.isNotEmpty) {
      return e;
    }
    return u['phone']?.toString() ?? "—";
  }

  String _sum(Map<String, dynamic> p) {
    final a = p['amount'];
    final n = a is int ? a : int.tryParse(a?.toString() ?? '0') ?? 0;
    return "${NumberFormat('#,###', 'en').format(n).replaceAll(',', ' ')} so'm";
  }

  String _methodLabel(String m) {
    final u = m.toUpperCase();
    if (u.contains('PAYME')) {
      return 'PAYME';
    }
    if (u.contains('CLICK')) {
      return 'VISA';
    }
    return m.isEmpty ? "—" : m;
  }

  String _dt(dynamic v) {
    if (v == null) {
      return "—";
    }
    final d = DateTime.tryParse(v.toString());
    if (d == null) {
      return "—";
    }
    return DateFormat("dd.MM.yyyy  HH:mm", 'en').format(d.toLocal());
  }
}
