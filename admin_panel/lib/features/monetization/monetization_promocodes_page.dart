import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/common.dart';

class MonetizationPromocodesPage extends StatefulWidget {
  const MonetizationPromocodesPage({super.key});

  @override
  State<MonetizationPromocodesPage> createState() =>
      _MonetizationPromocodesPageState();
}

class _MonetizationPromocodesPageState
    extends State<MonetizationPromocodesPage> {
  final _api = AdminApi();
  final _q = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _plans = [];
  String? _filterPlan;
  String? _filterStatus;
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
      _error = null;
    });
    try {
      final plans = await _api.listMonetizationPlans();
      if (!mounted) {
        return;
      }
      setState(() {
        _plans = plans;
      });
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
      final rows = await _api.listMonetizationPromocodes(
        q: _q.text.trim().isEmpty ? null : _q.text.trim(),
        planId: _filterPlan,
        status: _filterStatus,
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: AdminPageHeader(
                title: 'Promokodlar',
                subtitle: 'Monetizatsiya',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              onPressed: _loading ? null : () => _openForm(context, null),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
              ),
              child: const Text('Yangi promokod yaratish'),
            ),
          ],
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
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _chipDropdown(
              value: _filterPlan,
              hint: 'Barcha tariflar',
              items: {
                for (final p in _plans)
                  p['id']?.toString() ?? '': p['name']?.toString() ?? '',
              },
              onChanged: (v) {
                setState(() => _filterPlan = v);
                _load();
              },
            ),
            const SizedBox(width: 12),
            _chipDropdown(
              value: _filterStatus,
              hint: 'Barcha statuslar',
              items: {
                'active': 'Aktiv',
                'inactive': 'Nofaol',
                'archived': 'Arxiv',
              },
              onChanged: (v) {
                setState(() => _filterStatus = v);
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
          _PromoTable(
            rows: _rows,
            onEdit: (m) => _openForm(context, m),
            onDelete: (m) => _delete(m),
          ),
      ],
    );
  }

  Widget _chipDropdown({
    required String? value,
    required String hint,
    required Map<String, String> items,
    required void Function(String?)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: false,
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('(hammasi)'),
            ),
            ...items.entries.map(
              (e) => DropdownMenuItem<String>(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontSize: 14)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final id = m['id']?.toString();
    if (id == null) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("O'chirish"),
        content: Text('“${m['code']}” ni o‘chirmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "O'chirish",
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await _api.deleteMonetizationPromocode(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("O'chirildi")));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _openForm(
    BuildContext context,
    Map<String, dynamic>? existing,
  ) async {
    final codeC = TextEditingController(
      text: existing?['code']?.toString() ?? '',
    );
    final disC = TextEditingController(
      text: (existing?['discountPct']?.toString() ?? ''),
    );
    final limitC = TextEditingController(
      text: (existing?['usageLimit']?.toString() ?? '1000'),
    );
    final exp = existing?['expiresAt'] != null
        ? DateTime.tryParse(existing!['expiresAt'].toString()) ??
              DateTime.now().add(const Duration(days: 30))
        : DateTime.now().add(const Duration(days: 30));
    var expDate = DateTime(exp.year, exp.month, exp.day);
    var status = existing?['status']?.toString() ?? 'active';
    if (!['active', 'inactive', 'archived'].contains(status)) {
      status = 'active';
    }
    String? planId = existing?['planId']?.toString();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      existing == null
                          ? "Yangi promokod qo'shish"
                          : "Promokodni tahrirlash",
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Promokod nomi",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: codeC,
                      readOnly: existing != null,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Chegirma (%)",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: disC,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  hintText: "Foizni kiriting",
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Foydalanish limiti",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: limitC,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  hintText: "Limitni kiriting",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Amal qilish muddati",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final d = await showDatePicker(
                                    context: ctx,
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime(2040),
                                    initialDate: expDate,
                                  );
                                  if (d != null) {
                                    setS(() {
                                      expDate = d;
                                    });
                                  }
                                },
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                                label: Text(
                                  DateFormat('dd.MM.yyyy').format(expDate),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Status",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: status,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'active',
                                    child: Text('Aktiv'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'inactive',
                                    child: Text('Nofaol'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'archived',
                                    child: Text('Arxiv'),
                                  ),
                                ],
                                onChanged: (v) => setS(() {
                                  status = v ?? 'active';
                                }),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_plans.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        "Bog‘langan tarif (ixtiyoriy)",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String?>(
                        initialValue: planId,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('(barcha tariflar)'),
                          ),
                          ..._plans.map(
                            (p) => DropdownMenuItem<String?>(
                              value: p['id']?.toString(),
                              child: Text(
                                p['name']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setS(() => planId = v),
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Bekor qilish'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final dis = int.tryParse(disC.text) ?? 0;
                    final lim = int.tryParse(limitC.text) ?? 0;
                    final expIso = DateTime(
                      expDate.year,
                      expDate.month,
                      expDate.day,
                      23,
                      59,
                    ).toUtc().toIso8601String();
                    final body = <String, dynamic>{
                      'code': codeC.text.trim().toUpperCase(),
                      'discountPct': dis,
                      'usageLimit': lim,
                      'expiresAt': expIso,
                      'status': status,
                      'planId': planId,
                    };
                    try {
                      if (existing == null) {
                        await _api.createMonetizationPromocode(body);
                      } else {
                        body.remove('code');
                        await _api.updateMonetizationPromocode(
                          existing['id'].toString(),
                          body,
                        );
                      }
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saqlandi')),
                        );
                        await _load();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  child: const Text('Saqlash'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PromoTable extends StatelessWidget {
  const _PromoTable({
    required this.rows,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> rows;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Promokodlar yo‘q",
            style: TextStyle(color: AppColors.textSecondary),
          ),
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
                "Promo kod",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                "Chegirma",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                "Limit",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                "Ishlatilgan",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                "Status",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                "Muddati",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final m in rows)
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      m['code']?.toString() ?? '',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(Text("• ${m['discountPct']?.toString() ?? 0}%")),
                  DataCell(Text("${m['usageLimit']?.toString() ?? 0} marta")),
                  DataCell(_UsedCell(m: m)),
                  DataCell(_StatusText(m: m)),
                  DataCell(
                    Text(
                      _formatDt(m['expiresAt']),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    _ActionsRow(m: m, onEdit: onEdit, onDelete: onDelete),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDt(dynamic v) {
    if (v == null) {
      return '—';
    }
    final d = DateTime.tryParse(v.toString());
    if (d == null) {
      return '—';
    }
    return DateFormat("dd.MM.yyyy HH:mm").format(d.toLocal());
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.m,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> m;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  @override
  Widget build(BuildContext context) {
    final st = _status(m);
    final canEdit = st == 'active';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canEdit)
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => onEdit(m),
            tooltip: 'Tahrirlash',
          ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline,
            size: 18,
            color: AppColors.danger,
          ),
          onPressed: () => onDelete(m),
          tooltip: "O'chirish",
        ),
      ],
    );
  }
}

String _status(Map<String, dynamic> m) {
  if (m['status'] == 'archived' || m['status'] == 'inactive') {
    return 'expired';
  }
  if (m['status'] == 'active') {
    final ex = m['expiresAt'] != null
        ? DateTime.tryParse(m['expiresAt'].toString())
        : null;
    if (ex != null && ex.isBefore(DateTime.now())) {
      return 'expired';
    }
    final used = m['usedCount'] is int
        ? m['usedCount'] as int
        : int.tryParse(m['usedCount']?.toString() ?? '0') ?? 0;
    final lim = m['usageLimit'] is int
        ? m['usageLimit'] as int
        : int.tryParse(m['usageLimit']?.toString() ?? '0') ?? 0;
    if (used >= lim && lim > 0) {
      return 'limit';
    }
    return 'active';
  }
  return 'expired';
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.m});
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final s = _status(m);
    if (s == 'active') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Active',
          style: TextStyle(
            color: Color(0xFF166534),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }
    if (s == 'expired') {
      return const Text(
        "Tugagan",
        style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    if (s == 'limit') {
      return const Text(
        "Limit tugadi",
        style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
      );
    }
    return const Text('—');
  }
}

class _UsedCell extends StatelessWidget {
  const _UsedCell({required this.m});
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final used = m['usedCount'] is int
        ? m['usedCount'] as int
        : int.tryParse(m['usedCount']?.toString() ?? '0') ?? 0;
    final lim = m['usageLimit'] is int
        ? m['usageLimit'] as int
        : int.tryParse(m['usageLimit']?.toString() ?? '0') ?? 0;
    final p = (lim > 0 ? (used / lim) : 0.0).clamp(0.0, 1.0).toDouble();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$used', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
