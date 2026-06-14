// ─────────────────────────────────────────────────────────────────────
// UnlockRequestModal — bola qo'shimcha vaqt so'raydi (daqiqa + sabab)
// ─────────────────────────────────────────────────────────────────────
//
// Bloklangan ilova overlay'idagi "Ruxsat so'rash" tugmasi yoki "vaqting
// tugayapti" ogohlantirish notification'i Parvoz'ni ochganda shu modal
// chiqadi. Bola qancha vaqt (5..60 daqiqa) va sababini kiritadi, "SO'RASH"
// bossa ota-onaga so'rov ketadi.
//
// Foydalanish:
//   final input = await UnlockRequestModal.show(context, appName: 'YouTube');
//   if (input != null) repo.createRequest(..., requestedMinutes: input.minutes,
//                                          reason: input.reason);

// ignore_for_file: public_member_api_docs

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/shared/widgets/primary_button.dart';
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
    final adaptive = context.adaptive;
    final appName = widget.appName?.trim();
    return Padding(
      // Klaviatura ko'tarilganda input ko'rinib tursin.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: adaptive.bgPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: adaptive.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.lock_clock_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Qo'shimcha vaqt so'rash",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: adaptive.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              (appName != null && appName.isNotEmpty)
                  ? '"$appName" uchun ota-onangdan qancha vaqt so\'raysan?'
                  : "Ota-onangdan qancha qo'shimcha vaqt so'raysan?",
              style: TextStyle(
                fontSize: 14,
                color: adaptive.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _Label('Vaqt', color: adaptive.textTertiary),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in _options)
                  _MinuteChoice(
                    minutes: m,
                    selected: _minutes == m,
                    textPrimary: adaptive.textPrimary,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _minutes = m);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _Label('Sabab (ixtiyoriy)', color: adaptive.textTertiary),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              maxLength: 200,
              minLines: 2,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              style: TextStyle(color: adaptive.textPrimary),
              decoration: InputDecoration(
                hintText: 'Masalan: darsga tayyorlanyapman',
                hintStyle: TextStyle(color: adaptive.textTertiary),
                counterText: '',
                filled: true,
                fillColor: adaptive.bgSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: adaptive.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: adaptive.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              text: "SO'RASH",
              icon: Icons.send_rounded,
              onPressed: _submit,
            ),
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

/// Daqiqa tanlash chip'i — tanlangan bo'lsa to'la yashil, aks holda outline.
class _MinuteChoice extends StatelessWidget {
  const _MinuteChoice({
    required this.minutes,
    required this.selected,
    required this.textPrimary,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final Color textPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: 1.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Text(
            '$minutes daqiqa',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.textOnPrimary : textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
