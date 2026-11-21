import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Tachyo mark: a tachometer arc that runs from download blue to upload
/// green around a down/up arrow pair, on a near-black Astryx tile.
///
/// This painter is the single source of the app icon: tool/render_icon_test.dart
/// renders it to PNG and tool/make_icons.ps1 produces the Android mipmaps and
/// Windows .ico from that PNG.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48, this.withTile = true});
  final double size;
  final bool withTile;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: LogoPainter(withTile: withTile));
}

class LogoPainter extends CustomPainter {
  const LogoPainter({this.withTile = true, this.contentScale = 1});
  final bool withTile;

  /// < 1 shrinks the mark inside the canvas (Android adaptive-icon safe zone).
  final double contentScale;

  static const blue = Color(0xFF6D9CFE);
  static const green = Color(0xFF64AF4C);
  static const tileTop = Color(0xFF303030);
  static const tileBottom = Color(0xFF111111);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size.square(s);
    if (withTile) {
      final tile = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.225));
      canvas.drawRRect(
        tile,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tileTop, tileBottom],
          ).createShader(rect),
      );
    }

    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.scale(contentScale);
    canvas.translate(-s / 2, -s / 2);

    final c = Offset(s / 2, s * 0.53);
    final r = s * 0.31;
    final stroke = s * 0.075;
    const startAngle = math.pi * 0.75; // 135deg, lower-left
    const sweep = math.pi * 1.5; // 270deg tachometer

    // Track.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      startAngle,
      sweep,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    // Value arc, blue -> green.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      startAngle,
      sweep * 0.78,
      false,
      Paint()
        ..shader = const SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          transform: GradientRotation(startAngle),
          colors: [blue, blue, green, green, blue, blue],
          stops: [0, 0.12, 0.5, 0.8, 0.95, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r))
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    // Tip dot at the arc end.
    final tipAngle = startAngle + sweep * 0.78;
    canvas.drawCircle(
      c + Offset(math.cos(tipAngle), math.sin(tipAngle)) * r,
      stroke * 0.72,
      Paint()..color = Colors.white,
    );

    // Arrows: down (blue) on the left, up (green) on the right.
    final aw = s * 0.075; // shaft half-width
    final ah = s * 0.30; // arrow height
    _arrow(canvas, Offset(c.dx - s * 0.105, c.dy), aw, ah, down: true, color: blue);
    _arrow(canvas, Offset(c.dx + s * 0.105, c.dy), aw, ah, down: false, color: green);
    canvas.restore();
  }

  void _arrow(Canvas canvas, Offset center, double halfW, double h, {required bool down, required Color color}) {
    final dir = down ? 1.0 : -1.0;
    final headH = h * 0.42;
    final shaftW = halfW * 0.62;
    final top = center.dy - dir * h / 2; // tail end
    final tip = center.dy + dir * h / 2;
    final headBase = tip - dir * headH;
    final path = Path()
      ..moveTo(center.dx - shaftW, top)
      ..lineTo(center.dx + shaftW, top)
      ..lineTo(center.dx + shaftW, headBase)
      ..lineTo(center.dx + halfW * 1.45, headBase)
      ..lineTo(center.dx, tip)
      ..lineTo(center.dx - halfW * 1.45, headBase)
      ..lineTo(center.dx - shaftW, headBase)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(LogoPainter old) => old.withTile != withTile || old.contentScale != contentScale;
}
