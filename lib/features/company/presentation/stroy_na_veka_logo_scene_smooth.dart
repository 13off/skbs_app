import 'package:flutter/material.dart';

/// Лёгкая векторная сцена «Строй На Века» для splash-анимации.
/// Рисуется примитивами, без bitmap-логотипа, PathMetric и layout на каждом кадре.
class SmoothStroyNaVekaLogoScene extends StatelessWidget {
  final Animation<double> animation;

  const SmoothStroyNaVekaLogoScene({
    super.key,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(236, 258),
        isComplex: false,
        willChange: true,
        painter: _SmoothStroyNaVekaPainter(animation),
      ),
    );
  }
}

class _SmoothStroyNaVekaPainter extends CustomPainter {
  static const Color _blue = Color(0xFF315B9D);
  static const Color _blueDark = Color(0xFF23477F);
  static const Color _blueSoft = Color(0xFF6686BA);
  static const Color _white = Color(0xFFF7F9FC);

  final Animation<double> animation;
  late final TextPainter _title1;
  late final TextPainter _title2;

  _SmoothStroyNaVekaPainter(this.animation) : super(repaint: animation) {
    _title1 = TextPainter(
      text: const TextSpan(
        text: 'СТРОЙ',
        style: TextStyle(
          color: _white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _title2 = TextPainter(
      text: const TextSpan(
        text: 'НА ВЕКА',
        style: TextStyle(
          color: _white,
          fontSize: 23,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final phase = _phase(animation.value);
    if (phase <= 0) return;

    final sx = size.width / 236;
    final sy = size.height / 258;
    canvas.save();
    canvas.scale(sx, sy);

    final silhouette = _interval(phase, 0.00, 0.24);
    final wall = _interval(phase, 0.10, 0.55);
    final towers = _interval(phase, 0.22, 0.72);
    final roofs = _interval(phase, 0.56, 0.82);
    final title = _interval(phase, 0.72, 0.94);
    final settle = _interval(phase, 0.90, 1.00);

    _drawShield(canvas, silhouette);
    _drawWall(canvas, wall);
    _drawTower(canvas, 59, towers, 0.00);
    _drawTower(canvas, 177, towers, 0.05);
    _drawRoof(canvas, 59, roofs);
    _drawRoof(canvas, 177, _interval(roofs, 0.08, 1));
    _drawTitle(canvas, title);
    _drawAccent(canvas, towers, settle);

    canvas.restore();
  }

  double _phase(double value) => _clamp01((value - 0.50) / 0.50);

  void _drawShield(Canvas canvas, double p) {
    if (p <= 0) return;
    final eased = Curves.easeOutCubic.transform(p);
    final scale = 0.78 + (0.22 * eased);
    canvas.save();
    canvas.translate(118, 126);
    canvas.scale(scale, scale);
    canvas.translate(-118, -126);

    final outer = Path()
      ..moveTo(118, 8)
      ..lineTo(212, 60)
      ..lineTo(212, 172)
      ..lineTo(118, 244)
      ..lineTo(24, 172)
      ..lineTo(24, 60)
      ..close();
    canvas.drawPath(
      outer,
      Paint()..color = _blue.withValues(alpha: 0.12 + (0.88 * eased)),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..color = _blueDark.withValues(alpha: eased)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeJoin = StrokeJoin.round,
    );

    final inner = Path()
      ..moveTo(118, 23)
      ..lineTo(198, 67)
      ..lineTo(198, 164)
      ..lineTo(118, 226)
      ..lineTo(38, 164)
      ..lineTo(38, 67)
      ..close();
    canvas.drawPath(
      inner,
      Paint()
        ..color = _white.withValues(alpha: 0.92 * eased)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  void _drawWall(Canvas canvas, double p) {
    if (p <= 0) return;
    const rows = 5;
    const columns = 4;
    const left = 76.0;
    const bottom = 151.0;
    const brickW = 21.0;
    const brickH = 13.0;

    for (var row = 0; row < rows; row++) {
      final rp = _interval(p, row * 0.12, 0.48 + (row * 0.12));
      if (rp <= 0) continue;
      for (var col = 0; col < columns; col++) {
        final cp = _interval(rp, col * 0.08, 0.66 + (col * 0.08));
        if (cp <= 0) continue;
        final x = left + (col * brickW) - (row.isOdd ? 7 : 0);
        final y = bottom - ((row + 1) * brickH) + (8 * (1 - cp));
        _brick(canvas, Rect.fromLTWH(x, y, brickW - 2, brickH - 2), cp);
      }
    }

    final crown = _interval(p, 0.64, 1);
    for (var i = 0; i < 5; i++) {
      final cp = _interval(crown, i * 0.08, 0.65 + (i * 0.08));
      if (cp <= 0) continue;
      _brick(canvas, Rect.fromLTWH(81 + (i * 15), 78 + (7 * (1 - cp)), 10, 12), cp);
    }
  }

  void _drawTower(Canvas canvas, double cx, double p, double delay) {
    final tp = _interval(p, delay, 1);
    if (tp <= 0) return;
    const rows = 6;
    const bottom = 151.0;
    const rowH = 13.5;

    for (var row = 0; row < rows; row++) {
      final rp = _interval(tp, row * 0.11, 0.46 + (row * 0.11));
      if (rp <= 0) continue;
      final y = bottom - ((row + 1) * rowH) + (11 * (1 - rp));
      final leftW = row.isOdd ? 15.0 : 18.0;
      _brick(canvas, Rect.fromLTWH(cx - 18, y, leftW - 1, rowH - 2), rp);
      _brick(
        canvas,
        Rect.fromLTWH(cx - 18 + leftW, y, 36 - leftW - 1, rowH - 2),
        _interval(rp, 0.10, 1),
      );
    }

    final outlineP = _interval(tp, 0.20, 1);
    if (outlineP > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 18, 67, 36, 84),
          const Radius.circular(6),
        ),
        Paint()
          ..color = _blueDark.withValues(alpha: outlineP)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _window(canvas, cx, 96, outlineP);
      _window(canvas, cx, 124, outlineP);
    }
  }

  void _drawRoof(Canvas canvas, double cx, double p) {
    if (p <= 0) return;
    final eased = Curves.easeOutBack.transform(_clamp01(p));
    final tipY = 22 + (35 * (1 - eased));
    final baseY = 68 + (16 * (1 - eased));
    final roof = Path()
      ..moveTo(cx, tipY)
      ..lineTo(cx - 23, baseY)
      ..lineTo(cx + 23, baseY)
      ..close();
    canvas.drawPath(roof, Paint()..color = _white);
    canvas.drawPath(
      roof,
      Paint()
        ..color = _blueDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawTitle(Canvas canvas, double p) {
    if (p <= 0) return;
    final eased = Curves.easeOutCubic.transform(p);
    final panel = Path()
      ..moveTo(39, 151)
      ..lineTo(197, 151)
      ..lineTo(181, 204)
      ..lineTo(55, 204)
      ..close();
    canvas.drawPath(panel, Paint()..color = _blueDark);

    canvas.save();
    final revealTop = 204 - (53 * eased);
    canvas.clipRect(Rect.fromLTRB(39, revealTop, 197, 222));
    final dy = 8 * (1 - eased);
    _title1.paint(canvas, Offset(118 - (_title1.width / 2), 159 + dy));
    _title2.paint(canvas, Offset(118 - (_title2.width / 2), 178 + dy));
    canvas.restore();

    if (eased > 0.55) {
      final ornaments = _interval(eased, 0.55, 1);
      final paint = Paint()
        ..color = _white.withValues(alpha: ornaments)
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(72, 213), const Offset(107, 213), paint);
      canvas.drawLine(const Offset(129, 213), const Offset(164, 213), paint);
    }
  }

  void _drawAccent(Canvas canvas, double towers, double settle) {
    final active = _clamp01(towers * (1 - towers) * 3.2) * (1 - settle);
    if (active <= 0.02) return;
    final paint = Paint()
      ..color = _blueSoft.withValues(alpha: 0.18 * active)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final y = 151 - (68 * towers);
    for (var i = 0; i < 4; i++) {
      final x = 61 + (i * 38.0);
      canvas.drawLine(Offset(x, y), Offset(x + (i.isEven ? -7 : 7), y - 8), paint);
    }
  }

  void _window(Canvas canvas, double cx, double y, double p) {
    final path = Path()
      ..moveTo(cx - 4, y + 8)
      ..lineTo(cx - 4, y)
      ..quadraticBezierTo(cx, y - 5, cx + 4, y)
      ..lineTo(cx + 4, y + 8)
      ..close();
    canvas.drawPath(path, Paint()..color = _blueDark.withValues(alpha: 0.88 * p));
  }

  void _brick(Canvas canvas, Rect rect, double p) {
    if (p <= 0) return;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(1.3));
    canvas.drawRRect(r, Paint()..color = _white.withValues(alpha: 0.98 * p));
    canvas.drawRRect(
      r,
      Paint()
        ..color = _blueSoft.withValues(alpha: 0.78 * p)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  double _interval(double value, double begin, double end) {
    if (value <= begin) return 0;
    if (value >= end) return 1;
    return Curves.easeOutCubic.transform((value - begin) / (end - begin));
  }

  double _clamp01(double value) {
    if (value <= 0) return 0;
    if (value >= 1) return 1;
    return value;
  }

  @override
  bool shouldRepaint(covariant _SmoothStroyNaVekaPainter oldDelegate) => false;
}