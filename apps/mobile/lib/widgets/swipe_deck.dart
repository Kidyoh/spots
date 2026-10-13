import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A stacked, Tinder-style card deck. The top card follows the finger with a
/// tilt; let go past the threshold (or fling) and it sails off while the card
/// beneath — already growing into place as you drag — becomes the new top.
///
/// Swiping either way moves forward, like turning pages; going back is the
/// parent's job (it lowers [index], and the old card glides back in from the
/// side it left by). Any other jump (Surprise me) pops the new card in.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.itemCount,
    required this.index,
    required this.itemBuilder,
    required this.onSwiped,
    this.keyOf,
  });

  final int itemCount;
  final int index;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ValueChanged<AxisDirection> onSwiped;

  /// Stable identity per item so state (e.g. image loads) survives reorders.
  final Object Function(int index)? keyOf;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck> with TickerProviderStateMixin {
  Offset _drag = Offset.zero;
  late final AnimationController _fly = AnimationController(vsync: this);
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );
  Animation<Offset>? _flyAnim;
  Offset _enterFrom = Offset.zero;
  bool _enterPop = false;
  AxisDirection _lastExit = AxisDirection.left;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fly.addListener(() {
      if (_flyAnim != null) setState(() => _drag = _flyAnim!.value);
    });
  }

  @override
  void didUpdateWidget(SwipeDeck old) {
    super.didUpdateWidget(old);
    final n = widget.itemCount;
    if (n == 0 || old.itemCount != n) return;
    final back = (old.index - 1) % n == widget.index % n && old.index != widget.index;
    final forward = (old.index + 1) % n == widget.index % n;
    if (back && !forward) {
      // re-enter from the side the card left by
      _enterPop = false;
      _enterFrom = Offset(_lastExit == AxisDirection.left ? -1.3 : 1.3, 0.05);
      _enter.forward(from: 0);
    } else if (old.index != widget.index && !_busy) {
      // a jump (Surprise me / focus) — pop in
      _enterPop = true;
      _enter.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fly.dispose();
    _enter.dispose();
    super.dispose();
  }

  /// Last laid-out width, for the gesture handlers (never read during build).
  double _width = 360;

  void _onPanUpdate(DragUpdateDetails d) {
    if (_busy) return;
    setState(() => _drag += Offset(d.delta.dx, d.delta.dy * 0.35));
  }

  Future<void> _onPanEnd(DragEndDetails d) async {
    if (_busy) return;
    final w = _width;
    final vx = d.velocity.pixelsPerSecond.dx;
    final fling = vx.abs() > 900;
    final far = _drag.dx.abs() > w * 0.3;
    if ((far || fling) && widget.itemCount > 1) {
      final dir = (fling ? vx : _drag.dx) < 0 ? -1.0 : 1.0;
      _lastExit = dir < 0 ? AxisDirection.left : AxisDirection.right;
      _busy = true;
      HapticFeedback.lightImpact();
      _flyAnim = Tween(
        begin: _drag,
        end: Offset(dir * w * 1.6, _drag.dy + 40),
      ).animate(CurvedAnimation(parent: _fly, curve: Curves.easeInCubic));
      _fly.duration = const Duration(milliseconds: 260);
      await _fly.forward(from: 0);
      _flyAnim = null;
      _drag = Offset.zero;
      widget.onSwiped(_lastExit);
      _busy = false;
      if (mounted) setState(() {});
    } else {
      _flyAnim = Tween(begin: _drag, end: Offset.zero).animate(CurvedAnimation(parent: _fly, curve: Curves.elasticOut));
      _fly.duration = const Duration(milliseconds: 650);
      await _fly.forward(from: 0);
      _flyAnim = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.itemCount;
    if (n == 0) return const SizedBox.shrink();
    final depth = math.min(3, n);

    return LayoutBuilder(
      builder: (context, box) {
        _width = box.maxWidth;
        final progress = (_drag.dx.abs() / (_width * 0.3)).clamp(0.0, 1.0);
        final children = <Widget>[];
        // back to front: the deepest card first
        for (var layer = depth - 1; layer >= 0; layer--) {
          final i = (widget.index + layer) % n;
          final key = ValueKey(widget.keyOf?.call(i) ?? i);
          final card = widget.itemBuilder(context, i);

          if (layer == 0) {
            final rot = (_drag.dx / box.maxWidth) * 0.32;
            children.add(
              AnimatedBuilder(
                key: key,
                animation: _enter,
                builder: (context, child) {
                  final t = Curves.easeOutBack.transform(_enter.value);
                  final e = _enterPop
                      ? Matrix4.diagonal3Values(0.86 + 0.14 * t, 0.86 + 0.14 * t, 1)
                      : Matrix4.translationValues(
                          _enterFrom.dx * box.maxWidth * (1 - t),
                          _enterFrom.dy * box.maxHeight * (1 - t),
                          0,
                        );
                  return Opacity(
                    opacity: _enterPop ? _enter.value.clamp(0.0, 1.0) : 1,
                    child: Transform(alignment: Alignment.center, transform: e, child: child),
                  );
                },
                child: GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Transform.translate(
                    offset: _drag,
                    child: Transform.rotate(angle: rot, alignment: const Alignment(0, 1.6), child: card),
                  ),
                ),
              ),
            );
          } else {
            // cards beneath rise toward the front as the top one is dragged
            final eff = layer - progress;
            final scale = 1 - 0.055 * eff;
            final dy = 16.0 * eff;
            children.add(
              IgnorePointer(
                key: key,
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.bottomCenter,
                    child: Opacity(opacity: (1 - 0.25 * (eff - 1).clamp(0, 1)).toDouble(), child: card),
                  ),
                ),
              ),
            );
          }
        }
        return Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: children);
      },
    );
  }
}
