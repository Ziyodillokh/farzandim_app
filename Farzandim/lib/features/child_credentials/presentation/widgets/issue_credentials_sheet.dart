// ─────────────────────────────────────────────────────────────────────
// IssueCredentialsSheet — birinchi marta login va parol berish
// ─────────────────────────────────────────────────────────────────────
//
// Login ixtiyoriy: bo'sh qoldirilsa backend o'zi tanlaydi (masalan
// "aziza.k24"). Yozilsa — kichik harfga o'tkaziladi va backend naqshi
// bo'yicha tekshiriladi (buzilgan qoida maydon ostida aytiladi). Band login
// (409) shu varaqda, maydon ostida chiqadi — varaq yopilmaydi. Muvaffaqiyatda
// varaq `IssuedCredentials` bilan yopiladi; vaqtinchalik parolni chaqiruvchi
// "parol varag'i"da ko'rsatadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/child_credentials/data/child_login.dart';
import 'package:farzandim/features/child_credentials/data/credentials_failure.dart';
import 'package:farzandim/features/child_credentials/data/models/issued_credentials.dart';
import 'package:farzandim/features/child_credentials/presentation/providers/child_credentials_providers.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/credentials_ui.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Varaqni ochadi. Yangi login va vaqtinchalik parol berilsa — shu natija,
/// bekor qilinsa — `null`.
Future<IssuedCredentials?> showIssueCredentialsSheet(
  BuildContext context, {
  required String childId,
  required String childName,
}) {
  return showCredentialsSheet<IssuedCredentials>(
    context,
    builder: (_) =>
        IssueCredentialsSheet(childId: childId, childName: childName),
  );
}

class IssueCredentialsSheet extends ConsumerStatefulWidget {
  const IssueCredentialsSheet({
    required this.childId,
    required this.childName,
    super.key,
  });

  final String childId;
  final String childName;

  @override
  ConsumerState<IssueCredentialsSheet> createState() =>
      _IssueCredentialsSheetState();
}

class _IssueCredentialsSheetState extends ConsumerState<IssueCredentialsSheet> {
  final _login = TextEditingController();
  bool _busy = false;

  /// Serverdan kelgan xato (tarjima qilingan) — yangi kiritishda yo'qoladi.
  String? _error;

  bool get _hasLogin => ChildLogin.normalize(_login.text).isNotEmpty;

  /// Bo'sh login qoidaga zid emas (backend tanlaydi).
  ChildLoginIssue? get _issue =>
      _hasLogin ? ChildLogin.validate(_login.text) : null;

  /// "Kamida 4 belgi" yozayotganda xato emas — pastdagi izohda turadi;
  /// qolgan buzilishlar (harf, belgi, uzunlik) darhol qizil chiqadi.
  ChildLoginIssue? get _shownIssue =>
      _issue == ChildLoginIssue.tooShort ? null : _issue;

  bool get _canSubmit => !_busy && _issue == null;

  @override
  void dispose() {
    _login.dispose();
    super.dispose();
  }

  void _onChanged(String _) => setState(() => _error = null);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    final custom = _hasLogin ? ChildLogin.normalize(_login.text) : null;
    final actions = ref.read(childCredentialsActionsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    final CredentialsResult<IssuedCredentials> result;
    try {
      result = await actions.issue(widget.childId, login: custom);
    } on Object {
      // Kutilmagan dastur xatosi: varaq band holatda qotib qolmasin; xatoning
      // o'zi yuqoriga ketadi (hisobotga tushadi).
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'errors.generic'.tr();
        });
      }
      rethrow;
    }
    if (!mounted) return;
    final issued = result.data;
    if (issued != null) {
      Navigator.of(context).pop(issued);
      return;
    }
    setState(() {
      _busy = false;
      _error = _messageFor(result.failure, customLogin: custom != null);
    });
  }

  /// Yozilgan login qoidaga to'g'ri kelmagan bo'lsa (400) — login haqida;
  /// qolgan xatolar o'z xabari bilan.
  String _messageFor(CredentialsFailure? failure, {required bool customLogin}) {
    if (failure == null) return 'errors.generic'.tr();
    if (customLogin && failure.kind == CredentialsFailureKind.validation) {
      return 'childCredentials.login.invalidFormat'.tr();
    }
    return failure.messageKey.tr();
  }

  @override
  Widget build(BuildContext context) {
    final issue = _shownIssue;
    final error = _error;
    return PopScope(
      canPop: !_busy,
      child: SchoolSheetFrame(
        title: 'childCredentials.issue.title'.tr(),
        subtitle: 'childCredentials.issue.subtitle'.tr(
          namedArgs: {'name': widget.childName},
        ),
        children: [
          ParvozTextField(
            label: 'childCredentials.issue.loginLabel'.tr(),
            hint: 'childCredentials.issue.loginHint'.tr(),
            controller: _login,
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [_LowercaseFormatter()],
            onChanged: _onChanged,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'childCredentials.issue.loginHelp'.tr(),
              style: CredStyle.pop(12.5, c: CredStyle.dim),
            ),
          ),
          if (issue != null) ...[
            const SizedBox(height: 10),
            SchoolInlineError(message: issue.messageKey.tr()),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            SchoolInlineError(message: error),
          ],
          const SizedBox(height: 22),
          ParvozPrimaryButton(
            label: 'childCredentials.issue.submit'.tr(),
            onPressed: _submit,
            enabled: _canSubmit,
            loading: _busy,
            showArrow: false,
          ),
          const SizedBox(height: 4),
          SchoolTextButton(
            label: 'common.cancel'.tr(),
            onTap: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Login har doim kichik harfda ko'rinadi (backend ham shunday saqlaydi).
class _LowercaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toLowerCase();
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: newValue.selection.extentOffset.clamp(0, text.length),
      ),
    );
  }
}
