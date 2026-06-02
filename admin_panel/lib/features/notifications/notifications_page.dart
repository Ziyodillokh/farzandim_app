import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/error_state_view.dart';
import '../../core/widgets/skeletons.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _api = AdminApi();
  final _q = TextEditingController();
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _ai = [];
  String? _status;
  String? _audience;
  bool _loading = true;
  String? _error;
  _Mode _mode = _Mode.list;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Har bir so'rovni alohida — bittasi yiqilsa ham qolganlari ko'rinadi.
    Map<String, dynamic> stats = {};
    List<Map<String, dynamic>> rows = [];
    List<Map<String, dynamic>> ai = [];
    final errors = <String>[];

    try {
      stats = await _api.getNotificationStats();
    } catch (e) {
      errors.add('stats: $e');
    }
    try {
      rows = await _api.listNotifications(
        q: _q.text.trim().isEmpty ? null : _q.text.trim(),
        status: _status,
        audience: _audience,
      );
    } catch (e) {
      errors.add('list: $e');
    }
    try {
      ai = await _api.aiGenerateNotifications();
    } catch (e) {
      errors.add('ai: $e');
    }

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _rows = rows;
      _ai = ai;
      _loading = false;
      // Faqat AGAR rows fetch yiqilsa, bu jiddiy xato. Stats/AI ixtiyoriy.
      _error = (rows.isEmpty && errors.any((e) => e.startsWith('list:')))
          ? errors.firstWhere((e) => e.startsWith('list:'))
          : null;
    });
  }

  Future<void> _deleteNotification(Map<String, dynamic> m) async {
    final id = m['id']?.toString();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: const Text('O\'chirib bo\'lmadi: ID topilmadi'),
        ),
      );
      return;
    }
    final title = m['title']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bildirishnomani o\'chirish'),
        content: Text(
          title.isEmpty
              ? 'Ushbu bildirishnoma butunlay o\'chiriladi. App ichidagi nusxalar ham olib tashlanadi. Davom etilsinmi?'
              : '"$title" bildirishnomasi butunlay o\'chiriladi. App ichidagi nusxalar ham olib tashlanadi. Davom etilsinmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('O\'chirish',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deleteNotification(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.sidebarLime,
          content: Text(
            'Bildirishnoma o\'chirildi',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'O\'chirib bo\'lmadi: ${e.toString().substring(0, e.toString().length.clamp(0, 200))}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _Mode.create) {
      return _CreateWizard(
        initial: _selected,
        onBack: () => setState(() {
          _mode = _Mode.list;
          _selected = null;
        }),
        onDone: () async {
          setState(() {
            _mode = _Mode.list;
            _selected = null;
          });
          await _load();
        },
      );
    }
    if (_mode == _Mode.details && _selected != null) {
      return _DetailsPage(
        id: _selected!['id'].toString(),
        onBack: () => setState(() => _mode = _Mode.list),
      );
    }
    return _buildList();
  }

  Widget _buildList() {
    // Tugma + sarlavha har doim ko'rinadi — error/loading state'da ham yangi
    // xabar yaratish imkoniyati qoladi.
    final header = Row(
      children: [
        const Expanded(
          child: AdminPageHeader(
            title: 'Bildirishnoma',
            subtitle: 'Push va in-app kampaniyalar',
          ),
        ),
        ElevatedButton(
          onPressed: () => setState(() => _mode = _Mode.create),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
          ),
          child: const Text('+ Bildirishnoma yaratish'),
        ),
      ],
    );

    if (_loading) {
      return ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          header,
          const SizedBox(height: AppSpacing.md),
          const NotificationHistorySkeleton(),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          header,
          const SizedBox(height: AppSpacing.md),
          AppErrorStateView(
            error: _error!,
            onRetry: _load,
            title: 'Bildirishnoma yuklanmadi',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        header,
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _q,
                onSubmitted: (_) => _load(),
                decoration: const InputDecoration(
                  hintText: 'Qidiruv',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _Filter(
              value: _audience,
              hint: 'Barcha tariflar',
              items: const {
                'all': 'All Users',
                'parents': 'Parents Only',
                'children': 'Children Only',
                'premium': 'Premium',
                'age_group': 'Age Group',
              },
              onChanged: (v) {
                setState(() => _audience = v);
                _load();
              },
            ),
            const SizedBox(width: 12),
            _Filter(
              value: _status,
              hint: 'Barcha statuslar',
              items: const {
                'sent': 'Yuborilgan',
                'scheduled': 'Rejalashgan',
                'failed': 'Yuborilmadi',
              },
              onChanged: (v) {
                setState(() => _status = v);
                _load();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final cards = [
              _Stat(icon: Icons.check_circle_outline, color: const Color(0xFFD946EF), value: _n(_stats['todaySent']), label: 'Bugun yuborilgan bildirishnomalar'),
              _Stat(icon: Icons.trending_up, color: const Color(0xFF67E8F9), value: '${_num(_stats['deliveryRate'])}%', label: 'Yetkazib berish darajasi'),
              _Stat(icon: Icons.visibility_outlined, color: const Color(0xFFFF8A65), value: '${_num(_stats['openRate'])}%', label: 'Ochilish darajasi'),
              _Stat(icon: Icons.send_outlined, color: const Color(0xFF22C55E), value: _n(_stats['totalNotifications']), label: 'Yuborilgan jami bildirishnomalar soni'),
            ];
            return Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _AiSuggestions(
          items: _ai,
          onEdit: (m) => setState(() {
            _selected = m;
            _mode = _Mode.create;
          }),
          onSend: (m) async {
            await AdminApi().createNotification({
              ...m,
              'sendNow': true,
            });
            await _load();
          },
        ),
        const SizedBox(height: 18),
        const SectionTitle('Bildirishnomalar tarixi'),
        const SizedBox(height: 10),
        _HistoryTable(
          rows: _rows,
          onView: (m) => setState(() {
            _selected = m;
            _mode = _Mode.details;
          }),
          onDelete: _deleteNotification,
        ),
      ],
    );
  }
}

enum _Mode { list, create, details }

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.black, size: 22),
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });
  final String? value;
  final String hint;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          items: [
            const DropdownMenuItem(value: null, child: Text('(hammasi)')),
            ...items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({
    required this.rows,
    required this.onView,
    required this.onDelete,
  });
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> onView;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const EmptyStateView(
        title: "Bildirishnoma yo'q",
        subtitle: 'Yangi bildirishnoma yaratilgach bu yerda ko‘rinadi.',
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(Colors.grey.shade100),
          columns: const [
            DataColumn(label: Text('Sarlavha')),
            DataColumn(label: Text('Maqsadli auditoriya')),
            DataColumn(label: Text('Ochilish narxi')),
            DataColumn(label: Text('Yetkazildi')),
            DataColumn(label: Text('Yuborilgan sana')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final r in rows)
              DataRow(
                cells: [
                  DataCell(SizedBox(width: 210, child: Text(r['title']?.toString() ?? '-'))),
                  DataCell(Text(_audienceLabel(r['targetType']?.toString()))),
                  DataCell(Text('${_num(r['openRate'])}%')),
                  DataCell(Text(_n(r['deliveredCount']))),
                  DataCell(Text(_date(r['sentAt'] ?? r['scheduledAt'] ?? r['createdAt']))),
                  DataCell(_Status(r['status']?.toString() ?? 'sent')),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => onView(r),
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                      ),
                      IconButton(
                        onPressed: () => onDelete(r),
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                      ),
                    ],
                  )),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final sent = status == 'sent';
    final scheduled = status == 'scheduled' || status == 'queued' || status == 'sending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: sent
            ? const Color(0xFFE9FBE7)
            : scheduled
                ? const Color(0xFFFFF8DB)
                : const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        sent ? 'Yuborilgan' : scheduled ? 'Rejalash-gan' : 'Yuborilmadi',
        style: TextStyle(
          fontSize: 12,
          color: sent
              ? AppColors.success
              : scheduled
                  ? AppColors.warning
                  : AppColors.danger,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AiSuggestions extends StatelessWidget {
  const _AiSuggestions({
    required this.items,
    required this.onEdit,
    required this.onSend,
  });
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onSend;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('AI bildirishnoma'),
          const SizedBox(height: 10),
          for (final m in items.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(m['title']?.toString() ?? ''),
              subtitle: Text('${m['message'] ?? ''}\n${_audienceLabel(m['targetType']?.toString())} • ${_date(m['suggestedSendTime'])}'),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(onPressed: () => onEdit(m), icon: const Icon(Icons.edit_outlined)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.close)),
                  IconButton(onPressed: () => onSend(m), icon: const Icon(Icons.rocket_launch_outlined)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailsPage extends StatefulWidget {
  const _DetailsPage({required this.id, required this.onBack});
  final String id;
  final VoidCallback onBack;

  @override
  State<_DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<_DetailsPage> {
  final _api = AdminApi();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getNotification(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const AnalyticsSkeleton();
        if (snap.hasError) return AppErrorStateView(error: snap.error!, onRetry: () => setState(() => _future = _api.getNotification(widget.id)));
        final n = snap.data ?? {};
        final metrics = (n['metrics'] as Map?)?.cast<String, dynamic>() ?? {};
        final engagement = ((n['engagement'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Orqaga'),
              style: TextButton.styleFrom(alignment: Alignment.centerLeft),
            ),
            const AdminPageHeader(title: 'Bildirishnoma tafsilotlari', subtitle: ''),
            const SizedBox(height: 16),
            AppCard(
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Basic Information'),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(child: _Info(label: 'Title', value: n['title']?.toString() ?? '-')),
                        Expanded(child: _Info(label: 'Target Audience', value: _audienceLabel(n['targetType']?.toString()))),
                      ]),
                      const SizedBox(height: 14),
                      _Info(label: 'Message', value: n['message']?.toString() ?? '-'),
                      const SizedBox(height: 14),
                      _Info(label: 'Send Time', value: _date(n['sentAt'] ?? n['scheduledAt'])),
                    ],
                  ),
                  Positioned(right: 0, top: 0, child: _Status(n['status']?.toString() ?? 'sent')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _Metric(title: 'Delivered', value: _n(metrics['delivered']), hint: '100% of total')),
              const SizedBox(width: 12),
              Expanded(child: _Metric(title: 'Opened', value: _n(metrics['opened']), hint: '${_num(metrics['openRate'])}% of total')),
              const SizedBox(width: 12),
              Expanded(child: _Metric(title: 'Clicked', value: _n(metrics['clicked']), hint: '${_num(metrics['ctr'])}% of total')),
            ]),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Engagement Over Time'),
                  const SizedBox(height: 16),
                  SizedBox(height: 230, child: _EngagementChart(rows: engagement)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Performance Metrics'),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _Perf('Click-Through Rate', '${_num(metrics['ctr'])}%')),
                    const SizedBox(width: 12),
                    Expanded(child: _Perf('Avg. Open Time', '${_num(metrics['avgOpenTimeHours'])} hours')),
                    const SizedBox(width: 12),
                    Expanded(child: _Perf('Bounce Rate', '${_num(metrics['bounceRate'])}%')),
                    const SizedBox(width: 12),
                    Expanded(child: _Perf('Platform', metrics['platform']?.toString() ?? 'Mobile')),
                  ]),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.hint});
  final String title;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(title, style: const TextStyle(color: AppColors.textSecondary)), const Spacer(), const Icon(Icons.trending_up, size: 14)]),
        const SizedBox(height: 26),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(hint, style: const TextStyle(color: AppColors.success, fontSize: 12)),
      ]),
    );
  }
}

class _Perf extends StatelessWidget {
  const _Perf(this.title, this.value);
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ]),
    );
  }
}

class _EngagementChart extends StatelessWidget {
  const _EngagementChart({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final list = rows.isEmpty
        ? List.generate(6, (i) => {'label': '${i * 3}:00', 'opened': 0})
        : rows;
    final maxY = list.map((e) => (e['opened'] as num?)?.toDouble() ?? 0).fold<double>(1, (a, b) => a > b ? a : b) * 1.15;
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxY,
      gridData: const FlGridData(show: true, drawVerticalLine: true),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (v, m) {
            final i = v.toInt();
            if (i < 0 || i >= list.length) return const SizedBox.shrink();
            return Text(list[i]['label']?.toString() ?? '', style: const TextStyle(fontSize: 10));
          },
        )),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(list.length, (i) => FlSpot(i.toDouble(), ((list[i]['opened'] as num?)?.toDouble() ?? 0))),
          isCurved: true,
          color: AppColors.sidebarLime,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      ],
    ));
  }
}

class _CreateWizard extends StatefulWidget {
  const _CreateWizard({required this.onBack, required this.onDone, this.initial});
  final VoidCallback onBack;
  final VoidCallback onDone;
  final Map<String, dynamic>? initial;

  @override
  State<_CreateWizard> createState() => _CreateWizardState();
}

class _CreateWizardState extends State<_CreateWizard> {
  final _api = AdminApi();
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _deepLink = TextEditingController();
  final _ageFrom = TextEditingController(text: '3');
  final _ageTo = TextEditingController(text: '12');
  int _step = 0;
  String _target = 'all';
  bool _activeOnly = false;
  bool _premiumOnly = false;
  bool _schedule = false;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  bool _submitting = false;
  String? _formError;
  // Sprint 5.x — notification rasm uploadi (URL field o'rniga).
  String? _imageUrl;        // backend qaytargan signed URL
  String? _imageFileName;   // ko'rsatish uchun
  bool _imageUploading = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _title.text = i['title']?.toString() ?? '';
      _message.text = i['message']?.toString() ?? '';
      _target = i['targetType']?.toString() ?? 'all';
      _deepLink.text = i['deepLink']?.toString() ?? '';
      _activeOnly = ((i['filters'] as Map?)?['activeOnly']) == true;
      _premiumOnly = ((i['filters'] as Map?)?['premiumOnly']) == true;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _deepLink.dispose();
    _ageFrom.dispose();
    _ageTo.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_imageUploading) return;
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) return;

    setState(() {
      _imageUploading = true;
      _formError = null;
    });
    try {
      final url = await _api.uploadNotificationImage(
        MultipartFile.fromBytes(bytes, filename: picked.name),
      );
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _imageFileName = picked.name;
        _imageUploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _imageUploading = false;
        _formError = 'Rasm yuklanmadi: $e';
      });
    }
  }

  void _clearImage() {
    setState(() {
      _imageUrl = null;
      _imageFileName = null;
    });
  }

  String? _validateForm() {
    final t = _title.text.trim();
    final m = _message.text.trim();
    if (t.isEmpty) return 'Sarlavha majburiy';
    if (t.length > 120) return 'Sarlavha 120 belgidan oshmasin';
    if (m.isEmpty) return 'Xabar matni majburiy';
    if (m.length > 500) return 'Xabar 500 belgidan oshmasin';
    if (_target == 'age_group') {
      final af = int.tryParse(_ageFrom.text.trim());
      final at = int.tryParse(_ageTo.text.trim());
      if (af == null || at == null) return 'Yosh oraligi noto\'g\'ri';
      if (af < 0 || at > 25 || af > at) return 'Yosh: 0..25, dan ≤ gacha';
    }
    if (_schedule) {
      final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      if (dt.isBefore(DateTime.now())) {
        return 'Rejalashtirilgan vaqt o\'tib ketgan';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final err = _validateForm();
    if (err != null) {
      setState(() => _formError = err);
      // Jump back to content step if title/message bo'sh
      if (_step > 1 && (_title.text.trim().isEmpty || _message.text.trim().isEmpty)) {
        setState(() => _step = 1);
      }
      return;
    }
    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      final scheduledAt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      final result = await _api.createNotification({
        'title': _title.text.trim(),
        'message': _message.text.trim(),
        'targetType': _target,
        'filters': {
          if (_activeOnly) 'activeOnly': true,
          if (_premiumOnly) 'premiumOnly': true,
          if (_target == 'age_group') ...{
            'ageFrom': int.tryParse(_ageFrom.text.trim()) ?? 3,
            'ageTo': int.tryParse(_ageTo.text.trim()) ?? 12,
          },
        },
        if (_imageUrl != null && _imageUrl!.isNotEmpty) 'imageUrl': _imageUrl,
        if (_deepLink.text.trim().isNotEmpty) 'deepLink': _deepLink.text.trim(),
        if (_schedule) 'scheduledAt': scheduledAt.toIso8601String(),
      });
      if (!mounted) return;
      final delivered = (result['deliveredCount'] as num?)?.toInt() ?? 0;
      final status = result['status']?.toString() ?? 'sent';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.sidebarLime,
          content: Text(
            status == 'scheduled'
                ? 'Rejalashtirildi (${DateFormat('dd.MM HH:mm').format(scheduledAt)})'
                : 'Yuborildi · $delivered yetkazildi',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          ),
        ),
      );
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Yuborilmadi: ${e.toString().substring(0, e.toString().length.clamp(0, 200))}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        TextButton.icon(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, size: 16), label: const Text('Orqaga'), style: TextButton.styleFrom(alignment: Alignment.centerLeft)),
        const AdminPageHeader(title: 'Bildirishnoma yaratish', subtitle: ''),
        const SizedBox(height: 18),
        Center(child: SizedBox(width: 760, child: _Stepper(current: _step))),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 760,
            child: AppCard(
              child: [
                _audience(),
                _content(),
                _delivery(),
                _preview(),
              ][_step],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 760,
            child: AppCard(
              child: Row(children: [
                OutlinedButton(onPressed: _step == 0 ? null : () => setState(() => _step--), child: const Text('Back')),
                const Spacer(),
                ElevatedButton(
                  onPressed: _submitting ? null : (_step < 3 ? () => setState(() => _step++) : _submit),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  child: Text(_step < 3 ? 'Next' : (_schedule ? 'Schedule' : 'Send')),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _audience() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Auditoriya tanlash'),
        const SizedBox(height: 16),
        const Text('Auditoriya turi'),
        for (final e in const {
          'all': 'Hammasi',
          'parents': 'Faqat ota-onalar',
          'children': 'Faqat bolalar',
          'premium': 'Premium foydalanuvchilar',
          'age_group': 'Yosh guruhi (bolalar)',
        }.entries)
          RadioListTile<String>(
            dense: true,
            value: e.key,
            groupValue: _target,
            title: Text(e.value),
            onChanged: (v) => setState(() => _target = v ?? 'all'),
          ),
        if (_target == 'age_group') ...[
          const SizedBox(height: 8),
          const Text('Yosh oraligi (0–25)'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ageFrom,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Dan', isDense: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _ageTo,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Gacha', isDense: true),
              ),
            ),
          ]),
        ],
        const Divider(),
        const Text('Qo\'shimcha filtrlar'),
        Row(children: [
          Checkbox(value: _activeOnly, onChanged: (v) => setState(() => _activeOnly = v ?? false)),
          const Text('Faqat faol foydalanuvchilar'),
          const SizedBox(width: 26),
          Checkbox(value: _premiumOnly, onChanged: (v) => setState(() => _premiumOnly = v ?? false)),
          const Text('Faqat premium'),
        ]),
      ]);

  Widget _content() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Bildirishnoma matni'),
        const SizedBox(height: 16),
        const Text('Sarlavha *'),
        TextField(
          controller: _title,
          maxLength: 120,
          decoration: const InputDecoration(hintText: 'Sarlavha kiriting'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        const Text('Xabar *'),
        TextField(
          controller: _message,
          maxLength: 500,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Xabar matnini kiriting...'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        const Text('Rasm (ixtiyoriy, maks 5 MB)'),
        const SizedBox(height: 6),
        _ImagePickerField(
          uploadedUrl: _imageUrl,
          fileName: _imageFileName,
          uploading: _imageUploading,
          onPick: _pickImage,
          onClear: _clearImage,
        ),
        const SizedBox(height: 12),
        const Text('Deep Link (ixtiyoriy)'),
        TextField(controller: _deepLink, decoration: const InputDecoration(hintText: 'farzandim://...')),
        if (_formError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_formError!, style: const TextStyle(color: Colors.red))),
            ]),
          ),
        ],
      ]);

  Widget _delivery() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Delivery Settings'),
        const SizedBox(height: 16),
        const Text('Delivery Time'),
        RadioListTile<bool>(dense: true, value: false, groupValue: _schedule, title: const Text('Send Immediately'), onChanged: (v) => setState(() => _schedule = v ?? false)),
        RadioListTile<bool>(dense: true, value: true, groupValue: _schedule, title: const Text('Schedule for Later'), onChanged: (v) => setState(() => _schedule = v ?? true)),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () async {
            final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: _date);
            if (d != null) setState(() => _date = d);
          }, icon: const Icon(Icons.calendar_today, size: 16), label: Text(DateFormat('dd.MM.yyyy').format(_date)))),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: _time);
            if (t != null) setState(() => _time = t);
          }, icon: const Icon(Icons.access_time, size: 16), label: Text(_time.format(context)))),
        ]),
      ]);

  Widget _preview() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Preview & Send'),
        const SizedBox(height: 20),
        const Center(child: Text('Mobile Push Preview', style: TextStyle(color: AppColors.textSecondary))),
        const SizedBox(height: 12),
        Center(child: Container(width: 320, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]), child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.sidebarLime, borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('F'))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Farzandim', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(_title.text.isEmpty ? 'Your notification title' : _title.text),
            Text(_message.text.isEmpty ? 'Your notification message will appear here...' : _message.text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
          ])),
        ]))),
        const Divider(height: 32),
        const SectionTitle('Notification Summary'),
        _summary('Target Audience:', _audienceLabel(_target)),
        _summary('Filters:', [_activeOnly ? 'Active' : null, _premiumOnly ? 'Premium' : null].whereType<String>().join(', ').ifEmpty('None')),
        _summary('Delivery:', _schedule ? DateFormat('dd.MM.yyyy HH:mm').format(DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute)) : 'Send Immediately'),
      ]);

  Widget _summary(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Text(k, style: const TextStyle(color: AppColors.textSecondary)), const Spacer(), Text(v)]));
}

// ─── Image picker field (Sprint 5.x — URL o'rniga upload) ──────────────

class _ImagePickerField extends StatelessWidget {
  const _ImagePickerField({
    required this.uploadedUrl,
    required this.fileName,
    required this.uploading,
    required this.onPick,
    required this.onClear,
  });

  final String? uploadedUrl;
  final String? fileName;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasImage = uploadedUrl != null && uploadedUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                uploadedUrl!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 56,
                  height: 56,
                  color: AppColors.background,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.image_outlined,
                  color: AppColors.textSecondary, size: 26),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasImage ? (fileName ?? 'Rasm yuklandi') : 'Rasm tanlanmagan',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  hasImage
                      ? 'Boshqa rasm tanlash uchun "Yangilash"'
                      : 'JPG / PNG / WebP / GIF · maks 5 MB',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (uploading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            if (hasImage)
              IconButton(
                tooltip: 'Olib tashlash',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClear,
              ),
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_file, size: 16),
              label: Text(hasImage ? 'Yangilash' : 'Tanlash'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.current});
  final int current;
  @override
  Widget build(BuildContext context) {
    const labels = ['Audience Selection', 'Notification Content', 'Delivery Settings', 'Preview & Send'];
    return AppCard(child: Row(children: [
      for (var i = 0; i < 4; i++) ...[
        Expanded(child: Column(children: [
          CircleAvatar(radius: 18, backgroundColor: i <= current ? Colors.black : AppColors.background, child: Text('${i + 1}', style: TextStyle(color: i <= current ? Colors.white : AppColors.textSecondary))),
          const SizedBox(height: 8),
          Text(labels[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
        ])),
        if (i < 3) Expanded(child: Container(height: 1, color: AppColors.border)),
      ],
    ]));
  }
}

String _audienceLabel(String? v) {
  switch (v) {
    case 'parents':
      return 'Faqat ota-onalar';
    case 'children':
      return 'Faqat bolalar';
    case 'premium':
      return 'Premium foydalanuvchilar';
    case 'age_group':
      return 'Yosh bo‘yicha';
    default:
      return 'Barcha foydalanuvchilar';
  }
}

String _date(dynamic v) {
  if (v == null) return '-';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return '-';
  return DateFormat('dd.MM.yyyy | HH:mm').format(d.toLocal());
}

String _n(dynamic v) {
  final n = v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
  return NumberFormat('#,###', 'en').format(n).replaceAll(',', ',');
}

String _num(dynamic v) {
  final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 1);
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
