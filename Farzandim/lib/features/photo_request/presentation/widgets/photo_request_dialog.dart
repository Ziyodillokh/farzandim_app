// ─────────────────────────────────────────────────────────────────────
// PhotoRequestDialog — Parent → bola rasm so'rash (Sprint 4.4.16)
// ─────────────────────────────────────────────────────────────────────
//
// Parent App'da bola tanlangan paytda "Rasm so'rash" tugma orqali
// ochiladi. Message (ixtiyoriy) kiritib, Backend'ga POST yuboradi.
// Bola Child App'da WS push xabar oladi (sos kabi).

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/photo_request/presentation/providers/photo_request_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola'ga rasm so'rovi yuborish dialog'i.
///
/// Foydalanish:
/// ```dart
/// await PhotoRequestDialog.show(context, childId: 'uuid');
/// ```
class PhotoRequestDialog extends ConsumerStatefulWidget {
  /// `PhotoRequestDialog` konstruktor.
  const PhotoRequestDialog({required this.childId, super.key});

  /// Qaysi bola'ga rasm so'rov yuborilyapti.
  final String childId;

  /// Dialog ochish helper'i.
  static Future<void> show(BuildContext context,
      {required String childId}) {
    return showDialog<void>(
      context: context,
      builder: (_) => PhotoRequestDialog(childId: childId),
    );
  }

  @override
  ConsumerState<PhotoRequestDialog> createState() =>
      _PhotoRequestDialogState();
}

class _PhotoRequestDialogState extends ConsumerState<PhotoRequestDialog> {
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    setState(() => _isSending = true);
    final message = _messageController.text.trim();
    final ok = await ref
        .read(photoRequestActionsProvider.notifier)
        .createRequest(
          childId: widget.childId,
          message: message.isEmpty ? null : message,
        );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rasm so\'rovi yuborildi'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yuborilmadi, qaytadan urinib ko\'ring'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          const Icon(
            Icons.photo_camera_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              'Bola\'dan rasm so\'rash',
              style: AppTextStyles.headlineL.copyWith(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bolaga xabar (ixtiyoriy):',
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          TextField(
            controller: _messageController,
            maxLength: 120,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Bog\'da nima qilyapsan?',
              hintStyle: AppTextStyles.bodyM.copyWith(
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: AppTextStyles.bodyM,
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Bola Child App\'da push xabar oladi va rasm yuboradi.',
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Bekor qilish',
            style: AppTextStyles.bodyM.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: _isSending ? null : _onSend,
          child: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  'So\'rash',
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}
