import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/features/geo_zones/presentation/screens/full_screen_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:solar_icons/solar_icons.dart';

/// Geo-zona qo'shish/tahrirlash formidagi kichik xarita preview.
///
/// **Xususiyatlar:**
/// - 280dp baland xarita (default — `height` orqali o'zgartiriladi)
/// - Marker drag, xarita tap orqali markaz almashinadi
/// - Yuqori o'ng burchakda **fullscreen tugma** — to'liq ekran
///   xaritani ochadi (`FullScreenMapScreen`'ga `Navigator.push`)
/// - Fullscreen'dan yangi markaz qaytsa — xarita kameraga avtomatik
///   animatsiya qilinadi va `onCenterChanged` chaqiriladi
class ExpandableMap extends StatefulWidget {
  /// `ExpandableMap` konstruktor.
  const ExpandableMap({
    required this.center,
    required this.radius,
    required this.onCenterChanged,
    super.key,
    this.height = 240,
  });

  /// Joriy markaz — parent state'dan keladi.
  final LatLng center;

  /// Doira radiusi (metrlarda).
  final double radius;

  /// Markaz o'zgarganda chaqiriladi (drag, tap, yoki fullscreen
  /// qaytishidan keyin).
  final ValueChanged<LatLng> onCenterChanged;

  /// Xarita balandligi (default 280dp).
  final double height;

  @override
  State<ExpandableMap> createState() => _ExpandableMapState();
}

class _ExpandableMapState extends State<ExpandableMap> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(ExpandableMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent center'ni o'zgartirgan bo'lsa (masalan, fullscreen
    // qaytishidan keyin), kameraga ham animatsiya qilamiz —
    // foydalanuvchi yangi joyni darhol ko'radi.
    if (widget.center != oldWidget.center) {
      _controller?.animateCamera(CameraUpdate.newLatLng(widget.center));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openFullscreen({bool autofocusSearch = false}) async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => FullScreenMapScreen(
          initialCenter: widget.center,
          initialRadius: widget.radius,
          autofocusSearch: autofocusSearch,
        ),
      ),
    );
    if (result != null) {
      widget.onCenterChanged(result);
      // didUpdateWidget — kamera animatsiyasi avtomatik bajariladi.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.center,
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('center'),
                position: widget.center,
                draggable: true,
                onDragEnd: widget.onCenterChanged,
              ),
            },
            circles: {
              Circle(
                circleId: const CircleId('zone'),
                center: widget.center,
                radius: widget.radius,
                fillColor: AppColors.primary.withValues(alpha: 0.2),
                strokeColor: AppColors.primary,
                strokeWidth: 2,
              ),
            },
            onTap: widget.onCenterChanged,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) => _controller = c,
          ),

          // Yuqori o'ng burchakda 2 ta tugma: search va fullscreen.
          // Search bossa — fullscreen ekran ochiladi search'ga focus
          // bilan. Fullscreen bossa — fokussiz.
          Positioned(
            top: AppDimensions.sm,
            right: AppDimensions.sm,
            child: Column(
              children: [
                _CircleIconButton(
                  icon: SolarIconsBold.magnifier,
                  onTap: () => _openFullscreen(autofocusSearch: true),
                ),
                const SizedBox(height: AppDimensions.sm),
                _CircleIconButton(
                  icon: SolarIconsBold.fullScreen,
                  onTap: _openFullscreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(icon, size: 22, color: AppColors.onPrimary),
          ),
        ),
      ),
    );
  }
}
