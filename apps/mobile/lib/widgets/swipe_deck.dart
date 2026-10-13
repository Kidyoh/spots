import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// A stacked card deck. The top card follows the finger and tilts away from
/// where it was grabbed; let go past the threshold (or fling) and it leaves at
/// the speed you threw it while the card beneath — already rising as you drag
/// — settles into place. Short of the threshold it springs back without
/// wobbling.
///
/// Swiping either way moves forward. Going back is the parent's job: it
/// lowers [index] and the old card glides back in from the side it left by.
/// Any other jump (Surprise me) settles the new card in with a small pop.
///
/// Every card keeps one widget identity for as long as it is in the stack
/// (same type, keyed by [keyOf]), so promoting a card never rebuilds it or
/// reloads its image; only its transform changes.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.itemCount,
    required this.index,
    required this.itemBuilder,
    required this.onSwiped,
    required this.keyOf,
  });

  final int itemCount;
  final int index;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ValueChanged<AxisDirection> onSwiped;
  final Object Function(int index) keyOf;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck> with TickerProviderStateMixin {
  /// Top card offset from rest. A notifier, so dragging repaints transforms
  /// without rebuilding the cards.
  final _drag = ValueNotifier<Offset>(Offset.zero);

  /// +1 when grabbed in the top half (tilts with the drag), −1 in the bottom.
  double _tiltSign = 1;

  late final AnimationController _settle = AnimationController.unbounded(vsync: this);
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );
  _Entry _entry = _Entry.pop;
  AxisDirection _lastExit = AxisDirection.left;

  /// Set while a card is flying off, until the parent advances [index].
  bool _leaving = false;
  bool _pastThreshold = false;
  Size _size = const Size(360, 600);

  @override
  void didUpdateWidget(SwipeDeck old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index && old.itemCount == widget.itemCount) return;
    final n = widget.itemCount;
    final forward = n > 0 && (old.index + 1) % n == widget.index % n;
    if (_leaving && forward) {
      // the card that flew off is no longer on top; the new top starts at rest
      _leaving = false;
      _drag.value = Offset.zero;
      return;
    }
    _leaving = false;
    _settle.stop();
    _drag.value = Offset.zero;
    final back = n > 1 && (old.index - 1) % n == widget.index % n && old.itemCount == n;
    _entry = back ? (_lastExit == AxisDirection.left ? _Entry.fromLeft : _Entry.fromRight) : _Entry.pop;
    _enter.forward(from: 0);
  }

  @override
  void dispose() {
    _settle.dispose();
    _enter.dispose();
    _drag.dispose();
    super.dispose();
  }

  double get _threshold => _size.width * 0.28;

  void _onStart(DragStartDetails d) {
    if (_leaving) return;
    _settle.stop();
    _tiltSign = d.localPosition.dy < _size.height / 2 ? 1 : -1;
    _pastThreshold = _drag.value.dx.abs() > _threshold;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_leaving) return;
    final next = _drag.value + Offset(d.delta.dx, d.delta.dy * 0.4);
    _drag.value = next;
    final past = next.dx.abs() > _threshold;
    if (past != _pastThreshold) {
      _pastThreshold = past;
      if (past) HapticFeedback.selectionClick();
    }
  }

  void _onEnd(DragEndDetails d) {
    if (_leaving) return;
    final v = d.velocity.pixelsPerSecond;
    final dx = _drag.value.dx;
    final flung = v.dx.abs() > 700 && v.dx.sign == dx.sign;
    if (widget.itemCount > 1 && (dx.abs() > _threshold || flung)) {
      _flyOff(dx.sign == 0 ? v.dx.sign : dx.sign, v);
    } else {
      _springBack(v);
    }
  }

  /// Leave at the release speed (at least brisk), along the drag's line.
  void _flyOff(double dir, Offset velocity) {
    _leaving = true;
    _lastExit = dir < 0 ? AxisDirection.left : AxisDirection.right;
    HapticFeedback.lightImpact();
    final start = _drag.value;
    final end = Offset(dir * (_size.width * 1.25 + 80), start.dy + velocity.dy * 0.08);
    final distance = (end - start).distance;
    final speed = math.max(velocity.distance, 1800.0);
    final ms = (distance / speed * 1000).clamp(140, 320).round();
    _animate(start, end, Duration(milliseconds: ms), Curves.easeOutCubic, () {
      if (!mounted) return;
      // Hold the card off-screen until the parent moves on, so it never
      // flashes back into the middle for a frame.
      widget.onSwiped(_lastExit);
    });
  }

  /// A critically damped spring home: quick, no wobble.
  void _springBack(Offset velocity) {
    final start = _drag.value;
    if (start == Offset.zero) return;
    final sim = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 520, damping: 46),
      1,
      0,
      // drag = start · t, so dt/dt = (v · start) / |start|²
      (velocity.dx * start.dx + velocity.dy * start.dy) / (start.distance * start.distance),
    );
    _settle.removeListener(_tick);
    _from = start;
    _to = Offset.zero;
    _curve = null;
    _settle.addListener(_tick);
    _settle.animateWith(sim);
  }

  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  Curve? _curve;

  void _tick() {
    final t = _curve == null ? _settle.value : _curve!.transform(_settle.value.clamp(0.0, 1.0));
    // spring runs 1 → 0 over (start → rest); tween runs 0 → 1 over (from → to)
    _drag.value = _curve == null ? _from * t : Offset.lerp(_from, _to, t)!;
  }

  void _animate(Offset from, Offset to, Duration duration, Curve curve, VoidCallback done) {
    _settle.removeListener(_tick);
    _from = from;
    _to = to;
    _curve = curve;
    _settle.value = 0;
    _settle.addListener(_tick);
    _settle.animateTo(1, duration: duration, curve: Curves.linear).whenCompleteOrCancel(() {
      if (_settle.value >= 1) done();
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.itemCount;
    if (n == 0) return const SizedBox.shrink();
    final depth = math.min(3, n);

    return LayoutBuilder(
      builder: (context, box) {
        _size = box.biggest;
        final layers = <Widget>[];
        for (var layer = depth - 1; layer >= 0; layer--) {
          final i = (widget.index + layer) % n;
          layers.add(
            _DeckLayer(
              key: ValueKey(widget.keyOf(i)),
              layer: layer,
              drag: _drag,
              enter: _enter,
              entry: _entry,
              threshold: _threshold,
              tiltSign: () => _tiltSign,
              size: _size,
              onStart: _onStart,
              onUpdate: _onUpdate,
              onEnd: _onEnd,
              child: RepaintBoundary(child: widget.itemBuilder(context, i)),
            ),
          );
        }
        return Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: layers);
      },
    );
  }
}

enum _Entry { pop, fromLeft, fromRight }

/// One card in the stack. Same widget type at every depth, so a card that
/// moves up keeps its element (and its loaded image).
class _DeckLayer extends StatelessWidget {
  const _DeckLayer({
    super.key,
    required this.layer,
    required this.drag,
    required this.enter,
    required this.entry,
    required this.threshold,
    required this.tiltSign,
    required this.size,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.child,
  });

  final int layer;
  final ValueNotifier<Offset> drag;
  final Animation<double> enter;
  final _Entry entry;
  final double threshold;
  final double Function() tiltSign;
  final Size size;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = layer == 0;
    return AnimatedBuilder(
      animation: Listenable.merge([drag, enter]),
      child: child,
      builder: (context, child) {
        final d = drag.value;
        final Matrix4 m;
        if (top) {
          final e = Curves.easeOutCubic.transform(enter.value);
          final angle = (d.dx / size.width) * 0.32 * tiltSign();
          m = Matrix4.identity()
            ..translateByDouble(d.dx, d.dy, 0, 1)
            ..rotateZ(angle);
          switch (entry) {
            case _Entry.pop:
              final s = 0.94 + 0.06 * e;
              m.scaleByDouble(s, s, 1, 1);
            case _Entry.fromLeft:
            case _Entry.fromRight:
              final from = (entry == _Entry.fromLeft ? -1 : 1) * (size.width * 1.25);
              m
                ..setTranslationRaw(d.dx + from * (1 - e), d.dy, 0)
                ..rotateZ((entry == _Entry.fromLeft ? -0.12 : 0.12) * (1 - e));
          }
        } else {
          // rise toward the front as the top card is dragged away
          final progress = (d.dx.abs() / threshold).clamp(0.0, 1.0);
          final eff = layer - progress;
          final s = 1 - 0.05 * eff;
          m = Matrix4.identity()
            ..translateByDouble(0, 14 * eff, 0, 1)
            ..scaleByDouble(s, s, 1, 1);
        }
        final card = Transform(transform: m, alignment: Alignment.center, child: child);
        if (!top) return IgnorePointer(child: card);
        return GestureDetector(onPanStart: onStart, onPanUpdate: onUpdate, onPanEnd: onEnd, child: card);
      },
    );
  }
}
