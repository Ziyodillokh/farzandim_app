import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ux/app_error_handler.dart' show AppErrorHandler;
import '../../core/widgets/common.dart';
import '../../core/widgets/error_state_view.dart';
import '../../core/widgets/skeletons.dart';

const _kModalBg = Color(0xFF12131A);
const _kModalAccent = Color(0xFFEF4444);
const _kBlackBtn = Color(0xFF111827);

/// Admin "Konkurslar" – list, filters, live detail modals, 4-step create wizard.
class KonkurslarPage extends StatefulWidget {
  const KonkurslarPage({super.key});

  @override
  State<KonkurslarPage> createState() => _KonkurslarPageState();
}

class _KonkurslarPageState extends State<KonkurslarPage> {
  final _search = TextEditingController();
  final _api = AdminApi();
  Timer? _debounce;

  String _statusFilter = '';
  String _subjectFilter = '';
  String _ageFilter = '';
  String _dateFrom = '';
  String _dateTo = '';
  int _page = 1;
  static const _pageSize = 20;

  late Future<AdminOlympiadsPageResult> _future;

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

  Future<AdminOlympiadsPageResult> _load() {
    final (af, at) = _ageRange();
    return _api.listOlympiads(
      q: _search.text.trim(),
      status: _statusFilter.isEmpty ? null : _statusFilter,
      subject: _subjectFilter.isEmpty ? null : _subjectFilter,
      ageFrom: af,
      ageTo: at,
      dateFrom: _dateFrom.isEmpty ? null : _dateFrom,
      dateTo: _dateTo.isEmpty ? null : _dateTo,
      page: _page,
      limit: _pageSize,
    );
  }

  (int?, int?) _ageRange() {
    if (_ageFilter.isEmpty) return (null, null);
    if (_ageFilter == '6-8') return (6, 8);
    if (_ageFilter == '9-12') return (9, 12);
    if (_ageFilter == '13-16') return (13, 16);
    if (_ageFilter == '17+') return (17, 18);
    return (null, null);
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  String _labelStatus(String? raw) {
    switch (raw) {
      case 'UPCOMING':
        return "🟡 Oldindan rejalashtirilgan";
      case 'ACTIVE':
        return "🟢 Aktiv";
      case 'FINISHED':
        return "🔴 Yakunlangan";
      case 'DRAFT':
        return 'Qoralama';
      default:
        return raw ?? '—';
    }
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '—';
    final t = DateTime.tryParse(iso);
    if (t == null) return '—';
    return '${_pad(t.day)}.${_pad(t.month)}.${t.year} ${t.hour.toString().padLeft(2, "0")}:${_pad(t.minute)}';
  }

  String _pad(int n) => n < 10 ? '0$n' : '$n';

  Future<void> _openCreateWizard() async {
    final r = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _CreateKonkursDialog(),
    );
    if (r == true) _refresh();
  }

  Future<void> _onRowOpen(Map<String, dynamic> o) async {
    final st = o['status']?.toString() ?? o['lifecycle']?.toString() ?? '';
    final id = o['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (st == 'FINISHED') {
      await _openFinished(context, id, o);
    } else {
      await _openActiveLike(context, id, o, st);
    }
  }

  Future<void> _openActiveLike(
    BuildContext context,
    String id,
    Map<String, dynamic> o,
    String st,
  ) async {
    try {
      final parts = await _api.getOlympiadParticipants(id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(o['title']?.toString() ?? 'Konkurs'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  st == 'ACTIVE'
                      ? "🟢 Hozir o'tkazilmoqda"
                      : (st == 'UPCOMING' ? "🟡 Tez orada" : st),
                ),
                const SizedBox(height: 8),
                Text(
                  "Ishtirokchilar: ${o['participantCount'] ?? 0} | Savollar: ${o['questionCount'] ?? 0} | Davomiyligi: ${o['durationMin'] ?? "—"} daq.",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ishtirokchilar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text("Bola")),
                      DataColumn(label: Text('Yutuqlar')),
                      DataColumn(label: Text('Ball')),
                      DataColumn(label: Text("Holat")),
                    ],
                    rows: [
                      for (final p in parts)
                        DataRow(
                          cells: [
                            DataCell(Text(p['childName']?.toString() ?? '—')),
                            DataCell(Text(p['progress']?.toString() ?? '0/0')),
                            DataCell(Text('${p['score'] ?? 0}')),
                            DataCell(
                              Text(
                                p['status'] == 'finished'
                                    ? "Tugatgan"
                                    : "Jarayonda",
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Yopish'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorHandler.userMessage(e))));
      }
    }
  }

  Future<void> _openFinished(
    BuildContext context,
    String id,
    Map<String, dynamic> o,
  ) async {
    try {
      final board = await _api.getOlympiadLeaderboard(id, limit: 200);
      if (!context.mounted) return;
      final top = board.take(10).toList();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${o['title'] ?? "Konkurs"} — natijalar'),
          content: SizedBox(
            width: 560,
            height: 420,
            child: ListView(
              children: [
                const Text(
                  "🏆 Eng yaxshi 10 nafar",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < top.length; i++)
                  _rankTile(top[i] as Map, i + 1),
                const SizedBox(height: 16),
                const Text("Barcha ishtirokchilar (reyting)"),
                const SizedBox(height: 8),
                for (final row in board) _rankRow(row as Map),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Yopish'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorHandler.userMessage(e))));
      }
    }
  }

  Widget _rankTile(Map<dynamic, dynamic> m, int r) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(child: Text('$r')),
      title: Text(m['name']?.toString() ?? '—'),
      subtitle: Text("Vaqt: ${m['timeSec'] ?? "—"} s"),
      trailing: Text(
        '${m['score'] ?? 0} b.',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _rankRow(Map<dynamic, dynamic> m) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('${m['rank'] ?? "—"}', textAlign: TextAlign.center),
          ),
          Expanded(child: Text(m['name']?.toString() ?? '—')),
          Text('${m['score'] ?? 0}'),
          const SizedBox(width: 8),
          Text(
            '${m['timeSec'] ?? "—"} s',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Konkurslar',
                style: AppTextStyles.pageTitle.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kBlackBtn,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onPressed: _openCreateWizard,
                child: const Text("Konkurs yaratish"),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 1000;
              final search = SearchField(
                controller: _search,
                width: wide ? null : double.infinity,
                onChanged: (_) {},
              );
              void apply() {
                setState(() {
                  _page = 1;
                  _future = _load();
                });
              }

              final filters = [
                AppFilterDropdown(
                  hint: 'Status',
                  selectedValue: _statusFilter,
                  items: const [
                    DropdownMenuItem(
                      value: '',
                      child: Text('Barcha statuslar'),
                    ),
                    DropdownMenuItem(value: 'UPCOMING', child: Text("Keyingi")),
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Aktiv')),
                    DropdownMenuItem(
                      value: 'FINISHED',
                      child: Text('Yakunlangan'),
                    ),
                    DropdownMenuItem(value: 'DRAFT', child: Text('Qoralama')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _statusFilter = v ?? '';
                      apply();
                    });
                  },
                ),
                AppFilterDropdown(
                  hint: 'Fan',
                  selectedValue: _subjectFilter,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Barcha fanlar')),
                    DropdownMenuItem(
                      value: 'Matematika',
                      child: Text('Matematika'),
                    ),
                    DropdownMenuItem(
                      value: "Ona tili",
                      child: Text("Ona tili"),
                    ),
                    DropdownMenuItem(
                      value: "Tabiiy fan",
                      child: Text("Tabiiy fan"),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _subjectFilter = v ?? '';
                      apply();
                    });
                  },
                ),
                AppFilterDropdown(
                  hint: "Yosh guruhi",
                  selectedValue: _ageFilter,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Barcha')),
                    DropdownMenuItem(value: '6-8', child: Text('6–8')),
                    DropdownMenuItem(value: '9-12', child: Text('9–12')),
                    DropdownMenuItem(value: '13-16', child: Text('13–16')),
                    DropdownMenuItem(value: '17+', child: Text('17+')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _ageFilter = v ?? '';
                      apply();
                    });
                  },
                ),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: search),
                        const SizedBox(width: 8),
                        for (int fi = 0; fi < filters.length; fi++) ...[
                          filters[fi],
                          if (fi < filters.length - 1) const SizedBox(width: 6),
                        ],
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 128,
                          child: OutlinedButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2100),
                                initialDate: DateTime.now(),
                              );
                              if (d == null) return;
                              setState(() {
                                _dateFrom = d.toIso8601String();
                                _page = 1;
                                _future = _load();
                              });
                            },
                            child: const Text("Sanadan"),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 120,
                          child: OutlinedButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2100),
                                initialDate: DateTime.now(),
                              );
                              if (d == null) return;
                              setState(() {
                                _dateTo = d.toIso8601String();
                                _page = 1;
                                _future = _load();
                              });
                            },
                            child: const Text("Sanaga"),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    search,
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...filters,
                        OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2100),
                              initialDate: DateTime.now(),
                            );
                            if (d == null) return;
                            setState(() {
                              _dateFrom = d.toIso8601String();
                              _page = 1;
                              _future = _load();
                            });
                          },
                          child: const Text("Sanadan"),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2100),
                              initialDate: DateTime.now(),
                            );
                            if (d == null) return;
                            setState(() {
                              _dateTo = d.toIso8601String();
                              _page = 1;
                              _future = _load();
                            });
                          },
                          child: const Text("Sanaga"),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: FutureBuilder<AdminOlympiadsPageResult>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const UsersTableSkeleton();
                }
                if (snap.hasError) {
                  return AppErrorStateView(
                    error: snap.error!,
                    onRetry: _refresh,
                  );
                }
                final data = snap.data!;
                if (data.items.isEmpty) {
                  return const Center(child: Text("Konkurs topilmadi"));
                }
                return Column(
                  children: [
                    Expanded(
                      child: AppTable(
                        dataRowMinHeight: 64,
                        columns: const [
                          DataColumn(label: Text('Nomi')),
                          DataColumn(label: Text("Turi")),
                          DataColumn(label: Text("Ishtirokchi")),
                          DataColumn(label: Text('Boshlanish')),
                          DataColumn(label: Text('Tugash')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('')),
                        ],
                        rows: data.items.map((j) {
                          return DataRow(
                            onSelectChanged: (_) => _onRowOpen(j),
                            cells: [
                              DataCell(
                                Text(
                                  j['title']?.toString() ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DataCell(
                                Text(
                                  j['type'] == 'quiz' ? 'Viktorina' : 'Test',
                                ),
                              ),
                              DataCell(Text('${j['participantCount'] ?? 0}')),
                              DataCell(
                                Text(_fmtTime(j['startTime']?.toString())),
                              ),
                              DataCell(
                                Text(_fmtTime(j['endTime']?.toString())),
                              ),
                              DataCell(
                                _StatusPill(
                                  text: _labelStatus(
                                    j['status']?.toString() ??
                                        j['lifecycle']?.toString(),
                                  ),
                                ),
                              ),
                              DataCell(
                                AppSecondaryButton(
                                  onPressed: () => _onRowOpen(j),
                                  label: 'Batafsil',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _CreateKonkursDialog extends StatefulWidget {
  const _CreateKonkursDialog();

  @override
  State<_CreateKonkursDialog> createState() => _CreateKonkursDialogState();
}

class _Q {
  _Q(this.text, this.a, this.b, this.c, this.d, this.correct, this.points);
  String text;
  String a, b, c, d;
  int correct; // 0-3
  int points;
}

class _CreateKonkursDialogState extends State<_CreateKonkursDialog> {
  int _step = 0;
  final _title = TextEditingController(text: "Iste'dod Uchquni");
  final _desc = TextEditingController();
  String _subject = 'Matematika';
  String _age = '9-12';
  String _type = 'test';
  String _diff = "o'rta";
  DateTime _start = DateTime.now().add(const Duration(days: 1));
  DateTime _end = DateTime.now().add(const Duration(days: 1, hours: 1));
  int _duration = 30;
  int _attempts = 1;
  int _xp = 50;
  bool _shQ = true, _shA = true, _hide = false, _back = true, _cert = true;
  final List<_Q> _qs = [
    _Q("Qaysi biri ortiqcha?", "Olma", "Nok", "Sabzi", "Anor", 2, 10),
  ];
  final _api = AdminApi();
  String? _savedId;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  (int, int) get _agePair {
    if (_age == '6-8') return (6, 8);
    if (_age == '9-12') return (9, 12);
    if (_age == '13-16') return (13, 16);
    return (17, 18);
  }

  String _df(DateTime d) {
    return "${d.toUtc().toIso8601String().split(".").first}Z";
  }

  Map<String, dynamic> get _basePayload {
    final ag = _agePair;
    return {
      "title": _title.text.trim(),
      if (_desc.text.trim().isNotEmpty) "description": _desc.text.trim(),
      "subject": _subject,
      "ageFrom": ag.$1,
      "ageTo": ag.$2,
      "type": _type,
      "difficulty": _diff,
      "startTime": _df(_start),
      "endTime": _df(_end),
      "durationMin": _duration,
      "maxAttempts": _attempts,
      "xpReward": _xp,
      "shuffleQuestions": _shQ,
      "shuffleAnswers": _shA,
      "hideResults": _hide,
      "allowBack": _back,
      "certificateEnabled": _cert,
      "questions": [
        for (final q in _qs)
          {
            "text": q.text,
            "options": [q.a, q.b, q.c, q.d],
            "correctIndex": q.correct,
            "points": q.points,
          },
      ],
    };
  }

  Future<void> _saveDraft() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (_savedId == null) {
        final o = await _api.createOlympiad(_basePayload);
        _savedId = o['id']?.toString();
      } else {
        final p = Map<String, dynamic>.from(_basePayload)..remove('questions');
        await _api.updateOlympiad(_savedId!, p);
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Qoralama saqlandi.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorHandler.userMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _doPublish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final body = _basePayload;
      Map<String, dynamic> o;
      if (_savedId == null) {
        o = await _api.createOlympiad(body);
        _savedId = o['id']?.toString();
      } else {
        final p = Map<String, dynamic>.from(body)..remove('questions');
        o = await _api.updateOlympiad(_savedId!, p);
        _savedId = o['id']?.toString() ?? _savedId;
      }
      if (_savedId == null) throw StateError('No id');
      await _api.publishOlympiad(_savedId!);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("E'lon qilindi.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorHandler.userMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kModalBg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _step == 0
                        ? null
                        : () => setState(() => _step--),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      "Konkurs yaratish",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final on = i == _step;
                  return Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ["Asosiy", "Vaqt", "Savollar", "Sozlamalar"][i],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: on ? _kModalAccent : Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (i < 3)
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white24,
                            size: 16,
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildStepContent(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _saveDraft,
                    icon: const Icon(
                      Icons.save_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                    label: const Text(
                      "Qoralama",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            showDialog<void>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text("Ko'rib chiqish"),
                                content: SingleChildScrollView(
                                  child: Text(
                                    const JsonEncoder.withIndent(
                                      '  ',
                                    ).convert(_basePayload),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: "monospace",
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: const Text('Yopish'),
                                  ),
                                ],
                              ),
                            );
                          },
                    icon: const Icon(
                      Icons.remove_red_eye_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                    label: const Text(
                      "Oldindan ko'rish",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            if (_step < 3) {
                              setState(() => _step++);
                            } else {
                              _doPublish();
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: _kModalAccent,
                    ),
                    icon: Icon(
                      _step < 3 ? Icons.arrow_forward : Icons.send,
                      size: 18,
                    ),
                    label: Text(_step < 3 ? "Keyingi" : "E'lon qilish"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    Text label(String t) =>
        Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12));
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label("Konkurs nomi"),
            const SizedBox(height: 4),
            TextField(
              controller: _title,
              style: const TextStyle(color: Colors.white),
              maxLength: 100,
              decoration: _dec(),
            ),
            label("Tavsif"),
            const SizedBox(height: 4),
            TextField(
              controller: _desc,
              maxLength: 500,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _dec().copyWith(hintText: "Matn..."),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label("Fan"),
                      DropdownButtonFormField(
                        initialValue: _subject,
                        dropdownColor: _kModalBg,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec(),
                        items: const [
                          DropdownMenuItem(
                            value: "Matematika",
                            child: Text("Matematika"),
                          ),
                          DropdownMenuItem(
                            value: "Ona tili",
                            child: Text("Ona tili"),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _subject = v ?? 'Matematika'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label("Yosh guruhi"),
                      DropdownButtonFormField(
                        initialValue: _age,
                        dropdownColor: _kModalBg,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec(),
                        items: const [
                          DropdownMenuItem(
                            value: "6-8",
                            child: Text("6-8 yosh"),
                          ),
                          DropdownMenuItem(
                            value: "9-12",
                            child: Text("9-12 yosh"),
                          ),
                          DropdownMenuItem(
                            value: "13-16",
                            child: Text("13-16 yosh"),
                          ),
                        ],
                        onChanged: (v) => setState(() => _age = v ?? "9-12"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label("Turi"),
                      DropdownButtonFormField(
                        initialValue: _type,
                        dropdownColor: _kModalBg,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec(),
                        items: const [
                          DropdownMenuItem(
                            value: "test",
                            child: Text("Test olimpiada"),
                          ),
                          DropdownMenuItem(
                            value: "quiz",
                            child: Text("Viktorina"),
                          ),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? "test"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label("Qiyinlik"),
                      DropdownButtonFormField(
                        initialValue: _diff,
                        dropdownColor: _kModalBg,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec(),
                        items: const [
                          DropdownMenuItem(value: "oson", child: Text("Oson")),
                          DropdownMenuItem(
                            value: "o'rta",
                            child: Text("O'rta"),
                          ),
                          DropdownMenuItem(
                            value: "qiyin",
                            child: Text("Qiyin"),
                          ),
                        ],
                        onChanged: (v) => setState(() => _diff = v ?? "o'rta"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      case 1:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _timeCard(
                "Boshlanish",
                _start,
                (d) => setState(() {
                  _start = d;
                  if (!(_end.isAfter(_start))) {
                    _end = _start.add(const Duration(hours: 1));
                  }
                }),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _timeCard(
                "Tugash",
                _end,
                (d) => setState(() {
                  if (d.isAfter(_start)) {
                    _end = d;
                  }
                }),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    "Davomiyligi (min)",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  TextFormField(
                    key: ValueKey('dur-$_duration'),
                    initialValue: '$_duration',
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec().copyWith(hintText: "30"),
                    onChanged: (s) {
                      _duration = int.tryParse(s) ?? 30;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    "Urinishlar",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  TextFormField(
                    key: ValueKey('att-$_attempts'),
                    initialValue: '$_attempts',
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec().copyWith(hintText: "1"),
                    onChanged: (s) {
                      _attempts = int.tryParse(s) ?? 1;
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _qs.add(_Q("Yangi savol", "A", "B", "C", "D", 0, 10));
                    });
                  },
                  icon: const Icon(Icons.add, color: _kModalAccent),
                  label: const Text(
                    "Savol qo'shish",
                    style: TextStyle(color: _kModalAccent),
                  ),
                ),
              ],
            ),
            for (int i = 0; i < _qs.length; i++) _questionBlock(i, _qs[i]),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _qs.add(_Q("Yangi savol", "A", "B", "C", "D", 0, 10));
                });
              },
              child: const Text(" + Savol qo'shish "),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _switchRow(
              "Savollarni random berish",
              _shQ,
              (v) => setState(() => _shQ = v!),
            ),
            _switchRow(
              "Variantlarni aralashtirish",
              _shA,
              (v) => setState(() => _shA = v!),
            ),
            _switchRow(
              "Natijani yashirish",
              _hide,
              (v) => setState(() => _hide = v!),
            ),
            _switchRow(
              "Savollar orasida qaytish",
              _back,
              (v) => setState(() => _back = v!),
            ),
            _switchRow(
              "Sertifikat berilsinmi?",
              _cert,
              (v) => setState(() => _cert = v!),
            ),
            const SizedBox(height: 8),
            label("XP mukofoti"),
            TextFormField(
              key: ValueKey('xp-$_xp'),
              initialValue: '$_xp',
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              onChanged: (s) => _xp = int.tryParse(s) ?? 50,
              decoration: _dec(),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  InputDecoration _dec() => InputDecoration(
    filled: true,
    fillColor: const Color(0xFF1A1B24),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white10),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white10),
    ),
    hintStyle: const TextStyle(color: Colors.white30),
    counterStyle: const TextStyle(color: Colors.white38, fontSize: 10),
  );

  Widget _timeCard(String title, DateTime t, void Function(DateTime) onPicked) {
    return Card(
      color: const Color(0xFF1A1B24),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              _fmtD(t),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2100),
                  initialDate: t,
                );
                if (d == null) return;
                if (!mounted) return;
                final tm = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(t),
                );
                if (tm == null) return;
                onPicked(DateTime(d.year, d.month, d.day, tm.hour, tm.minute));
              },
              child: const Text("Tanlash"),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtD(DateTime t) {
    return '${_pad2(t.day)}.${_pad2(t.month)}.${t.year} ${t.hour.toString().padLeft(2, "0")}:${_pad2(t.minute)}';
  }

  String _pad2(int n) => n < 10 ? '0$n' : '$n';

  Widget _questionBlock(int i, _Q q) {
    return Card(
      color: const Color(0xFF1A1B24),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  "Savol ${i + 1}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                if (_qs.length > 1)
                  IconButton(
                    onPressed: () => setState(() => _qs.removeAt(i)),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white30,
                    ),
                  ),
              ],
            ),
            TextFormField(
              initialValue: q.text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _dec().copyWith(hintText: "Savol matni..."),
              onChanged: (s) => q.text = s,
            ),
            const SizedBox(height: 4),
            for (int o = 0; o < 4; o++)
              ListTile(
                dense: true,
                leading: Radio<int>(
                  value: o,
                  groupValue: q.correct,
                  activeColor: _kModalAccent,
                  onChanged: (v) => setState(() => q.correct = v ?? 0),
                ),
                title: TextFormField(
                  initialValue: [q.a, q.b, q.c, q.d][o],
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec().copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    hintText: "Variant ${"ABCD"[o]}",
                  ),
                  onChanged: (s) {
                    if (o == 0) {
                      q.a = s;
                    } else if (o == 1) {
                      q.b = s;
                    } else if (o == 2) {
                      q.c = s;
                    } else {
                      q.d = s;
                    }
                    setState(() {});
                  },
                ),
              ),
            Text("Ball: ${q.points}"),
            Slider(
              value: q.points.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              label: "${q.points}",
              onChanged: (v) => setState(() => q.points = v.toInt()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(String t, bool v, void Function(bool?) onCh) {
    return SwitchListTile(
      value: v,
      onChanged: onCh,
      title: Text(t, style: const TextStyle(color: Colors.white)),
      activeTrackColor: _kModalAccent,
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}
