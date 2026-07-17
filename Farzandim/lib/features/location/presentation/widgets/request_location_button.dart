// "Joylashuvni yoqishni so'rash" tugmasi — bola joylashuvni o'chirganда
// ota-ona bosadi, backend bolaga KO'RINADIGAN push yuboradi (bolada modal).
//
// Ikki joyda ishlatiladi: dashboard "Uy/Ko'chada" kartasi (dense) va to'liq
// joylashuv (xarita) ekrani. Yagona manba — ikkalasi bir xil ishlaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/location/data/repositories/backend_location_repository.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class RequestLocationButton extends ConsumerStatefulWidget {
  const RequestLocationButton({
    required this.childId,
    this.dense = false,
    super.key,
  });

  /// Qaysi bolaга so'rov yuboriladi.
  final String childId;

  /// `true` — ixcham (dashboard karta ichida); `false` — to'liq kenglik.
  final bool dense;

  @override
  ConsumerState<RequestLocationButton> createState() =>
      _RequestLocationButtonState();
}

class _RequestLocationButtonState
    extends ConsumerState<RequestLocationButton> {
  bool _sending = false;

  static const _blue = Color(0xFF216BFF);

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final ok = await ref
        .read(backendLocationRepositoryProvider)
        .requestLocationEnable(widget.childId);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      AppToast.success(context, 'location.enableRequest.sent'.tr());
    } else {
      AppToast.error(context, 'location.enableRequest.error'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.dense ? 40.0 : 48.0;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: _blue,
        borderRadius: BorderRadius.circular(widget.dense ? 12 : 14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _sending ? null : _send,
          child: Center(
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        SolarIconsBold.mapPoint,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'location.enableRequest.button'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.dense ? 13 : 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
