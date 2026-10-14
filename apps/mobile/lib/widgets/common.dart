import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Network image over a deterministic warm gradient: the gradient shows while
/// the image loads, and stays if it never arrives (TikTok/Telegram CDNs are
/// third parties we don't control). [fallbackUrl] is tried if [url] fails —
/// a WebP variant that hasn't been generated yet falls back to the original.
class Cover extends StatelessWidget {
  const Cover({super.key, required this.gradientKey, this.url, this.fallbackUrl, this.child, this.borderRadius});

  final String gradientKey;
  final String? url;
  final String? fallbackUrl;
  final Widget? child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget content = DecoratedBox(
      decoration: BoxDecoration(gradient: coverGradient(gradientKey)),
      child: Stack(
        fit: StackFit.expand,
        children: [if (url == null) const _CoverPattern(), if (url != null) _image(url!, fallbackUrl), ?child],
      ),
    );
    if (borderRadius != null) content = ClipRRect(borderRadius: borderRadius!, child: content);
    return content;
  }

  Widget _image(String src, String? fallback) => Image.network(
    src,
    fit: BoxFit.cover,
    frameBuilder: (context, child, frame, sync) => sync
        ? child
        : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 350), child: child),
    errorBuilder: (context, error, stack) =>
        fallback != null && fallback != src ? _image(fallback, null) : const _CoverPattern(),
  );
}

/// A faint topographic doodle so an imageless cover still feels designed
/// rather than empty.
class _CoverPattern extends StatelessWidget {
  const _CoverPattern();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ContourPainter());
}

class _ContourPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Palette.card.withValues(alpha: 0.16);
    final c = Offset(size.width * 0.78, size.height * 0.28);
    for (var i = 1; i <= 9; i++) {
      canvas.drawOval(Rect.fromCenter(center: c, width: i * size.width * 0.18, height: i * size.width * 0.13), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Five stars filled to a fractional value (e.g. 4.3 of 5).
class StarMeter extends StatelessWidget {
  const StarMeter({super.key, required this.value, this.size = 18, this.emptyColor = Palette.starEmpty});

  final double value;
  final double size;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    final pct = (value / 5).clamp(0.0, 1.0);
    Widget row(Color c) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (_) => Icon(Icons.star_rounded, size: size, color: c)),
    );
    return Semantics(
      label: '${value.toStringAsFixed(1)} out of 5 stars',
      child: Stack(
        children: [
          row(emptyColor),
          ClipRect(clipper: _FractionClipper(pct), child: row(Palette.starFill)),
        ],
      ),
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  _FractionClipper(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_FractionClipper old) => old.fraction != fraction;
}

/// Tappable stars for rating a visit; tapping the current value clears it.
class EditableStars extends StatelessWidget {
  const EditableStars({super.key, required this.value, required this.onChanged, this.size = 30});

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var n = 1; n <= 5; n++)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            tooltip: '$n star${n == 1 ? '' : 's'}',
            onPressed: () {
              HapticFeedback.lightImpact();
              onChanged(value == n ? 0 : n);
            },
            icon: AnimatedScale(
              scale: value >= n ? 1.12 : 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                value >= n ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: value >= n ? Palette.starFill : Palette.starEmpty,
              ),
            ),
          ),
      ],
    );
  }
}

/// A rounded chip used for filters. Selected chips fill deep green.
class FilterChipPill extends StatelessWidget {
  const FilterChipPill({super.key, required this.label, required this.selected, required this.onTap, this.leading});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Palette.green : Palette.card,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: selected ? Palette.green : Palette.line),
            boxShadow: selected
                ? [BoxShadow(color: Palette.green.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                Icon(leading, size: 17, color: selected ? Palette.gold : Palette.green),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Palette.bg : Palette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small translucent label laid over a cover image.
class GlassTag extends StatelessWidget {
  const GlassTag({super.key, required this.child, this.dark = false});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? Palette.greenDeep.withValues(alpha: 0.72) : Palette.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? Palette.bg : Palette.ink),
        child: IconTheme.merge(
          data: IconThemeData(size: 14, color: dark ? Palette.gold : Palette.green),
          child: child,
        ),
      ),
    );
  }
}

/// Round icon button with a card background — for actions floating over
/// covers and maps.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 44,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    // Shadow on a box outside the Material (never clipped, never washing
    // over an unfilled box); the filled Material on top carries the ripple.
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: Shadows.card),
        child: Material(
          color: active ? Palette.terracotta : Palette.card,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: size * 0.46, color: active ? Palette.card : Palette.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Editorial section heading: a title with a quiet count/subtitle beside it.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 10),
        if (trailing != null)
          Expanded(
            child: Text(
              trailing!,
              style: const TextStyle(fontSize: 13, color: Palette.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// Shimmering placeholder block for loading states.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height, this.radius = Radii.md});

  final double? width;
  final double? height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + _c.value * 3, 0),
            end: Alignment(-0.5 + _c.value * 3, 0),
            colors: const [Palette.lineSoft, Palette.card, Palette.lineSoft],
          ),
        ),
      ),
    );
  }
}

/// Friendly empty / error state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: Palette.press, shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: Palette.green),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            if (action != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
