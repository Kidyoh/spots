import 'package:flutter/material.dart';

/// The app logo from `BrandMark.tsx`: a location pin holding a golden-hour
/// Addis sunset. Drawn on a 48×48 grid, scaled to [size].
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'spots',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _BrandPainter()),
      ),
    );
  }
}

class _BrandPainter extends CustomPainter {
  static const _ink = Color(0xFF2C4232);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48);

    // soft drop shadow under the pin, like the web's drop-shadow filter
    final pin = Path()
      ..moveTo(24, 3.4)
      ..cubicTo(15, 3.4, 7.4, 10.5, 7.4, 19.2)
      ..cubicTo(7.4, 28.6, 17.6, 38.6, 22.7, 44.4)
      ..quadraticBezierTo(24, 45.7, 25.3, 44.4)
      ..cubicTo(30.4, 38.6, 40.6, 28.6, 40.6, 19.2)
      ..cubicTo(40.6, 10.5, 33, 3.4, 24, 3.4)
      ..close();
    canvas.drawShadow(pin, _ink.withValues(alpha: 0.5), 2, false);
    canvas.drawPath(pin, Paint()..color = _ink);

    const center = Offset(24, 19);
    const r = 12.6;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));

    const sky = Rect.fromLTWH(11, 6, 26, 27);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBE6C9), Color(0xFFF6CF95)],
        ).createShader(sky),
    );

    final sun = Rect.fromCircle(center: const Offset(24, 21.5), radius: 6.6);
    canvas.drawOval(
      sun,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.1),
          radius: 0.55,
          colors: [Color(0xFFFFD76A), Color(0xFFEF9A3D)],
        ).createShader(sun),
    );

    final farHill = Path()
      ..moveTo(11, 24.5)
      ..quadraticBezierTo(17, 19.9, 23, 23.5)
      ..quadraticBezierTo(30, 27.3, 37, 22.5)
      ..lineTo(37, 34.5)
      ..lineTo(11, 34.5)
      ..close();
    canvas.drawPath(farHill, Paint()..color = const Color(0xFF6E8F6A));

    final nearHill = Path()
      ..moveTo(11, 27.5)
      ..quadraticBezierTo(18, 24.5, 24, 28.3)
      ..quadraticBezierTo(30, 31.3, 37, 27.3)
      ..lineTo(37, 36.3)
      ..lineTo(11, 36.3)
      ..close();
    canvas.drawPath(nearHill, Paint()..color = const Color(0xFF3E5C44));
    canvas.restore();

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = _ink,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
