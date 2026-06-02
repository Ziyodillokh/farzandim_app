import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ux/app_error_handler.dart';
import 'staff_permissions.dart';

class ModeratorFormPage extends StatefulWidget {
  const ModeratorFormPage({super.key, this.editId});

  final String? editId;

  @override
  State<ModeratorFormPage> createState() => _ModeratorFormPageState();
}

class _ModeratorFormPageState extends State<ModeratorFormPage> {
  final _api = AdminApi();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController(text: '+998');
  final _password = TextEditingController();
  String? _roleKey;
  final Set<String> _perms = {};
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _isEdit => widget.editId != null && widget.editId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final m = await _api.getModerator(widget.editId!);
      if (!mounted) {
        return;
      }
      _name.text = '${m['name'] ?? ''}';
      _email.text = '${m['email'] ?? ''}';
      _phone.text = (m['phone'] as String?)?.trim().isNotEmpty == true
          ? '${m['phone']}'
          : '+998';
      _roleKey = m['moderatorRoleKey'] as String?;
      final p = m['permissions'];
      if (p is List) {
        _perms
          ..clear()
          ..addAll(p.map((e) => '$e'));
      }
    } catch (e) {
      _loadError = AppErrorHandler.userMessage(e);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _toggleAllForGroup(ModeratorPermGroup g, bool v) {
    setState(() {
      for (final k in g.keys) {
        if (v) {
          _perms.add(k.id);
        } else {
          _perms.remove(k.id);
        }
      }
    });
  }

  bool _groupAllSelected(ModeratorPermGroup g) =>
      g.keys.every((k) => _perms.contains(k.id));

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty || _roleKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("To'ldirilmagan maydonlar bor")),
      );
      return;
    }
    if (!_isEdit && _password.text.trim().length < 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Parol kamida 8 belgi')));
      return;
    }
    if (_perms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kamida bitta ruxsat tanlang")),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': name,
        'email': email,
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'moderatorRoleKey': _roleKey,
        'permissions': _perms.toList()..sort(),
        if (_password.text.trim().isNotEmpty) 'password': _password.text.trim(),
      };
      if (_isEdit) {
        if (_password.text.trim().isEmpty) {
          body.remove('password');
        }
        await _api.updateModerator(widget.editId!, body);
      } else {
        if (_password.text.trim().length < 8) {
          throw StateError('Parol kiritilishi shart');
        }
        body['password'] = _password.text.trim();
        await _api.createModerator(body);
      }
      if (!mounted) {
        return;
      }
      context.go('/moderators');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorHandler.userMessage(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  InputDecoration _field(String? hint, {String? label}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Color(0xFFF3F4F6),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return ColoredBox(
        color: const Color(0xFFF3F4F6),
        child: Center(
          child: Text(
            _loadError!,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      );
    }
    return ColoredBox(
      color: const Color(0xFFF3F4F6),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.go('/moderators'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    label: const Text('Orqaga'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEdit ? 'Moderatorni tahrirlash' : 'Yangi moderator',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                _card(
                  title: "Asosiy ma'lumotlar",
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth > 700;
                      final nameField = TextField(
                        controller: _name,
                        decoration: _field("Ism kiriting", label: "To'liq ism"),
                      );
                      final emailField = TextField(
                        controller: _email,
                        enabled: !_isEdit,
                        decoration: _field('email@example.com', label: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                      );
                      final phoneField = TextField(
                        controller: _phone,
                        decoration: _field(null, label: 'Telefon'),
                        keyboardType: TextInputType.phone,
                      );
                      final role = DropdownButtonFormField<String>(
                        initialValue: _roleKey,
                        decoration: _field(null, label: 'Rol'),
                        hint: const Text('Rolni tanlang'),
                        items: kModeratorRoleChoices
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _roleKey = v),
                      );
                      if (wide) {
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: nameField),
                                const SizedBox(width: 16),
                                Expanded(child: emailField),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: phoneField),
                                const SizedBox(width: 16),
                                Expanded(child: role),
                              ],
                            ),
                            if (!_isEdit) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _password,
                                obscureText: true,
                                decoration: _field(null, label: 'Parol'),
                              ),
                            ] else ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _password,
                                obscureText: true,
                                decoration:
                                    _field(
                                      'Yangi parol (ixtiyoriy)',
                                      label: 'Parol',
                                    ).copyWith(
                                      helperText:
                                          "Bo'sh qoldiring — o'zgarmasdan",
                                    ),
                              ),
                            ],
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          nameField,
                          const SizedBox(height: 12),
                          TextField(
                            controller: _email,
                            enabled: !_isEdit,
                            decoration: _field(
                              'email@example.com',
                              label: 'Email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          phoneField,
                          const SizedBox(height: 12),
                          role,
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            decoration: _field(
                              _isEdit ? 'Yangi parol' : 'Parol',
                              label: 'Parol',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ruxsatlar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final col = w >= 1000
                        ? 3
                        : w >= 700
                        ? 2
                        : 1;
                    return GridView.count(
                      crossAxisCount: col,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: kModeratorPermGroups
                          .map(
                            (g) => _permGroupCard(
                              g,
                              groupAll: _groupAllSelected(g),
                              onGroupAll: (v) => _toggleAllForGroup(g, v),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEdit ? 'Saqlash' : 'Yaratish'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _permGroupCard(
    ModeratorPermGroup g, {
    required bool groupAll,
    required ValueChanged<bool> onGroupAll,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(g.icon, size: 22, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  g.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Barchasini tanlash",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Checkbox(
                    value: groupAll,
                    onChanged: (v) => onGroupAll(v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          ...g.keys.map(
            (k) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(k.label, style: const TextStyle(fontSize: 14)),
              value: _perms.contains(k.id),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _perms.add(k.id);
                  } else {
                    _perms.remove(k.id);
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        ],
      ),
    );
  }
}
