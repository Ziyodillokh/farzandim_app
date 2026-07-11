// Platformaga mos Mapbox init (conditional import).
//
// Mobil (dart.library.io) → map_bootstrap_io.dart (haqiqiy Mapbox init).
// Web (dart.library.html) → map_bootstrap_web.dart (no-op).
//
// Shu tufayli WEB build mapbox_maps_flutter'ni kompilyatsiya qilmaydi —
// web build buzilmaydi (mapbox_maps_flutter web'ni to'liq qo'llamaydi).

export 'map_bootstrap_io.dart'
    if (dart.library.html) 'map_bootstrap_web.dart';
