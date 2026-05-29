import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/constants/api_keys.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';

/// To'liq ekran xarita — geo-zona markazini aniq tanlash uchun.
///
/// **UX patternlari:**
/// 1. **Pan + center pin** — xaritani suring, ekran markazidagi pin
///    sobit turadi. Camera to'xtaganida `_center` xaritaning hozirgi
///    markaziga yangilanadi.
/// 2. **Tap** — bosgan joyga animatsiya bilan boradi.
/// 3. **Search** (Bosqich 4.2.2) — yuqorida qidiruv panel, Places API
///    autocomplete (faqat O'zbekiston). Tanlangan joyga camera animatsiya.
///
/// `Navigator.pop(LatLng)` orqali tasdiqlangan markazni qaytaradi.
class FullScreenMapScreen extends StatefulWidget {
  /// `FullScreenMapScreen` konstruktor.
  const FullScreenMapScreen({
    required this.initialCenter,
    required this.initialRadius,
    super.key,
    this.autofocusSearch = false,
  });

  /// Boshlang'ich markaz — kichik xarita'dagi joriy qiymat.
  final LatLng initialCenter;

  /// Doira radiusi (preview uchun, o'zgartirib bo'lmaydi).
  final double initialRadius;

  /// `true` bo'lsa search bar ekran ochilganda darhol fokuslanadi
  /// (klaviatura chiqadi). ExpandableMap'dagi search tugmasi orqali
  /// kelganda `true`.
  final bool autofocusSearch;

  @override
  State<FullScreenMapScreen> createState() => _FullScreenMapScreenState();
}

class _FullScreenMapScreenState extends State<FullScreenMapScreen> {
  late LatLng _center;
  GoogleMapController? _controller;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter;
    // Diagnostika: console'da kalit uzunligi.
    // 0 → flag berilmagan (`flutter run --dart-define-from-file=env.json`).
    // 39 → to'g'ri.
    debugPrint(
      'PLACES API kalit uzunligi: ${ApiKeys.googleMapsKey.length}',
    );
    if (widget.autofocusSearch) {
      // initState'da darhol fokuslab bo'lmaydi (build hali tugamagan).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Camera harakatdan to'xtaganda ekran markazini hisoblab `_center`
  /// ni yangilaydi.
  Future<void> _onCameraIdle() async {
    final controller = _controller;
    if (controller == null) return;
    final region = await controller.getVisibleRegion();
    final centerLat =
        (region.northeast.latitude + region.southwest.latitude) / 2;
    final centerLng =
        (region.northeast.longitude + region.southwest.longitude) / 2;
    if (!mounted) return;
    setState(() => _center = LatLng(centerLat, centerLng));
  }

  void _onMapTap(LatLng latLng) {
    setState(() => _center = latLng);
    _controller?.animateCamera(CameraUpdate.newLatLng(latLng));
  }

  void _onPlaceSelected(Prediction prediction) {
    final lat = double.tryParse(prediction.lat ?? '');
    final lng = double.tryParse(prediction.lng ?? '');
    if (lat == null || lng == null) return;

    final newCenter = LatLng(lat, lng);
    setState(() => _center = newCenter);
    _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(newCenter, 16),
    );
    // Klaviaturani yashirish.
    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Klaviatura chiqsa xaritani siqmasin (pin ekran markazida qolsin).
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Layer 1: GoogleMap full screen.
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialCenter,
              zoom: 16,
            ),
            circles: {
              Circle(
                circleId: const CircleId('zone'),
                center: _center,
                radius: widget.initialRadius,
                fillColor: AppColors.primary.withValues(alpha: 0.2),
                strokeColor: AppColors.primary,
                strokeWidth: 2,
              ),
            },
            onTap: _onMapTap,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(bottom: 160),
            onMapCreated: (c) => _controller = c,
            onCameraIdle: _onCameraIdle,
          ),

          // Layer 2: Top bar — back tugma + search bar (yoki banner).
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: 12,
              ),
              child: Row(
                children: [
                  _CircleBackButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ApiKeys.googleMapsKey.isEmpty
                        ? const _MissingKeyBanner()
                        : _SearchBar(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onPlaceSelected: _onPlaceSelected,
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Layer 3: Center pin overlay.
          const IgnorePointer(child: _CenterPinOverlay()),

          // Layer 4: Bottom card.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomCard(
              center: _center,
              onConfirm: () => Navigator.of(context).pop(_center),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ TOP BAR ════════════════════════

/// Standart oq circle shadow — back tugma va search bar uchun bir xil.
const _kPanelShadow = [
  BoxShadow(
    color: Color(0x26000000), // black 0.15
    blurRadius: 12,
    offset: Offset(0, 4),
  ),
];

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: _kPanelShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: Icon(
                Icons.arrow_back,
                size: 24,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onPlaceSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<Prediction> onPlaceSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: _kPanelShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            // Theme override — oq fon ustida cursor/selection
            // dark theme'dan emas, mahalliy ranglardan keladi.
            // Aks holda lime green selection oq fonda yo'qoladi.
            child: Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: AppColors.primary,
                  selectionColor:
                      AppColors.primary.withValues(alpha: 0.3),
                  selectionHandleColor: AppColors.primary,
                ),
              ),
              child: GooglePlaceAutoCompleteTextField(
                textEditingController: controller,
                focusNode: focusNode,
                googleAPIKey: ApiKeys.googleMapsKey,
                countries: const ['uz'],
                getPlaceDetailWithLatLng: onPlaceSelected,
                itemClick: (prediction) {
                  controller.text = prediction.description ?? '';
                  controller.selection = TextSelection.fromPosition(
                    TextPosition(
                      offset: prediction.description?.length ?? 0,
                    ),
                  );
                },
                itemBuilder: (context, index, prediction) {
                  return _SearchResultTile(prediction: prediction);
                },
                seperatedBuilder: const Divider(
                  height: 1,
                  color: Color(0xFFEEEEEE),
                ),
                containerHorizontalPadding: 0,
                inputDecoration: InputDecoration(
                  hintText: 'fullScreenMap.searchHint'.tr(),
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                // backgroundColor: transparent — global dark theme'dan
                // matn ortidagi to'q rang oqib chiqmasligi uchun
                // (oq search bar'da matn o'qib bo'lsin).
                textStyle: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ),
          // Tozalash tugmasi — controller'da matn bo'lsa.
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: InkWell(
                  onTap: controller.clear,
                  borderRadius: BorderRadius.circular(20),
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// API kalit yo'q bo'lsa search bar o'rniga ko'rsatiladigan banner.
///
/// Bu xato deyarli har doim `--dart-define-from-file=env.json`
/// flag'i berilmaganida sodir bo'ladi.
class _MissingKeyBanner extends StatelessWidget {
  const _MissingKeyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'fullScreenMap.missingKeyTitle'.tr(),
                  style: AppTextStyles.label.copyWith(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'fullScreenMap.missingKeyHint'.tr(),
                  style: AppTextStyles.label.copyWith(
                    color: Colors.red.shade900,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final main = prediction.structuredFormatting?.mainText ??
        prediction.description ??
        '';
    final secondary = prediction.structuredFormatting?.secondaryText;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(
            Icons.location_on,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  main,
                  style: AppTextStyles.bodyS.copyWith(
                    color: AppColors.background,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (secondary != null && secondary.isNotEmpty)
                  Text(
                    secondary,
                    style: AppTextStyles.label.copyWith(
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ CENTER PIN OVERLAY ════════════════════════

class _CenterPinOverlay extends StatelessWidget {
  const _CenterPinOverlay();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 36),
          child: Icon(
            Icons.location_pin,
            size: 48,
            color: AppColors.primary,
            shadows: [
              Shadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════ BOTTOM CARD ════════════════════════

class _BottomCard extends StatelessWidget {
  const _BottomCard({required this.center, required this.onConfirm});

  final LatLng center;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.lg,
        MediaQuery.of(context).padding.bottom + AppDimensions.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_pin,
                size: 24,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'fullScreenMap.centerLabel'.tr(),
                      style: AppTextStyles.bodyS.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${center.latitude.toStringAsFixed(5)}, '
                      '${center.longitude.toStringAsFixed(5)}',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          PrimaryButton(
            label: 'fullScreenMap.confirmButton'.tr(),
            icon: Icons.check,
            onPressed: onConfirm,
          ),
        ],
      ),
    );
  }
}
