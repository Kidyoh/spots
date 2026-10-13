import 'dart:math' as math;

/// Distance helpers, ported from `apps/web/src/lib/geo.ts`. Coordinates stay
/// on the device — they are never written to Supabase or logged.

typedef Coords = ({double lat, double lng});

/// Greater Addis centre; the fallback when we have no fix.
const Coords addis = (lat: 9.0108, lng: 38.7613);
const _addisRadiusKm = 60.0;
const _earthKm = 6371.0;

double _rad(double d) => d * math.pi / 180;

/// Great-circle (Haversine) distance in kilometres.
double haversineKm(Coords a, Coords b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) + math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthKm * math.asin(math.sqrt(h));
}

bool isNearAddis(Coords c) => haversineKm(c, addis) <= _addisRadiusKm;

/// Road distance estimated from straight-line distance: road ≈ A · km^B,
/// calibrated against Google driving distances from a real Addis origin.
/// Only trustworthy within ~10 km.
double estimateRoadKm(double straightKm) => 2.51 * math.pow(math.max(0, straightKm), 0.68);

/// Rounded to the nearest 0.5 km — coarse on purpose, it reads as the
/// estimate it is. Floored at 0.5 so it never shows "0 km".
String formatRoadEstimate(double km) {
  final v = math.max(0.5, (km * 2).round() / 2);
  return v == v.roundToDouble() ? '${v.round()} km' : '$v km';
}
