import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ux/app_error_handler.dart';
import '../../core/ux/app_feedback.dart';
import '../../core/widgets/common.dart';

// Sprint 5.x — Sozlamalar (Settings) sahifa.
//
// Hozircha faqat 2FA boshqaruvi. Kelajakda profile edit, parol o'zgartirish,
// til, brand asset, ... shu yerga keladi.

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _api = AdminApi();
  bool _loading = true;
  bool _twoFactorEnabled = false;
  int _remainingBackupCodes = 0;
  DateTime? _enabledAt;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.twoFactorStatus(),
        _api.fetchStaffMe(),
      ]);
      if (!mounted) return;
      final s = results[0];
      final me = results[1];
      setState(() {
        _twoFactorEnabled = s['enabled'] == true;
        _remainingBackupCodes = (s['remainingBackupCodes'] as num?)?.toInt() ?? 0;
        _enabledAt = DateTime.tryParse(s['enabledAt']?.toString() ?? '');
        _profile = me;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppErrorHandler.showError(context, e);
    }
  }

  Future<void> _enable2fa() async {
    final enabled = await _TwoFactorSetupDialog.open(context, api: _api);
    if (enabled == true) await _loadAll();
  }

  Future<void> _disable2fa() async {
    final disabled = await _TwoFactorDisableDialog.open(context, api: _api);
    if (disabled == true) {
      if (!mounted) return;
      AppFeedback.success(context, '2FA o\'chirildi');
      await _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Sozlamalar'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Hisob xavfsizligi va shaxsiy sozlamalar.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          _ProfileCard(profile: _profile),
          const SizedBox(height: AppSpacing.md),
          _SecurityCard(
            loading: _loading,
            twoFactorEnabled: _twoFactorEnabled,
            remainingBackupCodes: _remainingBackupCodes,
            enabledAt: _enabledAt,
            onEnable: _enable2fa,
            onDisable: _disable2fa,
          ),
        ],
      ),
    );
  }
}

// ─── Profile card ──────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final email = profile['email']?.toString() ?? '—';
    final name = profile['name']?.toString() ?? '—';
    final role = profile['role']?.toString() ?? '—';
    return _Card(
      title: 'Profil',
      icon: Icons.person_outline,
      children: [
        _Row(label: 'Ism', value: name),
        _Row(label: 'Email', value: email),
        _Row(label: 'Rol', value: role),
      ],
    );
  }
}

// ─── Security (2FA) card ───────────────────────────────────────────────

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({
    required this.loading,
    required this.twoFactorEnabled,
    required this.remainingBackupCodes,
    required this.enabledAt,
    required this.onEnable,
    required this.onDisable,
  });

  final bool loading;
  final bool twoFactorEnabled;
  final int remainingBackupCodes;
  final DateTime? enabledAt;
  final VoidCallback onEnable;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Xavfsizlik',
      icon: Icons.shield_outlined,
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    twoFactorEnabled
                        ? Icons.lock_outline_rounded
                        : Icons.lock_open_rounded,
                    color: twoFactorEnabled ? Colors.green : Colors.orange,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ikki bosqichli autentifikatsiya (2FA)',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          twoFactorEnabled
                              ? 'Yoqilgan${enabledAt != null ? ' · ${_fmtDate(enabledAt!)}' : ''}'
                              : "O'chirilgan",
                          style: TextStyle(
                            color: twoFactorEnabled
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (twoFactorEnabled)
                    OutlinedButton.icon(
                      onPressed: onDisable,
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text('O\'chirish'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                    )
                  else
                    AppPrimaryButton(label: 'Yoqish', onPressed: onEnable),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'TOTP standartiga mos: Google Authenticator, Authy, 1Password va boshqa app\'lar bilan ishlaydi.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              if (twoFactorEnabled) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.key_outlined,
                        size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      'Backup kodlar: $remainingBackupCodes ta qoldi',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                if (remainingBackupCodes < 3) ...[
                  const SizedBox(height: 4),
                  Text(
                    remainingBackupCodes == 0
                        ? 'Backup kodlar tugadi. 2FA\'ni o\'chirib qayta yoqing.'
                        : 'Backup kodlar tugab boryapti. 2FA\'ni qayta yoqing.',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFEF4444)),
                  ),
                ],
              ],
            ],
          ),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}

// ─── Setup dialog (multi-step) ─────────────────────────────────────────

class _TwoFactorSetupDialog extends StatefulWidget {
  const _TwoFactorSetupDialog({required this.api});
  final AdminApi api;

  static Future<bool?> open(BuildContext context, {required AdminApi api}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TwoFactorSetupDialog(api: api),
    );
  }

  @override
  State<_TwoFactorSetupDialog> createState() => _TwoFactorSetupDialogState();
}

class _TwoFactorSetupDialogState extends State<_TwoFactorSetupDialog> {
  _Step _step = _Step.loading;
  String? _secret;
  String? _otpauthUri;
  final _codeController = TextEditingController();
  List<String> _backupCodes = const [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _step = _Step.loading;
      _error = null;
    });
    try {
      final r = await widget.api.twoFactorSetup();
      if (!mounted) return;
      setState(() {
        _secret = r['secret']?.toString();
        _otpauthUri = r['otpauthUri']?.toString();
        _step = _Step.scan;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.error;
        _error = AppErrorHandler.userMessage(e);
      });
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = '6 raqamli kodni kiriting');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.api.twoFactorEnable(code);
      if (!mounted) return;
      final codes = (r['backupCodes'] as List?)?.cast<dynamic>() ?? const [];
      setState(() {
        _backupCodes = codes.map((e) => e.toString()).toList();
        _step = _Step.backup;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppErrorHandler.userMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (_step) {
            _Step.loading => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
            _Step.error => _errorView(),
            _Step.scan => _scanView(),
            _Step.backup => _backupView(),
          },
        ),
      ),
    );
  }

  Widget _errorView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Xatolik'),
        const SizedBox(height: AppSpacing.sm),
        Text(_error ?? 'Noma\'lum xato'),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Yopish'),
            ),
            const SizedBox(width: 8),
            AppPrimaryButton(label: 'Qayta urinish', onPressed: _start),
          ],
        ),
      ],
    );
  }

  Widget _scanView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('2FA yoqish — 1/2 qadam'),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Authenticator app (Google Authenticator, Authy)\'da QR ni skanlang yoki secret\'ni qo\'lda kiriting.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_otpauthUri != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: QrImageView(
                data: _otpauthUri!,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (_secret != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _secret!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Nusxa olish',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _secret!));
                    if (!mounted) return;
                    AppFeedback.success(context, 'Nusxalandi');
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _codeController,
          maxLength: 6,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'App\'dagi 6 raqamli kod',
            counterText: '',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('Bekor qilish'),
            ),
            const SizedBox(width: 8),
            AppPrimaryButton(
              label: _busy ? 'Tekshirilmoqda...' : 'Tasdiqlash',
              onPressed: _busy ? null : _verify,
            ),
          ],
        ),
      ],
    );
  }

  Widget _backupView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('2FA yoqildi — 2/2 qadam'),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Backup kodlarni xavfsiz joyga saqlang. Bu kodlar telefoningiz yo\'qolganda 2FA o\'rniga ishlaydi. Har biri faqat bir marta ishlatiladi. Hozir ko\'rsatiladi va boshqa hech qachon ko\'rinmaydi.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            children: _backupCodes.map(_BackupCode.new).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: _backupCodes.join('\n')),
                );
                if (!mounted) return;
                AppFeedback.success(context, 'Backup kodlar nusxalandi');
              },
              icon: const Icon(Icons.copy_all, size: 18),
              label: const Text('Nusxa olish'),
            ),
            const Spacer(),
            AppPrimaryButton(
              label: 'Tushundim, saqladim',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ],
    );
  }
}

class _BackupCode extends StatelessWidget {
  const _BackupCode(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      code,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      ),
    );
  }
}

enum _Step { loading, scan, backup, error }

// ─── Disable dialog ────────────────────────────────────────────────────

class _TwoFactorDisableDialog extends StatefulWidget {
  const _TwoFactorDisableDialog({required this.api});
  final AdminApi api;

  static Future<bool?> open(BuildContext context, {required AdminApi api}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => _TwoFactorDisableDialog(api: api),
    );
  }

  @override
  State<_TwoFactorDisableDialog> createState() =>
      _TwoFactorDisableDialogState();
}

class _TwoFactorDisableDialogState extends State<_TwoFactorDisableDialog> {
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Parolni kiriting');
      return;
    }
    if (_code.text.trim().isEmpty) {
      setState(() => _error = 'Kodni kiriting (TOTP yoki backup)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.twoFactorDisable(
        password: _password.text,
        code: _code.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppErrorHandler.userMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('2FA o\'chirish'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tasdiqlash uchun parol va joriy 2FA kodni kiriting (yoki backup kod).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Parol',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'TOTP yoki backup kod',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Bekor'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? '...' : 'O\'chirish'),
        ),
      ],
    );
  }
}

// ─── Local helper widgets ──────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: Color(0xFF64748B))),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
