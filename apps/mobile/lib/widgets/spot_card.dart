import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../models/spot.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// The deck card: the spot is the hero. A full-bleed cover with the essentials
/// set over a deep-green scrim — name, where, rating, price — and the area and
/// review count floating as tags up top. Tapping opens the full details.
class SpotCard extends StatelessWidget {
  const SpotCard({
    super.key,
    required this.spot,
    required this.onOpen,
    this.distance,
    this.saved = false,
    this.visited = false,
    this.showHint = false,
  });

  final Spot spot;
  final VoidCallback onOpen;
  final String? distance;
  final bool saved;
  final bool visited;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final price = priceText(spot);
    return Semantics(
      button: true,
      label: '${spot.name}, ${spot.area}. Open details',
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.xl), boxShadow: Shadows.card),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'cover-${spot.placeId}',
                  child: Cover(gradientKey: spot.placeId, url: spot.coverImageUrl),
                ),
                // scrim: transparent up top, deep green where the text sits
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.32, 0.62, 1],
                      colors: [
                        Palette.greenDeep.withValues(alpha: 0.28),
                        Palette.greenDeep.withValues(alpha: 0),
                        Palette.greenDeep.withValues(alpha: 0.45),
                        Palette.greenDeep.withValues(alpha: 0.94),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      GlassTag(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [const Icon(Icons.place_rounded), const SizedBox(width: 4), Text(spot.area)],
                        ),
                      ),
                      if (spot.isNew) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Palette.terracotta,
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Palette.card,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (visited)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: GlassTag(dark: true, child: Icon(Icons.check_rounded)),
                        ),
                      if (saved)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: GlassTag(dark: true, child: Icon(Icons.bookmark_rounded)),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.play_circle_fill_rounded, size: 15, color: Palette.gold.withValues(alpha: 0.95)),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '${spot.videoCount} TikTok ${spot.videoCount == 1 ? 'review' : 'reviews'}'
                              '${distance != null ? '  ·  ~$distance' : ''}',
                              style: TextStyle(
                                color: Palette.bg.withValues(alpha: 0.85),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        spot.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Palette.bg,
                          fontSize: 30,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                      if (spot.summary != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          spot.summary!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Palette.bg.withValues(alpha: 0.86),
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          StarMeter(value: spot.stars, size: 17, emptyColor: Palette.bg.withValues(alpha: 0.3)),
                          const SizedBox(width: 7),
                          Text(
                            spot.stars.toStringAsFixed(1),
                            style: const TextStyle(color: Palette.bg, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(width: 12),
                          const Spacer(),
                          if (price != null)
                            Flexible(
                              flex: 6,
                              child: _PricePill(level: spot.priceLevel!, text: price),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (showHint) const Positioned(top: 0, bottom: 0, left: 0, right: 0, child: _SwipeHint()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.level, required this.text});

  final int level;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Palette.bg.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: Palette.bg.withValues(alpha: 0.25)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: r'$' * level,
              style: const TextStyle(color: Palette.gold),
            ),
            TextSpan(
              text: r'$' * (4 - level),
              style: TextStyle(color: Palette.bg.withValues(alpha: 0.35)),
            ),
            TextSpan(text: '  $text'),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Palette.bg, fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// "Swipe to browse", gently rocking side to side until the first swipe.
class _SwipeHint extends StatefulWidget {
  const _SwipeHint();

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) =>
              Transform.translate(offset: Offset((Curves.easeInOut.transform(_c.value) - 0.5) * 28, -30), child: child),
          child: GlassTag(
            dark: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.swipe_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Swipe to browse', style: TextStyle(fontSize: 13.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
