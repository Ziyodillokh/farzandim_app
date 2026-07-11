// SOS xabari modali (rasm 2) — bola joylashuvi xaritada, manzil, vaqt va
// "Telefon qilish" / "Xabar yozish" amallari. Bildirishnomalar varag'idagi
// SOS kartani bosganda ochiladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/map/map_tiles.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/location/presentation/providers/child_location_provider.dart';
import 'package:farzandim/features/location/presentation/providers/child_place_provider.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

// ════════════ Tokenlar (lokal, Parvoz) ════════════
const _sheetBg = Color(0xFF12171E);
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x14FFFFFF);
const _dim = Color(0x99FFFFFF); // oq 60%
const _dim2 = Color(0x80FFFFFF); // oq 50% — yorliq
const _divider = Color(0x14FFFFFF);

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.5,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.25,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.4);

/// SOS xabari modali.
class SosSheet {
  SosSheet._();

  /// Modalni ochadi.
  static Future<void> show(BuildContext context, AppNotification notif) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => _SosSheetBody(notification: notif),
    );
  }
}

class _SosSheetBody extends ConsumerWidget {
  const _SosSheetBody({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    final child = n.childId.isNotEmpty
        ? ref.watch(childByIdProvider(n.childId))
        : null;
    final place = n.childId.isNotEmpty
        ? ref.watch(childPlaceProvider(n.childId))
        : null;
    final address = place?.zoneName ?? place?.street;

    return Container(
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: _cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(width: 36),
                  Expanded(
                    child: Center(
                      child: Text(
                        'notifications.sos.cardTitle'.tr(),
                        style: _unb(23, w: FontWeight.w700),
                      ),
                    ),
                  ),
                  _CloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
              if (n.childName.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(n.childName.trim(), style: _pop(13, c: _dim)),
                ),
              ],
              const SizedBox(height: 18),
              _MapPreview(childId: n.childId, child: child),
              const SizedBox(height: 18),
              _InfoBlock(
                label: 'notifications.sos.addressLabel'.tr(),
                value: address ?? 'notifications.sos.noLocation'.tr(),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 1, color: _divider),
              const SizedBox(height: 14),
              _InfoBlock(
                label: 'notifications.sos.whenLabel'.tr(),
                value: _whenText(n.timestamp),
              ),
              const SizedBox(height: 22),
              _CallButton(onTap: () => _call(context, child)),
              const SizedBox(height: 12),
              ParvozSecondaryButton(
                label: 'notifications.sos.messageAction'.tr(),
                onPressed: () => _message(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── "Telefon qilish" — bolaning raqamiga native dialer ───
  Future<void> _call(BuildContext context, Child? child) async {
    final phone = child?.phoneNumber;
    if (phone == null || phone.trim().isEmpty) {
      AppToast.warning(context, 'notifications.sos.callNoPhone'.tr());
      return;
    }
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && context.mounted) {
      AppToast.error(context, 'notifications.sos.callFailed'.tr());
    }
  }

  // ─── "Xabar yozish" — messenjerni ochamiz ───
  void _message(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(AppRoutes.chatList);
  }

  String _whenText(DateTime ts) {
    String two(int x) => x.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(ts.year, ts.month, ts.day);
    final time = '${two(ts.hour)}:${two(ts.minute)}';
    final String dayLabel;
    if (day == today) {
      dayLabel = 'notifications.today'.tr();
    } else if (day == today.subtract(const Duration(days: 1))) {
      dayLabel = 'notifications.yesterday'.tr();
    } else {
      dayLabel = '${two(ts.day)}.${two(ts.month)}.${ts.year}';
    }
    return 'notifications.sos.whenAt'.tr(
      namedArgs: {'day': dayLabel, 'time': time},
    );
  }
}

// ════════════ Xarita ko'rinishi ════════════
class _MapPreview extends ConsumerWidget {
  const _MapPreview({required this.childId, required this.child});

  final String childId;
  final Child? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget content;
    if (childId.isEmpty) {
      content = const _MapPlaceholder();
    } else {
      final locAsync = ref.watch(childLocationProvider(childId));
      content = locAsync.when(
        loading: () => const _MapPlaceholder(loading: true),
        error: (_, __) => const _MapPlaceholder(),
        data: (loc) => loc == null
            ? const _MapPlaceholder()
            : _LiveMap(
                point: LatLng(loc.latitude, loc.longitude),
                child: child,
              ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(height: 188, width: double.infinity, child: content),
    );
  }
}

/// Jonli xarita — joylashuv o'zgarganda kamera markerga ergashadi (kartada
/// qo'l harakati o'chiq, shuning uchun avtomatik markazlash).
class _LiveMap extends StatefulWidget {
  const _LiveMap({required this.point, required this.child});

  final LatLng point;
  final Child? child;

  @override
  State<_LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<_LiveMap> {
  final MapController _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(_LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Joylashuv yangilanganda kamerani yangi nuqtaga ko'chiramiz (aks holda
    // initialCenter faqat bir marta ishlaydi va marker oynadan chiqib ketardi).
    if (_ready && widget.point != oldWidget.point) {
      _controller.move(widget.point, _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.point,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
        onMapReady: () {
          _ready = true;
          // Tayyor bo'lguncha joylashuv o'zgargan bo'lsa — hozirgi nuqtaga.
          _controller.move(widget.point, _controller.camera.zoom);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: whiteMapTileUrl,
          userAgentPackageName: kMapUserAgent,
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: widget.point,
              width: 56,
              height: 66,
              alignment: Alignment.bottomCenter,
              child: _MapPin(child: widget.child),
            ),
          ],
        ),
      ],
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({this.loading = false});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _card,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: _dim),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    SolarIconsOutline.mapPointRemove,
                    size: 30,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'notifications.sos.noLocation'.tr(),
                    style: _pop(12.5, c: _dim),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Xaritadagi bola pin'i — oq halqali avatar + pastga ishora uchburchak.
class _MapPin extends StatelessWidget {
  const _MapPin({required this.child});
  final Child? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child != null
              ? ChildAvatar(child: child!, size: 40, showBorder: false)
              : Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _card,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    SolarIconsBold.user,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
        ),
        Transform.translate(
          offset: const Offset(0, -2),
          child: CustomPaint(size: const Size(14, 9), painter: _PinTriangle()),
        ),
      ],
    );
  }
}

class _PinTriangle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════ Yorliq + qiymat bloki ════════════
class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _pop(13, c: _dim2)),
        const SizedBox(height: 5),
        Text(value, style: _unb(16)),
      ],
    );
  }
}

// ════════════ Tugmalar ════════════
class _CallButton extends StatelessWidget {
  const _CallButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ParvozGlass(
        blue: true,
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(SolarIconsBold.phone, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              'notifications.sos.callAction'.tr(),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: _cardBorder),
        ),
        child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
      ),
    );
  }
}
