import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Векторная реконструкция логотипа «Строй На Века» для анимации запуска.
/// Никаких нарезанных PNG: щит, стены, кирпичи, башни, крыши и надпись
/// рисуются отдельными примитивами и собираются по ходу анимации.
class StroyNaVekaLogoScene extends StatelessWidget {
  final double shieldProgress;
  final double wallProgress;
  final double towerProgress;
  final double roofProgress;
  final double titleProgress;
  final double settleProgress;

  const StroyNaVekaLogoScene({
    super.key,
    required this.shieldProgress,
    required this.wallProgress,
    required this.towerProgress,
    required this.roofProgress,
    required this.titleProgress,
    required this.settleProgress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 236,
      height: 258,
      child: CustomPaint(
        painter: _StroyNaVekaPainter(
          shieldProgress: shieldProgress,
          wallProgress: wallProgress,
          towerProgress: towerProgress,
          roofProgress: roofProgress,
          titleProgress: titleProgress,
          settleProgress: settleProgress,
        ),
      ),
    );
  }
}

class _StroyNaVekaPainter extends CustomPainter {
  static const Color _blue = Color(0xFF2E59A0);
  static const Color _blueDark = Color(0xFF244A8D);
  static const Color _blueSoft = Color(0xFF4B73B7);
  static const Color _white = Color(0xFFF8FAFD);

  final double shieldProgress;
  final double wallProgress;
  final double towerProgress;
  final double roofProgress;
  final double titleProgress;
  final double settleProgress;

  const _StroyNaVekaPainter({
    required this.shieldProgress,
    required this.wallProgress,
    required this.towerProgress,
    required this.roofProgress,
    required this.titleProgress,
    required this.settleProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 236;
    final sy = size.height / 258;
    canvas.save();
    canvas.scale(sx, sy);

    _drawShield(canvas);
    _drawTopChevron(canvas);
    _drawCentralWall(canvas);
    _drawTower(canvas, left: true);
    _drawTower(canvas, left: false);
    _drawRoofs(canvas);
    _drawTitleBlock(canvas);
    _drawGroundSpark(canvas);

    canvas.restore();
  }

  void _drawShield(Canvas canvas) {
    final p = _ease(shieldProgress);
    if (p <= 0) return;

    final outer = Path()
      ..moveTo(118, 8)
      ..lineTo(212, 60)
      ..lineTo(212, 172)
      ..lineTo(118, 244)
      ..lineTo(24, 172)
      ..lineTo(24, 60)
      ..close();

    final inner = Path()
      ..moveTo(118, 21)
      ..lineTo(199, 66)
      ..lineTo(199, 165)
      ..lineTo(118, 228)
      ..lineTo(37, 165)
      ..lineTo(37, 66)
      ..close();

    canvas.drawPath(
      outer,
      Paint()..color = _blue.withValues(alpha: 0.12 + (0.88 * p)),
    );

    final border = Paint()
      ..color = _blueDark.withValues(alpha: p)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeJoin = StrokeJoin.round;
    _drawPartialPath(canvas, outer, border, p);

    final innerBorder = Paint()
      ..color = _white.withValues(alpha: 0.96 * p)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    _drawPartialPath(canvas, inner, innerBorder, _interval(p, 0.18, 1.0));
  }

  void _drawTopChevron(Canvas canvas) {
    final p = _interval(shieldProgress, 0.32, 1.0);
    if (p <= 0) return;

    final paint = Paint()
      ..color = _white.withValues(alpha: p)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final upper = Path()
      ..moveTo(70, 57)
      ..lineTo(118, 30)
      ..lineTo(166, 57);
    _drawPartialPath(canvas, upper, paint, p);

    final lower = Path()
      ..moveTo(80, 67)
      ..lineTo(118, 46)
      ..lineTo(156, 67);
    final thin = Paint()
      ..color = _blueSoft.withValues(alpha: 0.9 * p)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    _drawPartialPath(canvas, lower, thin, _interval(p, 0.24, 1));
  }

  void _drawCentralWall(Canvas canvas) {
    final p = _ease(wallProgress);
    if (p <= 0) return;

    const left = 77.0;
    const right = 159.0;
    const bottom = 150.0;
    const brickH = 11.0;
    const rows = 6;

    for (var row = 0; row < rows; row++) {
      final rowStart = row / (rows + 1);
      final rowP = _interval(p, rowStart, math.min(1.0, rowStart + 0.42));
      if (rowP <= 0) continue;
      final y = bottom - ((row + 1) * brickH);
      final stagger = row.isOdd ? 6.0 : 0.0;
      final widths = row.isOdd
          ? <double>[18, 24, 24, 18]
          : <double>[22, 22, 22, 16];
      var x = left - stagger;
      for (var i = 0; i < widths.length; i++) {
        final local = _interval(rowP, i * 0.12, 0.54 + (i * 0.12));
        if (local <= 0) {
          x += widths[i];
          continue;
        }
        final rect = Rect.fromLTWH(
          x,
          y + (8 * (1 - local)),
          widths[i] - 1.5,
          brickH - 1.5,
        );
        _drawBrick(canvas, rect, local);
        x += widths[i];
        if (x >= right) break;
      }
    }

    final battlementP = _interval(p, 0.62, 1.0);
    if (battlementP > 0) {
      for (var i = 0; i < 5; i++) {
        final local = _interval(battlementP, i * 0.08, 0.58 + (i * 0.08));
        _drawBrick(
          canvas,
          Rect.fromLTWH(81 + (i * 15), 75 + (7 * (1 - local)), 10, 12),
          local,
        );
      }
    }
  }

  void _drawTower(Canvas canvas, {required bool left}) {
    final p = _ease(towerProgress);
    if (p <= 0) return;

    final cx = left ? 59.0 : 177.0;
    const bottom = 151.0;
    const width = 34.0;
    const rows = 8;
    const brickH = 10.5;
    final sideOffset = left ? 0.0 : 0.035;

    for (var row = 0; row < rows; row++) {
      final start = (row / (rows + 1)) + sideOffset;
      final rowP = _interval(p, start, math.min(1.0, start + 0.36));
      if (rowP <= 0) continue;
      final y = bottom - ((row + 1) * brickH);
      final offset = row.isOdd ? 4.0 : 0.0;
      final firstW = row.isOdd ? 14.0 : 18.0;
      final secondW = width - firstW;
      _drawBrick(
        canvas,
        Rect.fromLTWH(
          cx - (width / 2) - offset,
          y + (10 * (1 - rowP)),
          firstW + offset - 1.4,
          brickH - 1.3,
        ),
        rowP,
      );
      _drawBrick(
        canvas,
        Rect.fromLTWH(
          cx - (width / 2) + firstW,
          y + (10 * (1 - rowP)),
          secondW + offset - 1.4,
          brickH - 1.3,
        ),
        _interval(rowP, 0.10, 1),
      );
    }

    final bodyP = _interval(p, 0.20, 1);
    if (bodyP > 0) {
      final outline = Paint()
        ..color = _blueDark.withValues(alpha: 0.94 * bodyP)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 18, 63, 36, 89),
          const Radius.circular(7),
        ),
        outline,
      );
      _drawTowerWindow(canvas, cx, 91, bodyP);
      _drawTowerWindow(canvas, cx, 121, bodyP);
    }

    final crownP = _interval(p, 0.70, 1);
    if (crownP > 0) {
      final y = 58 + (9 * (1 - crownP));
      final cap = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 21, y, 42, 14),
        const Radius.circular(4),
      );
      canvas.drawRRect(cap, Paint()..color = _white.withValues(alpha: crownP));
      canvas.drawRRect(
        cap,
        Paint()
          ..color = _blueDark.withValues(alpha: crownP)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (var i = 0; i < 4; i++) {
        _drawBrick(
          canvas,
          Rect.fromLTWH(cx - 18 + (i * 11), y - 7, 7, 9),
          _interval(crownP, i * 0.08, 0.65 + (i * 0.08)),
        );
      }
    }
  }

  void _drawRoofs(Canvas canvas) {
    final p = _ease(roofProgress);
    if (p <= 0) return;

    for (final left in <bool>[true, false]) {
      final cx = left ? 59.0 : 177.0;
      final local = _interval(p, left ? 0.0 : 0.07, 1);
      if (local <= 0) continue;
      final tipY = 21 + (28 * (1 - local));
      final baseY = 61 + (11 * (1 - local));
      final roof = Path()
        ..moveTo(cx, tipY)
        ..lineTo(cx - 22, baseY)
        ..lineTo(cx + 22, baseY)
        ..close();
      canvas.drawPath(roof, Paint()..color = _white.withValues(alpha: local));
      canvas.drawPath(
        roof,
        Paint()
          ..color = _blueDark.withValues(alpha: local)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
      final stripes = Paint()
        ..color = _blueSoft.withValues(alpha: 0.8 * local)
        ..strokeWidth = 1.2;
      for (var i = 1; i <= 3; i++) {
        final y = tipY + ((baseY - tipY) * (i / 4));
        final half = 5 + (i * 4.1);
        canvas.drawLine(Offset(cx - half, y), Offset(cx + half, y), stripes);
      }
    }
  }

  void _drawTitleBlock(Canvas canvas) {
    final p = _ease(titleProgress);
    if (p <= 0) return;

    final panel = Path()
      ..moveTo(39, 151)
      ..lineTo(197, 151)
      ..lineTo(181, 204)
      ..lineTo(55, 204)
      ..close();
    canvas.drawPath(panel, Paint()..color = _blueDark.withValues(alpha: 0.96 * p));

    final tp1 = TextPainter(
      text: TextSpan(
        text: 'СТРОЙ',
        style: TextStyle(
          color: _white.withValues(alpha: p),
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp1.paint(canvas, Offset(118 - (tp1.width / 2), 159 + (5 * (1 - p))));

    final tp2 = TextPainter(
      text: TextSpan(
        text: 'НА ВЕКА',
        style: TextStyle(
          color: _white.withValues(alpha: p),
          fontSize: 23,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(118 - (tp2.width / 2), 178 + (6 * (1 - p))));

    final linePaint = Paint()
      ..color = _white.withValues(alpha: p)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(72, 213), const Offset(107, 213), linePaint);
    canvas.drawLine(const Offset(129, 213), const Offset(164, 213), linePaint);
    final diamond = Path()
      ..moveTo(118, 207)
      ..lineTo(124, 213)
      ..lineTo(118, 219)
      ..lineTo(112, 213)
      ..close();
    canvas.drawPath(diamond, Paint()..color = _white.withValues(alpha: p));
  }

  void _drawTowerWindow(Canvas canvas, double cx, double y, double p) {
    final window = Path()
      ..moveTo(cx - 4.5, y + 8)
      ..lineTo(cx - 4.5, y)
      ..quadraticBezierTo(cx, y - 6, cx + 4.5, y)
      ..lineTo(cx + 4.5, y + 8)
      ..close();
    canvas.drawPath(window, Paint()..color = _blueDark.withValues(alpha: 0.9 * p));
  }

  void _drawBrick(Canvas canvas, Rect rect, double p) {
    if (p <= 0) return;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(1.4));
    canvas.drawRRect(r, Paint()..color = _white.withValues(alpha: 0.98 * p));
    canvas.drawRRect(
      r,
      Paint()
        ..color = _blueSoft.withValues(alpha: 0.88 * p)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  void _drawGroundSpark(Canvas canvas) {
    final fade = _ease(1 - settleProgress);
    if (fade <= 0.02 || towerProgress <= 0.05) return;
    final active = _clamp01(towerProgress * (1 - towerProgress) * 3.4) * fade;
    if (active <= 0) return;
    final paint = Paint()
      ..color = _blueSoft.withValues(alpha: 0.25 * active)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final y = 153 - (72 * towerProgress);
    for (var i = 0; i < 6; i++) {
      final x = 54 + (i * 25.5);
      final dx = i.isEven ? -8.0 : 8.0;
      canvas.drawLine(Offset(x, y), Offset(x + dx, y - 8 - (i % 2) * 3), paint);
    }
  }

  void _drawPartialPath(Canvas canvas, Path path, Paint paint, double progress) {
    final p = _clamp01(progress);
    if (p <= 0) return;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * p), paint);
    }
  }

  double _ease(double value) => Curves.easeOutCubic.transform(_clamp01(value));

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
  bool shouldRepaint(covariant _StroyNaVekaPainter oldDelegate) {
    return oldDelegate.shieldProgress != shieldProgress ||
        oldDelegate.wallProgress != wallProgress ||
        oldDelegate.towerProgress != towerProgress ||
        oldDelegate.roofProgress != roofProgress ||
        oldDelegate.titleProgress != titleProgress ||
        oldDelegate.settleProgress != settleProgress;
  }
}
