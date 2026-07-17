// ─────────────────────────────────────────────────────────────────────
// AddEditGeoZoneScreen — "Yangi manzil" (Parvoz dizayn)
// ─────────────────────────────────────────────────────────────────────
//
// To'liq ekran xarita + markazda turuvchi oq pin (joy tanlash patterni:
// xarita siljiydi, pin markazda qoladi). Pastda shisha-qora panel: manzil
// (reverse-geocode), nom, Solar belgi tanlash, Bekor qilish / Saqlash.
//
// Ma'lumot: kamera markazi → lat/lng; nom → zona nomi; belgi → icon.
// Saqlash `geoZoneActionsProvider` orqali (add/update), real backend.
// Radius/bildirishnomalar Figma dizaynida ko'rsatilmaydi — default
// (yoki tahrir paytida mavjud qiymat) saqlanadi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/map/map_tiles.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zones_provider.dart';
import 'package:farzandim/features/geo_zones/presentation/widgets/geo_zone_address_search.dart';
import 'package:farzandim/features/location/data/services/geocoding_service.dart';
import 'package:farzandim/features/location/data/services/parent_location_service.dart';
import 'package:farzandim/shared/models/result.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:latlong2/latlong.dart' as ll;
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _sheetBg = Color(0xFF1A1F23);
const _iconBtnBg = Color(0xFF21262A);
const _border = Color(0x1AFFFFFF); // oq 10%
const _dim = Color(0x8CFFFFFF); // oq 55%
const _defaultCenter = LatLng(41.2995, 69.2401); // Toshkent markazi

/// Zona belgisi kaliti → SVG asset yo'li (marker uchun).
String _assetForKey(String key) {
  for (final p in _pickerIcons) {
    if (p.key == key) return p.asset;
  }
  return _pickerIcons.first.asset;
}

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w500,
  Color c = Colors.white,
  double ls = -0.3,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.4,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Belgi tanlash — Solar ikon + zona kaliti (`GeoZone.icon`) + turi.
class _PickerIcon {
  const _PickerIcon(this.key, this.asset, this.type);

  final String key;
  final String asset;
  final GeoZoneType type;
}

const _pickerIcons = <_PickerIcon>[
  _PickerIcon(
    'place',
    'assets/icons/solar_streets_map_point.svg',
    GeoZoneType.custom,
  ),
  _PickerIcon('school', 'assets/icons/solar_backpack.svg', GeoZoneType.school),
  _PickerIcon('home', 'assets/icons/solar_home2.svg', GeoZoneType.home),
  _PickerIcon('study', 'assets/icons/solar_calculator.svg', GeoZoneType.school),
  _PickerIcon('work', 'assets/icons/solar_case.svg', GeoZoneType.custom),
];

/// Geo-zona qo'shish / tahrirlash — Parvoz "Yangi manzil" dizayni.
class AddEditGeoZoneScreen extends ConsumerStatefulWidget {
  /// `AddEditGeoZoneScreen` konstruktor.
  const AddEditGeoZoneScreen({required this.childId, this.zoneId, super.key});

  /// Qaysi bola uchun zona.
  final String childId;

  /// Tahrirlanayotgan zona `id`. `null` bo'lsa — yangi zona qo'shish.
  final String? zoneId;

  @override
  ConsumerState<AddEditGeoZoneScreen> createState() =>
      _AddEditGeoZoneScreenState();
}

class _AddEditGeoZoneScreenState extends ConsumerState<AddEditGeoZoneScreen> {
  final MapController _mapController = MapController();
  final _nameController = TextEditingController();

  LatLng _center = _defaultCenter;
  LatLng _camTarget = _defaultCenter;
  double _radius = 100;
  bool _notifyOnEnter = true;
  bool _notifyOnExit = true;
  String _selectedIcon = 'place';
  GeoZoneType _type = GeoZoneType.custom;

  bool _mapReady = false;
  // "Mening joyim" tugmasi yuklanish holati (GPS o'qilyapti).
  bool _locating = false;
  // Xarita tayyor bo'lmasa nishon shu yerда kutadi (onMapReady qo'llaydi).
  // `initialCenter` bir marta o'qiladi — keyingi `_center` o'zgarishlari
  // (masalan qidiruv) kamerani o'zi ko'chirmaydi.
  LatLng? _pendingCamera;
  double _pendingZoom = 16;
  Timer? _idleTimer; // kamera to'xtaganini aniqlash uchun debounce
  String? _address;
  bool _addrLoading = false;
  int _geoReq = 0;
  bool _saving = false;

  bool get _isEditMode => widget.zoneId != null;
  bool get _isFormValid => _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) _loadExisting();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _mapController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _loadExisting() {
    final zone = ref.read(
      geoZoneByIdProvider((childId: widget.childId, zoneId: widget.zoneId!)),
    );
    if (zone != null) {
      _applyZone(zone);
    } else {
      // Stream hali kelmagan bo'lishi mumkin — keyingi frame'da qayta.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final z = ref.read(
          geoZoneByIdProvider((
            childId: widget.childId,
            zoneId: widget.zoneId!,
          )),
        );
        if (z != null) {
          setState(() => _applyZone(z));
          _moveCamera(_center, 15);
          unawaited(_reverseGeocode(_center));
        }
      });
    }
  }

  void _applyZone(GeoZone z) {
    _center = z.center;
    _camTarget = z.center;
    _nameController.text = z.name;
    _radius = z.radiusMeters;
    _notifyOnEnter = z.notifyOnEnter;
    _notifyOnExit = z.notifyOnExit;
    _type = z.type;
    _selectedIcon = z.icon ?? z.type.defaultIconName;
  }

  ll.LatLng _toLL(LatLng p) => ll.LatLng(p.latitude, p.longitude);

  void _onMapReady() {
    _mapReady = true;
    final pending = _pendingCamera;
    if (pending != null) {
      _mapController.move(_toLL(pending), _pendingZoom);
      _pendingCamera = null;
    }
    unawaited(_reverseGeocode(_center));
  }

  /// Kamerani [target]ga olib boradi. Xarita hali tayyor bo'lmasa — nishonni
  /// saqlab, `_onMapReady`да qo'llaymiz (kamera yo'qolmasин).
  void _moveCamera(LatLng target, double zoom) {
    if (_mapReady) {
      _mapController.move(_toLL(target), zoom);
    } else {
      _pendingCamera = target;
      _pendingZoom = zoom;
    }
  }

  void _onCameraIdle() {
    if (!mounted) return;
    setState(() => _center = _camTarget);
    unawaited(_reverseGeocode(_center));
  }

  /// "Mening joyim" — GPS'dan ota-onaning joriy joyini olib, kamerani o'sha
  /// yerga markazlaydi. Marker pin xarita MARKAZIDA turgani uchun zona
  /// avtomatik shu nuqtaga qo'yiladi (manzil ham yangilanadi).
  ///
  /// Joylashuv (Joylashuvi) ekranidagi `_locateMe` bilan bir xil mantiq —
  /// mavjud `parentLocationService`ni qayta ishlatadi (kalitsiz, ruxsat +
  /// xizmat holatini o'zi tekshiradi).
  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    final res = await ref.read(parentLocationServiceProvider).current();
    if (!mounted) return;
    setState(() => _locating = false);
    if (res.isOk) {
      final target = LatLng(res.latitude!, res.longitude!);
      _camTarget = target;
      setState(() => _center = target);
      _moveCamera(target, 16);
      unawaited(_reverseGeocode(target));
    } else {
      final msg = switch (res.status) {
        MyLocationStatus.serviceOff => 'location.myLocation.serviceOff'.tr(),
        MyLocationStatus.denied => 'location.myLocation.denied'.tr(),
        _ => 'location.myLocation.error'.tr(),
      };
      AppToast.error(context, msg);
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    final req = ++_geoReq;
    setState(() => _addrLoading = true);
    String? addr;
    try {
      addr = await ref
          .read(geocodingServiceProvider)
          .reverse(pos.latitude, pos.longitude);
    } catch (_) {
      addr = null;
    }
    if (!mounted || req != _geoReq) return;
    setState(() {
      _address = addr;
      _addrLoading = false;
    });
  }

  /// Manzil qidirish varag'ini ochadi. Foydalanuvchi joy tanlasa — xaritani
  /// o'sha joyga olib boradi, markazni yangilaydi, nom bo'sh bo'lsa joy nomini
  /// oldindan to'ldiradi va aniq manzilni (reverse-geocode) yangilaydi.
  Future<void> _openSearch() async {
    final picked = await showAddressSearch(
      context,
      // Jonli kamera markazi — `_center` faqat idle'да yangilanadi, pan qilib
      // darhol qidirса eskirган nuqtaga bias bo'lardi.
      centerLat: _camTarget.latitude,
      centerLng: _camTarget.longitude,
    );
    if (picked == null || !mounted) return;
    final target = LatLng(picked.latitude, picked.longitude);
    setState(() {
      _center = target;
      _camTarget = target;
      // Uchувчi reverse-geocode'ни bekor qilamiz — aks holda u (Google kaliti
      // bo'lmasa null qaytarib) tanlangan Photon manzilini o'chirib yuborardi.
      _geoReq++;
      _addrLoading = false;
      // Photon natijasi aniq nom + manzil beradi — reverse-geocode shart emas.
      _address = picked.address.isNotEmpty ? picked.address : picked.name;
      // Nom bo'sh bo'lsa — joy nomini taklif qilamiz (foydalanuvchi tahrirlashi
      // mumkin). Yozib qo'yilgan nomni buzmaymiz.
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = picked.name;
      }
    });
    _moveCamera(target, 16);
  }

  Future<void> _onSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final notifier = ref.read(geoZoneActionsProvider.notifier);
    Result<void> result;
    if (_isEditMode) {
      final current = ref.read(
        geoZoneByIdProvider((childId: widget.childId, zoneId: widget.zoneId!)),
      );
      if (current == null) {
        setState(() => _saving = false);
        return;
      }
      result = await notifier.updateZone(
        childId: widget.childId,
        zoneId: widget.zoneId!,
        current: current,
        name: name,
        type: _type,
        latitude: _center.latitude,
        longitude: _center.longitude,
        radiusMeters: _radius,
        notifyOnEnter: _notifyOnEnter,
        notifyOnExit: _notifyOnExit,
        icon: _selectedIcon,
      );
    } else {
      result = await notifier.addZone(
        childId: widget.childId,
        name: name,
        type: _type,
        latitude: _center.latitude,
        longitude: _center.longitude,
        radiusMeters: _radius,
        notifyOnEnter: _notifyOnEnter,
        notifyOnExit: _notifyOnExit,
        icon: _selectedIcon,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      context.pop();
    } else {
      AppToast.error(
        context,
        'geoZoneEdit.saveErrorPrefix'.tr(
          namedArgs: {'error': result.error ?? ''},
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _sheetBg,
        title: Text('geoZoneEdit.deleteDialog.title'.tr(), style: _unb(18)),
        content: Text(
          'geoZoneEdit.deleteDialog.content'.tr(
            namedArgs: {'name': _nameController.text.trim()},
          ),
          style: _pop(14, c: _dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'geoZoneEdit.deleteDialog.cancel'.tr(),
              style: _pop(14),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'geoZoneEdit.deleteDialog.delete'.tr(),
              style: _pop(14, w: FontWeight.w600, c: const Color(0xFFFF5A5D)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref
        .read(geoZoneActionsProvider.notifier)
        .deleteZone(childId: widget.childId, zoneId: widget.zoneId!);
    if (!mounted) return;
    if (result.isSuccess) {
      context.pop();
    } else {
      AppToast.error(
        context,
        'geoZoneEdit.deleteErrorPrefix'.tr(
          namedArgs: {'error': result.error ?? ''},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Boshqa zonalar (tahrirlanayotgandan tashqari) — xaritada belgi + doira.
    final zones =
        ref.watch(geoZonesProvider(widget.childId)).valueOrNull ??
        const <GeoZone>[];
    final otherZones = [
      for (final z in zones)
        if (z.id != widget.zoneId) z,
    ];

    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sheetMax = constraints.maxHeight * 0.78;
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _toLL(_center),
                          initialZoom: 15,
                          minZoom: 3,
                          maxZoom: 18,
                          onMapReady: _onMapReady,
                          onPositionChanged: (camera, hasGesture) {
                            _camTarget = LatLng(
                              camera.center.latitude,
                              camera.center.longitude,
                            );
                            if (!hasGesture) return;
                            _idleTimer?.cancel();
                            _idleTimer = Timer(
                              const Duration(milliseconds: 350),
                              _onCameraIdle,
                            );
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: mapTileUrl,
                            userAgentPackageName: kMapUserAgent,
                          ),
                          if (otherZones.isNotEmpty) ...[
                            CircleLayer(
                              circles: [
                                for (final z in otherZones)
                                  CircleMarker(
                                    point: _toLL(z.center),
                                    radius: z.radiusMeters,
                                    useRadiusInMeter: true,
                                    color: _blue.withValues(alpha: 0.10),
                                    borderColor: _blue.withValues(alpha: 0.5),
                                    borderStrokeWidth: 1.5,
                                  ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                for (final z in otherZones)
                                  Marker(
                                    point: _toLL(z.center),
                                    width: 44,
                                    height: 44,
                                    child: _ZoneMarkerBubble(
                                      asset: _assetForKey(
                                        z.icon ?? z.type.defaultIconName,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Tepa qorong'i fade — sarlavha o'qiladigan bo'lsin.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: topPad + 130,
                      child: const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [_bg, Color(0x0000060A)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Markaz pin (xarita markazini belgilaydi).
                    const Center(
                      child: IgnorePointer(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 48),
                          child: _CenterPin(),
                        ),
                      ),
                    ),
                    // "Mening joyim" tugmasi — Joylashuvi ekranidagidek ◎.
                    // Xarita o'ng-past burchagida (pastki varaq ustida).
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: _MyLocationButton(
                        loading: _locating,
                        onTap: _locateMe,
                      ),
                    ),
                    // Header — web/emulyatorda topPad=0, shuning uchun aniq
                    // bo'shliq (tepaga yopishib qolmasin).
                    Positioned(
                      top: (topPad < 36 ? 36 : topPad) + 12,
                      left: 16,
                      right: 16,
                      child: _Header(
                        title: _isEditMode
                            ? 'geoZoneEdit.headerEdit'.tr()
                            : 'geoZoneEdit.headerAdd'.tr(),
                        onBack: () => context.pop(),
                        onDelete: _isEditMode ? _confirmDelete : null,
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: sheetMax),
                child: _BottomSheet(
                  bottomPad: bottomPad,
                  address: _address,
                  addrLoading: _addrLoading,
                  onAddressTap: _openSearch,
                  nameController: _nameController,
                  onNameChanged: (_) => setState(() {}),
                  selectedIcon: _selectedIcon,
                  onIconSelected: (item) => setState(() {
                    _selectedIcon = item.key;
                    _type = item.type;
                  }),
                  saving: _saving,
                  canSave: _isFormValid,
                  onCancel: () => context.pop(),
                  onSave: _onSave,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ════════════ Boshqa zona markeri ════════════

/// Boshqa zonalar markeri — qora yumaloq "bubble" + oq SVG belgi.
class _ZoneMarkerBubble extends StatelessWidget {
  const _ZoneMarkerBubble({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _iconBtnBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
          bottomLeft: Radius.circular(6),
        ),
        border: Border.all(color: const Color(0x2EFFFFFF), width: 1.5),
      ),
      child: SvgPicture.asset(
        asset,
        width: 22,
        height: 22,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }
}

// ════════════ Markaz pin ════════════

/// "Mening joyim" tugmasi — Joylashuvi (location) ekranidagi bilan bir xil
/// ko'rinish: solid-glass fon, ko'k GPS ikoni, yuklanishda spinner.
class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF20E1622),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x1FFFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: _blue,
                    ),
                  )
                : const Icon(SolarIconsBold.gps, size: 22, color: _blue),
          ),
        ),
      ),
    );
  }
}

class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: _sheetBg,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Container(
          width: 4,
          height: 18,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
        ),
      ],
    );
  }
}

// ════════════ Header ════════════

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack, this.onDelete});

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SquareIconButton(icon: SolarIconsOutline.arrowLeft, onTap: onBack),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title, maxLines: 1, style: _unb(24, ls: -0.72)),
          ),
        ),
        if (onDelete != null)
          _SquareIconButton(
            icon: SolarIconsBold.trashBinMinimalistic,
            onTap: onDelete!,
          )
        else
          const SizedBox(width: 56),
      ],
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _sheetBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, size: 24, color: Colors.white),
      ),
    );
  }
}

// ════════════ Pastki panel ════════════

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.bottomPad,
    required this.address,
    required this.addrLoading,
    required this.onAddressTap,
    required this.nameController,
    required this.onNameChanged,
    required this.selectedIcon,
    required this.onIconSelected,
    required this.saving,
    required this.canSave,
    required this.onCancel,
    required this.onSave,
  });

  final double bottomPad;
  final String? address;
  final bool addrLoading;
  final VoidCallback onAddressTap;
  final TextEditingController nameController;
  final ValueChanged<String> onNameChanged;
  final String selectedIcon;
  final ValueChanged<_PickerIcon> onIconSelected;
  final bool saving;
  final bool canSave;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  String get _addressText {
    final addr = address;
    if (addr != null && addr.isNotEmpty) return addr;
    if (addrLoading) return 'geoZoneEdit.addressLoading'.tr();
    return 'geoZoneEdit.addressTapHint'.tr();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: _border),
          left: BorderSide(color: _border),
          right: BorderSide(color: _border),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('geoZoneEdit.addressLabel'.tr()),
                  const SizedBox(height: 8),
                  _DisplayPill(
                    text: _addressText,
                    dim: address == null,
                    onTap: onAddressTap,
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel('geoZoneEdit.placeNameLabel'.tr()),
                  const SizedBox(height: 8),
                  _NamePill(
                    controller: nameController,
                    onChanged: onNameChanged,
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel('geoZoneEdit.chooseIconLabel'.tr()),
                  const SizedBox(height: 10),
                  _IconPickerRow(
                    selected: selectedIcon,
                    onSelected: onIconSelected,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCancel,
                  behavior: HitTestBehavior.opaque,
                  child: ParvozGlass(
                    height: 54,
                    child: Text(
                      'geoZoneEdit.cancelButton'.tr(),
                      style: _pop(16, w: FontWeight.w500),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Opacity(
                  opacity: canSave ? 1 : 0.5,
                  child: GestureDetector(
                    onTap: (canSave && !saving) ? onSave : null,
                    behavior: HitTestBehavior.opaque,
                    child: ParvozGlass(
                      blue: true,
                      height: 54,
                      child: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'geoZoneEdit.saveButton'.tr(),
                                  style: _pop(16, w: FontWeight.w500),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  SolarIconsBold.checkCircle,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Text(text, style: _pop(14)),
    );
  }
}

/// Manzil qatori — bosilsa qidiruv varag'i ochiladi (o'ng chetда qidiruv
/// ikoni). Matn: joriy manzil (reverse-geocode / tanlangan joy) yoki yo'riq.
class _DisplayPill extends StatelessWidget {
  const _DisplayPill({
    required this.text,
    required this.dim,
    required this.onTap,
  });

  final String text;
  final bool dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _sheetBg,
          borderRadius: BorderRadius.circular(60),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _pop(14, c: dim ? _dim : Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(SolarIconsOutline.magnifier, size: 20, color: _blue),
          ],
        ),
      ),
    );
  }
}

/// Nom kiritish — qora pill ichida shaffof TextField (ko'k kursor).
class _NamePill extends StatelessWidget {
  const _NamePill({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.circular(60),
        border: Border.all(color: _border),
      ),
      alignment: Alignment.center,
      child: TextSelectionTheme(
        data: const TextSelectionThemeData(
          cursorColor: _blue,
          selectionHandleColor: _blue,
          selectionColor: Color(0x5C216BFF),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          cursorColor: _blue,
          style: _pop(14),
          decoration: InputDecoration(
            filled: false,
            isCollapsed: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: 'geoZoneEdit.nameHint'.tr(),
            hintStyle: _pop(14, c: Colors.white.withValues(alpha: 0.35)),
          ),
        ),
      ),
    );
  }
}

/// Belgi tanlash — gorizontal Solar ikonalar qatori.
class _IconPickerRow extends StatelessWidget {
  const _IconPickerRow({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<_PickerIcon> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 8),
        itemCount: _pickerIcons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = _pickerIcons[i];
          return _IconPickerBtn(
            item: item,
            selected: item.key == selected,
            onTap: () => onSelected(item),
          );
        },
      ),
    );
  }
}

class _IconPickerBtn extends StatelessWidget {
  const _IconPickerBtn({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _PickerIcon item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _iconBtnBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF2D6FFF)
                      : Colors.transparent,
                ),
              ),
              child: Center(
                child: SvgPicture.asset(item.asset, width: 28, height: 28),
              ),
            ),
            if (selected)
              Positioned(
                top: -8,
                right: -6,
                child: SvgPicture.asset(
                  'assets/icons/solar_check_circle.svg',
                  width: 24,
                  height: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
