// ─────────────────────────────────────────────────────────────────────
// Ota-ona PIN dialogi — "Ekran vaqti" sozlamalarini o'zgartirishdan oldin
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:farzandim_child/features/permissions/presentation/widgets/permission_setup_widgets.dart';
import 'package:farzandim_child/features/screen_time/data/parent_pin_store.dart';

/// PIN yo'q bo'lsa — o'rnatadi (ikki marta kiritish), bor bo'lsa — tekshiradi.
/// `true` — ota-ona tasdiqladi.
Future<bool> confirmParent(BuildContext context, ParentPinStore store) async {
  if (await store.hasPin()) {
    if (!context.mounted) return false;
    return _verifyPin(context, store);
  }
  if (!context.mounted) return false;
  return _createPin(context, store);
}

Future<bool> _createPin(BuildContext context, ParentPinStore store) async {
  String? error;
  while (true) {
    if (!context.mounted) return false;
    final first = await _askPin(
      context,
      title: 'screenTime.pinCreateTitle'.tr(),
      body: 'screenTime.pinCreateBody'.tr(),
      error: error,
    );
    if (first == null || !context.mounted) return false;
    final second = await _askPin(
      context,
      title: 'screenTime.pinConfirmTitle'.tr(),
    );
    if (second == null) return false;
    if (first == second) {
      await store.setPin(first);
      return true;
    }
    error = 'screenTime.pinMismatch'.tr();
  }
}

Future<bool> _verifyPin(BuildContext context, ParentPinStore store) async {
  String? error = await _lockedMessage(store);
  while (true) {
    if (!context.mounted) return false;
    final pin = await _askPin(
      context,
      title: 'screenTime.pinEnterTitle'.tr(),
      error: error,
    );
    if (pin == null) return false;
    switch (await store.verify(pin)) {
      case PinCheckResult.ok:
        return true;
      case PinCheckResult.wrong:
        error = 'screenTime.pinWrong'.tr();
      case PinCheckResult.locked:
        error = await _lockedMessage(store);
    }
  }
}

Future<String?> _lockedMessage(ParentPinStore store) async {
  final left = await store.lockRemaining();
  if (left == null) return null;
  final minutes = (left.inSeconds / 60).ceil();
  return 'screenTime.pinLocked'.tr(namedArgs: {'minutes': '$minutes'});
}

Future<String?> _askPin(
  BuildContext context, {
  required String title,
  String? body,
  String? error,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinDialog(title: title, body: body, error: error),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title, this.body, this.error});

  final String title;
  final String? body;
  final String? error;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isComplete => ParentPinStore.isValidFormat(_controller.text);

  void _submit() {
    if (_isComplete) Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.body;
    final error = widget.error;
    return AlertDialog(
      backgroundColor: const Color(0xFF12171E),
      title: Text(
        widget.title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (body != null) ...[
            Text(
              body,
              style: GoogleFonts.poppins(
                color: PermColors.dim,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: ParentPinStore.pinLength,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              letterSpacing: 12,
            ),
            decoration: const InputDecoration(
              counterText: '',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: PermColors.dim),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: PermColors.blueLight),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error,
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF6B6B),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'screenTime.pinCancel'.tr(),
            style: GoogleFonts.poppins(color: PermColors.dim),
          ),
        ),
        TextButton(
          onPressed: _isComplete ? _submit : null,
          child: Text(
            'screenTime.pinNext'.tr(),
            style: GoogleFonts.poppins(
              color: _isComplete ? PermColors.blueLight : PermColors.dim,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
