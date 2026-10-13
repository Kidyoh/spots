import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// "Surprise me": the die tumbles to a new face (with a haptic rattle) and
/// the deck jumps to a random spot. Ported from `DiceButton.tsx`, but as a
/// floating capsule that sits above the tab bar.
class DiceButton extends StatefulWidget {
  const DiceButton({super.key, required this.onRoll, this.label = 'Surprise me', this.compact = false});

  final VoidCallback onRoll;
  final String label;
  final bool compact;

  @override
  State<DiceButton> createState() => _DiceButtonState();
}

class _DiceButtonState extends State<DiceButton> with SingleTickerProviderStateMixin {
  final _rng = math.Random();
  int _face = 5;
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _roll() async {
    HapticFeedback.mediumImpact();
    setState(() => _face = 1 + _rng.nextInt(6));
    _c.forward(from: 0);
    widget.onRoll();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final die = AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        final hop = math.sin(_c.value * math.pi) * -6;
        return Transform.translate(
          offset: Offset(0, hop),
          child: Transform.rotate(angle: t * math.pi * 2, child: child),
        );
      },
      child: SizedBox.square(dimension: 22, child: CustomPaint(painter: _DiePainter(_face))),
    );

    return Semantics(
      button: true,
      label: widget.label,
      child: Material(
        color: Palette.terracotta,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.pill),
          onTap: _roll,
          child: Container(
            height: 52,
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 15 : 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.pill),
              boxShadow: [
                BoxShadow(
                  color: Palette.terracotta.withValues(alpha: 0.38),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                die,
                if (!widget.compact) ...[
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: const TextStyle(color: Palette.card, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiePainter extends CustomPainter {
  _DiePainter(this.face);
  final int face;

  static const _pips = {
    1: [(50, 50)],
    2: [(32, 32), (68, 68)],
    3: [(32, 32), (50, 50), (68, 68)],
    4: [(32, 32), (68, 32), (32, 68), (68, 68)],
    5: [(32, 32), (68, 32), (50, 50), (32, 68), (68, 68)],
    6: [(32, 30), (68, 30), (32, 50), (68, 50), (32, 70), (68, 70)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(6, 6, 88, 88), const Radius.circular(24)),
      Paint()..color = Palette.card,
    );
    final pip = Paint()..color = Palette.terracotta;
    for (final (x, y) in _pips[face]!) {
      canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), 9.5, pip);
    }
  }

  @override
  bool shouldRepaint(_DiePainter old) => old.face != face;
}
