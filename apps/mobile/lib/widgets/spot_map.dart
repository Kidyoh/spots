import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../theme/tokens.dart';

/// Raster basemap. Defaults to the standard OpenStreetMap tiles (fine for
/// light use with an identifying user agent); point it at another provider —
/// e.g. CARTO Voyager, which now needs an API key — with
/// `--dart-define=MAP_TILE_URL=https://…/{z}/{x}/{y}.png` and
/// `--dart-define=MAP_ATTRIBUTION=…`.
const _tileUrl = String.fromEnvironment('MAP_TILE_URL', defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
const _attribution = String.fromEnvironment('MAP_ATTRIBUTION', defaultValue: '© OpenStreetMap contributors');

TileLayer basemapTiles() =>
    TileLayer(urlTemplate: _tileUrl, userAgentPackageName: 'io.spots.spots_mobile', maxZoom: 19);

Widget mapAttribution() =>
    const SimpleAttributionWidget(source: Text(_attribution), backgroundColor: Color(0xCCFFFEFB));

/// The spot pin: a deep-green teardrop with a terracotta heart, matching the
/// web's `.spot-pin`.
class SpotPin extends StatelessWidget {
  const SpotPin({super.key, this.selected = false, this.label});

  final bool selected;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 46.0 : 34.0;
    return AnimatedScale(
      scale: 1,
      duration: const Duration(milliseconds: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: selected ? Palette.terracotta : Palette.greenDeep,
              shape: BoxShape.circle,
              border: Border.all(color: Palette.card, width: 3),
              boxShadow: [
                BoxShadow(color: Palette.shadow.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            alignment: Alignment.center,
            child: label != null
                ? Text(
                    label!,
                    style: TextStyle(color: Palette.card, fontWeight: FontWeight.w700, fontSize: selected ? 14 : 12),
                  )
                : Icon(Icons.favorite_rounded, size: size * 0.42, color: selected ? Palette.card : Palette.gold),
          ),
          CustomPaint(size: const Size(12, 7), painter: _Tip(selected ? Palette.terracotta : Palette.greenDeep)),
        ],
      ),
    );
  }
}

class _Tip extends CustomPainter {
  _Tip(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Tip old) => old.color != color;
}

/// "You are here": a pulsing terracotta dot.
class YouAreHere extends StatefulWidget {
  const YouAreHere({super.key});

  @override
  State<YouAreHere> createState() => _YouAreHereState();
}

class _YouAreHereState extends State<YouAreHere> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 18 + 30 * _c.value,
            height: 18 + 30 * _c.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Palette.terracotta.withValues(alpha: 0.35 * (1 - _c.value)),
            ),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Palette.terracotta,
              border: Border.all(color: Palette.card, width: 3),
              boxShadow: Shadows.card,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small, non-interactive map centred on one spot (for the detail page).
class SpotMiniMap extends StatelessWidget {
  const SpotMiniMap({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return FlutterMap(
      options: MapOptions(
        initialCenter: point,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        basemapTiles(),
        MarkerLayer(
          markers: [
            Marker(
              point: point,
              width: 52,
              height: 60,
              alignment: Alignment.topCenter,
              child: const SpotPin(selected: true),
            ),
          ],
        ),
        mapAttribution(),
      ],
    );
  }
}
