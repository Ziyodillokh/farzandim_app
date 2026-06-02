import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/common.dart';
import 'monetization_feature_catalog.dart';

class MonetizationPlansPage extends StatefulWidget {
  const MonetizationPlansPage({super.key});

  @override
  State<MonetizationPlansPage> createState() => _MonetizationPlansPageState();
}

class _MonetizationPlansPageState extends State<MonetizationPlansPage> {
  final _api = AdminApi();
  List<Map<String, dynamic>> _plans = [];
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.listMonetizationPlans();
      if (!mounted) {
        return;
      }
      setState(() {
        _plans = rows;
        _loading = false;
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

  String _formatSom(int n) {
    if (n == 0) {
      return "0 so'm";
    }
    return "${NumberFormat('#,###', 'en').format(n).replaceAll(',', ' ')} so'm";
  }

  String _periodUz(String? p) {
    switch (p) {
      case 'free':
        return 'Bepul';
      case 'monthly':
        return 'Oylik';
      case 'yearly':
        return 'Yillik';
      default:
        return p ?? '—';
    }
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
                title: 'Tariflar',
                subtitle: 'Monetizatsiya',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              onPressed: _loading ? null : () => _openPlanDialog(context, null),
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
              child: const Text('Yangi tarif yaratish'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 960;
              if (_plans.isEmpty) {
                return const Text(
                  'Hozircha tariflar yo‘q. Yangi tarif yarating.',
                  style: TextStyle(color: AppColors.textSecondary),
                );
              }
              final children = _plans
                  .map(
                    (p) => _PlanCard(
                      plan: p,
                      formatSom: _formatSom,
                      periodUz: _periodUz,
                      onEdit: () => _openPlanDialog(context, p),
                      onDelete: () => _confirmDelete(p),
                    ),
                  )
                  .toList();
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(child: children[i]),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    children[i],
                  ],
                ],
              );
            },
          ),
      ],
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> p) async {
    final name = p['name']?.toString() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("O'chirish"),
        content: Text('“$name” ni o‘chirmoqchimisiz?'),
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
    final id = p['id']?.toString();
    if (id == null) {
      return;
    }
    try {
      final r = await _api.deleteMonetizationPlan(id);
      if (mounted) {
        final soft = r['soft'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              soft
                  ? 'Tarif o‘chirilmadi, nofaol qilindi (bog‘liq yozuvlar bor).'
                  : 'Tarif o‘chirildi.',
            ),
          ),
        );
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

  Future<void> _openPlanDialog(
    BuildContext context,
    Map<String, dynamic>? existing,
  ) async {
    final nameC = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    final slugC = TextEditingController(
      text: existing?['slug']?.toString() ?? '',
    );
    final priceC = TextEditingController(
      text: (existing?['priceUzs'] is int)
          ? '${existing!['priceUzs']}'
          : (existing?['priceUzs']?.toString() ?? '0'),
    );
    final descC = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );
    final badgeC = TextEditingController(
      text: existing?['badge']?.toString() ?? '',
    );
    var period = (existing?['period']?.toString() ?? 'monthly');
    if (!['free', 'monthly', 'yearly'].contains(period)) {
      period = 'monthly';
    }
    var tier = (existing?['entitlementTier']?.toString() ?? 'standard');
    if (!['free', 'standard', 'premium'].contains(tier)) {
      tier = 'standard';
    }
    final selected = <String>{
      if (existing?['features'] is List)
        ...((existing!['features'] as List)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)),
    };

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
                          ? 'Yangi tarif yaratish'
                          : "Tarifni tahrirlash",
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
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Tarif nomi',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameC,
                        decoration: const InputDecoration(
                          hintText: 'Masalan: Premium tarif',
                        ),
                        onChanged: (v) {
                          if (existing == null && slugC.text.isEmpty) {
                            final s = v
                                .toLowerCase()
                                .trim()
                                .replaceAll(RegExp(r'\s+'), '-')
                                .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
                            slugC.text = s;
                          }
                        },
                      ),
                      if (existing == null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Slug (URL)',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: slugC,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-z0-9\-]'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        "Narx (so'm)",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: priceC,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(hintText: '0'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Davr',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: period,
                        items: const [
                          DropdownMenuItem(
                            value: 'free',
                            child: Text("Bepul (free)"),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('Oylik'),
                          ),
                          DropdownMenuItem(
                            value: 'yearly',
                            child: Text('Yillik'),
                          ),
                        ],
                        onChanged: (v) => setS(() => period = v ?? 'monthly'),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Huquq darajasi (entitlement)",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: tier,
                        items: kEntitlementTiers
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(t.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setS(() => tier = v ?? 'standard'),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Yorliq (ixtiyoriy, masalan: Mashhur)",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: badgeC,
                        decoration: const InputDecoration(hintText: 'Mashhur'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tavsif',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descC,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: "Tarif haqida qisqacha ma'lumot...",
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Imkoniyatlar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: Scrollbar(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final f in kPlanFeatureOptions)
                                CheckboxListTile(
                                  dense: true,
                                  value: selected.contains(f.id),
                                  onChanged: (v) {
                                    setS(() {
                                      if (v == true) {
                                        selected.add(f.id);
                                      } else {
                                        selected.remove(f.id);
                                      }
                                    });
                                  },
                                  title: Text(
                                    f.labelUz,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Bekor qilish'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sidebarLime,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  onPressed: () async {
                    final price = int.tryParse(priceC.text.trim()) ?? 0;
                    final features = selected.toList()..sort();
                    final body = <String, dynamic>{
                      'name': nameC.text.trim(),
                      'description': descC.text.trim().isEmpty
                          ? null
                          : descC.text.trim(),
                      'period': period,
                      'priceUzs': price,
                      'features': features,
                      'badge': badgeC.text.trim().isEmpty
                          ? null
                          : badgeC.text.trim(),
                      'entitlementTier': tier,
                    };
                    if (existing == null) {
                      var slug = slugC.text.trim();
                      if (slug.isEmpty) {
                        slug = nameC.text
                            .toLowerCase()
                            .trim()
                            .replaceAll(RegExp(r'\s+'), '-')
                            .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
                      }
                      body['slug'] = slug;
                    }
                    try {
                      if (existing == null) {
                        await _api.createMonetizationPlan(body);
                      } else {
                        await _api.updateMonetizationPlan(
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.formatSom,
    required this.periodUz,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> plan;
  final String Function(int) formatSom;
  final String Function(String?) periodUz;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = plan['name']?.toString() ?? '';
    final period = plan['period']?.toString() ?? 'monthly';
    final price = (plan['priceUzs'] is int)
        ? plan['priceUzs'] as int
        : int.tryParse(plan['priceUzs']?.toString() ?? '0') ?? 0;
    final features = (plan['features'] is List)
        ? (plan['features'] as List)
        : const [];
    final badge = plan['badge']?.toString();
    final active = plan['isActive'] != false;

    return Opacity(
      opacity: active ? 1 : 0.55,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          periodUz(period),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (badge != null && badge.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sidebarLime.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                formatSom(price),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                period == 'yearly'
                    ? 'yiliga'
                    : (period == 'free' ? ' ' : 'oyiga'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              for (final f in features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _labelForFeatureId(f.toString()),
                          style: const TextStyle(fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Tahrirlash'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onDelete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text("O'chirish"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _labelForFeatureId(String id) {
    for (final o in kPlanFeatureOptions) {
      if (o.id == id) {
        return o.labelUz;
      }
    }
    return id;
  }
}
