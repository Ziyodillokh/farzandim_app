// ─────────────────────────────────────────────────────────────────────
// UnlockRequestModal — bola qo'shimcha vaqt so'raydi (daqiqa + sabab)
// ─────────────────────────────────────────────────────────────────────
//
// Bloklangan ilova overlay'idagi "Ruxsat so'rash" tugmasi yoki "vaqting
// tugayapti" ogohlantirish notification'i Parvoz'ni ochganda shu modal
// chiqadi. Bola qancha vaqt (5..60 daqiqa) va sababini kiritadi, SO'RASH
// bossa ota-onaga so'rov ketadi.
//
// Dizayn: Parvoz NIGHT (navy + aqua) — `context.adaptive.pv*` tokenlari
// bilan (ConsentScreen / PairWaiting bilan bir xil tizim). Eski adaptive
// (oq/aqua) ko'rinish o'rniga redizayn palitrasiga moslashtirildi.
//
// Foydalanish:
//   final input = await UnlockRequestModal.show(context, appName: 'YouTube');
//   if (input != null) repo.createRequest(..., requestedMinutes: input.minutes,
//                                          reason: input.reason);

// ignore_for_file: public_member_api_docs

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal natijasi — so'ralgan daqiqa va sabab.
@immutable
class UnlockRequestInput {
  const UnlockRequestInput({required this.minutes, required this.reason});

  /// So'ralgan daqiqa (5..60).
  final int minutes;

  /// Sabab (bo'sh bo'lishi mumkin).
  final String reason;
}

class UnlockRequestModal extends StatefulWidget {
  const UnlockRequestModal({this.appName, super.key});

  /// Bloklangan ilova nomi (bo'lsa sarlavhada ko'rsatiladi).
  final String? appName;

  /// Modalni ochadi; bola so'rasa [UnlockRequestInput], bekor qilsa null.
  static Future<UnlockRequestInput?> show(
    BuildContext context, {
    String? appName,
  }) {
    return showModalBottomSheet<UnlockRequestInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => UnlockRequestModal(appName: appName),
    );
  }

  @override
  State<UnlockRequestModal> createState() => _UnlockRequestModalState();
}

class _UnlockRequestModalState extends State<UnlockRequestModal> {
  static const List<int> _options = [5, 15, 30, 60];
  int _minutes = 15;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      UnlockRequestInput(
        minutes: _minutes,
        reason: _reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = context.adaptive;
    final appName = widget.appName?.trim();
    return Padding(
      // Klaviatura ko'tarilganda input ko'rinib tursin.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: a.pvBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: a.pvBorderStrong)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: a.pvBorderStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: a.pvGreen.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lock_clock_rounded,
                    color: a.pvGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'unlockRequest.title'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: a.pvText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              (appName != null && appName.isNotEmpty)
                  ? 'unlockRequest.subtitleWithApp'.tr(
                      namedArgs: {'app': appName},
                    )
                  : 'unlockRequest.subtitle'.tr(),
              style: TextStyle(fontSize: 14, color: a.pvTextDim, height: 1.4),
            ),
            const SizedBox(height: 20),
            _Label('unlockRequest.timeLabel'.tr(), color: a.pvTextDim),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in _options)
                  _MinuteChoice(
                    minutes: m,
                    selected: _minutes == m,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _minutes = m);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _Label('unlockRequest.reasonLabel'.tr(), color: a.pvTextDim),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              maxLength: 200,
              minLines: 2,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              cursorColor: a.pvGreen,
              style: TextStyle(color: a.pvText),
              decoration: InputDecoration(
                hintText: 'unlockRequest.reasonHint'.tr(),
                hintStyle: TextStyle(color: a.pvTextDim),
                counterText: '',
                filled: true,
                fillColor: a.pvSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: a.pvBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: a.pvBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: a.pvGreen, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SubmitButton(onTap: _submit),
          ],
        ),
      ),
    );
  }
}

/// Kichik bo'lim sarlavhasi.
class _Label extends StatelessWidget {
  const _Label(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// Daqiqa tanlash chip'i — tanlangan bo'lsa to'la aqua, aks holda navy surface.
class _MinuteChoice extends StatelessWidget {
  const _MinuteChoice({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = context.adaptive;
    return Material(
      color: selected ? a.pvGreen : a.pvSurface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? a.pvGreen : a.pvBorder, width: 1.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Text(
            'unlockRequest.minutes'.tr(namedArgs: {'minutes': '$minutes'}),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? a.pvOnGreen : a.pvText,
            ),
          ),
        ),
      ),
    );
  }
}

/// "SO'RASH" — to'liq-kenglik aqua CTA (Parvoz night).
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = context.adaptive;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: a.pvGreen,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: a.pvGreen.withValues(alpha: 0.32),
              blurRadius: 18,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'unlockRequest.submit'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: a.pvOnGreen,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.send_rounded, size: 19, color: a.pvOnGreen),
          ],
        ),
      ),
    );
  }
}
