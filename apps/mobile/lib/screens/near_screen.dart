import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../logic/format.dart';
import '../logic/geo.dart';
import '../models/spot.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/spot_map.dart';
import 'discover_screen.dart' show navClearance;
import 'spot_detail_screen.dart';

/// "Near me" — the web's `/near`: spots sorted by estimated road distance,
/// on a full-screen map with a swipeable card rail floating above the tabs.
class NearScreen extends StatefulWidget {
  const NearScreen({super.key});

  @override
  State<NearScreen> createState() => _NearScreenState();
}

class _NearScreenState extends State<NearScreen> with TickerProviderStateMixin {
  final _map = MapController();
  final _pages = PageController(viewportFraction: 0.86);
  int _selected = 0;

  /// The card the rail is sliding to after a pin tap. While set, the pages
  /// it passes on the way are ignored — otherwise each one would re-select
  /// its spot and the map would fly back and forth.
  int? _railTarget;
  double _radius = 10;
  AnimationController? _moveAnim;

  static const _radii = [2.0, 5.0, 10.0];

  @override
  void dispose() {
    _moveAnim?.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// Smoothly fly the camera (flutter_map's move() jumps).
  void _flyTo(LatLng to, [double? zoom]) {
    final cam = _map.camera;
    final latT = Tween(begin: cam.center.latitude, end: to.latitude);
    final lngT = Tween(begin: cam.center.longitude, end: to.longitude);
    final zT = Tween(begin: cam.zoom, end: zoom ?? cam.zoom);
    _moveAnim?.dispose();
    final c = _moveAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    final a = CurvedAnimation(parent: c, curve: Curves.easeInOutCubic);
    c.addListener(() => _map.move(LatLng(latT.evaluate(a), lngT.evaluate(a)), zT.evaluate(a)));
    c.forward();
  }

  List<(Spot, double)> _nearby(AppState state) {
    final all = state.spots ?? const <Spot>[];
    final list = [for (final s in all) (s, state.roadKmTo(s))]..sort((a, b) => a.$2.compareTo(b.$2));
    final within = list.where((e) => e.$2 <= _radius).toList();
    return within;
  }

  void _select(int i, List<(Spot, double)> list, {bool fromMap = false}) {
    if (i >= list.length) return;
    setState(() => _selected = i);
    final s = list[i].$1;
    _flyTo(LatLng(s.lat, s.lng), 14.5);
    if (fromMap && _pages.hasClients) {
      _railTarget = i;
      // far away: jump next to it first, so the slide is one short step
      final current = _pages.page?.round() ?? i;
      if ((current - i).abs() > 2) _pages.jumpToPage(i + (current < i ? -1 : 1));
      _pages
          .animateToPage(i, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic)
          .whenComplete(() => _railTarget = null);
    }
  }

  void _onPageChanged(int i, List<(Spot, double)> list) {
    if (_railTarget != null) return; // passing through on the way to a tapped pin
    _select(i, list);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final list = _nearby(state);
    if (_selected >= list.length) _selected = 0;
    final origin = state.origin;
    final located = state.coords != null && !state.farFromAddis;
    final top = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: LatLng(origin.lat, origin.lng),
            initialZoom: 13,
            minZoom: 10,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            basemapTiles(),
            if (located)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(origin.lat, origin.lng),
                    radius: _radius * 1000 / 1.9, // road km → rough straight-line metres
                    useRadiusInMeter: true,
                    color: Palette.terracotta.withValues(alpha: 0.06),
                    borderColor: Palette.terracotta.withValues(alpha: 0.35),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final (i, (s, _)) in list.indexed)
                  Marker(
                    point: LatLng(s.lat, s.lng),
                    width: 56,
                    height: 64,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _select(i, list, fromMap: true);
                      },
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SpotPin(selected: i == _selected, label: '${i + 1}'),
                      ),
                    ),
                  ),
                if (located)
                  Marker(point: LatLng(origin.lat, origin.lng), width: 60, height: 60, child: const YouAreHere()),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(bottom: navClearance(context) + (list.isEmpty ? 0 : 150)),
              child: mapAttribution(),
            ),
          ],
        ),
        // floating header
        Positioned(
          top: top + 10,
          left: 16,
          right: 16,
          child: _Header(
            state: state,
            radius: _radius,
            radii: _radii,
            count: list.length,
            onRadius: (r) => setState(() {
              _radius = r;
              _selected = 0;
            }),
            onLocate: () async {
              await state.requestLocation();
              final o = state.origin;
              if (mounted) _flyTo(LatLng(o.lat, o.lng), 13.5);
            },
          ),
        ),
        // card rail
        Positioned(
          left: 0,
          right: 0,
          bottom: navClearance(context),
          height: 138,
          child: list.isEmpty
              ? Center(
                  child: GlassTag(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        state.spots == null
                            ? 'Loading spots…'
                            : 'Nothing within ${_radius.round()} km — widen the radius',
                      ),
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _pages,
                  itemCount: list.length,
                  onPageChanged: (i) => _onPageChanged(i, list),
                  itemBuilder: (context, i) {
                    final (s, km) = list[i];
                    return AnimatedScale(
                      scale: i == _selected ? 1 : 0.93,
                      duration: const Duration(milliseconds: 260),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _NearCard(spot: s, rank: i + 1, distance: formatRoadEstimate(km), approximate: !located),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.radius,
    required this.radii,
    required this.count,
    required this.onRadius,
    required this.onLocate,
  });

  final AppState state;
  final double radius;
  final List<double> radii;
  final int count;
  final ValueChanged<double> onRadius;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final located = state.coords != null && !state.farFromAddis;
    final status = switch (state.locStatus) {
      LocStatus.locating => 'Finding you…',
      LocStatus.denied => 'Location is off — measuring from central Addis',
      LocStatus.unavailable => "Couldn't get a fix — measuring from central Addis",
      LocStatus.granted when state.farFromAddis => "You're outside Addis — measuring from the centre",
      LocStatus.granted => '$count spots within ~${radius.round()} km by road',
      LocStatus.idle => 'Measuring from central Addis',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: Shadows.floating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Near me', style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.1)),
                    const SizedBox(height: 2),
                    Text(status, style: const TextStyle(fontSize: 12.5, color: Palette.muted)),
                  ],
                ),
              ),
              Material(
                color: located ? Palette.press : Palette.terracotta,
                borderRadius: BorderRadius.circular(Radii.pill),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  onTap: state.locStatus == LocStatus.locating ? null : onLocate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.locStatus == LocStatus.locating)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Palette.card),
                          )
                        else
                          Icon(Icons.my_location_rounded, size: 17, color: located ? Palette.green : Palette.card),
                        const SizedBox(width: 6),
                        Text(
                          located ? 'Recenter' : 'Use my location',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: located ? Palette.green : Palette.card,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final r in radii) ...[
                FilterChipPill(label: '${r.round()} km', selected: radius == r, onTap: () => onRadius(r)),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NearCard extends StatelessWidget {
  const _NearCard({required this.spot, required this.rank, required this.distance, required this.approximate});

  final Spot spot;
  final int rank;
  final String distance;
  final bool approximate;

  @override
  Widget build(BuildContext context) {
    final price = spot.priceLevel != null ? priceLabels[spot.priceLevel] : null;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.lg), boxShadow: Shadows.floating),
      child: Material(
        color: Palette.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: () => openSpot(context, spot, heroTag: 'near-${spot.placeId}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: double.infinity,
                  child: Hero(
                    tag: 'near-${spot.placeId}',
                    child: Cover(
                      gradientKey: spot.placeId,
                      url: spot.coverVariant(480) ?? spot.coverImageUrl,
                      fallbackUrl: spot.coverImageUrl,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Palette.accentWash,
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                            child: Text(
                              '${approximate ? '' : '~'}$distance${approximate ? ' from centre' : ''}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Palette.accentText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$rank. ${spot.name}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 15, color: Palette.starFill),
                          const SizedBox(width: 3),
                          Text(
                            spot.stars.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Palette.ink),
                          ),
                          Expanded(
                            child: Text(
                              '  ·  ${spot.areaShort}${price != null ? '  ·  $price' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: Palette.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
