import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/map/map_tiles.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zones_provider.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/data/models/location_stop.dart';
import 'package:farzandim/features/location/data/repositories/backend_location_repository.dart';
import 'package:farzandim/features/location/data/services/parent_location_service.dart';
import 'package:farzandim/features/location/data/services/track_cleaner.dart';
import 'package:farzandim/features/location/presentation/providers/child_location_provider.dart';
import 'package:farzandim/features/location/presentation/providers/location_history_provider.dart';
import 'package:farzandim/features/location/presentation/providers/road_route_provider.dart';
import 'package:farzandim/features/location/presentation/widgets/request_location_button.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as ll;
import 'package:solar_icons/solar_icons.dart';

part 'location_map_sheet.dart';
part 'location_map_widgets.dart';

// ─── "Parvoz" dizayn tokenlari (dashboard bilan bir xil til) ───
// Bu ekran lokal palitra ishlatadi — dashboard'ni refactor qilmaymiz,
// faqat vizual tilni takrorlaymiz.
const Color _bg = Color(0xFF00060A);
const Color _blue = Color(0xFF216BFF); // accent / polyline / tanlangan / jonli
const Color _cardBg = Color(0x12FFFFFF); // oq ~7% shisha fon
const Color _cardBorder = Color(0x1AFFFFFF); // oq ~10% chegara
const Color _dim = Color(0x8CFFFFFF); // oq 55% ikkilamchi matn
const Color _success = Color(0xFF22C55E); // "Bordi" badge yashili
const Color _warning = Color(0xFFEF9900); // ogohlantirish (ixtiyoriy)
const double _radius = 24; // katta kartalar
const double _radiusSm = 16; // kichik chip/plitkalar
const double _sheetInitial = 0.36; // pastki varaqning boshlang'ich ulushi

/// Unbounded sarlavha stili.
TextStyle _lunb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double? ls,
}) {
  return GoogleFonts.unbounded(
    fontSize: size,
    fontWeight: w,
    color: c,
    letterSpacing: ls,
    height: 1.3,
  );
}

/// Poppins body/label stili.
TextStyle _lpop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) {
  return GoogleFonts.poppins(
    fontSize: size,
    fontWeight: w,
    color: c,
    height: 1.4,
  );
}

/// Ikki `LatLng` orasidagi masofa (metr) — haversine. Stop'ni geo-zonaga
/// moslashtirish uchun ishlatiladi (timeline va place nomi).
double _metersBetween(gmaps.LatLng a, gmaps.LatLng b) {
  const r = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// Stop'ni eng yaqin mos geo-zonaga moslaydi — radius ichida bo'lsa shu
/// zona qaytadi, aks holda `null`.
GeoZone? _zoneForStop(gmaps.LatLng point, List<GeoZone> zones) {
  GeoZone? best;
  var bestDist = double.infinity;
  for (final zone in zones) {
    final d = _metersBetween(point, zone.center);
    if (d <= zone.radiusMeters && d < bestDist) {
      bestDist = d;
      best = zone;
    }
  }
  return best;
}

/// `gmaps.LatLng` → flutter_map `latlong2.LatLng` (render uchun).
ll.LatLng _toLL(double lat, double lng) => ll.LatLng(lat, lng);

/// Xarita kamerasi uchun kompensatsiya — bola markerini pastki sheet
/// yopmasin uchun kamerani biroz JANUBGA suradi. Natijada marker
/// ekranning yuqori-o'rtasida (~35-40% top-dan) joylashadi.
///
/// Formula: metersPerPixel = 156543.03 * cos(lat) * 2^-zoom.
/// [pixelOffset] — markerni yuqoriga surish miqdori (pikselda).
ll.LatLng _cameraAnchorFor(
  double lat,
  double lng, {
  required double zoom,
  double pixelOffset = 260,
}) {
  final latRad = lat * (math.pi / 180);
  final metersPerPixel = 156543.03 * math.cos(latRad) * math.pow(2, -zoom);
  final metersOffset = pixelOffset * metersPerPixel;
  final degOffset = metersOffset / 111320.0;
  return ll.LatLng(lat - degOffset, lng);
}

/// Bugungi kun uchun tarix so'rovi — mahalliy yarim tundan kun oxirigacha.
///
/// MUHIM: `toMs` kun OXIRI (ertangi yarim tun), `now` EMAS. Aks holda kalit
/// har millisekundda o'zgarib, `FutureProvider.autoDispose.family` doim
/// qaytadan `loading`ga tushardi (timeline va yo'l chizig'i abadiy spinner).
LocationHistoryQuery _todayQuery(String childId) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final endOfToday = startOfToday.add(const Duration(days: 1));
  return (
    childId: childId,
    fromMs: startOfToday.millisecondsSinceEpoch,
    toMs: endOfToday.millisecondsSinceEpoch,
  );
}

/// Bola joylashuvini xaritada ko'rsatuvchi ekran.
///
/// Child App backend'ga joylashuv yozadi; `childLocationProvider.family`
/// REST + WS orqali real-vaqt marker chiqaradi. Xarita kalitsiz CARTO dark
/// plitkalarida (flutter_map) chiziladi — Google Maps kaliti shart emas.
///
/// `childId` — qaysi bola ko'rsatiladi. `null` bo'lsa birinchi bola.
class LocationMapScreen extends ConsumerStatefulWidget {
  /// `LocationMapScreen` konstruktor.
  const LocationMapScreen({super.key, this.childId});

  /// Ko'rsatiladigan bola identifikatori. `null` bo'lsa ro'yxatdagi
  /// birinchi bola tanlanadi.
  final String? childId;

  @override
  ConsumerState<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends ConsumerState<LocationMapScreen> {
  final MapController _mapController = MapController();
  // Xarita tayyor bo'lgach (onMapReady) move() chaqirish mumkin — undan
  // oldin chaqirilsa flutter_map exception beradi.
  bool _mapReady = false;
  gmaps.LatLng? _lastAnimatedTo;
  bool _userMovedCamera = false;
  // Sheet'ning joriy ochilish ulushi — suzuvchi karta shunga qarab yuqoriga
  // suriladi va kengayganda so'nadi (sheet ostida ko'milib qolmasligi uchun).
  double _sheetExtent = _sheetInitial;
  // Qaysi bola uchun wake-push yuborilgan (har bola uchun bir marta).
  String? _wokeChildId;
  // Ota-onaning O'Z joylashuvi (xaritada ko'k nuqta) + tugma yuklanish holati.
  gmaps.LatLng? _myLocation;
  bool _locating = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Yangi joylashuv kelganda kamerani avtomatik markerga olib boradi —
  /// faqat user qo'lda surganida emas.
  void _maybeAnimateCamera(gmaps.LatLng target, {bool force = false}) {
    if (!_mapReady) return;
    if (!force && _userMovedCamera) return;
    final prev = _lastAnimatedTo;
    // Dead-zone KATTALASHTIRILDI (~1m → ~20m): uy ICHIDA GPS "jitter" (har
    // fix'da 5–50m sakraydi) kamerani doim qayta markazlashtirib butun
    // xaritani sakratardi ("atrofga sochilish" effekti). Endi faqat SEZILARLI
    // siljishda (bola haqiqatan boshqa joyga yurganda) kamera markazga
    // qaytadi; kichik jitter e'tiborsiz qoladi — xarita tinch turadi.
    const deadZoneDeg = 0.0002; // ~20–22 metr
    if (!force &&
        prev != null &&
        (prev.latitude - target.latitude).abs() < deadZoneDeg &&
        (prev.longitude - target.longitude).abs() < deadZoneDeg) {
      return;
    }
    _lastAnimatedTo = target;
    final zoom = _mapController.camera.zoom;
    _mapController.move(
      _cameraAnchorFor(target.latitude, target.longitude, zoom: zoom),
      zoom,
    );
  }

  /// User qo'lda xaritani surdi — auto-follow'ni o'chiramiz.
  void _onUserGesture() {
    _userMovedCamera = true;
  }

  /// Kamerani JONLI joylashuvga qaytaradi (eski `_lastAnimatedTo` emas —
  /// bola surilgan paytda harakatlangan bo'lsa, eski nuqtaga qaytarmasin).
  void _recenter(gmaps.LatLng loc) {
    if (!_mapReady) return;
    _userMovedCamera = false;
    _lastAnimatedTo = loc;
    _mapController.move(
      _cameraAnchorFor(loc.latitude, loc.longitude, zoom: 16),
      16,
    );
  }

  /// "Mening joylashuvim" — ota-ona qurilmasining GPS joyini oladi, xaritani
  /// o'sha yerga olib boradi va ko'k nuqta ko'rsatadi. Ruxsat yo'q / GPS o'chiq
  /// / xato bo'lsa mos toast chiqadi.
  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    final res = await ref.read(parentLocationServiceProvider).current();
    if (!mounted) return;
    if (res.isOk) {
      final loc = gmaps.LatLng(res.latitude!, res.longitude!);
      // Bola auto-follow'ini to'xtatamiz — aks holda keyingi bola yangilanishi
      // kamerani bolага qaytarib, "mening joyim"ни bekor qilardi.
      _userMovedCamera = true;
      _lastAnimatedTo = loc;
      setState(() {
        _myLocation = loc;
        _locating = false;
      });
      if (_mapReady) {
        _mapController.move(
          _cameraAnchorFor(loc.latitude, loc.longitude, zoom: 16),
          16,
        );
      }
    } else {
      setState(() => _locating = false);
      final msg = switch (res.status) {
        MyLocationStatus.serviceOff => 'location.myLocation.serviceOff'.tr(),
        MyLocationStatus.denied => 'location.myLocation.denied'.tr(),
        _ => 'location.myLocation.error'.tr(),
      };
      AppToast.error(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenListProvider);

    if (children.isEmpty) {
      return const _NoChildrenScreen();
    }

    final child = widget.childId == null
        ? children.first
        : children.firstWhereOrNull((c) => c.id == widget.childId) ??
              children.first;

    // Xarita ochildi/bola almashdi — boladan darhol yangi GPS fix so'raymiz
    // (backend data-only FCM yuboradi, javob WS orqali bir necha soniyada
    // keladi). Har bola uchun bir marta.
    if (_wokeChildId != child.id) {
      _wokeChildId = child.id;
      unawaited(
        ref
            .read(backendLocationRepositoryProvider)
            .requestLocationUpdate(child.id),
      );
    }

    final zones =
        ref.watch(geoZonesProvider(child.id)).valueOrNull ?? const <GeoZone>[];

    // Bugungi trek (polyline) — bugun yarim tunidan hozirgacha.
    final todayQuery = _todayQuery(child.id);
    final track =
        ref.watch(locationHistoryProvider(todayQuery)).valueOrNull ??
        const <ChildLocation>[];
    // Ko'chalarga yopishtirilgan yo'l (OSRM). Tayyor bo'lmasa — xom trek
    // (to'g'ri chiziq) bilan ko'rsatamiz.
    final roadRoute = ref.watch(roadRouteProvider(todayQuery)).valueOrNull;
    // roadRoute tayyor bo'lmasa — tozalanган xom trek (sochilishsiz).
    final routeLine = (roadRoute != null && roadRoute.length >= 2)
        ? roadRoute
        : [
            for (final p in TrackCleaner.clean(track))
              ll.LatLng(p.latitude, p.longitude),
          ];

    final locationAsync = ref.watch(childLocationProvider(child.id));

    // Yangi location kelganda kamera markerga harakatlanadi
    // (user qo'lda harakatlantirmagan bo'lsa).
    ref.listen<AsyncValue<ChildLocation?>>(childLocationProvider(child.id), (
      _,
      next,
    ) {
      final loc = next.valueOrNull;
      if (loc != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeAnimateCamera(loc.latLng);
        });
      }
    });

    return Scaffold(
      backgroundColor: _bg,
      body: locationAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _blue)),
        error: (e, _) => _ErrorState(child: child, error: e),
        data: (location) {
          if (location == null) {
            return _NoLocationState(child: child);
          }
          // Birinchi data — kamera nishonini eslab qolamiz.
          _lastAnimatedTo ??= location.latLng;
          final screenH = MediaQuery.of(context).size.height;
          // Karta sheet kengayganda so'nadi: 0.36 da to'liq, ~0.60 da g'oyib.
          final cardOpacity = (1 - (_sheetExtent - _sheetInitial) / 0.24).clamp(
            0.0,
            1.0,
          );
          return NotificationListener<DraggableScrollableNotification>(
            onNotification: (n) {
              if ((n.extent - _sheetExtent).abs() > 0.002) {
                setState(() => _sheetExtent = n.extent);
              }
              return false;
            },
            child: Stack(
              children: [
                _MapLayer(
                  location: location,
                  child: child,
                  zones: zones,
                  route: routeLine,
                  myLocation: _myLocation,
                  controller: _mapController,
                  onUserGesture: _onUserGesture,
                  onMapReady: () => _mapReady = true,
                ),
                // Suzuvchi holat kartasi (Figma) — sheet bilan birga suriladi
                // va kengayganda so'nadi (ostida ko'milib qolmaydi).
                Positioned(
                  left: AppDimensions.md,
                  right: AppDimensions.md,
                  bottom: screenH * _sheetExtent + AppDimensions.sm,
                  child: IgnorePointer(
                    ignoring: cardOpacity < 0.05,
                    child: Opacity(
                      opacity: cardOpacity,
                      child: _StatusCard(
                        child: child,
                        location: location,
                        zones: zones,
                        onRecenter: () => _recenter(location.latLng),
                      ),
                    ),
                  ),
                ),
                // "Mening joylashuvim" tugmasi (Google Maps dumaloqчаsi) —
                // status karta ustida, o'ng chetда. Sheet kengayганда so'nadi.
                Positioned(
                  right: AppDimensions.md,
                  bottom: screenH * _sheetExtent + AppDimensions.sm + 76,
                  child: IgnorePointer(
                    ignoring: cardOpacity < 0.05,
                    child: Opacity(
                      opacity: cardOpacity,
                      child: _MyLocationButton(
                        loading: _locating,
                        active: _myLocation != null,
                        onTap: _locateMe,
                      ),
                    ),
                  ),
                ),
                // Yuqori scrim — sarlavha/ikonlar xarita ustida toza o'qilsin
                // (Figmadagidek; aks holda xarita yozuvlari ortidan ko'rinadi).
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: MediaQuery.of(context).padding.top + 150,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _bg.withValues(alpha: 0.92),
                            _bg.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    // Tepadan pastroq (yuqori chetga yopishmasin).
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.md,
                      AppDimensions.md + 44,
                      AppDimensions.md,
                      AppDimensions.md,
                    ),
                    child: _TopBar(child: child),
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: _sheetInitial,
                  minChildSize: 0.26,
                  maxChildSize: 0.9,
                  snap: true,
                  snapSizes: const [_sheetInitial, 0.9],
                  builder: (context, scrollController) => _LocationSheet(
                    child: child,
                    scrollController: scrollController,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════ MAP LAYER ════════════════════════

/// OQ xarita qatlami — light plitkalar + ko'k yo'l chizig'i + aniqlik/zona
/// doiralari + bola avatar-pin markeri + (ixtiyoriy) ota-ona ko'k nuqtasi.
class _MapLayer extends StatelessWidget {
  const _MapLayer({
    required this.location,
    required this.child,
    required this.zones,
    required this.route,
    required this.myLocation,
    required this.controller,
    required this.onUserGesture,
    required this.onMapReady,
  });

  final ChildLocation location;
  final Child child;
  final List<GeoZone> zones;

  /// Ko'chalarga yopishtirilgan bugungi yo'l — ko'k uzuq-uzuq polyline.
  final List<ll.LatLng> route;

  /// Ota-onaning O'Z joylashuvi (ko'k nuqta). `null` bo'lsa ko'rsatilmaydi.
  final gmaps.LatLng? myLocation;
  final MapController controller;
  final VoidCallback onUserGesture;
  final VoidCallback onMapReady;

  @override
  Widget build(BuildContext context) {
    final here = _toLL(location.latitude, location.longitude);
    // Kamera avatar'ni ekranning yuqori qismida ko'rsatsin (sheet
    // ostiga tushmasin) — biroz janubga surilgan boshlang'ich markaz.
    final initialAnchor = _cameraAnchorFor(
      location.latitude,
      location.longitude,
      zoom: 16,
    );
    // Yo'l oxirini AYNAN avatar (joriy joylashuv) nuqtasiga ulaymiz — OSRM
    // yo'lni eng yaqin ko'chaga yopishtirgani uchun kichik bo'shliq qolardi
    // va "chiziq turgan joyga bormagan"dek ko'rinardi.
    final line = (route.isNotEmpty && route.last == here)
        ? route
        : [...route, here];
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialAnchor,
        initialZoom: 16,
        onMapReady: onMapReady,
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) onUserGesture();
        },
        // Markaz va zoom cheklovi — OSM/CARTO plitka diapazoni.
        minZoom: 3,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          // Yorug' + POI'li xarita — Mapbox streets-v12 (token) yoki CARTO
          // Voyager (kalitsiz). map_tiles.dart'да markazlashган.
          urlTemplate: mapTileUrl,
          userAgentPackageName: kMapUserAgent,
        ),
        // Bugungi yo'l chizig'i (ko'chaga yopishган) — kamida 2 nuqta bo'lsa.
        if (line.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: line,
                color: _blue,
                strokeWidth: 4,
                pattern: StrokePattern.dashed(segments: const [18.0, 10.0]),
              ),
            ],
          ),
        // Aniqlik halosi + geo-zona doiralari (metrda).
        CircleLayer(
          circles: [
            CircleMarker(
              point: here,
              radius: location.accuracy.clamp(20, 120).toDouble(),
              useRadiusInMeter: true,
              color: _blue.withValues(alpha: 0.10),
              borderColor: _blue.withValues(alpha: 0.45),
              borderStrokeWidth: 1,
            ),
            for (final zone in zones)
              CircleMarker(
                point: _toLL(zone.latitude, zone.longitude),
                radius: zone.radiusMeters,
                useRadiusInMeter: true,
                color: _blue.withValues(alpha: 0.12),
                borderColor: _blue,
                borderStrokeWidth: 2,
              ),
          ],
        ),
        // Markerlar. Ota-ona ko'k nuqtasi AVVAL (bola avatari uning ustida
        // qolsin — bola asosiy nishon).
        MarkerLayer(
          markers: [
            // Geo-zona nishonlari ("qo'yilgan tochkalar") — zona ikoni + nomi.
            // Avval zonalar faqat XIRA DOIRA bo'lib chizilardi, marker/nom
            // yo'q edi → "Uy"/"Maktab" tochkasi ko'rinmasdi.
            for (final zone in zones)
              Marker(
                point: _toLL(zone.latitude, zone.longitude),
                width: 96,
                height: 60,
                child: _ZonePin(zone: zone),
              ),
            if (myLocation != null)
              Marker(
                point: _toLL(myLocation!.latitude, myLocation!.longitude),
                width: 28,
                height: 28,
                child: const _MyLocationDot(),
              ),
            // Bola markeri — oq doira ichida avatar + pastga ishora "dumcha".
            Marker(
              point: here,
              width: 58,
              height: 70,
              alignment: Alignment.topCenter,
              // Pin'ni quti pastiga tekislaymiz — "dumcha" uchi aynan
              // joylashuv nuqtasiga tushadi (aks holda ~12px yuqorida edi).
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _AvatarPin(child: child),
              ),
            ),
          ],
        ),
        // Attribution (Mapbox/OSM ToS talabi) — kichik kengayadigan "i".
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          showFlutterMapAttribution: false,
          attributions: [TextSourceAttribution(mapAttribution)],
        ),
      ],
    );
  }
}

/// Bola markeri: oq doira ichida avatar + pastga ishora qiluvchi uchburchak.
class _AvatarPin extends StatelessWidget {
  const _AvatarPin({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ChildAvatar(child: child, size: 42, showBorder: false),
        ),
        // Oq uchburchak "dumcha" — joylashuv nuqtasiga ishora qiladi.
        Transform.translate(
          offset: const Offset(0, -2),
          child: CustomPaint(
            size: const Size(16, 10),
            painter: _PinTailPainter(),
          ),
        ),
      ],
    );
  }
}

/// Markerning pastki oq uchburchagi.
class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
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

// ════════════════════════ MENING JOYLASHUVIM ════════════════════════

/// Ota-onaning O'Z joylashuvi — Google Maps uslubidagi ko'k nuqta
/// (oq halqa + ko'k glow).
/// Geo-zona nishoni — doira ichida zona ikoni (Uy/Maktab/...) va ostida nomi.
///
/// Avval xaritada zonalar FAQAT xira ko'k doira bo'lib chizilardi: "qo'yilgan
/// tochka" ko'zga tashlanmasdi. Endi har zona aniq nishon + nom bilan
/// ko'rinadi (ikon `GeoZone.iconFromString` — model allaqachon bergan).
class _ZonePin extends StatelessWidget {
  const _ZonePin({required this.zone});

  final GeoZone zone;

  @override
  Widget build(BuildContext context) {
    final name = zone.name.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            GeoZone.iconFromString(zone.icon ?? zone.type.defaultIconName),
            size: 17,
            color: Colors.white,
          ),
        ),
        if (name.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.45),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// "Mening joylashuvim" tugmasi — Google Maps dumaloqчаsi (GPS ikoni).
/// Bosilса ota-ona joyiga markazlashadi. [active] — joylashuv topilган (ko'k).
class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({
    required this.loading,
    required this.active,
    required this.onTap,
  });

  final bool loading;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Status karta bilan bir xil solid-glass fon.
      color: const Color(0xF20E1622),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _cardBorder),
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
                : Icon(
                    SolarIconsBold.gps,
                    size: 22,
                    color: active ? _blue : Colors.white,
                  ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ STATUS CARD (Figma) ════════════════════════

/// Xarita ustidagi suzuvchi holat kartasi (Figma): chap — joy ikoni,
/// markaz — joy holati (Ko'chada yoki zona nomi) + manzil, o'ng —
/// recenter (navigatsiya) tugmasi.
class _StatusCard extends ConsumerWidget {
  const _StatusCard({
    required this.child,
    required this.location,
    required this.zones,
    required this.onRecenter,
  });

  final Child child;
  final ChildLocation location;
  final List<GeoZone> zones;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(childAddressProvider(child.id)).valueOrNull;
    // Joriy joylashuv biror zona ichidami — "Uyda"/"Maktabda", aks holda
    // "Ko'chada" (Figma).
    final currentZone = _zoneForStop(location.latLng, zones);
    final status = currentZone != null
        ? 'location.status.inZone'.tr(
            namedArgs: {'zone': currentZone.name},
          )
        : "Ko'chada";
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xF20E1622),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(SolarIconsBold.mapPoint, size: 20, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(status, style: _lunb(16, w: FontWeight.w700, ls: -0.2)),
                const SizedBox(height: 3),
                Text(
                  address ?? 'location.command.addressLoading'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _lpop(12.5, c: _dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Recenter — markerga qaytish (Figma navigatsiya o'qi).
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRecenter,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  SolarIconsBold.mapArrowUp,
                  size: 19,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
