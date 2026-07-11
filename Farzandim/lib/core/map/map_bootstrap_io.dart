// Mapbox init — mobil (Android/iOS). Ilova ishga tushganda access token'ni
// bir marta o'rnatadi (xarita chizish uchun). Token bo'sh bo'lsa — no-op
// (env.json to'ldirilmagan bo'lsa ilova baribir ishga tushadi).

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Mapbox public access token'ni o'rnatadi (Android/iOS).
void initMapbox(String token) {
  if (token.isEmpty) return;
  MapboxOptions.setAccessToken(token);
}
