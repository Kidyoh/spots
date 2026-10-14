import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/format.dart';
import '../logic/geo.dart';
import '../models/spot.dart';
import '../models/visit.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/account_sheet.dart';
import '../widgets/common.dart';
import '../widgets/spot_map.dart';

Future<void> openSpot(BuildContext context, Spot spot, {String? heroTag}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 480),
      reverseTransitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (context, a, b) => SpotDetailScreen(spot: spot, heroTag: heroTag),
      transitionsBuilder: (context, a, b, child) => FadeTransition(
        opacity: CurvedAnimation(
          parent: a,
          curve: const Interval(0, 0.6, curve: Curves.easeOut),
        ),
        child: child,
      ),
    ),
  );
}

Future<void> shareSpot(Spot spot) =>
    SharePlus.instance.share(ShareParams(text: '${spotShareText(spot)}\n${spotShareUrl(spot)}', subject: spot.name));

Future<void> openUrl(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

class SpotDetailScreen extends StatefulWidget {
  const SpotDetailScreen({super.key, required this.spot, this.heroTag});

  final Spot spot;
  final String? heroTag;

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  final _confetti = ConfettiController(duration: const Duration(milliseconds: 900));

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Spot get spot => widget.spot;

  Future<void> _needSignIn(bool ok, String why) async {
    if (!ok && mounted) await showAccountSheet(context, reason: why);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final saved = state.isSaved(spot.placeId);
    final visit = state.visitFor(spot.placeId);
    final top = MediaQuery.paddingOf(context).top;
    final distance = state.coords != null && !state.farFromAddis ? formatRoadEstimate(state.roadKmTo(spot)) : null;

    Widget cover = Cover(
      gradientKey: spot.placeId,
      url: spot.coverVariant(960) ?? spot.coverImageUrl,
      fallbackUrl: spot.coverImageUrl,
    );
    if (widget.heroTag != null) cover = Hero(tag: widget.heroTag!, child: cover);

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                stretch: true,
                automaticallyImplyLeading: false,
                backgroundColor: Palette.bg,
                toolbarHeight: 64,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      cover,
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Palette.greenDeep.withValues(alpha: 0.35), Colors.transparent, Colors.transparent],
                          ),
                        ),
                      ),
                      if (spot.sourceVideoUrl != null)
                        Center(child: _PlayButton(onTap: () => openUrl(Uri.parse(spot.sourceVideoUrl!)))),
                      // the page's rounded top edge, drawn over the cover so
                      // the content reads as a sheet pulled up over it
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -1,
                        height: 31,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Palette.bg,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: Palette.bg,
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(spot: spot, distance: distance),
                      const SizedBox(height: 18),
                      _Actions(spot: spot),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _ToggleButton(
                              on: visit != null,
                              icon: Icons.check_circle_rounded,
                              offIcon: Icons.check_circle_outline_rounded,
                              onLabel: 'Been here',
                              offLabel: 'Mark as been',
                              onTap: () async => _needSignIn(
                                await state.toggleVisited(spot),
                                'Sign in to keep a log of the places you\'ve been.',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ToggleButton(
                              on: saved,
                              accent: true,
                              icon: Icons.bookmark_rounded,
                              offIcon: Icons.bookmark_outline_rounded,
                              onLabel: 'Saved',
                              offLabel: 'Want to go',
                              onTap: () async => _needSignIn(
                                await state.toggleSaved(spot),
                                'Sign in to save spots to your "Want to go" list.',
                              ),
                            ),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutCubic,
                        child: visit == null
                            ? const SizedBox(width: double.infinity)
                            : _YourRating(
                                visit: visit,
                                onRate: (r) {
                                  if (r == 5) _confetti.play();
                                  state.updateVisit(visit.copyWith(rating: r));
                                },
                              ),
                      ),
                      if (spot.summary != null) ...[const SizedBox(height: 22), _Quote(text: spot.summary!)],
                      if (spot.tags.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Wrap(spacing: 7, runSpacing: 7, children: [for (final t in spot.tags) _Tag(t)]),
                      ],
                      const SizedBox(height: 22),
                      _RatingCard(spot: spot),
                      const SizedBox(height: 14),
                      _PriceCard(spot: spot),
                      const SizedBox(height: 14),
                      _MapCard(spot: spot),
                      SizedBox(height: 40 + MediaQuery.paddingOf(context).bottom),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // floating top controls
          Positioned(
            top: top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                RoundIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'Share this spot',
                  onPressed: () => shareSpot(spot),
                ),
                const SizedBox(width: 10),
                RoundIconButton(
                  icon: saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                  tooltip: saved ? 'Remove from Want to go' : 'Save to Want to go',
                  active: saved,
                  onPressed: () async =>
                      _needSignIn(await state.toggleSaved(spot), 'Sign in to save spots to your "Want to go" list.'),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 28,
              maxBlastForce: 32,
              minBlastForce: 12,
              gravity: 0.25,
              colors: const [Palette.terracotta, Palette.amber, Palette.gold, Palette.sage, Palette.green],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.spot, this.distance});

  final Spot spot;
  final String? distance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              spot.area.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: Palette.accentText,
              ),
            ),
            if (spot.isNew) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Palette.accentWash, borderRadius: BorderRadius.circular(Radii.pill)),
                child: const Text(
                  'NEW',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Palette.accentText),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(spot.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(height: 1.12)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.place_outlined, size: 17, color: Palette.sage),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                [spot.address ?? spot.area, if (distance != null) '~$distance away'].join(' · '),
                style: const TextStyle(color: Palette.inkSoft, fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, VoidCallback)>[
      if (spot.sourceVideoUrl != null)
        (Icons.play_arrow_rounded, 'Watch', () => openUrl(Uri.parse(spot.sourceVideoUrl!))),
      if (!spot.hideMap) (Icons.map_outlined, 'Map', () => openUrl(mapsUri(spot))),
      (Icons.directions_rounded, 'Directions', () => openUrl(directionsUri(spot))),
      (Icons.ios_share_rounded, 'Share', () => shareSpot(spot)),
    ];
    return Row(
      children: [
        for (final (icon, label, onTap) in actions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: Palette.card,
                borderRadius: BorderRadius.circular(Radii.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: Palette.lineSoft),
                    ),
                    child: Column(
                      children: [
                        Icon(icon, color: Palette.green, size: 22),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Palette.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.on,
    required this.icon,
    required this.offIcon,
    required this.onLabel,
    required this.offLabel,
    required this.onTap,
    this.accent = false,
  });

  final bool on;
  final IconData icon;
  final IconData offIcon;
  final String onLabel;
  final String offLabel;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final fill = accent ? Palette.terracotta : Palette.green;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        height: 52,
        decoration: BoxDecoration(
          color: on ? fill : Palette.card,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: on ? fill : Palette.line, width: 1.4),
          boxShadow: on
              ? [BoxShadow(color: fill.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(on ? icon : offIcon, key: ValueKey(on), color: on ? Palette.card : Palette.ink, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              on ? onLabel : offLabel,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: on ? Palette.card : Palette.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _YourRating extends StatelessWidget {
  const _YourRating({required this.visit, required this.onRate});

  final Visit visit;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(color: Palette.press, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Our rating',
              style: TextStyle(fontWeight: FontWeight.w700, color: Palette.green),
            ),
          ),
          EditableStars(value: visit.rating, onChanged: onRate, size: 26),
        ],
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Palette.amber, width: 3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          height: 1.55,
          color: Palette.ink,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: Palette.lineSoft),
      ),
      child: Text(
        '#$label',
        style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Palette.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Palette.muted,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      label: 'Rating',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                spot.stars.toStringAsFixed(1),
                style: const TextStyle(fontSize: 40, height: 1, fontWeight: FontWeight.w700, color: Palette.ink),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: StarMeter(value: spot.stars, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('from Google reviews + TikTok comments', style: TextStyle(fontSize: 12.5, color: Palette.muted)),
          const SizedBox(height: 16),
          for (final (i, (label, v)) in spot.dimensions.labelled.indexed) _Bar(label: label, value: v, delay: i),
        ],
      ),
    );
  }
}

/// One dimension bar, filling in with a slight stagger on first build.
class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.delay});

  final String label;
  final double value;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Palette.inkSoft),
            ),
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value / 5).clamp(0, 1)),
              duration: Duration(milliseconds: 700 + delay * 110),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => Container(
                height: 8,
                decoration: BoxDecoration(color: Palette.lineSoft, borderRadius: BorderRadius.circular(Radii.pill)),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: t,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.pill),
                      gradient: const LinearGradient(colors: [Palette.sage, Palette.green]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              value.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    final price = priceText(spot);
    return _InfoCard(
      label: 'Price range',
      child: price == null
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No price data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Palette.muted),
                ),
                SizedBox(height: 4),
                Text('not enough signal in the reviews yet', style: TextStyle(fontSize: 12.5, color: Palette.muted)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: r'$' * spot.priceLevel!,
                            style: const TextStyle(color: Palette.accentText),
                          ),
                          TextSpan(
                            text: r'$' * (4 - spot.priceLevel!),
                            style: const TextStyle(color: Palette.starEmpty),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      price,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${basisLabel(spot)} · ${priceRangeText[spot.priceLevel!]} ETB band',
                  style: const TextStyle(fontSize: 12.5, color: Palette.muted),
                ),
              ],
            ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: SizedBox(
        height: 230,
        child: Stack(
          children: [
            SpotMiniMap(lat: spot.lat, lng: spot.lng),
            Positioned(
              right: 12,
              top: 12,
              child: Material(
                color: Palette.card,
                borderRadius: BorderRadius.circular(Radii.pill),
                elevation: 2,
                shadowColor: Palette.shadow.withValues(alpha: 0.3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  onTap: () => openUrl(directionsUri(spot)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.navigation_rounded, size: 16, color: Palette.terracotta),
                        SizedBox(width: 6),
                        Text('Take me there', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Watch the review',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 70 + 26 * _c.value,
                height: 70 + 26 * _c.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Palette.card.withValues(alpha: 0.3 * (1 - _c.value)),
                ),
              ),
              child!,
            ],
          ),
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Palette.card.withValues(alpha: 0.92),
              boxShadow: Shadows.floating,
            ),
            child: Transform.translate(
              offset: Offset(math.sqrt2, 0),
              child: const Icon(Icons.play_arrow_rounded, size: 38, color: Palette.greenDeep),
            ),
          ),
        ),
      ),
    );
  }
}
