// ─────────────────────────────────────────────────────────────────────
// PhotoRequestDialog — Parent → bola rasm so'rash (Sprint 4.4.16)
// ─────────────────────────────────────────────────────────────────────
//
// Parent App'da bola tanlangan paytda "Rasm so'rash" tugma orqali
// ochiladi. Message (ixtiyoriy) kiritib, Backend'ga POST yuboradi.
// Bola Child App'da WS push xabar oladi (sos kabi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/photo_request/presentation/providers/photo_request_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
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
  static Future<void> show(BuildContext context, {required String childId}) {
    return showDialog<void>(
      context: context,
      builder: (_) => PhotoRequestDialog(childId: childId),
    );
  }

  @override
  ConsumerState<PhotoRequestDialog> createState() => _PhotoRequestDialogState();
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
      AppToast.success(context, 'photoRequests.sentSnack'.tr());
    } else {
      AppToast.error(context, 'photoRequests.sendErrorSnack'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(Icons.photo_camera_rounded, color: AppColors.accent),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              'photoRequests.dialogTitle'.tr(),
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
            'photoRequests.messageLabel'.tr(),
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.sm),
          TextField(
            controller: _messageController,
            maxLength: 120,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'photoRequests.messageHint'.tr(),
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
            'photoRequests.dialogNote'.tr(),
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: Text(
            'common.cancel'.tr(),
            style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _isSending ? null : _onSend,
          child: _isSending
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              : Text(
                  'photoRequests.sendButton'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}
