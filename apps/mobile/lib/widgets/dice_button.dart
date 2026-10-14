import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// "Surprise me": the die tumbles to a new face (with the web's roll sound
/// and a haptic rattle) and the deck jumps to a random spot. Ported from `DiceButton.tsx`, but as a
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
  AudioPlayer? _audio;

  @override
  void dispose() {
    _c.dispose();
    _audio?.dispose();
    super.dispose();
  }

  /// The same dice-roll.mp3 as the web. Like the web, it plays at media
  /// volume even when the ringer is on silent/vibrate (respecting silence is
  /// why the first build made no sound), and it mixes with whatever else is
  /// playing instead of pausing someone's music. The clip loads as the finger
  /// touches down (the roll fires on release), so the first roll isn't lost
  /// to loading. A flourish only: any
  /// failure is swallowed so the roll itself never waits on it.
  Future<AudioPlayer>? _ready;

  Future<AudioPlayer> _prepare() async {
    final audio = _audio = AudioPlayer();
    await audio.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers, respectSilence: false).build(),
    );
    await audio.setReleaseMode(ReleaseMode.stop); // keep the clip loaded between rolls
    await audio.setVolume(0.7);
    await audio.setSource(AssetSource('sounds/dice-roll.mp3'));
    return audio;
  }

  Future<void> _playSound() async {
    try {
      final audio = await (_ready ??= _prepare());
      await audio.seek(Duration.zero);
      await audio.resume();
    } catch (_) {
      _ready = null; // try loading again next roll
    }
  }

  Future<void> _roll() async {
    HapticFeedback.mediumImpact();
    setState(() => _face = 1 + _rng.nextInt(6));
    _c.forward(from: 0);
    _playSound();
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
          onTapDown: (_) => _ready ??= _prepare()..ignore(),
          onTap: _roll,
          child: Container(
            height: 52,
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 15 : 17),
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
                  const SizedBox(width: 8),
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
