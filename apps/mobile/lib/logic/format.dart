import '../models/spot.dart';

/// Ports of `apps/web/src/lib/format.ts`.

String etb(num n) {
  final s = n.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

const priceLabels = {1: r'$', 2: r'$$', 3: r'$$$', 4: r'$$$$'};
const priceRangeText = {1: 'under 300', 2: '300–700', 3: '700–1,500', 4: 'over 1,500'};

/// "ETB 300–700", or null when the reviews gave no price signal.
String? priceText(Spot s) {
  if (!s.hasPrice) return null;
  final max = s.priceMax;
  return 'ETB ${etb(s.priceMin!)}${max != null && max > 0 ? '–${etb(max)}' : ''}';
}

String basisLabel(Spot s) => s.priceBasis == 'total' ? 'total' : 'per person';

/// Google Maps deep link to the spot's exact place (by place_id).
Uri mapsUri(Spot s) => Uri.parse(
  'https://www.google.com/maps/search/?api=1'
  '&query=${Uri.encodeComponent(s.name)}'
  '&query_place_id=${s.placeId}',
);

/// Turn-by-turn directions from wherever the phone is.
Uri directionsUri(Spot s) => Uri.parse(
  'https://www.google.com/maps/dir/?api=1'
  '&destination=${s.lat},${s.lng}'
  '&destination_place_id=${s.placeId}',
);

/// Where the web app is deployed (`--dart-define=WEB_ORIGIN=https://…`).
const webOrigin = String.fromEnvironment('WEB_ORIGIN');

/// The deep link the web carousel already honours (`?spot=<place_id>`), so a
/// shared spot lands on its card; falls back to the Maps link when the app
/// doesn't know the site's origin.
String spotShareUrl(Spot s) =>
    webOrigin.isEmpty ? mapsUri(s).toString() : '$webOrigin/?spot=${Uri.encodeComponent(s.placeId)}';

String spotShareText(Spot s) =>
    s.neighborhood != null ? '${s.name} — ${s.neighborhood}, Addis Ababa' : '${s.name} — Addis Ababa';
